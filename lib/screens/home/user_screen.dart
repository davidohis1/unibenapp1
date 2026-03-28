import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_constants.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class UserScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();

  List<PostModel> _userPosts = [];
  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserPosts();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data();
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadUserPosts() async {
    try {
      final posts = await _postService.getPostsStream().first;
      // Filter posts by this user and sort by creation date (newest first)
      final userPosts = posts
          .where((post) => post.userId == widget.userId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _userPosts = userPosts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user posts: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getProxiedMediaUrl(String url) {
    if (!kIsWeb) return url;

    try {
      final uri = Uri.parse(url);

      if (uri.path.contains('get_image.php') || uri.path.contains('get_video.php')) {
        return url;
      }

      final pathSegments = uri.pathSegments;
      final uploadsIndex = pathSegments.indexOf('uploads');

      if (uploadsIndex != -1 && pathSegments.length > uploadsIndex + 2) {
        final folder = pathSegments[uploadsIndex + 1];
        final filename = pathSegments.last;
        final baseUrl = '${uri.scheme}://${uri.host}';
        final schoolPath = pathSegments.sublist(0, uploadsIndex).join('/');

        // Check if it's video or image
        if (url.contains('.mp4') || url.contains('.mov')) {
          return '$baseUrl/$schoolPath/get_video.php?folder=$folder&file=$filename';
        } else {
          return '$baseUrl/$schoolPath/get_image.php?folder=$folder&file=$filename';
        }
      }
    } catch (e) {
      print('Error parsing URL: $e');
    }

    return url;
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Add Friend',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Send a friend request to @${widget.username}?',
          style: GoogleFonts.poppins(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.white70,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement friend request functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Friend request sent!'),
                  backgroundColor: AppColors.primaryPurple,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Send',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Message',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Start a conversation with @${widget.username}?',
          style: GoogleFonts.poppins(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.white70,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement messaging functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening chat...'),
                  backgroundColor: AppColors.primaryPurple,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Message',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final userAvatar = _userData?['avatarUrl'];
    final bio = _userData?['bio'] ?? '';

    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey.withOpacity(0.3),
            backgroundImage: userAvatar != null
                ? CachedNetworkImageProvider(_getProxiedMediaUrl(userAvatar))
                : null,
            child: userAvatar == null
                ? Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
          SizedBox(height: 16),

          // Username
          Text(
            '@${widget.username.toLowerCase()}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),

          // Bio
          if (bio.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                bio,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          SizedBox(height: 20),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem('Posts', _userPosts.length),
              SizedBox(width: 40),
              _buildStatItem('Likes', _calculateTotalLikes()),
            ],
          ),
          SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddFriendDialog,
                  icon: Icon(Icons.person_add, size: 20),
                  label: Text(
                    'Add Friend',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showMessageDialog,
                  icon: Icon(Icons.message, size: 20),
                  label: Text(
                    'Message',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white, width: 1.5),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          _formatCount(count),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  int _calculateTotalLikes() {
    return _userPosts.fold(0, (sum, post) => sum + post.likeCount);
  }

  Widget _buildPostsGrid() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      );
    }

    if (_userPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 80,
                color: Colors.grey.withOpacity(0.5),
              ),
              SizedBox(height: 16),
              Text(
                'No posts yet',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        return _buildGridItem(post);
      },
    );
  }

  Widget _buildGridItem(PostModel post) {
    // Determine what to show
    Widget thumbnail;

    if (post.hasMedia && post.mediaUrls.isNotEmpty) {
      // Show first image or video thumbnail
      thumbnail = CachedNetworkImage(
        imageUrl: _getProxiedMediaUrl(post.mediaUrls.first),
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.withOpacity(0.3),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryPurple,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.withOpacity(0.3),
          child: Icon(Icons.broken_image, color: Colors.white),
        ),
      );
    } else {
      // Text-only post - show colored background with text preview
      thumbnail = Container(
        color: _getPostColor(post.id),
        padding: EdgeInsets.all(8),
        child: Center(
          child: Text(
            post.content,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to post detail screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post tapped!'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          thumbnail,
          
          // Video indicator
          if (post.hasVideos)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 24,
              ),
            ),

          // Like count overlay
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    _formatCount(post.likeCount),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPostColor(String postId) {
    final colors = [
      Color(0xFFE74C3C), // Red
      Color(0xFF3498DB), // Blue
      Color(0xFF2ECC71), // Green
      Color(0xFFE67E22), // Orange
      Color(0xFF9B59B6), // Purple
      Color(0xFF1ABC9C), // Turquoise
      Color(0xFFF39C12), // Yellow
      Color(0xFFE91E63), // Pink
      Color(0xFF00BCD4), // Cyan
      Color(0xFFFF5722), // Deep Orange
    ];
    
    final index = postId.hashCode % colors.length;
    return colors[index.abs()];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '@${widget.username.toLowerCase()}',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // TODO: Show more options
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            SizedBox(height: 8),
            Divider(color: Colors.grey.withOpacity(0.3), height: 1),
            SizedBox(height: 8),
            _buildPostsGrid(),
          ],
        ),
      ),
    );
  }
}