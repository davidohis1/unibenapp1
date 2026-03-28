import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/quiz_game_model.dart';
import '../models/game_participant_model.dart';
import '../models/quiz_question_model.dart';

class QuizGameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============== GAME MANAGEMENT ==============

  // Get active game (waiting for players) - auto-creates if none exists
  Stream<QuizGameModel?> getActiveGame() {
    return _firestore
        .collection('quiz_games')
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) {
        // No active game exists, create one automatically
        print('No active game found, creating new game...');
        try {
          final newGameRef = _firestore.collection('quiz_games').doc();
          final newGame = QuizGameModel(
            id: newGameRef.id,
            createdAt: DateTime.now(),
          );
          
          await newGameRef.set(newGame.toMap());
          print('New game created: ${newGameRef.id}');
          
          return newGame;
        } catch (e) {
          print('Error creating new game: $e');
          return null;
        }
      }
      
      return QuizGameModel.fromMap(snapshot.docs.first.data());
    });
  }

  // Get all games (for history)
  Stream<List<QuizGameModel>> getAllGames() {
    return _firestore
        .collection('quiz_games')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => QuizGameModel.fromMap(doc.data())).toList());
  }

  // Get game by ID
  Future<QuizGameModel?> getGameById(String gameId) async {
    try {
      final doc = await _firestore.collection('quiz_games').doc(gameId).get();
      if (doc.exists) {
        return QuizGameModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting game: $e');
      return null;
    }
  }

  // Join game
  // Join game
Future<bool> joinGame(String gameId, String userId, String username, String? profileImageUrl) async {
  try {
    return await _firestore.runTransaction((transaction) async {
      try {
        // Get game
        final gameRef = _firestore.collection('quiz_games').doc(gameId);
        final gameDoc = await transaction.get(gameRef);
        
        if (!gameDoc.exists) {
          throw Exception('Game not found');
        }

        final game = QuizGameModel.fromMap(gameDoc.data()!);

        // Check if game is full
        if (game.currentPlayers >= game.maxPlayers) {
          throw Exception('Game is full');
        }

        // Check if game is still accepting players
        if (game.status != 'waiting') {
          throw Exception('Game is no longer accepting players');
        }

        // Check if user already joined
        final participantRef = gameRef.collection('participants').doc(userId);
        final participantDoc = await transaction.get(participantRef);
        
        if (participantDoc.exists) {
          throw Exception('You have already joined this game');
        }

        // Deduct entry fee from user wallet
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data();
        if (userData == null) {
          throw Exception('User data not found');
        }

        final currentBalance = (userData['walletBalance'] ?? 0).toDouble();
        
        if (currentBalance < game.entryFee) {
          throw Exception('Insufficient balance. You need ₦${game.entryFee}');
        }

        // Get 20 random questions for this user
        final questionsSnapshot = await _firestore
            .collection('quiz_questions')
            .get();

        if (questionsSnapshot.docs.length < 20) {
          throw Exception('Not enough questions available');
        }

        // Shuffle and pick 20 random questions
        final allQuestions = questionsSnapshot.docs;
        allQuestions.shuffle(Random());
        final selectedQuestionIds = allQuestions
            .take(20)
            .map((doc) => doc.id)
            .toList();

        // Create participant
        final participant = GameParticipantModel(
          userId: userId,
          username: username,
          profileImageUrl: profileImageUrl,
          joinedAt: DateTime.now(),
          questionIds: selectedQuestionIds,
          answers: List.filled(20, -1), // -1 means unanswered
        );

        // Update user wallet
        transaction.update(userRef, {
          'walletBalance': FieldValue.increment(-game.entryFee),
        });

        // Add participant
        transaction.set(participantRef, participant.toMap());

        // Update game
        final newPlayerCount = game.currentPlayers + 1;
        final newTotalPool = game.totalPool + game.entryFee;

        transaction.update(gameRef, {
          'currentPlayers': newPlayerCount,
          'totalPool': newTotalPool,
        });

        // If game is now full, schedule it
        if (newPlayerCount >= game.maxPlayers) {
          final tomorrow = DateTime.now().add(Duration(days: 1));
          
          // Random time between 3pm (15:00) and 6pm (18:00)
          final random = Random();
          final startHour = 15 + random.nextInt(3); // 15, 16, or 17
          final startMinute = random.nextInt(60);
          
          final scheduledStart = DateTime(
            tomorrow.year,
            tomorrow.month,
            tomorrow.day,
            startHour,
            startMinute,
          );

          final scheduledEnd = scheduledStart.add(Duration(hours: 3));

          transaction.update(gameRef, {
            'status': 'scheduled',
            'scheduledStartTime': Timestamp.fromDate(scheduledStart),
            'scheduledEndTime': Timestamp.fromDate(scheduledEnd),
          });

          // Create new game for next batch
          final newGameRef = _firestore.collection('quiz_games').doc();
          final newGame = QuizGameModel(
            id: newGameRef.id,
            createdAt: DateTime.now(),
          );
          transaction.set(newGameRef, newGame.toMap());
        }

        return true;
      } catch (e) {
        print('Transaction error: $e');
        throw Exception('Transaction failed: $e');
      }
    });
  } catch (e) {
    print('Error joining game: $e');
    print('Stack trace: ${StackTrace.current}');
    throw Exception('Failed to join game: ${e.toString()}');
  }
}

  // ============== QUIZ GAMEPLAY ==============

  // Get user's questions for a game
  Future<List<QuizQuestionModel>> getUserQuestions(String gameId, String userId) async {
    try {
      final participantDoc = await _firestore
          .collection('quiz_games')
          .doc(gameId)
          .collection('participants')
          .doc(userId)
          .get();

      if (!participantDoc.exists) {
        throw Exception('Participant not found');
      }

      final participant = GameParticipantModel.fromMap(participantDoc.data()!);
      final questionIds = participant.questionIds;

      // Fetch all questions
      final questions = <QuizQuestionModel>[];
      for (final questionId in questionIds) {
        final questionDoc = await _firestore
            .collection('quiz_questions')
            .doc(questionId)
            .get();
        
        if (questionDoc.exists) {
          questions.add(QuizQuestionModel.fromMap(questionDoc.data()!));
        }
      }

      return questions;
    } catch (e) {
      print('Error getting user questions: $e');
      rethrow;
    }
  }

  // Submit answer for a question
  Future<void> submitAnswer({
    required String gameId,
    required String userId,
    required int questionIndex,
    required int selectedAnswer,
    required bool isCorrect,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final participantRef = _firestore
            .collection('quiz_games')
            .doc(gameId)
            .collection('participants')
            .doc(userId);

        final participantDoc = await transaction.get(participantRef);
        
        if (!participantDoc.exists) {
          throw Exception('Participant not found');
        }

        final participant = GameParticipantModel.fromMap(participantDoc.data()!);
        
        // Update answers array
        final newAnswers = List<int>.from(participant.answers);
        newAnswers[questionIndex] = selectedAnswer;

        // Calculate new score and streak
        int newScore = participant.score;
        int newStreak = participant.currentStreak;
        int newMaxStreak = participant.maxStreak;
        int newCorrect = participant.correctAnswers;
        int newWrong = participant.wrongAnswers;

        if (isCorrect) {
          newCorrect++;
          newStreak++;
          newScore += 3; // Base points for correct answer

          // Streak bonus
          if (newStreak >= 2) {
            newScore += newStreak - 1; // +1 for 2 in a row, +2 for 3, +3 for 4, etc.
          }

          if (newStreak > newMaxStreak) {
            newMaxStreak = newStreak;
          }
        } else {
          newWrong++;
          newScore -= 1; // -1 for wrong answer
          newStreak = 0; // Reset streak
        }

        // Update participant
        transaction.update(participantRef, {
          'answers': newAnswers,
          'score': newScore,
          'currentStreak': newStreak,
          'maxStreak': newMaxStreak,
          'correctAnswers': newCorrect,
          'wrongAnswers': newWrong,
        });
      });
    } catch (e) {
      print('Error submitting answer: $e');
      rethrow;
    }
  }

  // Mark quiz as completed
  Future<void> completeQuiz(String gameId, String userId) async {
    try {
      await _firestore
          .collection('quiz_games')
          .doc(gameId)
          .collection('participants')
          .doc(userId)
          .update({
        'hasCompleted': true,
        'completedAt': Timestamp.now(),
      });

      // Update user stats
      await _firestore.collection('users').doc(userId).update({
        'totalGamesPlayed': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error completing quiz: $e');
      rethrow;
    }
  }

  // ============== LEADERBOARD ==============

  // Get leaderboard for a game
  Stream<List<GameParticipantModel>> getLeaderboard(String gameId) {
    return _firestore
        .collection('quiz_games')
        .doc(gameId)
        .collection('participants')
        .orderBy('score', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GameParticipantModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Check if user is in top 50
  Future<int?> getUserRank(String gameId, String userId) async {
    try {
      final participants = await _firestore
          .collection('quiz_games')
          .doc(gameId)
          .collection('participants')
          .orderBy('score', descending: true)
          .get();

      final rankedList = participants.docs
          .map((doc) => GameParticipantModel.fromMap(doc.data()))
          .toList();

      final userIndex = rankedList.indexWhere((p) => p.userId == userId);
      
      if (userIndex == -1) return null;
      
      return userIndex + 1; // Rank starts from 1
    } catch (e) {
      print('Error getting user rank: $e');
      return null;
    }
  }

  // ============== PRIZE DISTRIBUTION ==============

  // Calculate prize for a rank
  double getPrizeForRank(int rank) {
    if (rank >= 1 && rank <= 10) return 2500;
    if (rank >= 11 && rank <= 20) return 2000;
    if (rank >= 21 && rank <= 30) return 1400;
    if (rank >= 31 && rank <= 40) return 1000;
    if (rank >= 41 && rank <= 50) return 600;
    return 0;
  }

  // Distribute prizes (should be called by Cloud Function or admin)
  Future<void> distributePrizes(String gameId) async {
    try {
      final participants = await _firestore
          .collection('quiz_games')
          .doc(gameId)
          .collection('participants')
          .orderBy('score', descending: true)
          .limit(50)
          .get();

      final batch = _firestore.batch();

      for (int i = 0; i < participants.docs.length; i++) {
        final rank = i + 1;
        final prize = getPrizeForRank(rank);
        
        if (prize > 0) {
          final participant = GameParticipantModel.fromMap(participants.docs[i].data());
          final userRef = _firestore.collection('users').doc(participant.userId);

          batch.update(userRef, {
            'walletBalance': FieldValue.increment(prize),
            'totalWinnings': FieldValue.increment(prize),
            'totalGamesWon': FieldValue.increment(1),
          });
        }
      }

      // Update game status
      final gameRef = _firestore.collection('quiz_games').doc(gameId);
      batch.update(gameRef, {
        'status': 'ended',
        'endedAt': Timestamp.now(),
      });

      await batch.commit();
    } catch (e) {
      print('Error distributing prizes: $e');
      rethrow;
    }
  }

  // Check if user joined a game
  Future<bool> hasUserJoinedGame(String gameId, String userId) async {
    try {
      final doc = await _firestore
          .collection('quiz_games')
          .doc(gameId)
          .collection('participants')
          .doc(userId)
          .get();
      
      return doc.exists;
    } catch (e) {
      print('Error checking user joined: $e');
      return false;
    }
  }

  // Create initial game manually (call this once on first app launch)
  Future<void> createInitialGame() async {
    try {
      // Check if any game exists
      final existingGames = await _firestore
          .collection('quiz_games')
          .limit(1)
          .get();
      
      if (existingGames.docs.isEmpty) {
        print('Creating initial game...');
        final newGameRef = _firestore.collection('quiz_games').doc();
        final newGame = QuizGameModel(
          id: newGameRef.id,
          createdAt: DateTime.now(),
        );
        
        await newGameRef.set(newGame.toMap());
        print('Initial game created successfully: ${newGameRef.id}');
      } else {
        print('Games already exist, no need to create initial game');
      }
    } catch (e) {
      print('Error creating initial game: $e');
      rethrow;
    }
  }

  // Get user's participant data for a game
  Stream<GameParticipantModel?> getUserParticipantData(String gameId, String userId) {
    return _firestore
        .collection('quiz_games')
        .doc(gameId)
        .collection('participants')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return GameParticipantModel.fromMap(doc.data()!);
    });
  }
}