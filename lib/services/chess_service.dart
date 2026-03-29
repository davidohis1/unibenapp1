import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chess/chess.dart';
import '../models/chess_game_model.dart';

class ChessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // LOBBY MANAGEMENT
  // ============================================================
  

  /// Find an open waiting game or create one.
  /// Returns the [ChessGameModel] — caller should watch [getGameStream]
  /// and navigate when status flips to 'active'.
  Future<ChessGameModel> findOrCreateGame(
      String userId, String username, String? avatarUrl) async {
    // 1. Clean up stale waiting games (older than 2 minutes)
    await _cleanStaleWaitingGames();

    // 2. Check if this user is already in a waiting game
    final myWaiting = await _firestore
        .collection('chess_games')
        .where('players', arrayContains: userId)
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (myWaiting.docs.isNotEmpty) {
      return ChessGameModel.fromMap(myWaiting.docs.first.data());
    }

    // 3. Look for someone else's waiting game (1 player, not us)
    final open = await _firestore
        .collection('chess_games')
        .where('status', isEqualTo: 'waiting')
        .limit(20)
        .get();

    DocumentSnapshot? available;
    for (final doc in open.docs) {
      final players = List<String>.from(doc['players'] ?? []);
      if (players.length == 1 && !players.contains(userId)) {
        available = doc;
        break;
      }
    }

    if (available != null) {
      // Join and start the game
      return await _joinAndStartGame(available, userId, username, avatarUrl);
    }

    // 4. No open game — create one
    return await _createWaitingGame(userId, username, avatarUrl);
  }

  /// Joins an existing 1-player game and flips it to 'active'.
  Future<ChessGameModel> _joinAndStartGame(DocumentSnapshot doc, String userId,
      String username, String? avatarUrl) async {
    final gameRef = doc.reference;
    final data = doc.data() as Map<String, dynamic>;

    final players = List<String>.from(data['players'] ?? []);
    players.add(userId);

    final playerNames = Map<String, String>.from(data['playerNames'] ?? {});
    playerNames[userId] = username;

    final playerAvatars = Map<String, String>.from(data['playerAvatars'] ?? {});
    if (avatarUrl != null) playerAvatars[userId] = avatarUrl;

    final now = DateTime.now();
    final timers = <String, int>{
      players[0]: 420,
      players[1]: 420,
    };

    // Deduct fees for both players
    await _deductEntryFee(players[0]);
    await _deductEntryFee(players[1]);

    await gameRef.update({
      'players': players,
      'playerNames': playerNames,
      'playerAvatars': playerAvatars,
      'status': 'active',
      'startedAt': Timestamp.fromDate(now),
      'lastMoveTime': Timestamp.fromDate(now),
      'currentTurn': players[0], // white (creator) goes first
      'timers': timers,
    });

    final updated = await gameRef.get();
    return ChessGameModel.fromMap(updated.data() as Map<String, dynamic>);
  }

  /// Creates a new waiting game for a single player.
  Future<ChessGameModel> _createWaitingGame(
      String userId, String username, String? avatarUrl) async {
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
    return game;
  }

  /// Deletes waiting games that are older than 2 minutes.
  Future<void> _cleanStaleWaitingGames() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
      final stale = await _firestore
          .collection('chess_games')
          .where('status', isEqualTo: 'waiting')
          .get();

      final batch = _firestore.batch();
      bool hasDeletions = false;

      for (final doc in stale.docs) {
        final data = doc.data();
        DateTime? createdAt;
        final raw = data['createdAt'];
        if (raw is Timestamp) {
          createdAt = raw.toDate();
        } else if (raw is String) {
          createdAt = DateTime.tryParse(raw);
        }

        if (createdAt != null && createdAt.isBefore(cutoff)) {
          batch.delete(doc.reference);
          hasDeletions = true;
        }
      }

      if (hasDeletions) await batch.commit();
    } catch (e) {
      // Non-fatal — just log
      print('Stale cleanup error: $e');
    }
  }

  // ============================================================
  // GAME PLAY
  // ============================================================

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

    if (game.currentTurn != userId) throw Exception('Not your turn');
    if (game.status != ChessGameStatus.active) throw Exception('Game is not active');

    final chess = Chess.fromFEN(game.fen);

    // chess.dart requires a Map, not a string like 'e2e4'
    final moveMap = <String, String>{'from': from, 'to': to};
    if (promotion != null) moveMap['promotion'] = promotion;

    final success = chess.move(moveMap);
    if (!success) throw Exception('Invalid move');

    final isCheckmate = chess.in_checkmate;
    final isStalemate = chess.in_stalemate;
    final isDraw = chess.in_draw || chess.insufficient_material;

    // Update timer for the player who just moved
    final now = DateTime.now();
    final lastMove = game.lastMoveTime ?? game.startedAt ?? now;
    final elapsed = now.difference(lastMove).inSeconds;

    final timers = Map<String, int>.from(game.timers);
    final remaining = (timers[userId] ?? 420) - elapsed;

    if (remaining <= 0) {
      final opponentId = game.getOpponentId(userId);
      if (opponentId != null) {
        await _endGameWithWinner(gameRef, opponentId, 'timeout');
      }
      return;
    }

    timers[userId] = remaining;
    final nextTurn = game.getOpponentId(userId);

    final updates = <String, dynamic>{
      'fen': chess.fen,
      'currentTurn': nextTurn,
      'lastMoveTime': Timestamp.fromDate(now),
      'timers': timers,
      'moveHistory': FieldValue.arrayUnion(['$from$to']),
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

  Future<void> offerDraw(String gameId, String userId) async {
    await _firestore
        .collection('chess_games')
        .doc(gameId)
        .update({'drawOfferBy': userId});
  }

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

  Future<void> declineDraw(String gameId) async {
    await _firestore
        .collection('chess_games')
        .doc(gameId)
        .update({'drawOfferBy': null});
  }

  Future<void> offerRematch(String gameId, String userId) async {
    await _firestore
        .collection('chess_games')
        .doc(gameId)
        .update({'rematchOfferBy': userId});
  }

  Future<ChessGameModel> acceptRematch(String gameId, String userId) async {
    final gameDoc =
        await _firestore.collection('chess_games').doc(gameId).get();
    if (!gameDoc.exists) throw Exception('Game not found');

    final oldGame = ChessGameModel.fromMap(gameDoc.data()!);
    // Swap colors for rematch
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
      timers: {players[0]: 420, players[1]: 420},
    );

    await newGameRef.set(newGame.toMap());
    await _deductEntryFee(players[0]);
    await _deductEntryFee(players[1]);

    return newGame;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Future<void> _deductEntryFee(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'walletBalance': FieldValue.increment(-350),
    });
  }

  Future<void> _awardWinner(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'walletBalance': FieldValue.increment(500),
      'totalGamesWon': FieldValue.increment(1),
    });
  }

  Future<void> _refundPlayers(List<String> players) async {
    for (final id in players) {
      await _firestore.collection('users').doc(id).update({
        'walletBalance': FieldValue.increment(350),
      });
    }
  }

  Future<void> _endGameWithWinner(
      DocumentReference gameRef, String winnerId, String reason) async {
    await gameRef.update({
      'status': 'completed',
      'winnerId': winnerId,
      'endReason': reason,
      'endedAt': Timestamp.now(),
    });
    await _awardWinner(winnerId);
  }

  Stream<ChessGameModel?> getGameStream(String gameId) {
    return _firestore
        .collection('chess_games')
        .doc(gameId)
        .snapshots()
        .map((doc) => doc.exists
            ? ChessGameModel.fromMap(doc.data()!)
            : null);
  }

  /// All active or waiting games for this user.
  Stream<List<ChessGameModel>> getUserActiveGames(String userId) {
    return _firestore
        .collection('chess_games')
        .where('players', arrayContains: userId)
        .where('status', whereIn: ['waiting', 'active'])
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChessGameModel.fromMap(d.data()))
            .toList());
  }

  Future<void> leaveWaitingGame(String gameId, String userId) async {
    final gameRef = _firestore.collection('chess_games').doc(gameId);
    final gameDoc = await gameRef.get();
    if (!gameDoc.exists) return;

    final game = ChessGameModel.fromMap(gameDoc.data()!);
    if (game.status != ChessGameStatus.waiting) return;

    final updated = game.players.where((id) => id != userId).toList();
    if (updated.isEmpty) {
      await gameRef.delete();
    } else {
      await gameRef.update({'players': updated});
    }
  }

  // Periodic stale-game cleanup — call this from a background isolate or
  // just invoke it on lobby screen mount so it runs client-side.
  Future<void> runPeriodicCleanup() => _cleanStaleWaitingGames();
}