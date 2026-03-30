import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../models/user_model.dart';

class QuizQuestion {
  final String id;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer; // 'A', 'B', 'C', or 'D'

  QuizQuestion({
    required this.id,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map, String id) {
    return QuizQuestion(
      id: id,
      question: map['question'] ?? '',
      optionA: map['optionA'] ?? '',
      optionB: map['optionB'] ?? '',
      optionC: map['optionC'] ?? '',
      optionD: map['optionD'] ?? '',
      correctAnswer: map['correctAnswer'] ?? 'A',
    );
  }
}

class PlayerResult {
  final String uid;
  final String username;
  final int score;
  final int totalTimeSeconds;
  final int correctAnswers;
  final int wrongAnswers;

  PlayerResult({
    required this.uid,
    required this.username,
    required this.score,
    required this.totalTimeSeconds,
    required this.correctAnswers,
    required this.wrongAnswers,
  });

  factory PlayerResult.fromMap(Map<String, dynamic> map) {
    return PlayerResult(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      score: map['score'] ?? 0,
      totalTimeSeconds: map['totalTimeSeconds'] ?? 0,
      correctAnswers: map['correctAnswers'] ?? 0,
      wrongAnswers: map['wrongAnswers'] ?? 0,
    );
  }
}

class QuizGameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int ENTRY_FEE = 250;
  static const int PRIZE_2P = 400;
  static const int PRIZE_4P = 750;
  static const int QUESTIONS_PER_GAME = 15;
  static const int SECONDS_PER_QUESTION = 10;
  String get currentUid => _auth.currentUser?.uid ?? '';
  // Calculate score for a single answer
  // Correct: (10 - secondsTaken) * 10  [max 100 if instant, min 10 if took 9s]
  // Wrong: -25
  int calculateQuestionScore(bool isCorrect, int secondsTaken) {
    if (isCorrect) {
      final remaining = SECONDS_PER_QUESTION - secondsTaken;
      return remaining * 10;
    } else {
      return -25;
    }
  }

  // Fetch 15 random questions from the last 2 days
  Future<List<QuizQuestion>> fetchGameQuestions() async {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    final snapshot = await _firestore
        .collection('quiz_questions')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(twoDaysAgo))
        .get();

    if (snapshot.docs.length < QUESTIONS_PER_GAME) {
      throw Exception(
          'Not enough questions available. Need at least $QUESTIONS_PER_GAME questions added in the last 2 days.');
    }

    final allDocs = snapshot.docs..shuffle(Random());
    final selected = allDocs.take(QUESTIONS_PER_GAME).toList();

