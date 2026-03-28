import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../constants/app_constants.dart';
import '../../models/discussion_model.dart';
import '../../models/discussion_message_model.dart';
import '../../services/discussion_service.dart';
import '../../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DiscussionChatScreen extends StatefulWidget {
  final DiscussionModel discussion;

  const DiscussionChatScreen({
    Key? key,
    required this.discussion,
  }) : super(key: key);

  @override
  State<DiscussionChatScreen> createState() => _DiscussionChatScreenState();
}

class _DiscussionChatScreenState extends State<DiscussionChatScreen> {
  final DiscussionService _discussionService = DiscussionService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  File? _selectedImage;
  PlatformFile? _selectedImageFile; // For web support
  DiscussionMessageModel? _replyToMessage;
  bool _hasJoined = false;
  String _username = '';
  String? _userAvatar;

  @override
  void initState() {
    super.initState();
    _checkJoinStatus();
    _loadUserData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkJoinStatus() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _hasJoined = widget.discussion.hasUserJoined(userId);
    });
  }

  Future<void> _loadUserData() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      setState(() {
        _username = userDoc.data()?['username'] ?? 'User';
        _userAvatar = userDoc.data()?['avatarUrl'];
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _joinDiscussion() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      await _discussionService.joinDiscussion(
        widget.discussion.id,
        userId,
        _username,
      );
      setState(() => _hasJoined = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining discussion')),
      );
    }
  }

  Future<void> _leaveDiscussion() async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Leave Discussion',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to leave this discussion?',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Leave', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;

      try {
        await _discussionService.leaveDiscussion(
          widget.discussion.id,
          userId,
          _username,
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving discussion')),
        );
      }
    }
  }

  Future<void> _deleteDiscussion() async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Discussion',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will delete the discussion and all messages in 10 seconds. This cannot be undone.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Schedule deletion with countdown
        _discussionService.scheduleDiscussionDeletion(
          discussionId: widget.discussion.id,
          countdownSeconds: 10,
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting discussion')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      print('Opening file picker...');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Important for web - loads file bytes
      );

      if (result == null) {
        print('File picker cancelled by user');
        return;
      }

      if (result.files.isEmpty) {
        print('No files selected');
        return;
      }

      final file = result.files.first;
      print('File selected: ${file.name}');
      print('File size: ${file.size} bytes');
      print('Is web: $kIsWeb');
      
      if (kIsWeb) {
        if (file.bytes == null) {
          throw Exception('File bytes not available on web. Please try again.');
        }
        print('Web: File bytes loaded successfully (${file.bytes!.length} bytes)');
      } else {
        if (file.path == null || file.path!.isEmpty) {
          throw Exception('File path not available on mobile. Please try again.');
        }
        print('Mobile: File path = ${file.path}');
      }

      // Validate file size (max 5MB)
      if (file.size > 5242880) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image must be less than 5MB'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _selectedImageFile = file;
        if (!kIsWeb && file.path != null) {
          _selectedImage = File(file.path!);
        }
      });

      print('Image selected successfully and stored in state');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image selected: ${file.name}'),
          backgroundColor: AppColors.primaryPurple,
          duration: Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      print('ERROR picking image: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Error selecting image',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                e.toString(),
                style: GoogleFonts.poppins(fontSize: 11),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please sign in to send messages'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_hasJoined) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please join the discussion first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty && _selectedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a message or select an image'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      String? imageUrl;
      
      // Handle image upload
      if (_selectedImageFile != null) {
        print('Starting image upload...');
        print('File name: ${_selectedImageFile!.name}');
        print('File size: ${_selectedImageFile!.size} bytes');
        
        if (kIsWeb) {
          // Web upload using bytes
          if (_selectedImageFile!.bytes != null) {
            print('Uploading from web using bytes');
            imageUrl = await _discussionService.uploadDiscussionImage(
              fileBytes: _selectedImageFile!.bytes,
              fileName: _selectedImageFile!.name,
              discussionId: widget.discussion.id,
            );
          } else {
            throw Exception('Image bytes not available for web upload');
          }
        } else {
          // Mobile upload using file path
          if (_selectedImage != null && _selectedImage!.path.isNotEmpty) {
            print('Uploading from mobile using file path: ${_selectedImage!.path}');
            imageUrl = await _discussionService.uploadDiscussionImage(
              filePath: _selectedImage!.path,
              fileName: _selectedImageFile!.name,
              discussionId: widget.discussion.id,
            );
          } else {
            throw Exception('Image file path not available for mobile upload');
          }
        }
        
        print('Image uploaded successfully: $imageUrl');
      }

      // Send message
      print('Sending message to discussion: ${widget.discussion.id}');
      await _discussionService.sendMessage(
        discussionId: widget.discussion.id,
        senderId: userId,
        senderName: _username,
        senderAvatar: _userAvatar,
        message: message,
        imageUrl: imageUrl,
        replyToMessageId: _replyToMessage?.id,
        replyToMessage: _replyToMessage?.message,
        replyToSenderName: _replyToMessage?.senderName,
      );

      print('Message sent successfully');

      // Clear inputs
      _messageController.clear();
      setState(() {
        _selectedImage = null;
        _selectedImageFile = null;
        _replyToMessage = null;
      });

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message sent!'),
          backgroundColor: AppColors.primaryPurple,
          duration: Duration(seconds: 1),
        ),
      );

      // Scroll to bottom after a short delay
      Future.delayed(Duration(milliseconds: 500), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('ERROR sending message: $e');
      
      // Show detailed error message
      String errorMessage = 'Failed to send message';
      if (e.toString().contains('upload')) {
        errorMessage = 'Failed to upload image. Please try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your settings.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                errorMessage,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Error: ${e.toString()}',
                style: GoogleFonts.poppins(fontSize: 11),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: _sendMessage,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${timestamp.minute.toString().padLeft(2, '0')} $period';
  }

  Widget _buildMessageBubble(DiscussionMessageModel message, bool isMe) {
    if (message.isSystemMessage) {
      return Center(
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.message,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () {
        setState(() {
          _replyToMessage = message;
        });
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.withOpacity(0.3),
                backgroundImage: message.senderAvatar != null
                  ? CachedNetworkImageProvider(message.senderAvatar!)
                  : null,
                child: message.senderAvatar == null
                    ? Text(
                        message.senderName[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(
                        message.senderName,
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primaryPurple : Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                        bottomLeft: isMe ? Radius.circular(12) : Radius.circular(4),
                        bottomRight: isMe ? Radius.circular(4) : Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.hasReply)
                          Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.replyToSenderName ?? '',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  message.replyToMessage ?? '',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        if (message.hasImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: message.imageUrl!,
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (message.message.isNotEmpty)
                          Text(
                            message.message,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _formatTime(message.createdAt),
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isMe) SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;
    final isCreator = userId == widget.discussion.createdBy;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    widget.discussion.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.discussion.fireEmojis.isNotEmpty) ...[
                  SizedBox(width: 6),
                  Text(widget.discussion.fireEmojis, style: TextStyle(fontSize: 14)),
                ],
              ],
            ),
            Text(
              '\${widget.discussion.participantCount} participants',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (_hasJoined)
            PopupMenuButton(
              icon: Icon(Icons.more_vert, color: Colors.white),
              color: Color(0xFF1E1E1E),
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: _leaveDiscussion,
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.white70, size: 20),
                      SizedBox(width: 12),
                      Text('Leave Discussion', style: GoogleFonts.poppins(color: Colors.white)),
                    ],
                  ),
                ),
                if (isCreator)
                  PopupMenuItem(
                    onTap: _deleteDiscussion,
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Delete Discussion', style: GoogleFonts.poppins(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_hasJoined)
            Container(
              padding: EdgeInsets.all(16),
              color: AppColors.primaryPurple.withOpacity(0.2),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primaryPurple),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Join this discussion to send messages',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _joinDiscussion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Join', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<DiscussionMessageModel>>(
              stream: _discussionService.getMessages(widget.discussion.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && 
                    !snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primaryPurple),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.red),
                        SizedBox(height: 12),
                        Text(
                          'Error loading messages',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 60, color: Colors.white54),
                        SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Be the first to say something!',
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                // Auto-scroll to bottom when new message arrives
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == userId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          if (_replyToMessage != null)
            Container(
              padding: EdgeInsets.all(12),
              color: Color(0xFF1A1A1A),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to \${_replyToMessage!.senderName}',
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _replyToMessage!.message,
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => setState(() => _replyToMessage = null),
                  ),
                ],
              ),
            ),
          if (_selectedImageFile != null)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail preview
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryPurple.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: kIsWeb
                          ? (_selectedImageFile!.bytes != null
                              ? Image.memory(
                                  _selectedImageFile!.bytes!,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Error loading image preview: $error');
                                    return Container(
                                      color: Colors.grey.shade800,
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.white54,
                                        size: 30,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey.shade800,
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.white54,
                                    size: 30,
                                  ),
                                ))
                          : (_selectedImage != null
                              ? Image.file(
                                  _selectedImage!,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Error loading image preview: $error');
                                    return Container(
                                      color: Colors.grey.shade800,
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.white54,
                                        size: 30,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey.shade800,
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.white54,
                                    size: 30,
                                  ),
                                )),
                    ),
                  ),
                  SizedBox(width: 12),
                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedImageFile!.name,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${(_selectedImageFile!.size / 1024).toStringAsFixed(1)} KB',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ready to send',
                            style: GoogleFonts.poppins(
                              color: AppColors.primaryPurple,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Remove button
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white70, size: 22),
                    onPressed: () {
                      print('Removing selected image');
                      setState(() {
                        _selectedImage = null;
                        _selectedImageFile = null;
                      });
                    },
                    tooltip: 'Remove image',
                  ),
                ],
              ),
            ),
          if (_hasJoined)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, -2))],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.image, color: AppColors.primaryPurple),
                      onPressed: _pickImage,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: GoogleFonts.poppins(color: Colors.white),
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: GoogleFonts.poppins(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSending ? null : _sendMessage,
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple,
                          shape: BoxShape.circle,
                        ),
                        child: _isSending
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Icon(Icons.send, color: Colors.white, size: 20),
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
}