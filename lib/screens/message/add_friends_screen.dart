import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_constants.dart';
import '../../services/friend_service.dart';
import '../../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({Key? key}) : super(key: key);

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  final FriendService _friendService = FriendService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  Map<String, String> _requestStatuses = {}; // userId -> status

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getProxiedMediaUrl(String url) {
    if (!kIsWeb) return url;

    try {
      final uri = Uri.parse(url);

      if (uri.path.contains('get_image.php')) {
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

  Future<void> _checkRequestStatus(String otherUserId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    final status = await _friendService.getFriendRequestStatus(userId, otherUserId);
    if (mounted) {
      setState(() {
        _requestStatuses[otherUserId] = status ?? 'none';
      });
    }
  }

  Future<void> _sendFriendRequest(String receiverId, String username) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      await _friendService.sendFriendRequest(userId, receiverId);
      
      setState(() {
        _requestStatuses[receiverId] = 'pending';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to $username!'),
          backgroundColor: AppColors.primaryPurple,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send friend request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildActionButton(String userId, String username, String status) {
    switch (status) {
      case 'accepted':
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text(
                'Friends',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case 'pending':
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Pending',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      default:
        return ElevatedButton(
          onPressed: () => _sendFriendRequest(userId, username),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Add Friend',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Friends',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFF1A1A1A),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: GoogleFonts.poppins(color: Colors.white54),
                prefixIcon: Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.white54),
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
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Users List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primaryPurple),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No users found',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                var users = snapshot.data!.docs;

                // Filter out current user
                users = users.where((doc) => doc.id != currentUserId).toList();

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  users = users.where((doc) {
                    final username = doc['username'] ?? '';
                    return username
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userDoc = users[index];
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final userId = userDoc.id;
                    final username = userData['username'] ?? 'User';
                    final avatarUrl = userData['avatarUrl'];
                    final bio = userData['bio'] ?? '';

                    // Check request status
                    if (!_requestStatuses.containsKey(userId)) {
                      _checkRequestStatus(userId);
                    }

                    final status = _requestStatuses[userId] ?? 'none';

                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey.withOpacity(0.3),
                            backgroundImage: avatarUrl != null
                                ? CachedNetworkImageProvider(
                                    _getProxiedMediaUrl(avatarUrl))
                                : null,
                            child: avatarUrl == null
                                ? Icon(Icons.person, color: Colors.white, size: 30)
                                : null,
                          ),
                          SizedBox(width: 12),

                          // User Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (bio.isNotEmpty)
                                  Text(
                                    bio,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white60,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),

                          // Action Button
                          _buildActionButton(userId, username, status),
                        ],
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
  }
}