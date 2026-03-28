import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_constants.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/auth_service.dart';
import 'create_post_screen.dart';
import 'comments_bottom_sheet.dart';
import 'user_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();
  
  // Tab Controller
  late TabController _tabController;
  
  // Feed (Images) Controllers
  final PageController _feedPageController = PageController();
  final ScrollController _feedScrollController = ScrollController();
  List<PostModel> _feedPosts = [];
  int _currentFeedPage = 0;
  
  // Reels (Videos) Controllers
  final PageController _reelsPageController = PageController();
  List<PostModel> _reelsPosts = [];
  int _currentReelIndex = 0;
  Map<String, VideoPlayerController> _videoControllers = {};
  Map<String, ChewieController> _chewieControllers = {};
  
  // Loading states
  bool _isFeedLoading = true;
  bool _isReelsLoading = true;
  
  // Preloading
  List<PostModel> _preloadedReels = [];
  int _preloadIndex = 0;
  Timer? _autoScrollTimer;
  
  // Carousel indicators
  Map<String, int> _currentCarouselIndex = {};

  // Random background colors for text-only posts
  final List<Color> _backgroundColors = [
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
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadFeedPosts();
    _loadReelsPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedPageController.dispose();
    _feedScrollController.dispose();
    _reelsPageController.dispose();
    _autoScrollTimer?.cancel();
    _disposeAllVideoControllers();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index == 1) {
      // Switched to Reels
      _initializeCurrentReel();
    } else {
      // Switched to Feed
      _autoScrollTimer?.cancel();
      _pauseAllVideos();
    }
  }

  // ============== IMAGE FEED METHODS ==============

  Future<void> _loadFeedPosts() async {
    try {
      final posts = await _postService.getPostsStream().first;
      // Filter only image posts and text-only posts (no videos)
      final feedPosts = posts.where((post) => 
        !post.hasVideos
      ).toList();
      
      setState(() {
        _feedPosts = feedPosts;
        _isFeedLoading = false;
      });
    } catch (e) {
      print('Error loading feed posts: $e');
      setState(() => _isFeedLoading = false);
    }
  }

  // ============== REELS (VIDEOS) METHODS ==============

  Future<void> _loadReelsPosts() async {
    try {
      final posts = await _postService.getPostsStream().first;
      // Filter only video posts
      final videoPosts = posts.where((post) => post.hasVideos).toList();
      
      setState(() {
        _reelsPosts = videoPosts;
        _isReelsLoading = false;
      });
      
      // Initialize first video and preload next ones
      if (_reelsPosts.isNotEmpty) {
        _initializeVideoController(0);
        _preloadNextVideos();
      }
    } catch (e) {
      print('Error loading reels posts: $e');
      setState(() => _isReelsLoading = false);
    }
  }

  void _initializeCurrentReel() {
    if (_reelsPosts.isNotEmpty && _currentReelIndex < _reelsPosts.length) {
      _playVideo(_reelsPosts[_currentReelIndex].id);
    }
  }

  void _initializeVideoController(int index) {
    if (index >= _reelsPosts.length) return;

    final post = _reelsPosts[index];
    if (!_videoControllers.containsKey(post.id)) {
      try {
        // AFTER — Bunny Stream direct MP4 URLs don't need proxying
          final videoUrl = post.mediaUrls.firstWhere(
            (url) => url.contains('.mp4') || url.contains('.b-cdn.net'),
            orElse: () => post.mediaUrls.first,
          );

          final controller = VideoPlayerController.network(videoUrl);
        
        _videoControllers[post.id] = controller;

        final chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: false,
          looping: false,
          showControls: true,
          showControlsOnInitialize: false, // ADD THIS
          hideControlsTimer: Duration(seconds: 2), // ADD THIS - controls hide after 2 seconds
          allowFullScreen: true,
          allowPlaybackSpeedChanging: false, // CHANGE THIS to false
          materialProgressColors: ChewieProgressColors(
            playedColor: AppColors.primaryPurple,
            handleColor: AppColors.primaryPurple,
            backgroundColor: Colors.grey.withOpacity(0.5),
            bufferedColor: Colors.grey.withOpacity(0.3),
          ),
          placeholder: Container(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
          ),
        );
        _chewieControllers[post.id] = chewieController;

        controller.initialize().then((_) {
          // Add listener for video completion
          controller.addListener(() {
            if (controller.value.position >= controller.value.duration) {
              _onVideoComplete();
            }
          });
          
          if (mounted && index == _currentReelIndex) {
            setState(() {});
          }
        });
      } catch (e) {
        print('Error initializing video controller: $e');
      }
    }
  }

  void _onVideoComplete() {
    // Auto-advance to next reel
    if (_currentReelIndex < _reelsPosts.length - 1) {
      _reelsPageController.nextPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _playVideo(String postId) {
    final controller = _videoControllers[postId];
    if (controller != null && !controller.value.isPlaying) {
      controller.play();
    }
  }

  void _pauseVideo(String postId) {
    final controller = _videoControllers[postId];
    if (controller != null && controller.value.isPlaying) {
      controller.pause();
    }
  }

  void _pauseAllVideos() {
    _videoControllers.forEach((id, controller) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    });
  }

  void _disposeAllVideoControllers() {
    _videoControllers.forEach((key, controller) {
      controller.dispose();
    });
    _chewieControllers.forEach((key, controller) {
      controller.dispose();
    });
    _videoControllers.clear();
    _chewieControllers.clear();
  }

  void _preloadNextVideos() {
    final startIndex = _currentReelIndex + 1;
    final endIndex = startIndex + 4; // Preload 4 videos ahead
    
    for (int i = startIndex; i < endIndex && i < _reelsPosts.length; i++) {
      _initializeVideoController(i);
    }
  }

  void _onReelPageChanged(int newIndex) {
    // Pause previous video
    if (_currentReelIndex < _reelsPosts.length) {
      final prevPost = _reelsPosts[_currentReelIndex];
      _pauseVideo(prevPost.id);
    }

    // Update current index
    _currentReelIndex = newIndex;
    
    // Play new video
    if (newIndex < _reelsPosts.length) {
      final currentPost = _reelsPosts[newIndex];
      _playVideo(currentPost.id);
    }

    // Preload next videos
    _preloadNextVideos();
  }

  // ============== HELPER METHODS ==============

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

  Color _getRandomBackgroundColor(String postId) {
    // Use post ID to generate consistent color for each post
    final random = Random(postId.hashCode);
    return _backgroundColors[random.nextInt(_backgroundColors.length)];
  }

  // Navigate to user screen
  void _navigateToUserScreen(String userId, String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserScreen(
          userId: userId,
          username: username,
        ),
      ),
    );
  }

  // ============== SHARED UI COMPONENTS ==============

  Future<void> _toggleLike(String postId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    
    try {
      await _postService.toggleLike(postId, userId);
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<void> _sharePost(PostModel post) async {
    try {
      final shareableLink = 'https://campusconnect.app/post/${post.id}';
      await Share.share('Check out this post: $shareableLink');
      await _postService.incrementShareCount(post.id);
    } catch (e) {
      print('Error sharing post: $e');
    }
  }

  void _showComments(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(postId: postId),
    );
  }

  Widget _buildSideActions(PostModel post, {bool isTextOnly = false}) {
    final userId = _authService.currentUser?.uid;
    final isLiked = userId != null && post.isLikedBy(userId);

    return Positioned(
      right: 16,
      bottom: isTextOnly ? 80 : 100,
      child: Column(
        children: [
          // Profile Avatar
          GestureDetector(
            onTap: () {
              if (!post.isAnonymous) {
                _navigateToUserScreen(post.userId, post.username);
              }
            },
            child: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage: post.isAnonymous || post.userAvatar == null
                  ? null
                  : CachedNetworkImageProvider(_getProxiedMediaUrl(post.userAvatar!)),
              child: post.isAnonymous || post.userAvatar == null
                  ? Icon(Icons.person, size: 20, color: Colors.white)
                  : null,
            ),
          ),
          SizedBox(height: 20),

          // Like Button
          _buildActionButton(
            icon: Icons.favorite,
            count: post.likeCount,
            isActive: isLiked,
            onTap: () => _toggleLike(post.id),
          ),
          SizedBox(height: 20),

          // Comment Button
          _buildActionButton(
            icon: Icons.comment,
            count: post.commentsCount,
            onTap: () => _showComments(post.id),
          ),
          SizedBox(height: 20),

          // Share Button
          _buildActionButton(
            icon: Icons.share,
            count: post.shareCount,
            onTap: () => _sharePost(post),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            size: 30,
            color: isActive ? AppColors.primaryPurple : Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          _formatCount(count),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildPostContent(PostModel post, {bool isTextOnly = false}) {
    return Positioned(
      left: 16,
      right: 100,
      bottom: isTextOnly ? 60 : 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username - Clickable
          GestureDetector(
            onTap: () {
              if (!post.isAnonymous) {
                _navigateToUserScreen(post.userId, post.username);
              }
            },
            child: Text(
              '@${post.isAnonymous ? 'anonymous' : post.username.toLowerCase()}',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 8),

          // Post Content
          if (post.content.isNotEmpty) _buildExpandableText(post.content),

          // Tags
          if (post.tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: post.tags.map((tag) {
                return Text(
                  '#$tag',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandableText(String text) {
    bool isExpanded = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final textPainter = TextPainter(
                  text: TextSpan(
                    text: text,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  maxLines: 3,
                  textDirection: TextDirection.ltr,
                );

                textPainter.layout(maxWidth: constraints.maxWidth);
                final isTextLong = textPainter.didExceedMaxLines;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      maxLines: isExpanded ? null : 3,
                      overflow: isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
                    ),
                    if (isTextLong && !isExpanded)
                      GestureDetector(
                        onTap: () => setState(() => isExpanded = true),
                        child: Text(
                          'See more',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ============== FEED (IMAGES & TEXT) UI ==============

  Widget _buildTextOnlyPost(PostModel post) {
    final backgroundColor = _getRandomBackgroundColor(post.id);

    return Stack(
      children: [
        // Colored Background
        Positioned.fill(
          child: Container(
            color: backgroundColor,
          ),
        ),

        // Centered Text Content
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Username - Clickable
                GestureDetector(
                  onTap: () {
                    if (!post.isAnonymous) {
                      _navigateToUserScreen(post.userId, post.username);
                    }
                  },
                  child: Text(
                    '@${post.isAnonymous ? 'anonymous' : post.username.toLowerCase()}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 24),

                // Post Content
                Text(
                  post.content,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Tags
                if (post.tags.isNotEmpty) ...[
                  SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: post.tags.map((tag) {
                      return Text(
                        '#$tag',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Side Actions
        _buildSideActions(post, isTextOnly: true),
      ],
    );
  }

  Widget _buildImageCarousel(PostModel post) {
    if (!_currentCarouselIndex.containsKey(post.id)) {
      _currentCarouselIndex[post.id] = 0;
    }

    return Stack(
      children: [
        // Image Carousel
        PageView.builder(
          itemCount: post.mediaUrls.length,
          onPageChanged: (index) {
            setState(() {
              _currentCarouselIndex[post.id] = index;
            });
          },
          itemBuilder: (context, index) {
            return GestureDetector(
              onDoubleTap: () => _toggleLike(post.id),
              child: Container(
                color: Colors.black,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: _getProxiedMediaUrl(post.mediaUrls[index]),
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(color: AppColors.primaryPurple),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Icon(Icons.broken_image, size: 50, color: Colors.white),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // White dots indicator
        if (post.mediaUrls.length > 1)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                post.mediaUrls.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentCarouselIndex[post.id] == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeedPost(PostModel post) {
    // Check if it's a text-only post
    if (!post.hasMedia || post.mediaUrls.isEmpty) {
      return _buildTextOnlyPost(post);
    }

    // Regular image post
    return Stack(
      children: [
        // Image Carousel
        Positioned.fill(
          child: _buildImageCarousel(post),
        ),

        // Gradient Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Post Content
        _buildPostContent(post),

        // Side Actions
        _buildSideActions(post),
      ],
    );
  }

  Widget _buildFeedPage() {
    if (_isFeedLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      );
    }

    if (_feedPosts.isEmpty) {
      return _buildEmptyState('No posts yet');
    }

    return PageView.builder(
      controller: _feedPageController,
      scrollDirection: Axis.vertical,
      itemCount: _feedPosts.length,
      onPageChanged: (index) {
        setState(() => _currentFeedPage = index);
      },
      itemBuilder: (context, index) {
        return _buildFeedPost(_feedPosts[index]);
      },
    );
  }

  // ============== REELS (VIDEOS) UI ==============

  Widget _buildReelPost(PostModel post, int index) {
    final chewieController = _chewieControllers[post.id];

    return Stack(
      children: [
        // Video Player
        Positioned.fill(
          child: chewieController != null
              ? Chewie(controller: chewieController)
              : Center(
                  child: CircularProgressIndicator(color: AppColors.primaryPurple),
                ),
        ),

        // Gradient Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Post Content
        _buildPostContent(post),

        // Side Actions
        _buildSideActions(post),

        // Video Progress Indicator
        if (post.mediaUrls.length > 1)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                post.mediaUrls.length,
                (i) => Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 0 ? Colors.white : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReelsPage() {
    if (_isReelsLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      );
    }

    if (_reelsPosts.isEmpty) {
      return _buildEmptyState('No video reels yet');
    }

    return PageView.builder(
      controller: _reelsPageController,
      scrollDirection: Axis.vertical,
      itemCount: _reelsPosts.length,
      onPageChanged: _onReelPageChanged,
      itemBuilder: (context, index) {
        return _buildReelPost(_reelsPosts[index], index);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _tabController.index == 0 ? Icons.photo_library : Icons.video_library,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============== MAIN BUILD ==============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Campus Connect',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryPurple,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: Icon(Icons.grid_on, color: Colors.white)
            ),
            Tab(
              icon: Icon(Icons.video_library, color: Colors.white)
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Feed Tab (Images & Text)
          _buildFeedPage(),
          
          // Reels Tab (Videos)
          _buildReelsPage(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreatePostScreen(
              onPostCreated: () {
                _loadFeedPosts();
                _loadReelsPosts();
              },
            ),
          ),
        ),
        backgroundColor: AppColors.primaryPurple,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}