import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_marketplace_app/constants/app_constants.dart';
import 'package:school_marketplace_app/models/quiz_game_model.dart';
import 'package:school_marketplace_app/models/user_model.dart';
import 'package:school_marketplace_app/services/quiz_game_service.dart';
import 'package:school_marketplace_app/services/auth_service.dart';
import 'quiz_play_screen.dart';
import 'game_leaderboard_screen.dart';



class QuizGameLobbyScreen extends StatefulWidget {
  const QuizGameLobbyScreen({Key? key}) : super(key: key);

  @override
  State<QuizGameLobbyScreen> createState() => _QuizGameLobbyScreenState();
}

class _QuizGameLobbyScreenState extends State<QuizGameLobbyScreen> {
  final QuizGameService _gameService = QuizGameService();
  final AuthService _authService = AuthService();

  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _ensureGameExists();
  }

  Future<void> _ensureGameExists() async {
    try {
      await _gameService.createInitialGame();
    } catch (e) {
      print('Error ensuring game exists: $e');
    }
  }

  Future<void> _openDepositPage() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    // Replace with your actual deposit website URL
    final url = 'https://yourschool.com/campus_connect/deposit.php?userId=$userId';
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch deposit page');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening deposit page: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _joinGame(QuizGameModel game, double userBalance) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    if (userBalance < game.entryFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance! You need ₦${game.entryFee}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'DEPOSIT',
            textColor: Colors.white,
            onPressed: _openDepositPage,
          ),
        ),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final username = userDoc.data()?['username'] ?? 'Player';
      final profileImageUrl = userDoc.data()?['profileImageUrl'];

      await _gameService.joinGame(game.id, userId, username, profileImageUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined the game!'),
          backgroundColor: AppColors.primaryPurple,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isJoining = false);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final dayName = days[dateTime.weekday - 1];
    final month = months[dateTime.month - 1];
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    
    return '$dayName, $month ${dateTime.day} at ${hour == 0 ? 12 : hour}:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  Widget _buildWalletCard(double balance) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryPurple, Color(0xFF7B3FF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'WALLET BALANCE',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '₦${balance.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openDepositPage,
              icon: Icon(Icons.add_circle_outline, size: 20),
              label: Text(
                'Deposit Coins',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryPurple,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(QuizGameModel game, bool hasJoined, double userBalance) {
    final now = DateTime.now();
    final canPlay = game.isLive && 
                    game.scheduledStartTime != null && 
                    game.scheduledEndTime != null &&
                    now.isAfter(game.scheduledStartTime!) && 
                    now.isBefore(game.scheduledEndTime!);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: game.isLive ? Colors.green : AppColors.primaryPurple.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quiz Game',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (game.isLive)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: GoogleFonts.poppins(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          
          _buildInfoRow(Icons.people, 'Players', '${game.currentPlayers}/${game.maxPlayers}'),
          SizedBox(height: 8),
          _buildInfoRow(Icons.account_balance_wallet, 'Entry Fee', '₦${game.entryFee.toStringAsFixed(0)}'),
          SizedBox(height: 8),
          _buildInfoRow(Icons.emoji_events, 'Prize Pool', '₦${game.totalPool.toStringAsFixed(0)}'),
          
          if (game.isScheduled && game.scheduledStartTime != null) ...[
            SizedBox(height: 8),
            _buildInfoRow(Icons.schedule, 'Starts', _formatDateTime(game.scheduledStartTime!)),
          ],

          if (game.isEnded) ...[
            SizedBox(height: 8),
            _buildInfoRow(Icons.check_circle, 'Status', 'Ended'),
          ],

          SizedBox(height: 16),
          
          LinearProgressIndicator(
            value: game.currentPlayers / game.maxPlayers,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          
          SizedBox(height: 16),

          if (game.isWaiting && !hasJoined)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isJoining ? null : () => _joinGame(game, userBalance),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isJoining
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Join Game - ₦${game.entryFee.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

          if (hasJoined && game.isWaiting)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You\'re in! Waiting for more players...',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (hasJoined && game.isScheduled)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primaryPurple, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Game is scheduled!',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Come back tomorrow to play between 3PM - 6PM',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          if (hasJoined && canPlay)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizPlayScreen(game: game),
                    ),
                  );
                },
                icon: Icon(Icons.play_arrow, size: 24),
                label: Text(
                  'PLAY NOW',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          if (hasJoined && game.isEnded)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GameLeaderboardScreen(game: game),
                    ),
                  );
                },
                icon: Icon(Icons.leaderboard, size: 20),
                label: Text(
                  'View Leaderboard',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryPurple,
                  side: BorderSide(color: AppColors.primaryPurple, width: 2),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Please sign in to play',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        title: Text(
          'Quiz Game',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: Column(
        children: [
          // Get user balance from Firestore
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .snapshots(),
            builder: (context, snapshot) {
              final balance = snapshot.hasData && snapshot.data?.data() != null
    ? ((snapshot.data!.data() as Map<String, dynamic>)['walletBalance'] as num?)?.toDouble() ?? 0.0
    : 0.0;
              return _buildWalletCard(balance);
            },
          ),

          Expanded(
            child: StreamBuilder<QuizGameModel?>(
              stream: _gameService.getActiveGame(),
              builder: (context, activeSnapshot) {
                return StreamBuilder<List<QuizGameModel>>(
                  stream: _gameService.getAllGames(),
                  builder: (context, allSnapshot) {
                    if (activeSnapshot.connectionState == ConnectionState.waiting &&
                        allSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: AppColors.primaryPurple),
                      );
                    }

                    final games = <QuizGameModel>[];
                    
                    if (activeSnapshot.hasData && activeSnapshot.data != null) {
                      games.add(activeSnapshot.data!);
                    }
                    
                    if (allSnapshot.hasData) {
                      for (final game in allSnapshot.data!) {
                        if (!games.any((g) => g.id == game.id)) {
                          games.add(game);
                        }
                      }
                    }

                    if (games.isEmpty) {
                      return Center(
                        child: Text(
                          'Loading games...',
                          style: GoogleFonts.poppins(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.only(bottom: 16),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        final game = games[index];
                        
                        return StreamBuilder<bool>(
                          stream: Stream.fromFuture(
                            _gameService.hasUserJoinedGame(game.id, userId),
                          ),
                          builder: (context, joinSnapshot) {
                            final hasJoined = joinSnapshot.data ?? false;
                            
                            // Get user balance for join button
                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .snapshots(),
                              builder: (context, userSnapshot) {
                                final userBalance = userSnapshot.hasData 
                                  ? ((userSnapshot.data?.data() as Map<String, dynamic>?)?['walletBalance'] as num?)?.toDouble() ?? 0.0
                                  : 0.0;
                                
                                return _buildGameCard(game, hasJoined, userBalance);
                              },
                            );
                          },
                        );
                      },
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