import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_game_service.dart';
import 'quiz_game_screen.dart';

class QuizLobbyScreen extends StatefulWidget {
  final int playerMode;

  const QuizLobbyScreen({Key? key, required this.playerMode}) : super(key: key);

  @override
  State<QuizLobbyScreen> createState() => _QuizLobbyScreenState();
}

class _QuizLobbyScreenState extends State<QuizLobbyScreen>
    with TickerProviderStateMixin {
  final QuizGameService _service = QuizGameService();
  String? _lobbyId;
  bool _isJoining = true;
  String _statusMessage = 'Finding a match...';
  StreamSubscription? _lobbySubscription;
  bool _navigated = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.85, end: 1.0).animate(_pulseController);
    _joinLobby();
  }

  Future<void> _joinLobby() async {
    try {
      final lobbyId = await _service.joinLobby(widget.playerMode);
      if (!mounted) return;
      setState(() {
        _lobbyId = lobbyId;
        _isJoining = false;
        _statusMessage = 'Waiting for players...';
      });
      _listenToLobby(lobbyId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    }
  }

  void _listenToLobby(String lobbyId) {
    _lobbySubscription = _service.streamLobby(lobbyId).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] as String;
      final players =
          List<Map<String, dynamic>>.from(data['players'] ?? []);

      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Players found: ${players.length}/${widget.playerMode}';
      });

      if ((status == 'starting' || status == 'playing') && !_navigated) {
        _navigated = true;
        final questions = List<Map<String, dynamic>>.from(
            data['questions'] ?? []);
        final quizQuestions = questions
            .map((q) => QuizQuestion.fromMap(q, q['id'] ?? ''))
            .toList();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuizGameScreen(
              lobbyId: lobbyId,
              playerMode: widget.playerMode,
              questions: quizQuestions,
              prize: data['prize'] as int,
            ),
          ),
        );
      }
    });
  }

  Future<void> _leaveLobby() async {
    _lobbySubscription?.cancel();
    if (_lobbyId != null) {
      await _service.leaveLobby(_lobbyId!);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _lobbySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _leaveLobby();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _leaveLobby,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.playerMode}-Player Mode',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              const Spacer(),

              // Animated pulsing radar
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6C63FF).withOpacity(0.3),
                        const Color(0xFF6C63FF).withOpacity(0.0),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF6C63FF).withOpacity(0.2),
                        border: Border.all(
                          color: const Color(0xFF6C63FF),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.search,
                        color: Color(0xFF6C63FF),
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                _isJoining ? 'Joining...' : 'Matchmaking',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 48),

              // Lobby stream - show players
              if (_lobbyId != null)
                StreamBuilder<DocumentSnapshot>(
                  stream: _service.streamLobby(_lobbyId!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final data =
                        snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final players = List<Map<String, dynamic>>.from(
                        data['players'] ?? []);
                    return _PlayersRow(
                        players: players, playerMode: widget.playerMode);
                  },
                ),

              const Spacer(),

              // Prize info
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFFFD700).withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emoji_events,
                          color: Color(0xFFFFD700), size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Prize: ₦${widget.playerMode == 2 ? QuizGameService.PRIZE_2P : QuizGameService.PRIZE_4P}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayersRow extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final int playerMode;

  const _PlayersRow({required this.players, required this.playerMode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(playerMode, (index) {
          final hasPlayer = index < players.length;
          final player = hasPlayer ? players[index] : null;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasPlayer
                        ? const Color(0xFF6C63FF).withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: hasPlayer
                          ? const Color(0xFF6C63FF)
                          : Colors.white.withOpacity(0.15),
                      width: 2,
                    ),
                  ),
                  child: hasPlayer
                      ? (player!['profileImageUrl'] != null
                          ? ClipOval(
                              child: Image.network(
                                player['profileImageUrl'],
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Text(
                                (player['username'] as String? ?? '?')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                              ),
                            ))
                      : const Icon(Icons.person_outline,
                          color: Colors.white30, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  hasPlayer
                      ? (player!['username'] as String? ?? 'Player')
                      : 'Waiting...',
                  style: TextStyle(
                    color: hasPlayer
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}