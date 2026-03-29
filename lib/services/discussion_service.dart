import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/discussion_model.dart';
import '../models/discussion_message_model.dart';

class DiscussionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Bunny.net Configuration
  final String _storageZone = 'unibenmeet';
  final String _accessKey = '8dc7a526-d5de-43cc-baac55789bab-2fae-46c8';
  final String _pullZoneUrl = 'https://unibenmeet.b-cdn.net';
  final String _uploadUrl = 'https://uk.storage.bunnycdn.com';

  // ============== DISCUSSION MANAGEMENT ==============

  // Create new discussion
  Future<String> createDiscussion({
    required String title,
    required String createdBy,
    required String creatorName,
  }) async {
    try {
      final discussionId =
          _firestore.collection('discussions').doc().id;
      
      final discussion = DiscussionModel(
        id: discussionId,
        title: title,
        createdBy: createdBy,
        creatorName: creatorName,
        createdAt: DateTime.now(),
        lastMessageTime: DateTime.now(),
        participantIds: [createdBy], // Creator auto-joins
      );

      await _firestore
          .collection('discussions')
          .doc(discussionId)
          .set(discussion.toMap());

      // Add system message
      await _sendSystemMessage(
        discussionId: discussionId,
        message: '$creatorName created this discussion',
      );

      return discussionId;
    } catch (e) {
      print('Error creating discussion: $e');
      rethrow;
    }
  }

  // Get all discussions
  Stream<List<DiscussionModel>> getDiscussions() {
    return _firestore
        .collection('discussions')
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DiscussionModel.fromMap(doc.data()))
            .toList());
  }

  // Get ongoing discussions (last message < 1 hour)
  Stream<List<DiscussionModel>> getOngoingDiscussions() {
    final oneHourAgo = DateTime.now().subtract(Duration(hours: 1));
    
    return _firestore
        .collection('discussions')
        .where('lastMessageTime', isGreaterThan: Timestamp.fromDate(oneHourAgo))
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DiscussionModel.fromMap(doc.data()))
            .toList());
  }

  // Get recent discussions
  Stream<List<DiscussionModel>> getRecentDiscussions() {
    return _firestore
        .collection('discussions')
        .orderBy('lastMessageTime', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DiscussionModel.fromMap(doc.data()))
            .toList());
  }

  // Join discussion
  Future<void> joinDiscussion(String discussionId, String userId, String username) async {
    try {
      final discussionRef = _firestore.collection('discussions').doc(discussionId);
      final doc = await discussionRef.get();

      if (!doc.exists) return;

      final participantIds = List<String>.from(doc.data()?['participantIds'] ?? []);

      if (!participantIds.contains(userId)) {
        participantIds.add(userId);

        await discussionRef.update({
          'participantIds': participantIds,
        });

        // Add system message
        await _sendSystemMessage(
          discussionId: discussionId,
          message: '$username joined the discussion',
        );
      }
    } catch (e) {
      print('Error joining discussion: $e');
      rethrow;
    }
  }

  // Leave discussion
  Future<void> leaveDiscussion(String discussionId, String userId, String username) async {
    try {
      final discussionRef = _firestore.collection('discussions').doc(discussionId);
      final doc = await discussionRef.get();

      if (!doc.exists) return;

      final participantIds = List<String>.from(doc.data()?['participantIds'] ?? []);

      if (participantIds.contains(userId)) {
        participantIds.remove(userId);

        await discussionRef.update({
          'participantIds': participantIds,
        });

        // Add system message
        await _sendSystemMessage(
          discussionId: discussionId,
          message: '$username left the discussion',
        );
      }
    } catch (e) {
      print('Error leaving discussion: $e');
      rethrow;
    }
  }

  // Delete discussion (creator only)
  Future<void> deleteDiscussion(String discussionId) async {
    try {
      // Delete all messages
      final messages = await _firestore
          .collection('discussion_messages')
          .where('discussionId', isEqualTo: discussionId)
          .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete discussion
      await _firestore.collection('discussions').doc(discussionId).delete();
    } catch (e) {
      print('Error deleting discussion: $e');
      rethrow;
    }
  }

  // ============== MESSAGE MANAGEMENT ==============

  // Upload image to Bunny.net
  Future<String> uploadDiscussionImage({
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
    required String discussionId,
  }) async {
    try {
      Uint8List bytes;
      String ext = fileName.split('.').last.toLowerCase();
      
      // Get bytes from either filePath or fileBytes
      if (fileBytes != null) {
        bytes = Uint8List.fromList(fileBytes);
      } else if (filePath != null) {
        // For mobile, we need to read the file
        final file = await http.get(Uri.parse(filePath));
        bytes = file.bodyBytes;
      } else {
        throw Exception('No file provided for upload');
      }

      // Generate unique filename
      final uniqueFileName = 'discussions/${discussionId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      print('Uploading image to Bunny.net: $uniqueFileName');

      // Upload to Bunny.net
      final uploadResponse = await http.put(
        Uri.parse('$_uploadUrl/$_storageZone/$uniqueFileName'),
        headers: {
          'AccessKey': _accessKey,
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );

      if (uploadResponse.statusCode == 201) {
        final imageUrl = '$_pullZoneUrl/$uniqueFileName';
        print('Image uploaded successfully: $imageUrl');
        return imageUrl;
      } else {
        print('Upload failed: HTTP ${uploadResponse.statusCode}');
        print('Response: ${uploadResponse.body}');
        throw Exception('Failed to upload image: HTTP ${uploadResponse.statusCode}');
      }
    } catch (e) {
      print('Error uploading image to Bunny.net: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Send message
  Future<void> sendMessage({
    required String discussionId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String message,
    String? imageUrl,
    String? replyToMessageId,
    String? replyToMessage,
    String? replyToSenderName,
  }) async {
    try {
      final messageId = _firestore.collection('discussion_messages').doc().id;
      
      final discussionMessage = DiscussionMessageModel(
        id: messageId,
        discussionId: discussionId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        message: message,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        replyToMessageId: replyToMessageId,
        replyToMessage: replyToMessage,
        replyToSenderName: replyToSenderName,
      );

      // Add message
      await _firestore
          .collection('discussion_messages')
          .doc(messageId)
          .set(discussionMessage.toMap());

      // Update discussion
      final discussionRef = _firestore.collection('discussions').doc(discussionId);
      final discussionDoc = await discussionRef.get();
      final currentMessageCount = discussionDoc.data()?['messageCount'] ?? 0;

      await discussionRef.update({
        'lastMessage': message.isNotEmpty ? message : '📷 Photo',
        'lastMessageSenderId': senderId,
        'lastMessageSenderName': senderName,
        'lastMessageTime': Timestamp.now(),
        'messageCount': currentMessageCount + 1,
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Send system message
  Future<void> _sendSystemMessage({
    required String discussionId,
    required String message,
  }) async {
    try {
      final messageId = _firestore.collection('discussion_messages').doc().id;
      
      final systemMessage = DiscussionMessageModel(
        id: messageId,
        discussionId: discussionId,
        senderId: 'system',
        senderName: 'System',
        message: message,
        createdAt: DateTime.now(),
        isSystemMessage: true,
      );

      await _firestore
          .collection('discussion_messages')
          .doc(messageId)
          .set(systemMessage.toMap());
    } catch (e) {
      print('Error sending system message: $e');
    }
  }

  // Get messages stream
  Stream<List<DiscussionMessageModel>> getMessages(String discussionId) {
    return _firestore
        .collection('discussion_messages')
        .where('discussionId', isEqualTo: discussionId)
        .orderBy('createdAt', descending: false) // Latest at bottom
        .snapshots()
        .handleError((error) {
          print('Error loading messages: $error');
          return Stream.value([]);
        })
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return <DiscussionMessageModel>[];
          }
          return snapshot.docs
              .map((doc) {
                try {
                  return DiscussionMessageModel.fromMap(doc.data());
                } catch (e) {
                  print('Error parsing message: $e');
                  return null;
                }
              })
              .whereType<DiscussionMessageModel>()
              .toList();
        });
  }

  // Get discussion by ID
  Future<DiscussionModel?> getDiscussionById(String discussionId) async {
    try {
      final doc = await _firestore.collection('discussions').doc(discussionId).get();
      if (doc.exists) {
        return DiscussionModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting discussion: $e');
      return null;
    }
  }

  // Schedule discussion deletion with countdown
  Future<void> scheduleDiscussionDeletion({
    required String discussionId,
    required int countdownSeconds,
  }) async {
    try {
      // Send countdown system message
      await _sendSystemMessage(
        discussionId: discussionId,
        message: '⚠️ This discussion will be deleted in $countdownSeconds seconds',
      );

      // Wait for countdown
      await Future.delayed(Duration(seconds: countdownSeconds));

      // Delete discussion
      await deleteDiscussion(discussionId);
    } catch (e) {
      print('Error scheduling deletion: $e');
      rethrow;
    }
  }
}