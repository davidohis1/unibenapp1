import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create or get conversation
  Future<String> getOrCreateConversation(String userId, String otherUserId) async {
    try {
      // Check if conversation exists
      final existingConversation = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .get();

      for (var doc in existingConversation.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participantIds'] ?? []);
        if (participants.contains(otherUserId)) {
          return doc.id;
        }
      }

      // Create new conversation
      final conversationId = _firestore.collection('conversations').doc().id;
      final conversation = ConversationModel(
        id: conversationId,
        participantIds: [userId, otherUserId],
        lastMessageTime: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .set(conversation.toMap());

      return conversationId;
    } catch (e) {
      print('Error getting/creating conversation: $e');
      rethrow;
    }
  }

  // Send message
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
  }) async {
    try {
      final messageId = _firestore.collection('messages').doc().id;
      final message = MessageModel(
        id: messageId,
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        type: type,
        mediaUrl: mediaUrl,
        createdAt: DateTime.now(),
      );

      // Add message to messages collection
      await _firestore.collection('messages').doc(messageId).set(message.toMap());

      // Update conversation
      final conversationRef = _firestore.collection('conversations').doc(conversationId);
      final conversationDoc = await conversationRef.get();
      final currentUnreadCount = Map<String, int>.from(
        conversationDoc.data()?['unreadCount'] ?? {}
      );
      
      // Increment unread count for receiver
      currentUnreadCount[receiverId] = (currentUnreadCount[receiverId] ?? 0) + 1;

      await conversationRef.update({
        'lastMessage': content,
        'lastMessageSenderId': senderId,
        'lastMessageTime': Timestamp.now(),
        'unreadCount': currentUnreadCount,
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages stream
  // Get messages stream - FIXED for WhatsApp style
Stream<List<MessageModel>> getMessages(String conversationId) {
  return _firestore
      .collection('messages')
      .where('conversationId', isEqualTo: conversationId)
      .orderBy('createdAt', descending: true) // Keep this as true
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data()))
          .toList());
}

  // Get conversations stream
  // Get conversations stream - FIXED
Stream<List<ConversationModel>> getConversations(String userId) {
  return _firestore
      .collection('conversations')
      .where('participantIds', arrayContains: userId)
      .snapshots()
      .map((snapshot) {
        final conversations = snapshot.docs
            .map((doc) => ConversationModel.fromMap(doc.data()))
            .toList();
        
        // Sort manually by lastMessageTime
        conversations.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        return conversations;
      });
}

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      final conversationRef = _firestore.collection('conversations').doc(conversationId);
      final conversationDoc = await conversationRef.get();
      final currentUnreadCount = Map<String, int>.from(
        conversationDoc.data()?['unreadCount'] ?? {}
      );
      
      // Reset unread count for this user
      currentUnreadCount[userId] = 0;

      await conversationRef.update({
        'unreadCount': currentUnreadCount,
      });

      // Mark individual messages as read
      final messages = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': Timestamp.now(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
      rethrow;
    }
  }

  // Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete all messages in conversation
      final messages = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete conversation
      await _firestore.collection('conversations').doc(conversationId).delete();
    } catch (e) {
      print('Error deleting conversation: $e');
      rethrow;
    }
  }

  // Get total unread count
  Future<int> getTotalUnreadCount(String userId) async {
    try {
      final conversations = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .get();

      int totalUnread = 0;
      for (var doc in conversations.docs) {
        final data = doc.data();
        final unreadCount = Map<String, int>.from(data['unreadCount'] ?? {});
        totalUnread += (unreadCount[userId] ?? 0);
      }
      return totalUnread;
    } catch (e) {
      print('Error getting total unread count: $e');
      return 0;
    }
  }
}