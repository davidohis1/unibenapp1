import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../constants/app_constants.dart';
import '../../../services/chess_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import '../../../models/chess_game_model.dart';
import 'chess_game_screen.dart';

class ChessLobbyScreen extends StatefulWidget {
  const ChessLobbyScreen({Key? key}) : super(key: key);

  @override
  State<ChessLobbyScreen> createState() => _ChessLobbyScreenState();
}

class _ChessLobbyScreenState extends State<ChessLobbyScreen> {
  final ChessService _chessService = ChessService();
  final AuthService _authService = AuthService();
  
  UserModel? _userData;
  bool _isFindingGame = false;
  String? _currentGameId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _authService.getUserData(user.uid);
      setState(() {
        _userData = userData;
      });
    }
  }

  Future<void> _findGame() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _userData == null) return;

    // Check if user has enough coins
    if (_userData!.walletBalance < 350) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance. You need 350 coins to play.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isFindingGame = true);

    try {
      // Listen for game creation/joining
      _chessService.findOrCreateGame(
        user.uid,
        _userData!.username,
        _userData!.profileImageUrl,
      ).listen((game) {
        if (game != null && mounted) {
          setState(() {
            _currentGameId = game.id;
            _isFindingGame = false;
          });

          if (game.isActive) {
            // Game started, navigate to game screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ChessGameScreen(
                  gameId: game.id,
                  userId: user.uid,
                ),
              ),
            );
          }
        }
      }, onError: (error) {
        print('Error finding game: $error');
        setState(() => _isFindingGame = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding game: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } catch (e) {
      setState(() => _isFindingGame = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _leaveWaitingGame() async {
    if (_currentGameId == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _chessService.leaveWaitingGame(_currentGameId!, user.uid);
      setState(() {
        _currentGameId = null;
        _isFindingGame = false;
      });
    } catch (e) {
      print('Error leaving game: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Chess Arena',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<ChessGameModel>>(
        stream: user != null ? _chessService.getUserActiveGames(user.uid) : null,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            );
          }

          final activeGames = snapshot.data ?? [];

          return Column(
            children: [
              // Balance Display
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Balance',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '₦${_userData?.walletBalance.toStringAsFixed(0) ?? '0'}',
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryPurple,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Entry Fee',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '₦350',
                            style: GoogleFonts.poppins(
                              color: AppColors.primaryPurple,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Finding Game Status
              if (_isFindingGame)
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.primaryPurple,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Finding opponent...',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Looking for another player to join',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _leaveWaitingGame,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                        ),
                        child: Text('Cancel'),
                      ),
                    ],
                  ),
                ),

              // Active Games
              if (activeGames.isNotEmpty && !_isFindingGame) ...[
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Your Active Games',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: activeGames.length,
                    itemBuilder: (context, index) {
                      final game = activeGames[index];
                      return _buildActiveGameCard(game, user!.uid);
                    },
                  ),
                ),
              ],

              if (!_isFindingGame && activeGames.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 80,
                          color: AppColors.primaryPurple.withOpacity(0.5),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Ready to Play?',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Join a game and compete with other players',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Entry Fee: 350 coins | Winner gets 600 coins',
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryPurple,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _findGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            'Play Game',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveGameCard(ChessGameModel game, String userId) {
    final opponentId = game.getOpponentId(userId);
    final opponentName = opponentId != null ? game.playerNames[opponentId] : 'Waiting...';
    final playerColor = game.getPlayerColor(userId);
    final isMyTurn = game.isPlayerTurn(userId);
    final timeLeft = game.getPlayerTimer(userId);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChessGameScreen(
              gameId: game.id,
              userId: userId,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: game.isActive 
                ? AppColors.primaryPurple.withOpacity(0.5)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Player Color Indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: playerColor == 'white' ? Colors.white : Colors.black,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  playerColor == 'white' ? Icons.emoji_events : Icons.star,
                  color: playerColor == 'white' ? Colors.black : Colors.white,
                  size: 20,
                ),
              ),
            ),
            SizedBox(width: 16),
            
            // Game Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.isWaiting ? 'Waiting for opponent...' : 'vs $opponentName',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      if (game.isActive) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isMyTurn ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          isMyTurn ? 'Your turn' : 'Opponent\'s turn',
                          style: GoogleFonts.poppins(
                            color: isMyTurn ? Colors.green : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.timer, size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          '${(timeLeft / 60).floor()}:${(timeLeft % 60).toString().padLeft(2, '0')}',
                          style: GoogleFonts.poppins(
                            color: timeLeft < 60 ? Colors.red : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}