    return selected
        .map((doc) => QuizQuestion.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Join matchmaking lobby
  Future<String> joinLobby(int playerMode) async {
    final uid = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final user = UserModel.fromMap(userDoc.data()!);

    // Check wallet balance
    if (user.walletBalance < ENTRY_FEE) {
      throw Exception('Insufficient wallet balance. You need ₦$ENTRY_FEE to play.');
    }

    // Deduct entry fee
    await _firestore.collection('users').doc(uid).update({
      'walletBalance': FieldValue.increment(-ENTRY_FEE),
    });

    // Look for existing open lobby with correct player mode
    final openLobby = await _firestore
        .collection('quiz_lobbies')
        .where('playerMode', isEqualTo: playerMode)
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    String lobbyId;

    if (openLobby.docs.isNotEmpty) {
      lobbyId = openLobby.docs.first.id;
      final lobbyData = openLobby.docs.first.data();
      final players = List<Map<String, dynamic>>.from(lobbyData['players'] ?? []);

      players.add({
        'uid': uid,
        'username': user.username,
        'profileImageUrl': user.profileImageUrl,
        'ready': false,
      });

      final isFull = players.length >= playerMode;

      // If full, fetch questions and embed them in the lobby doc
      if (isFull) {
        final questions = await fetchGameQuestions();
        final questionsData = questions
            .map((q) => {
                  'id': q.id,
                  'question': q.question,
                  'optionA': q.optionA,
                  'optionB': q.optionB,
                  'optionC': q.optionC,
                  'optionD': q.optionD,
                  'correctAnswer': q.correctAnswer,
                })
            .toList();

        await _firestore.collection('quiz_lobbies').doc(lobbyId).update({
          'players': players,
          'status': 'starting',
          'questions': questionsData,
          'startTime': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('quiz_lobbies').doc(lobbyId).update({
          'players': players,
        });
      }
    } else {
      // Create new lobby
      final newLobbyRef = _firestore.collection('quiz_lobbies').doc();
      lobbyId = newLobbyRef.id;
      await newLobbyRef.set({
        'lobbyId': lobbyId,
        'playerMode': playerMode,
        'status': 'waiting',
        'players': [
          {
            'uid': uid,
            'username': user.username,
            'profileImageUrl': user.profileImageUrl,
            'ready': false,
          }
        ],
        'questions': [],
        'results': {},
        'createdAt': FieldValue.serverTimestamp(),
        'startTime': null,
        'prize': playerMode == 2 ? PRIZE_2P : PRIZE_4P,
        'entryFee': ENTRY_FEE,
      });
    }

    return lobbyId;
  }

  // Stream lobby updates
  Stream<DocumentSnapshot> streamLobby(String lobbyId) {
    return _firestore.collection('quiz_lobbies').doc(lobbyId).snapshots();
  }

  // Submit player result after finishing all questions
  Future<void> submitResult({
    required String lobbyId,
    required int totalScore,
    required int totalTimeSeconds,
    required int correctAnswers,
    required int wrongAnswers,
  }) async {
    final uid = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final username = userDoc.data()?['username'] ?? 'Player';

    await _firestore.collection('quiz_lobbies').doc(lobbyId).update({
      'results.$uid': {
        'uid': uid,
        'username': username,
        'score': totalScore,
        'totalTimeSeconds': totalTimeSeconds,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
        'finishedAt': FieldValue.serverTimestamp(),
      }
    });
  }

  // Determine winner and distribute prize (called once all results are in)
  Future<void> finalizeGame(String lobbyId) async {
    final lobbyDoc = await _firestore.collection('quiz_lobbies').doc(lobbyId).get();
    final data = lobbyDoc.data()!;
    final playerMode = data['playerMode'] as int;
    final prize = data['prize'] as int;
    final results = Map<String, dynamic>.from(data['results'] ?? {});

    if (results.length < playerMode) return; // Not all done yet

    // Already finalized?
    if (data['status'] == 'finished') return;

    // Sort players: highest score wins; tie-break = lowest totalTimeSeconds
    final sorted = results.entries.toList()
      ..sort((a, b) {
        final scoreA = a.value['score'] as int;
        final scoreB = b.value['score'] as int;
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        final timeA = a.value['totalTimeSeconds'] as int;
        final timeB = b.value['totalTimeSeconds'] as int;
        return timeA.compareTo(timeB);
      });

    final winnerId = sorted.first.key;
    final winnerUsername = sorted.first.value['username'];

    // Award prize to winner
    await _firestore.collection('users').doc(winnerId).update({
      'walletBalance': FieldValue.increment(prize),
      'totalGamesWon': FieldValue.increment(1),
      'totalWinnings': FieldValue.increment(prize.toDouble()),
    });

    // Increment totalGamesPlayed for all
    for (final entry in results.entries) {
      await _firestore.collection('users').doc(entry.key).update({
        'totalGamesPlayed': FieldValue.increment(1),
      });
    }

    // Mark lobby finished
    await _firestore.collection('quiz_lobbies').doc(lobbyId).update({
      'status': 'finished',
      'winnerId': winnerId,
      'winnerUsername': winnerUsername,
      'rankedResults': sorted.map((e) => e.value).toList(),
    });
  }

  // Leave lobby and refund if game hasn't started
  Future<void> leaveLobby(String lobbyId) async {
    final uid = _auth.currentUser!.uid;
    final lobbyDoc =
        await _firestore.collection('quiz_lobbies').doc(lobbyId).get();
    if (!lobbyDoc.exists) return;
    final data = lobbyDoc.data()!;
    final status = data['status'] as String;

    if (status == 'waiting') {
      // Refund entry fee
      await _firestore.collection('users').doc(uid).update({
        'walletBalance': FieldValue.increment(ENTRY_FEE),
      });

      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
      players.removeWhere((p) => p['uid'] == uid);

      if (players.isEmpty) {
        await _firestore.collection('quiz_lobbies').doc(lobbyId).delete();
      } else {
        await _firestore
            .collection('quiz_lobbies')
            .doc(lobbyId)
            .update({'players': players});
      }
    }
  }
}