import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_constants.dart';
import '../../models/conversation_model.dart';
import '../../models/friend_model.dart';
import '../../services/message_service.dart';
import '../../services/friend_service.dart';
import '../../services/auth_service.dart';
import 'add_friends_screen.dart';
import 'friend_requests_screen.dart';
import 'chat_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final MessageService _messageService = MessageService();
  final FriendService _friendService = FriendService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingRequestsCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingRequestsCount() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    _friendService.getPendingRequests(userId).listen((requests) {
      if (mounted) {
        setState(() {
          _pendingRequestsCount = requests.length;
        });
      }
    });
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

        return '$baseUrl/$schoolPath/get_image.php?folder=$folder&file=$filename';
      }
    } catch (e) {
      print('Error parsing URL: $e');
    }
    return url;
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      final hour = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
      final period = timestamp.hour >= 12 ? 'PM' : 'AM';
      return '${hour == 0 ? 12 : hour}:${timestamp.minute.toString().padLeft(2, '0')} $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _navigateToAllFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllFriendsScreen(),
      ),
    );
  }

  Widget _buildFriendsList() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<List<FriendModel>>(
      stream: _friendService.getFriends(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 120,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
          );
        }

        if (snapshot.hasError) {
          print('Error loading friends: ${snapshot.error}');
          return Container(
            height: 120,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Error loading friends',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 120,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 40,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No friends yet',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddFriendsScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Add Friends',
                      style: GoogleFonts.poppins(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final friends = snapshot.data!;
        
        return Container(
          height: 140,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Friends',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${friends.length}',
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryPurple,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'total',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _navigateToAllFriends,
                          child: Text(
                            'View All',
                            style: GoogleFonts.poppins(
                              color: AppColors.primaryPurple,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(friend.friendId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 12),
                            child: const Column(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.grey,
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryPurple,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                        final username = userData['username'] ?? 'User';
                        final avatarUrl = userData['avatarUrl'];
                        final isOnline = userData['isOnline'] ?? false;

                        return GestureDetector(
                          onTap: () async {
                            try {
                              final conversationId = await _messageService
                                  .getOrCreateConversation(userId, friend.friendId);
                              
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      conversationId: conversationId,
                                      otherUserId: friend.friendId,
                                      otherUsername: username,
                                      otherUserAvatar: avatarUrl,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              print('Error starting chat: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error starting conversation'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isOnline 
                                              ? Colors.green 
                                              : Colors.grey.withOpacity(0.5),
                                          width: 2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.grey.withOpacity(0.3),
                                        backgroundImage: avatarUrl != null
                                            ? CachedNetworkImageProvider(
                                                _getProxiedMediaUrl(avatarUrl))
                                            : null,
                                        child: avatarUrl == null
                                            ? Icon(Icons.person,
                                                color: Colors.white, size: 28)
                                            : null,
                                      ),
                                    ),
                                    if (isOnline)
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.black,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  username.length > 8
                                      ? '${username.substring(0, 8)}...'
                                      : username,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConversationsList() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      return Center(
        child: Text(
          'Please sign in to view messages',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      );
    }

    return StreamBuilder<List<ConversationModel>>(
      stream: _messageService.getConversations(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryPurple),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.withOpacity(0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading conversations',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start chatting with your friends!',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        var conversations = snapshot.data!;
        
        if (_searchQuery.isNotEmpty) {
          conversations = conversations.where((conversation) {
            final otherUserId = conversation.getOtherParticipantId(userId);
            return true;
          }).toList();
        }

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final otherUserId = conversation.getOtherParticipantId(userId);
            final unreadCount = conversation.getUnreadCount(userId);

            return FutureBuilder<Map<String, dynamic>?>(
              future: _getUserData(otherUserId),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox(height: 80);
                }

                final userData = userSnapshot.data!;
                final username = userData['username'] ?? 'User';
                final avatarUrl = userData['avatarUrl'];
                final isOnline = userData['isOnline'] ?? false;

                if (_searchQuery.isNotEmpty &&
                    !username.toLowerCase().contains(_searchQuery.toLowerCase())) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: unreadCount > 0 
                        ? AppColors.primaryPurple.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          backgroundImage: avatarUrl != null
                              ? CachedNetworkImageProvider(_getProxiedMediaUrl(avatarUrl))
                              : null,
                          child: avatarUrl == null
                              ? Icon(Icons.person, color: Colors.white, size: 28)
                              : null,
                        ),
                        if (isOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      username,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      conversation.lastMessage.isNotEmpty
                          ? conversation.lastMessage
                          : 'Start a conversation',
                      style: GoogleFonts.poppins(
                        color: unreadCount > 0
                            ? Colors.white
                            : Colors.white60,
                        fontSize: 14,
                        fontWeight: unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTimestamp(conversation.lastMessageTime),
                          style: GoogleFonts.poppins(
                            color: unreadCount > 0
                                ? AppColors.primaryPurple
                                : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversationId: conversation.id,
                            otherUserId: otherUserId,
                            otherUsername: username,
                            otherUserAvatar: avatarUrl,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          // View All Friends button
          IconButton(
            icon: const Icon(Icons.people, color: Colors.white, size: 26),
            onPressed: _navigateToAllFriends,
            tooltip: 'All Friends',
          ),
          // Friend Requests Icon
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.person_add, color: Colors.white, size: 26),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FriendRequestsScreen(),
                    ),
                  );
                },
                tooltip: 'Friend Requests',
              ),
              if (_pendingRequestsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        _pendingRequestsCount > 9
                            ? '9+'
                            : _pendingRequestsCount.toString(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Add Friend Icon
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.white, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddFriendsScreen(),
                ),
              );
            },
            tooltip: 'Add Friends',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1A1A1A),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: GoogleFonts.poppins(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Friends Horizontal List
          _buildFriendsList(),

          // Divider
          Divider(color: Colors.grey.withOpacity(0.3), height: 1),

          // Conversations List
          Expanded(
            child: _buildConversationsList(),
          ),
        ],
      ),
    );
  }
}

class AllFriendsScreen extends StatelessWidget {
  const AllFriendsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final friendService = FriendService();
    final messageService = MessageService();
    final userId = authService.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Friends',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: userId == null
          ? Center(
              child: Text(
                'Please sign in',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            )
          : StreamBuilder<List<FriendModel>>(
              stream: friendService.getFriends(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryPurple),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading friends',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No friends yet',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add friends to start chatting!',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddFriendsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add),
                          label: Text(
                            'Add Friends',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final friends = snapshot.data!;
                
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFF1A1A1A),
                      child: Row(
                        children: [
                          Text(
                            '${friends.length}',
                            style: GoogleFonts.poppins(
                              color: AppColors.primaryPurple,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            friends.length == 1 ? 'Friend' : 'Friends',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(friend.friendId)
                                .get(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A1A),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryPurple,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }

                              final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                              final username = userData['username'] ?? 'User';
                              final fullName = userData['fullName'] ?? '';
                              final avatarUrl = userData['avatarUrl'];
                              final isOnline = userData['isOnline'] ?? false;
                              final lastSeen = userData['lastSeen'] != null
                                  ? (userData['lastSeen'] as Timestamp).toDate()
                                  : null;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.grey.withOpacity(0.3),
                                        backgroundImage: avatarUrl != null
                                            ? CachedNetworkImageProvider(avatarUrl)
                                            : null,
                                        child: avatarUrl == null
                                            ? const Icon(Icons.person, 
                                                color: Colors.white, size: 30)
                                            : null,
                                      ),
                                      if (isOnline)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF1A1A1A),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    username,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (fullName.isNotEmpty)
                                        Text(
                                          fullName,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white54,
                                            fontSize: 14,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isOnline 
                                                  ? Colors.green 
                                                  : Colors.grey,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isOnline 
                                                ? 'Online' 
                                                : lastSeen != null
                                                    ? 'Last seen ${_formatLastSeen(lastSeen)}'
                                                    : 'Offline',
                                            style: GoogleFonts.poppins(
                                              color: isOnline 
                                                  ? Colors.green 
                                                  : Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: SizedBox(
                                    width: 100,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.chat_bubble_outline,
                                            color: AppColors.primaryPurple,
                                          ),
                                          onPressed: () async {
                                            try {
                                              final conversationId = await messageService
                                                  .getOrCreateConversation(
                                                      userId, friend.friendId);
                                              
                                              if (context.mounted) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChatScreen(
                                                      conversationId: conversationId,
                                                      otherUserId: friend.friendId,
                                                      otherUsername: username,
                                                      otherUserAvatar: avatarUrl,
                                                    ),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              print('Error starting chat: $e');
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Error starting conversation'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          tooltip: 'Chat',
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(
                                            Icons.more_vert,
                                            color: Colors.white54,
                                          ),
                                          color: const Color(0xFF2A2A2A),
                                          onSelected: (value) async {
                                            if (value == 'remove') {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  backgroundColor: const Color(0xFF1A1A1A),
                                                  title: Text(
                                                    'Remove Friend',
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  content: Text(
                                                    'Are you sure you want to remove $username from your friends?',
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: Text(
                                                        'Cancel',
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.white54,
                                                        ),
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: Text(
                                                        'Remove',
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.red,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              
                                              if (confirm == true && context.mounted) {
                                                await friendService.removeFriend(
                                                    userId, friend.friendId);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('$username removed from friends'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'remove',
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.person_remove,
                                                    color: Colors.red,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Remove Friend',
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
    }
  }
}