import 'package:cloud_firestore/cloud_firestore.dart';

class DiscussionModel {
  final String id;
  final String title;
  final String createdBy;
  final String creatorName;
  final DateTime createdAt;
  final String lastMessage;
  final String lastMessageSenderId;
  final String lastMessageSenderName;
  final DateTime lastMessageTime;
  final List<String> participantIds; // Users who joined
  final int messageCount;
  final String? imageUrl;

  DiscussionModel({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.creatorName,
    required this.createdAt,
    this.lastMessage = '',
    this.lastMessageSenderId = '',
    this.lastMessageSenderName = '',
    required this.lastMessageTime,
    this.participantIds = const [],
    this.messageCount = 0,
    this.imageUrl,
  });

  factory DiscussionModel.fromMap(Map<String, dynamic> map) {
    return DiscussionModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      createdBy: map['createdBy'] ?? '',
      creatorName: map['creatorName'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      lastMessageSenderName: map['lastMessageSenderName'] ?? '',
      lastMessageTime:
          (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participantIds: List<String>.from(map['participantIds'] ?? []),
      messageCount: map['messageCount']?.toInt() ?? 0,
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageSenderName': lastMessageSenderName,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'participantIds': participantIds,
      'messageCount': messageCount,
      'imageUrl': imageUrl,
    };
  }

  int get participantCount => participantIds.length;

  bool get isOngoing {
    final difference = DateTime.now().difference(lastMessageTime);
    return difference.inHours < 1;
  }

  String get fireEmojis {
    if (participantCount >= 100) return '🔥🔥🔥';
    if (participantCount >= 50) return '🔥🔥';
    if (participantCount >= 10) return '🔥';
    return '';
  }

  bool hasUserJoined(String userId) => participantIds.contains(userId);
}