import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_model.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send friend request
  Future<void> sendFriendRequest(String senderId, String receiverId) async {
    try {
      // Check if request already exists
      final existingRequest = await _firestore
          .collection('friends')
          .where('senderId', isEqualTo: senderId)
          .where('receiverId', isEqualTo: receiverId)
          .get();

      final reverseRequest = await _firestore
          .collection('friends')
          .where('senderId', isEqualTo: receiverId)
          .where('receiverId', isEqualTo: senderId)
          .get();

      if (existingRequest.docs.isNotEmpty || reverseRequest.docs.isNotEmpty) {
        throw Exception('Friend request already exists');
      }

      final requestId = _firestore.collection('friends').doc().id;
      final request = FriendModel(
        id: requestId,
        userId: senderId,
        friendId: receiverId,
        status: FriendStatus.pending,
        createdAt: DateTime.now(),
        isRequestSender: true,
      );

      await _firestore.collection('friends').doc(requestId).set(request.toMap());
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friends').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error accepting friend request: $e');
      rethrow;
    }
  }

  // Reject/Delete friend request
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friends').doc(requestId).delete();
    } catch (e) {
      print('Error rejecting friend request: $e');
      rethrow;
    }
  }

  // Remove friend
  Future<void> removeFriend(String userId, String friendId) async {
    try {
      final friendDocs = await _firestore
          .collection('friends')
          .where('status', isEqualTo: 'accepted')
          .get();

      for (var doc in friendDocs.docs) {
        final data = doc.data();
        if ((data['senderId'] == userId && data['receiverId'] == friendId) ||
            (data['senderId'] == friendId && data['receiverId'] == userId)) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      print('Error removing friend: $e');
      rethrow;
    }
  }

  // Get pending friend requests (received)
  Stream<List<FriendModel>> getPendingRequests(String userId) {
    return _firestore
        .collection('friends')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendModel.fromMap(doc.data(), userId))
            .toList());
  }

  // Get all friends (accepted)
  Stream<List<FriendModel>> getFriends(String userId) {
    return _firestore
        .collection('friends')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .asyncMap((snapshot) async {
      List<FriendModel> friends = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['senderId'] == userId || data['receiverId'] == userId) {
          friends.add(FriendModel.fromMap(data, userId));
        }
      }
      
      return friends;
    });
  }

  // Check if users are friends
  Future<bool> areFriends(String userId, String otherUserId) async {
    try {
      final snapshot = await _firestore
          .collection('friends')
          .where('status', isEqualTo: 'accepted')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if ((data['senderId'] == userId && data['receiverId'] == otherUserId) ||
            (data['senderId'] == otherUserId && data['receiverId'] == userId)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error checking friendship: $e');
      return false;
    }
  }

  // Check if friend request exists
  Future<String?> getFriendRequestStatus(String userId, String otherUserId) async {
    try {
      // Check if current user sent request
      final sentRequest = await _firestore
          .collection('friends')
          .where('senderId', isEqualTo: userId)
          .where('receiverId', isEqualTo: otherUserId)
          .get();

      if (sentRequest.docs.isNotEmpty) {
        return sentRequest.docs.first.data()['status'];
      }

      // Check if current user received request
      final receivedRequest = await _firestore
          .collection('friends')
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: userId)
          .get();

      if (receivedRequest.docs.isNotEmpty) {
        return receivedRequest.docs.first.data()['status'];
      }

      return null;
    } catch (e) {
      print('Error checking request status: $e');
      return null;
    }
  }

  // Get friend request ID
  Future<String?> getFriendRequestId(String senderId, String receiverId) async {
    try {
      final request = await _firestore
          .collection('friends')
          .where('senderId', isEqualTo: senderId)
          .where('receiverId', isEqualTo: receiverId)
          .get();

      if (request.docs.isNotEmpty) {
        return request.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Error getting request ID: $e');
      return null;
    }
  }
}