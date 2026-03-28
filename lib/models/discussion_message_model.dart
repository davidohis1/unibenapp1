import 'package:cloud_firestore/cloud_firestore.dart';

class DiscussionMessageModel {
  final String id;
  final String discussionId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String message;
  final String? imageUrl;
  final DateTime createdAt;
  final String? replyToMessageId;
  final String? replyToMessage;
  final String? replyToSenderName;
  final bool isSystemMessage; // For "User joined", "User left", etc.

  DiscussionMessageModel({
    required this.id,
    required this.discussionId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.message,
    this.imageUrl,
    required this.createdAt,
    this.replyToMessageId,
    this.replyToMessage,
    this.replyToSenderName,
    this.isSystemMessage = false,
  });

  factory DiscussionMessageModel.fromMap(Map<String, dynamic> map) {
    return DiscussionMessageModel(
      id: map['id'] ?? '',
      discussionId: map['discussionId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderAvatar: map['senderAvatar'],
      message: map['message'] ?? '',
      imageUrl: map['imageUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyToMessageId: map['replyToMessageId'],
      replyToMessage: map['replyToMessage'],
      replyToSenderName: map['replyToSenderName'],
      isSystemMessage: map['isSystemMessage'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'discussionId': discussionId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'message': message,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'replyToMessageId': replyToMessageId,
      'replyToMessage': replyToMessage,
      'replyToSenderName': replyToSenderName,
      'isSystemMessage': isSystemMessage,
    };
  }

  bool get hasReply => replyToMessageId != null;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}