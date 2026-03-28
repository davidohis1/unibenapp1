import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendStatus {
  pending,
  accepted,
  blocked,
}

class FriendModel {
  final String id;
  final String userId; // The user who sent/received the request
  final String friendId; // The other user in the relationship
  final FriendStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final bool isRequestSender; // True if userId sent the request

  FriendModel({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    required this.isRequestSender,
  });

  factory FriendModel.fromMap(Map<String, dynamic> map, String currentUserId) {
    final senderId = map['senderId'] ?? '';
    final receiverId = map['receiverId'] ?? '';
    
    return FriendModel(
      id: map['id'] ?? '',
      userId: currentUserId,
      friendId: currentUserId == senderId ? receiverId : senderId,
      status: _statusFromString(map['status'] ?? 'pending'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (map['acceptedAt'] as Timestamp?)?.toDate(),
      isRequestSender: currentUserId == senderId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': isRequestSender ? userId : friendId,
      'receiverId': isRequestSender ? friendId : userId,
      'status': _statusToString(status),
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
    };
  }

  static FriendStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return FriendStatus.accepted;
      case 'blocked':
        return FriendStatus.blocked;
      default:
        return FriendStatus.pending;
    }
  }

  static String _statusToString(FriendStatus status) {
    switch (status) {
      case FriendStatus.accepted:
        return 'accepted';
      case FriendStatus.blocked:
        return 'blocked';
      default:
        return 'pending';
    }
  }

  bool get isPending => status == FriendStatus.pending;
  bool get isAccepted => status == FriendStatus.accepted;
  bool get isBlocked => status == FriendStatus.blocked;
}