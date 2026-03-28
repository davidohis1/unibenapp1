import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_constants.dart';
import '../../models/voting_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'add_voting_screen.dart';
import 'voting_detail_screen.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({Key? key}) : super(key: key);

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _authService.getUserData(user.uid);
      setState(() {
        _currentUser = userData;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text('Voting',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Ended'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search voting...',
                hintStyle:
                    GoogleFonts.poppins(fontSize: 14, color: AppColors.grey),
                prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                filled: true,
                fillColor: AppColors.lightGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVotingList(isActive: true),
                _buildVotingList(isActive: false),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddVotingScreen()),
          ).then((_) => _loadCurrentUser()); // Refresh user data
        },
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add, color: AppColors.white),
        label: Text('Create Voting',
            style: GoogleFonts.poppins(color: AppColors.white)),
      ),
    );
  }

  Widget _buildVotingList({required bool isActive}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.votingCollection)
          .where('isActive', isEqualTo: isActive)
          .snapshots(), // Remove orderBy temporarily to test
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryPurple),
          );
        }

        if (snapshot.hasError) {
          print('Error: ${snapshot.error}');
          return Center(
            child: Text(
              'Error loading votings',
              style: GoogleFonts.poppins(color: AppColors.errorRed),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.how_to_vote,
                    size: 80, color: AppColors.grey.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  isActive ? 'No active voting' : 'No ended voting',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ],
            ),
          );
        }

        // Convert and sort manually
        var votings = snapshot.data!.docs
            .map((doc) {
              try {
                return VotingModel.fromMap(doc.data() as Map<String, dynamic>);
              } catch (e) {
                print('Error parsing voting: $e');
                return null;
              }
            })
            .whereType<VotingModel>()
            .toList();

        // Sort manually by createdAt
        votings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Apply search filter
        if (_searchController.text.isNotEmpty) {
          votings = votings.where((voting) {
            return voting.title
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());
          }).toList();
        }

        if (votings.isEmpty) {
          return Center(
            child: Text('No voting found', style: GoogleFonts.poppins()),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: votings.length,
          itemBuilder: (context, index) {
            return _buildVotingCard(votings[index]);
          },
        );
      },
    );
  }

  Widget _buildVotingCard(VotingModel voting) {
    final totalVotes = voting.totalVotes;
    final daysLeft = voting.endDate != null
        ? voting.endDate!.difference(DateTime.now()).inDays
        : null;

    // Check if user can vote in this voting
    bool userCanVote =
        _currentUser != null && voting.canUserVote(_currentUser!);
    Color accessColor = _getAccessColor(voting.accessType);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VotingDetailScreen(voting: voting),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          voting.title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Access Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accessColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getAccessIcon(voting.accessType),
                              size: 12,
                              color: accessColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getAccessShortText(voting),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: accessColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Categories and Votes
                  Row(
                    children: [
                      Icon(Icons.category, size: 14, color: AppColors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${voting.categories.length} categories',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.grey),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.how_to_vote, size: 14, color: AppColors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '$totalVotes votes',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.grey),
                      ),
                    ],
                  ),

                  // Preview of first few categories
                  if (voting.categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Categories: ${voting.categories.take(3).map((c) => c.name).join(' • ')}${voting.categories.length > 3 ? '...' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // End Date and Eligibility
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (voting.isActive && daysLeft != null)
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: daysLeft > 3
                                  ? AppColors.successGreen
                                  : AppColors.errorRed,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              daysLeft > 0
                                  ? '$daysLeft days left'
                                  : 'Ending soon',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: daysLeft > 3
                                    ? AppColors.successGreen
                                    : AppColors.errorRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                      // Eligibility indicator
                      if (!voting.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Ended',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: AppColors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (_currentUser != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: userCanVote
                                ? AppColors.successGreen.withOpacity(0.1)
                                : AppColors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                userCanVote ? Icons.check_circle : Icons.lock,
                                size: 10,
                                color: userCanVote
                                    ? AppColors.successGreen
                                    : AppColors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                userCanVote ? 'Eligible' : 'Not eligible',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: userCanVote
                                      ? AppColors.successGreen
                                      : AppColors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'By ${voting.creatorName}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // Leading Contestant Preview
            if (voting.categories.isNotEmpty &&
                voting.categories.first.contestants.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey.withOpacity(0.5),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Leading: ${voting.categories.first.contestants.reduce((a, b) => a.votes > b.votes ? a : b).name}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppColors.primaryPurple,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getAccessColor(VotingAccess access) {
    switch (access) {
      case VotingAccess.general:
        return AppColors.successGreen;
      case VotingAccess.faculty:
        return AppColors.primaryPurple;
      case VotingAccess.department:
        return Colors.orange;
    }
  }

  IconData _getAccessIcon(VotingAccess access) {
    switch (access) {
      case VotingAccess.general:
        return Icons.public;
      case VotingAccess.faculty:
        return Icons.school;
      case VotingAccess.department:
        return Icons.account_balance;
    }
  }

  String _getAccessShortText(VotingModel voting) {
    switch (voting.accessType) {
      case VotingAccess.general:
        return 'All';
      case VotingAccess.faculty:
        return voting.restrictedFaculty?.split(' ').last ?? 'Faculty';
      case VotingAccess.department:
        return voting.restrictedDepartment?.split(' ').first ?? 'Dept';
    }
  }
}
