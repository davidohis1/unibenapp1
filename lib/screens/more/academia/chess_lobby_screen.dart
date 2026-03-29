import 'dart:async';
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
  String? _waitingGameId;

  // Stream subscription that watches our waiting game doc
  StreamSubscription<DocumentSnapshot>? _gameSub;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Clean stale lobbies every time the screen is opened
    _chessService.runPeriodicCleanup();
  }

  @override
  void dispose() {
    _gameSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _authService.getUserData(user.uid);
      if (mounted) setState(() => _userData = userData);
    }
  }

  // ------------------------------------------------------------------
  // Find / create game
  // ------------------------------------------------------------------

  Future<void> _findGame() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _userData == null) return;

    if (_userData!.walletBalance < 350) {
      _showSnack('Insufficient balance. You need 350 coins to play.',
          isError: true);
      return;
    }

    if (mounted) setState(() => _isFindingGame = true);

    try {
      final game = await _chessService.findOrCreateGame(
        user.uid,
        _userData!.username,
        _userData!.profileImageUrl,
      );

      if (!mounted) return;

      if (game.isActive) {
        // Second player joined — go straight to game
        _navigateToGame(game.id);
        return;
      }

      // We are the creator — wait for opponent
      setState(() => _waitingGameId = game.id);
      _watchForOpponent(game.id);
    } catch (e) {
      if (mounted) {
        setState(() => _isFindingGame = false);
        _showSnack('Error: $e', isError: true);
      }
    }
  }

  /// Watches the game document; navigates when it flips to 'active'.
  void _watchForOpponent(String gameId) {
    _gameSub?.cancel();
    _gameSub = FirebaseFirestore.instance
        .collection('chess_games')
        .doc(gameId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) {
        // Game was deleted (stale cleanup)
        if (mounted) setState(() { _isFindingGame = false; _waitingGameId = null; });
        return;
      }

      final game = ChessGameModel.fromMap(snap.data()!);
      if (game.isActive && mounted) {
        _gameSub?.cancel();
        _navigateToGame(gameId);
      }
    });
  }

  void _navigateToGame(String gameId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (mounted) setState(() { _isFindingGame = false; _waitingGameId = null; });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChessGameScreen(gameId: gameId, userId: user.uid),
      ),
    );
  }

  Future<void> _cancelSearch() async {
    _gameSub?.cancel();
    if (_waitingGameId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _chessService.leaveWaitingGame(_waitingGameId!, user.uid);
      }
    }
    if (mounted) setState(() { _isFindingGame = false; _waitingGameId = null; });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Chess Arena',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(children: [
        _buildBalanceCard(),
        Expanded(
          child: _isFindingGame ? _buildSearchingView() : _buildReadyView(),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------------
  // Widgets
  // ------------------------------------------------------------------

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your Balance',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              '₦${_userData?.walletBalance.toStringAsFixed(0) ?? '0'}',
              style: GoogleFonts.poppins(
                  color: AppColors.primaryPurple,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ]),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Text('Entry Fee',
                  style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              Text('₦350',
                  style: GoogleFonts.poppins(
                      color: AppColors.primaryPurple,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyView() {
    final canPlay = (_userData?.walletBalance ?? 0) >= 350;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.emoji_events, size: 80, color: Color(0x7F9C27B0)),
          const SizedBox(height: 24),
          Text('Ready to Play?',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Join a game and compete with other players',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Entry: 350 coins  |  Winner gets 600 coins',
              style: GoogleFonts.poppins(
                  color: AppColors.primaryPurple,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canPlay ? _findGame : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canPlay ? AppColors.primaryPurple : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                canPlay ? 'Play Game' : 'Insufficient Coins',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),

          // Open lobbies list
          const SizedBox(height: 32),
          _buildOpenLobbies(),
        ]),
      ),
    );
  }

  /// Shown while we are the waiting creator.
  Widget _buildSearchingView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _waitingGameId == null
          ? null
          : FirebaseFirestore.instance
              .collection('chess_games')
              .doc(_waitingGameId)
              .snapshots(),
      builder: (context, snap) {
        int playerCount = 1;
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>?;
          final players = List<String>.from(data?['players'] ?? []);
          playerCount = players.length;
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1/2 indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primaryPurple.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people, color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      '$playerCount / 2',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text('players',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              CircularProgressIndicator(color: AppColors.primaryPurple),
              const SizedBox(height: 24),

              Text('Waiting for opponent…',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('You will enter the game together when someone joins.',
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center),

              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _cancelSearch,
                icon: const Icon(Icons.close, color: Colors.red),
                label: Text('Cancel',
                    style: GoogleFonts.poppins(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Lists waiting (1-player) games from other users.
  Widget _buildOpenLobbies() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chess_games')
          .where('status', isEqualTo: 'waiting')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final lobbies = snap.data!.docs.where((doc) {
          final players = List<String>.from(doc['players'] ?? []);
          // Only show lobbies we didn't create and that have exactly 1 player
          return players.length == 1 && !players.contains(user?.uid);
        }).toList();

        if (lobbies.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Open Lobbies',
                style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...lobbies.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final names = Map<String, String>.from(data['playerNames'] ?? {});
              final players = List<String>.from(data['players'] ?? []);
              final creatorName =
                  players.isNotEmpty ? (names[players[0]] ?? 'Player') : 'Player';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppColors.primaryPurple.withOpacity(0.2),
                    child: const Icon(Icons.person,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(creatorName,
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                          Row(children: [
                            Text('1 / 2 · ',
                                style: GoogleFonts.poppins(
                                    color: AppColors.primaryPurple,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            Text('Waiting for opponent…',
                                style: GoogleFonts.poppins(
                                    color: Colors.white54, fontSize: 11)),
                          ]),
                        ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('OPEN',
                        style: GoogleFonts.poppins(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}