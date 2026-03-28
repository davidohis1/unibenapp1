import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chess/chess.dart';
import '../models/chess_game_model.dart';

class ChessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============== LOBBY MANAGEMENT ==============

  // Find or create a game
  // Find or create a game
Stream<ChessGameModel?> findOrCreateGame(String userId, String username, String? avatarUrl) {
  return _firestore
      .collection('chess_games')
      .where('status', isEqualTo: 'waiting')
      .snapshots()
      .asyncMap((snapshot) async {
    
    // First, check if user is already in any waiting game
    for (var doc in snapshot.docs) {
      final players = List<String>.from(doc['players'] ?? []);
      if (players.contains(userId)) {
        print('User already in waiting game: ${doc.id}');
        return ChessGameModel.fromMap(doc.data());
      }
    }
    
    // Look for a game with only 1 player (not full)
    DocumentSnapshot? availableGame;
    for (var doc in snapshot.docs) {
      final players = List<String>.from(doc['players'] ?? []);
      if (players.length == 1) {
        availableGame = doc;
        break;
      }
    }
    
    if (availableGame != null) {
      // Join existing game
      print('Joining existing game: ${availableGame.id}');
      final gameRef = availableGame.reference;
      final gameData = availableGame.data() as Map<String, dynamic>;
      final currentPlayers = List<String>.from(gameData['players'] ?? []);
      
      // Add user to game
      currentPlayers.add(userId);
      
      // Update player names and avatars
      final playerNames = Map<String, String>.from(gameData['playerNames'] ?? {});
      playerNames[userId] = username;
      
      final playerAvatars = Map<String, String>.from(gameData['playerAvatars'] ?? {});
      if (avatarUrl != null) {
        playerAvatars[userId] = avatarUrl;
      }

      // Start game immediately
      final now = DateTime.now();
      final timers = {
        currentPlayers[0]: 420,
        currentPlayers[1]: 420,
      };

      // Deduct entry fee from both players
      await _deductEntryFee(currentPlayers[0]);
      await _deductEntryFee(currentPlayers[1]);

      await gameRef.update({
        'players': currentPlayers,
        'playerNames': playerNames,
        'playerAvatars': playerAvatars,
        'status': 'active',
        'startedAt': Timestamp.fromDate(now),
        'lastMoveTime': Timestamp.fromDate(now),
        'currentTurn': currentPlayers[0],
        'timers': timers,
      });

      final updatedDoc = await gameRef.get();
      final updatedData = updatedDoc.data() as Map<String, dynamic>;
      return ChessGameModel.fromMap(updatedData);
    } else {
      // No available game, create new one
      print('Creating new game for user: $userId');
      return _createNewGame(userId, username, avatarUrl);
    }
  }).handleError((error) {
    print('Error in findOrCreateGame: $error');
    return null;
  });
}

  Future<ChessGameModel> _createNewGame(String userId, String username, String? avatarUrl) async {
  final gameRef = _firestore.collection('chess_games').doc();
  final now = DateTime.now();

  final game = ChessGameModel(
    id: gameRef.id,
    players: [userId],
    playerNames: {userId: username},
    playerAvatars: avatarUrl != null ? {userId: avatarUrl} : {},
    status: ChessGameStatus.waiting,
    createdAt: now,
  );

  await gameRef.set(game.toMap());
  print('New game created: ${gameRef.id}');
  return game;
}

  Future<void> _deductEntryFee(String userId) async {
    const entryFee = 350;
    await _firestore.collection('users').doc(userId).update({
      'walletBalance': FieldValue.increment(-entryFee),
    });
  }

  // ============== GAME PLAY ==============

  // Make a move
  Future<void> makeMove({
    required String gameId,
    required String userId,
    required String from,
    required String to,
    String? promotion,
  }) async {
    final gameRef = _firestore.collection('chess_games').doc(gameId);
    final gameDoc = await gameRef.get();
    
    if (!gameDoc.exists) throw Exception('Game not found');

    final game = ChessGameModel.fromMap(gameDoc.data()!);
    
    // Validate turn
    if (game.currentTurn != userId) {
      throw Exception('Not your turn');
    }

    if (game.status != ChessGameStatus.active) {
      throw Exception('Game is not active');
    }

    // Initialize chess library
    final chess = Chess.fromFEN(game.fen);
    
    // Make the move
    // Create a move using the chess library's move generator
    // Make the move
    final moveString = promotion != null ? '$from$to$promotion' : '$from$to';
    final success = chess.move(moveString);

    if (!success) {
      throw Exception('Invalid move');
    }

    // Check game end conditions
    final isCheckmate = chess.in_checkmate;
    final isStalemate = chess.in_stalemate;
    final isDraw = chess.in_draw || chess.insufficient_material;

    // Update timers
    final now = DateTime.now();
    final lastMove = game.lastMoveTime ?? game.startedAt ?? now;
    final timeDiff = now.difference(lastMove).inSeconds;
    
    final timers = Map<String, int>.from(game.timers);
    final currentTimer = (timers[userId] ?? 420) - timeDiff;
    
    if (currentTimer <= 0) {
      // Player ran out of time
      final opponentId = game.getOpponentId(userId);
      if (opponentId != null) {
        await _endGameWithWinner(gameRef, opponentId, 'timeout');
      }
      return;
    }
    
    timers[userId] = currentTimer;
    final nextTurn = game.getOpponentId(userId);

    // Update game
    final updates = {
      'fen': chess.fen,
      'currentTurn': nextTurn,
      'lastMoveTime': Timestamp.fromDate(now),
      'timers': timers,
    };

    if (isCheckmate) {
      updates['status'] = 'completed';
      updates['winnerId'] = userId;
      updates['endedAt'] = Timestamp.fromDate(now);
      await _awardWinner(userId);
    } else if (isStalemate || isDraw) {
      updates['status'] = 'completed';
      updates['endedAt'] = Timestamp.fromDate(now);
      await _refundPlayers(game.players);
    }

    await gameRef.update(updates);
  }

  // Resign game
  Future<void> resignGame(String gameId, String userId) async {
    final gameRef = _firestore.collection('chess_games').doc(gameId);
    final gameDoc = await gameRef.get();
    
    if (!gameDoc.exists) throw Exception('Game not found');

    final game = ChessGameModel.fromMap(gameDoc.data()!);
    final opponentId = game.getOpponentId(userId);

    if (opponentId == null) throw Exception('Opponent not found');

    await gameRef.update({
      'status': 'completed',
      'winnerId': opponentId,
      'endedAt': Timestamp.now(),
    });

    await _awardWinner(opponentId);
  }

  // Offer draw
  Future<void> offerDraw(String gameId, String userId) async {
    await _firestore.collection('chess_games').doc(gameId).update({
      'drawOfferBy': userId,
    });
  }

  // Accept draw
  Future<void> acceptDraw(String gameId, String userId) async {
    final gameRef = _firestore.collection('chess_games').doc(gameId);
    final gameDoc = await gameRef.get();
    
    if (!gameDoc.exists) throw Exception('Game not found');

    final game = ChessGameModel.fromMap(gameDoc.data()!);
    
    if (game.drawOfferBy == null || game.drawOfferBy == userId) {
      throw Exception('No draw offer to accept');
    }

    await gameRef.update({
      'status': 'completed',
      'endedAt': Timestamp.now(),
    });

    await _refundPlayers(game.players);
  }

  // Decline draw
  Future<void> declineDraw(String gameId) async {
    await _firestore.collection('chess_games').doc(gameId).update({
      'drawOfferBy': null,
    });
  }

  // Offer rematch
  Future<void> offerRematch(String gameId, String userId) async {
    await _firestore.collection('chess_games').doc(gameId).update({
      'rematchOfferBy': userId,
    });
  }

  // Accept rematch
  Future<ChessGameModel> acceptRematch(String gameId, String userId) async {
    final gameDoc = await _firestore.collection('chess_games').doc(gameId).get();
    if (!gameDoc.exists) throw Exception('Game not found');

    final oldGame = ChessGameModel.fromMap(gameDoc.data()!);
    
    final players = [oldGame.players[1], oldGame.players[0]];
    
    final newGameRef = _firestore.collection('chess_games').doc();
    final now = DateTime.now();

    final newGame = ChessGameModel(
      id: newGameRef.id,
      players: players,
      playerNames: oldGame.playerNames,
      playerAvatars: oldGame.playerAvatars,
      status: ChessGameStatus.active,
      createdAt: now,
      startedAt: now,
      lastMoveTime: now,
      currentTurn: players[0],
      timers: {
        players[0]: 420,
        players[1]: 420,
      },
    );

    await newGameRef.set(newGame.toMap());
    
    await _deductEntryFee(players[0]);
    await _deductEntryFee(players[1]);

    return newGame;
  }

  // Check for timeout
  Future<void> checkTimeouts(String gameId) async {
    final gameDoc = await _firestore.collection('chess_games').doc(gameId).get();
    if (!gameDoc.exists) return;

    final game = ChessGameModel.fromMap(gameDoc.data()!);
    
    if (game.status != ChessGameStatus.active) return;
    if (game.lastMoveTime == null) return;

    final now = DateTime.now();
    final currentPlayerId = game.currentTurn;
    
    if (currentPlayerId == null) return;

    final timeDiff = now.difference(game.lastMoveTime!).inSeconds;
    final playerTimer = game.getPlayerTimer(currentPlayerId);

    if (timeDiff > playerTimer) {
      final opponentId = game.getOpponentId(currentPlayerId);
      if (opponentId != null) {
        await _endGameWithWinner(gameDoc.reference, opponentId, 'timeout');
      }
    }
  }

  // ============== HELPER METHODS ==============

  Future<void> _awardWinner(String userId) async {
    const prize = 600;
    await _firestore.collection('users').doc(userId).update({
      'walletBalance': FieldValue.increment(prize),
      'totalGamesWon': FieldValue.increment(1),
    });
  }

  Future<void> _refundPlayers(List<String> players) async {
    const refund = 350;
    for (final playerId in players) {
      await _firestore.collection('users').doc(playerId).update({
        'walletBalance': FieldValue.increment(refund),
      });
    }
  }

  Future<void> _endGameWithWinner(DocumentReference gameRef, String winnerId, String reason) async {
    await gameRef.update({
      'status': 'completed',
      'winnerId': winnerId,
      'endedAt': Timestamp.now(),
    });
    await _awardWinner(winnerId);
  }

  // Get game stream
  Stream<ChessGameModel?> getGameStream(String gameId) {
    return _firestore
        .collection('chess_games')
        .doc(gameId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return ChessGameModel.fromMap(doc.data()!);
        });
  }

  // Get user's active games
  Stream<List<ChessGameModel>> getUserActiveGames(String userId) {
    return _firestore
        .collection('chess_games')
        .where('players', arrayContains: userId)
        .where('status', whereIn: ['waiting', 'active'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChessGameModel.fromMap(doc.data()))
              .toList();
        });
  }

  // Leave waiting game
  Future<void> leaveWaitingGame(String gameId, String userId) async {
    final gameRef = _firestore.collection('chess_games').doc(gameId);
    final gameDoc = await gameRef.get();
    
    if (!gameDoc.exists) return;

    final game = ChessGameModel.fromMap(gameDoc.data()!);
    
    if (game.status != ChessGameStatus.waiting) return;
    
    final updatedPlayers = game.players.where((id) => id != userId).toList();
    
    if (updatedPlayers.isEmpty) {
      await gameRef.delete();
    } else {
      await gameRef.update({'players': updatedPlayers});
    }
  }
}