import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import 'storage_service.dart';
import 'auth_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  // Collection references
  CollectionReference get _postsCollection => _firestore.collection('posts');
  CollectionReference get _commentsCollection => _firestore.collection('comments');

  // Create a new post
  Future<String> createPost({
    required String content,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
    String? audioUrl,
    List<String> tags = const [],
    String backgroundColor = '#FFFFFF',
    bool isAnonymous = false,
    bool isVideoReel = false,
    double? videoDuration,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not logged in');

      final userData = await _authService.getUserData(user.uid);
      final postId = _uuid.v4();

      final post = PostModel(
        id: postId,
        userId: user.uid,
        username: isAnonymous ? 'Anonymous' : (userData?.username ?? 'User'),
        userAvatar: isAnonymous ? null : userData?.profileImageUrl,
        content: content,
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
        audioUrl: audioUrl,
        tags: tags,
        backgroundColor: backgroundColor,
        isAnonymous: isAnonymous,
        createdAt: DateTime.now(),
        isVideoReel: isVideoReel,
        videoDuration: videoDuration,
      );

      await _postsCollection.doc(postId).set(post.toMap());
      return postId;
    } catch (e) {
      print('Error creating post: $e');
      throw Exception('Failed to create post: $e');
    }
  }

  // Get posts stream (real-time updates)
  Stream<List<PostModel>> getPostsStream() {
    return _postsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                return PostModel.fromMap(doc.data() as Map<String, dynamic>);
              } catch (e) {
                print('Error parsing post ${doc.id}: $e');
                return PostModel(
                  id: doc.id,
                  userId: '',
                  username: 'Unknown',
                  content: 'Post unavailable',
                  createdAt: DateTime.now(),
                );
              }
            })
            .where((post) => post.userId.isNotEmpty) // Filter out invalid posts
            .toList());
  }

  // Get posts for TikTok-style feed (shuffle/random order)
  Stream<List<PostModel>> getTikTokFeedStream() {
    return _postsCollection
        .where('isVideoReel', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) {
                try {
                  return PostModel.fromMap(doc.data() as Map<String, dynamic>);
                } catch (e) {
                  print('Error parsing post ${doc.id}: $e');
                  return null;
                }
              })
              .where((post) => post != null && post.userId.isNotEmpty)
              .cast<PostModel>()
              .toList();
          
          // Shuffle posts for random feed (optional)
          // posts.shuffle();
          return posts;
        });
  }

  // Like/unlike a post
  Future<void> toggleLike(String postId, String userId) async {
    try {
      final postRef = _postsCollection.doc(postId);
      final postDoc = await postRef.get();
      
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final post = PostModel.fromMap(postDoc.data() as Map<String, dynamic>);
      final newLikes = List<String>.from(post.likes);

      if (newLikes.contains(userId)) {
        newLikes.remove(userId);
      } else {
        newLikes.add(userId);
      }

      await postRef.update({'likes': newLikes});
    } catch (e) {
      print('Error toggling like: $e');
      throw Exception('Failed to toggle like: $e');
    }
  }

  // Add comment
  Future<String> addComment({
    required String postId,
    required String content,
    bool isAnonymous = false,
    String? parentCommentId,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not logged in');

      final userData = await _authService.getUserData(user.uid);
      final commentId = _uuid.v4();

      final comment = CommentModel(
        id: commentId,
        postId: postId,
        userId: user.uid,
        username: isAnonymous ? 'Anonymous' : (userData?.username ?? 'User'),
        userAvatar: isAnonymous ? null : userData?.profileImageUrl,
        content: content,
        isAnonymous: isAnonymous,
        createdAt: DateTime.now(),
        parentCommentId: parentCommentId,
      );

      // Add comment
      await _commentsCollection.doc(commentId).set(comment.toMap());

      // Update post comment count
      await _postsCollection.doc(postId).update({
        'commentsCount': FieldValue.increment(1),
      });

      return commentId;
    } catch (e) {
      print('Error adding comment: $e');
      throw Exception('Failed to add comment: $e');
    }
  }

  // Get comments for a post
  Stream<List<CommentModel>> getCommentsStream(String postId) {
    return _commentsCollection
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Get replies for a comment
  Stream<List<CommentModel>> getRepliesStream(String parentCommentId) {
    return _commentsCollection
        .where('parentCommentId', isEqualTo: parentCommentId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Like/unlike a comment
  Future<void> toggleCommentLike(String commentId, String userId) async {
    try {
      final commentRef = _commentsCollection.doc(commentId);
      final commentDoc = await commentRef.get();
      
      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final comment = CommentModel.fromMap(commentDoc.data() as Map<String, dynamic>);
      final newLikes = List<String>.from(comment.likes);

      if (newLikes.contains(userId)) {
        newLikes.remove(userId);
      } else {
        newLikes.add(userId);
      }

      await commentRef.update({'likes': newLikes});
    } catch (e) {
      print('Error toggling comment like: $e');
      throw Exception('Failed to toggle comment like: $e');
    }
  }

  // Increment share count
  Future<void> incrementShareCount(String postId) async {
    try {
      await _postsCollection.doc(postId).update({
        'shareCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing share count: $e');
      throw Exception('Failed to increment share count: $e');
    }
  }

  // Delete post
  Future<void> deletePost(String postId, String userId) async {
    try {
      final postDoc = await _postsCollection.doc(postId).get();
      if (!postDoc.exists) return;

      final post = PostModel.fromMap(postDoc.data() as Map<String, dynamic>);
      if (post.userId != userId) throw Exception('Not authorized to delete this post');

      // Delete post
      await _postsCollection.doc(postId).delete();

      // Delete all comments for this post
      final commentsSnapshot = await _commentsCollection
          .where('postId', isEqualTo: postId)
          .get();

      final batch = _firestore.batch();
      for (final doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete associated media from storage (optional)
      for (final mediaUrl in post.mediaUrls) {
        try {
          await _storageService.deleteMedia(mediaUrl);
        } catch (e) {
          print('Error deleting media $mediaUrl: $e');
        }
      }

    } catch (e) {
      print('Error deleting post: $e');
      throw Exception('Failed to delete post: $e');
    }
  }

  // Get post by ID
  Future<PostModel?> getPostById(String postId) async {
    try {
      final doc = await _postsCollection.doc(postId).get();
      if (doc.exists) {
        return PostModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting post: $e');
      return null;
    }
  }

  // Get posts by user ID
  Stream<List<PostModel>> getUserPostsStream(String userId) {
    return _postsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Search posts by content or tags
  Stream<List<PostModel>> searchPosts(String query) {
    if (query.isEmpty) {
      return const Stream.empty();
    }

    return _postsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
            .where((post) =>
                post.content.toLowerCase().contains(query.toLowerCase()) ||
                post.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase())))
            .toList());
  }

  // Get trending posts (most liked in last 7 days)
  Stream<List<PostModel>> getTrendingPosts() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));

    return _postsCollection
        .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
              .toList();
          
          // Sort by like count (descending)
          posts.sort((a, b) => b.likeCount.compareTo(a.likeCount));
          return posts.take(20).toList(); // Return top 20
        });
  }

  // Update post content
  Future<void> updatePostContent(String postId, String newContent) async {
    try {
      await _postsCollection.doc(postId).update({
        'content': newContent,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating post content: $e');
      throw Exception('Failed to update post content: $e');
    }
  }

  // Mark post as video reel
  Future<void> markAsVideoReel(String postId, bool isVideoReel) async {
    try {
      await _postsCollection.doc(postId).update({
        'isVideoReel': isVideoReel,
      });
    } catch (e) {
      print('Error marking as video reel: $e');
      throw Exception('Failed to mark as video reel: $e');
    }
  }

  // Report post
  Future<void> reportPost(String postId, String userId, String reason) async {
    try {
      await _firestore.collection('reports').add({
        'postId': postId,
        'userId': userId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'resolved': false,
      });
    } catch (e) {
      print('Error reporting post: $e');
      throw Exception('Failed to report post: $e');
    }
  }

  // Get post analytics (views, likes, shares)
  Future<Map<String, dynamic>> getPostAnalytics(String postId) async {
    try {
      final postDoc = await _postsCollection.doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final post = PostModel.fromMap(postDoc.data() as Map<String, dynamic>);

      // Get view count from analytics collection
      final analyticsDoc = await _firestore
          .collection('post_analytics')
          .doc(postId)
          .get();

      final views = analyticsDoc.exists 
          ? (analyticsDoc.data()?['views'] ?? 0)
          : 0;

      return {
        'postId': postId,
        'likes': post.likeCount,
        'comments': post.commentsCount,
        'shares': post.shareCount,
        'views': views,
        'createdAt': post.createdAt,
      };
    } catch (e) {
      print('Error getting post analytics: $e');
      throw Exception('Failed to get post analytics: $e');
    }
  }
}