import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Bunny.net Configuration - add at top of StorageService class

  // Collection references
  CollectionReference get _postsCollection => _firestore.collection('posts');
  CollectionReference get _commentsCollection =>
      _firestore.collection('comments');

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
      );

      await _postsCollection.doc(postId).set(post.toMap());
      return postId;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  // Get posts stream (real-time updates)
  Stream<List<PostModel>> getPostsStream() {
    return _postsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Like/unlike a post
  Future<void> toggleLike(String postId, String userId) async {
    try {
      final postRef = _postsCollection.doc(postId);
      final postDoc = await postRef.get();

      if (!postDoc.exists) return;

      final post = PostModel.fromMap(postDoc.data() as Map<String, dynamic>);
      final newLikes = List<String>.from(post.likes);

      if (newLikes.contains(userId)) {
        newLikes.remove(userId);
      } else {
        newLikes.add(userId);
      }

      await postRef.update({'likes': newLikes});
    } catch (e) {
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
      throw Exception('Failed to add comment: $e');
    }
  }

  // Get comments for a post
  Stream<List<CommentModel>> getCommentsStream(String postId) {
    return _commentsCollection
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                CommentModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Get replies for a comment
  Stream<List<CommentModel>> getRepliesStream(String parentCommentId) {
    return _commentsCollection
        .where('parentCommentId', isEqualTo: parentCommentId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                CommentModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Like/unlike a comment
  Future<void> toggleCommentLike(String commentId, String userId) async {
    try {
      final commentRef = _commentsCollection.doc(commentId);
      final commentDoc = await commentRef.get();

      if (!commentDoc.exists) return;

      final comment =
          CommentModel.fromMap(commentDoc.data() as Map<String, dynamic>);
      final newLikes = List<String>.from(comment.likes);

      if (newLikes.contains(userId)) {
        newLikes.remove(userId);
      } else {
        newLikes.add(userId);
      }

      await commentRef.update({'likes': newLikes});
    } catch (e) {
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
      throw Exception('Failed to increment share count: $e');
    }
  }

  // Delete post
  Future<void> deletePost(String postId, String userId) async {
    try {
      final postDoc = await _postsCollection.doc(postId).get();
      if (!postDoc.exists) return;

      final post = PostModel.fromMap(postDoc.data() as Map<String, dynamic>);
      if (post.userId != userId) throw Exception('Not authorized');

      // Delete post
      await _postsCollection.doc(postId).delete();

      // Delete all comments for this post
      final commentsSnapshot =
          await _commentsCollection.where('postId', isEqualTo: postId).get();

      for (final doc in commentsSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }
}
