import 'package:cloud_firestore/cloud_firestore.dart';

enum GameStatus { waiting, scheduled, live, ended }

class QuizGameModel {
  final String id;
  final double entryFee;
  final int maxPlayers;
  final int currentPlayers;
  final double totalPool;
  final GameStatus status;
  final DateTime? scheduledStartTime;
  final DateTime? scheduledEndTime;
  final DateTime createdAt;
  final DateTime? endedAt;

  QuizGameModel({
    required this.id,
    this.entryFee = 300.0,
    this.maxPlayers = 350,
    this.currentPlayers = 0,
    this.totalPool = 0.0,
    this.status = GameStatus.waiting,
    this.scheduledStartTime,
    this.scheduledEndTime,
    required this.createdAt,
    this.endedAt,
  });

  factory QuizGameModel.fromMap(Map<String, dynamic> map) {
    return QuizGameModel(
      id: map['id'] ?? '',
      entryFee: (map['entryFee'] ?? 300).toDouble(),
      maxPlayers: map['maxPlayers'] ?? 350,
      currentPlayers: map['currentPlayers'] ?? 0,
      totalPool: (map['totalPool'] ?? 0).toDouble(),
      status: _statusFromString(map['status'] ?? 'waiting'),
      scheduledStartTime: (map['scheduledStartTime'] as Timestamp?)?.toDate(),
      scheduledEndTime: (map['scheduledEndTime'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entryFee': entryFee,
      'maxPlayers': maxPlayers,
      'currentPlayers': currentPlayers,
      'totalPool': totalPool,
      'status': _statusToString(status),
      'scheduledStartTime': scheduledStartTime != null ? Timestamp.fromDate(scheduledStartTime!) : null,
      'scheduledEndTime': scheduledEndTime != null ? Timestamp.fromDate(scheduledEndTime!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    };
  }

  static GameStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'waiting': return GameStatus.waiting;
      case 'scheduled': return GameStatus.scheduled;
      case 'live': return GameStatus.live;
      case 'ended': return GameStatus.ended;
      default: return GameStatus.waiting;
    }
  }

  static String _statusToString(GameStatus status) {
    return status.toString().split('.').last;
  }

  bool get isFull => currentPlayers >= maxPlayers;
  bool get isWaiting => status == GameStatus.waiting;
  bool get isScheduled => status == GameStatus.scheduled;
  bool get isLive => status == GameStatus.live;
  bool get isEnded => status == GameStatus.ended;
  bool get canJoin => status == GameStatus.waiting && !isFull;
}