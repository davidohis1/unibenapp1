import 'package:cloud_firestore/cloud_firestore.dart';

class GameParticipantModel {
  final String userId;
  final String username;
  final String? profileImageUrl;
  final int score;
  final int correctAnswers;
  final int wrongAnswers;
  final int currentStreak;
  final int maxStreak;
  final DateTime joinedAt;
  final DateTime? completedAt;
  final bool hasCompleted;
  final List<int> answers; // User's answers (-1 for unanswered)
  final List<String> questionIds; // The 20 questions they got

  GameParticipantModel({
    required this.userId,
    required this.username,
    this.profileImageUrl,
    this.score = 0,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    required this.joinedAt,
    this.completedAt,
    this.hasCompleted = false,
    this.answers = const [],
    this.questionIds = const [],
  });

  factory GameParticipantModel.fromMap(Map<String, dynamic> map) {
    return GameParticipantModel(
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      score: map['score'] ?? 0,
      correctAnswers: map['correctAnswers'] ?? 0,
      wrongAnswers: map['wrongAnswers'] ?? 0,
      currentStreak: map['currentStreak'] ?? 0,
      maxStreak: map['maxStreak'] ?? 0,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      hasCompleted: map['hasCompleted'] ?? false,
      answers: List<int>.from(map['answers'] ?? []),
      questionIds: List<String>.from(map['questionIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'score': score,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'currentStreak': currentStreak,
      'maxStreak': maxStreak,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'hasCompleted': hasCompleted,
      'answers': answers,
      'questionIds': questionIds,
    };
  }

  int get rank => 0; // Will be calculated when fetching leaderboard
}