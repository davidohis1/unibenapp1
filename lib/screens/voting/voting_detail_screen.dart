import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_constants.dart';
import '../../models/voting_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class VotingDetailScreen extends StatefulWidget {
  final VotingModel voting;
  const VotingDetailScreen({Key? key, required this.voting}) : super(key: key);

  @override
  State<VotingDetailScreen> createState() => _VotingDetailScreenState();
}

class _VotingDetailScreenState extends State<VotingDetailScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;
  Map<String, String?> _userVotedFor = {}; // categoryId -> contestantId
  Map<String, bool> _isVoting = {};
  UserModel? _currentUser;
  bool _canVote = false;
  String? _accessDeniedReason;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.voting.categories.length,
      vsync: this,
    );
    _checkUserVote();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _authService.getUserData(user.uid);
      setState(() {
        _currentUser = userData;
        _checkAccessPermission(userData);
      });
    }
  }

  void _checkAccessPermission(UserModel? user) {
    if (user == null) {
      setState(() {
        _canVote = false;
        _accessDeniedReason = 'Please login to vote';
      });
      return;
    }

    if (!widget.voting.isActive) {
      setState(() {
        _canVote = false;
        _accessDeniedReason = 'Voting has ended';
      });
      return;
    }

    if (widget.voting.accessType == VotingAccess.general) {
      setState(() {
        _canVote = true;
        _accessDeniedReason = null;
      });
      return;
    }

    if (!user.isVerified) {
      setState(() {
        _canVote = false;
        _accessDeniedReason = 'Only verified students can vote';
      });
      return;
    }

    if (widget.voting.accessType == VotingAccess.faculty) {
      if (user.faculty == widget.voting.restrictedFaculty) {
        setState(() {
          _canVote = true;
          _accessDeniedReason = null;
        });
      } else {
        setState(() {
          _canVote = false;
          _accessDeniedReason = 'This voting is only for ${widget.voting.restrictedFaculty} students';
        });
      }
      return;
    }

    if (widget.voting.accessType == VotingAccess.department) {
      if (user.department == widget.voting.restrictedDepartment) {
        setState(() {
          _canVote = true;
          _accessDeniedReason = null;
        });
      } else {
        setState(() {
          _canVote = false;
          _accessDeniedReason = 'This voting is only for ${widget.voting.restrictedDepartment} students';
        });
      }
      return;
    }
  }

  Future<void> _checkUserVote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        for (var category in widget.voting.categories) {
          for (var contestant in category.contestants) {
            if (contestant.voters.contains(user.uid)) {
              _userVotedFor[category.id] = contestant.id;
              break;
            }
          }
        }
      });
    }
  }

  Future<void> _vote(String categoryId, String contestantId) async {
    if (!_canVote) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_accessDeniedReason ?? 'You cannot vote'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to vote')),
      );
      return;
    }

    if (_userVotedFor.containsKey(categoryId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already voted in this category')),
      );
      return;
    }

    setState(() => _isVoting[categoryId] = true);

    try {
      final votingRef = FirebaseFirestore.instance
          .collection(AppConstants.votingCollection)
          .doc(widget.voting.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(votingRef);
        if (!snapshot.exists) {
          throw Exception('Voting not found');
        }

        final votingData = VotingModel.fromMap(snapshot.data()!);
        
        // Update the specific category and contestant
        final updatedCategories = votingData.categories.map((category) {
          if (category.id != categoryId) return category;
          
          final updatedContestants = category.contestants.map((contestant) {
            if (contestant.id != contestantId) return contestant;
            
            return Contestant(
              id: contestant.id,
              name: contestant.name,
              tag: contestant.tag,
              imageUrl: contestant.imageUrl,
              votes: contestant.votes + 1,
              voters: [...contestant.voters, user.uid],
            );
          }).toList();

          return VotingCategory(
            id: category.id,
            name: category.name,
            description: category.description,
            contestants: updatedContestants,
          );
        }).toList();

        final updatedVoting = VotingModel(
          id: votingData.id,
          creatorId: votingData.creatorId,
          creatorName: votingData.creatorName,
          title: votingData.title,
          categories: updatedCategories,
          createdAt: votingData.createdAt,
          endDate: votingData.endDate,
          isActive: votingData.isActive,
          shareableLink: votingData.shareableLink,
          accessType: votingData.accessType,
          restrictedFaculty: votingData.restrictedFaculty,
          restrictedDepartment: votingData.restrictedDepartment,
        );

        transaction.update(votingRef, updatedVoting.toMap());
      });

      setState(() {
        _userVotedFor[categoryId] = contestantId;
        _isVoting[categoryId] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote submitted successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isVoting[categoryId] = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _shareVoting() {
    String accessText = '';
    switch (widget.voting.accessType) {
      case VotingAccess.general:
        accessText = 'Open to all students';
        break;
      case VotingAccess.faculty:
        accessText = 'Only for ${widget.voting.restrictedFaculty} students';
        break;
      case VotingAccess.department:
        accessText = 'Only for ${widget.voting.restrictedDepartment} students';
        break;
    }

    Share.share(
      '🎉 ${widget.voting.title}\n\n'
      '$accessText\n\n'
      '${widget.voting.categories.length} Categories\n\n'
      'Join the voting now!\n'
      '${widget.voting.shareableLink}',
      subject: widget.voting.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalVotes = widget.voting.totalVotes;
    final daysLeft = widget.voting.endDate != null
        ? widget.voting.endDate!.difference(DateTime.now()).inDays
        : null;

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text('Voting Details', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.white,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: widget.voting.categories.map((category) {
            return Tab(text: category.name);
          }).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareVoting,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.votingCollection)
            .doc(widget.voting.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            );
          }

          final voting = VotingModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);
          final updatedTotalVotes = voting.totalVotes;

          return Column(
            children: [
              // Info Header
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voting.title,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Access Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getAccessColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getAccessIcon(),
                            size: 14,
                            color: _getAccessColor(),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            voting.accessDescription,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: _getAccessColor(),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Stats Row
                    Row(
                      children: [
                        Icon(Icons.category, size: 16, color: AppColors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${voting.categories.length} Categories',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.grey),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.how_to_vote, size: 16, color: AppColors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '$updatedTotalVotes Total Votes',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.grey),
                        ),
                      ],
                    ),
                    
                    // End Date
                    if (daysLeft != null && voting.isActive) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: AppColors.grey),
                          const SizedBox(width: 4),
                          Text(
                            daysLeft > 0 ? 'Ends in $daysLeft days' : 'Ending today',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: daysLeft > 3 ? AppColors.successGreen : AppColors.errorRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Access Denied Message
                    if (!_canVote && _accessDeniedReason != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock, size: 16, color: AppColors.errorRed),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _accessDeniedReason!,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.errorRed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 4),
                    Text(
                      'Created by ${voting.creatorName}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Bar View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: voting.categories.map((category) {
                    return _buildCategoryPage(voting, category);
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getAccessColor() {
    switch (widget.voting.accessType) {
      case VotingAccess.general:
        return AppColors.successGreen;
      case VotingAccess.faculty:
        return AppColors.primaryPurple;
      case VotingAccess.department:
        return Colors.orange;
    }
  }

  IconData _getAccessIcon() {
    switch (widget.voting.accessType) {
      case VotingAccess.general:
        return Icons.public;
      case VotingAccess.faculty:
        return Icons.school;
      case VotingAccess.department:
        return Icons.account_balance;
    }
  }

  Widget _buildCategoryPage(VotingModel voting, VotingCategory category) {
    final categoryTotalVotes = category.totalVotes;
    final hasVoted = _userVotedFor.containsKey(category.id);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: category.contestants.length,
      itemBuilder: (context, index) {
        final contestant = category.contestants[index];
        final percentage = categoryTotalVotes > 0
            ? (contestant.votes / categoryTotalVotes * 100).toStringAsFixed(1)
            : '0.0';
        final isVotedFor = _userVotedFor[category.id] == contestant.id;

        return _buildContestantCard(
          contestant: contestant,
          percentage: percentage,
          isVotedFor: isVotedFor,
          hasVoted: hasVoted,
          categoryId: category.id,
          totalVotes: categoryTotalVotes,
        );
      },
    );
  }

  Widget _buildContestantCard({
    required Contestant contestant,
    required String percentage,
    required bool isVotedFor,
    required bool hasVoted,
    required String categoryId,
    required int totalVotes,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: isVotedFor
            ? Border.all(color: AppColors.primaryPurple, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (_isVoting[categoryId] == true) || hasVoted || !_canVote
              ? null
              : () => _vote(categoryId, contestant.id),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Contestant Image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: contestant.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: contestant.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 32,
                              color: AppColors.primaryPurple,
                            ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Contestant Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contestant.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (contestant.tag != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              contestant.tag!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Vote Count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${contestant.votes}',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        Text(
                          'votes',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Vote Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: totalVotes > 0 ? contestant.votes / totalVotes : 0,
                    backgroundColor: AppColors.lightGrey,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isVotedFor ? AppColors.primaryPurple : AppColors.primaryPurple.withOpacity(0.5),
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Percentage and Vote Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_isVoting[categoryId] == true)
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Voting...',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        ],
                      )
                    else if (isVotedFor)
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: AppColors.primaryPurple),
                          const SizedBox(width: 4),
                          Text(
                            'Your vote',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else if (!_canVote)
                      Row(
                        children: [
                          Icon(Icons.lock, size: 16, color: AppColors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Cannot vote',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      )
                    else if (!hasVoted)
                      Row(
                        children: [
                          Icon(Icons.how_to_vote, size: 16, color: AppColors.primaryPurple),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to vote',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(),
                    
                    Text(
                      '$percentage%',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}