import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../constants/app_constants.dart';
import '../../../models/quiz_game_model.dart';
import '../../../models/game_participant_model.dart';
import '../../../services/quiz_game_service.dart';
import '../../../services/auth_service.dart';

class GameLeaderboardScreen extends StatefulWidget {
  final QuizGameModel game;

  const GameLeaderboardScreen({
    Key? key,
    required this.game,
  }) : super(key: key);

  @override
  State<GameLeaderboardScreen> createState() => _GameLeaderboardScreenState();
}

class _GameLeaderboardScreenState extends State<GameLeaderboardScreen> {
  final QuizGameService _gameService = QuizGameService();
  final AuthService _authService = AuthService();

  Color _getRankColor(int rank) {
    if (rank == 1) return Color(0xFFFFD700); // Gold
    if (rank == 2) return Color(0xFFC0C0C0); // Silver
    if (rank == 3) return Color(0xFFCD7F32); // Bronze
    return Colors.white70;
  }

  IconData _getRankIcon(int rank) {
    if (rank <= 3) return Icons.emoji_events;
    return Icons.person;
  }

  String _getPrizeText(int rank) {
    final prize = _gameService.getPrizeForRank(rank);
    if (prize > 0) {
      return '₦${prize.toStringAsFixed(0)}';
    }
    return '';
  }

  Widget _buildPodium(List<GameParticipantModel> topThree) {
    if (topThree.isEmpty) return SizedBox();

    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 2nd Place
          if (topThree.length > 1) _buildPodiumPosition(topThree[1], 2, 100),
          SizedBox(width: 8),
          // 1st Place
          _buildPodiumPosition(topThree[0], 1, 130),
          SizedBox(width: 8),
          // 3rd Place
          if (topThree.length > 2) _buildPodiumPosition(topThree[2], 3, 80),
        ],
      ),
    );
  }

  Widget _buildPodiumPosition(GameParticipantModel participant, int rank, double height) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _getRankColor(rank), width: 3),
            image: participant.profileImageUrl != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(participant.profileImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: participant.profileImageUrl == null
              ? Center(
                  child: Text(
                    participant.username[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
        SizedBox(height: 8),
        Icon(
          Icons.emoji_events,
          color: _getRankColor(rank),
          size: 32,
        ),
        SizedBox(height: 4),
        Text(
          participant.username,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${participant.score} pts',
          style: GoogleFonts.poppins(
            color: AppColors.primaryPurple,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: 90,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getRankColor(rank).withOpacity(0.6),
                _getRankColor(rank).withOpacity(0.3),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getPrizeText(rank),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardItem(GameParticipantModel participant, int rank, bool isCurrentUser) {
    final prize = _getPrizeText(rank);
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser 
            ? AppColors.primaryPurple.withOpacity(0.2)
            : Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser 
              ? AppColors.primaryPurple 
              : rank <= 50 ? Colors.amber.withOpacity(0.3) : Colors.transparent,
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 50,
            child: Column(
              children: [
                Icon(
                  _getRankIcon(rank),
                  color: _getRankColor(rank),
                  size: 24,
                ),
                SizedBox(height: 4),
                Text(
                  '#$rank',
                  style: GoogleFonts.poppins(
                    color: _getRankColor(rank),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Avatar
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: rank <= 3 ? _getRankColor(rank) : Colors.white24,
                width: 2,
              ),
              image: participant.profileImageUrl != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(participant.profileImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: participant.profileImageUrl == null
                ? Center(
                    child: Text(
                      participant.username[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          
          SizedBox(width: 12),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        participant.username,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'YOU',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  '${participant.correctAnswers} correct • ${participant.maxStreak} max streak',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Score and prize
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${participant.score}',
                style: GoogleFonts.poppins(
                  color: AppColors.primaryPurple,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'points',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
              if (prize.isNotEmpty) ...[
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    prize,
                    style: GoogleFonts.poppins(
                      color: Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;

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
          'Leaderboard',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<List<GameParticipantModel>>(
        stream: _gameService.getLeaderboard(widget.game.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.leaderboard, size: 80, color: Colors.white54),
                  SizedBox(height: 16),
                  Text(
                    'No participants yet',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final participants = snapshot.data!;
          final topThree = participants.take(3).toList();
          
          return Column(
            children: [
              // Prize pool banner
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade700, Colors.amber.shade900],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRIZE POOL',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          '₦${widget.game.totalPool.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Podium for top 3
              if (topThree.isNotEmpty) _buildPodium(topThree),

              SizedBox(height: 16),
              
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Top 50 Win Prizes 🏆',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Full leaderboard
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: 16),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final participant = participants[index];
                    final rank = index + 1;
                    final isCurrentUser = userId == participant.userId;
                    
                    return _buildLeaderboardItem(participant, rank, isCurrentUser);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}