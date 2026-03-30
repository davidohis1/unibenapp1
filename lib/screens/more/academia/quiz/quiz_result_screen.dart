import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quiz_game_service.dart';

class QuizResultScreen extends StatefulWidget {
  final String lobbyId;
  final String myUid;
  final int myScore;
  final int totalTimeSeconds;
  final int correctAnswers;
  final int wrongAnswers;
  final int prize;
  final int playerMode;

  const QuizResultScreen({
    Key? key,
    required this.lobbyId,
    required this.myUid,
    required this.myScore,
    required this.totalTimeSeconds,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.prize,
    required this.playerMode,
  }) : super(key: key);

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  List<Map<String, dynamic>> _rankedResults = [];
  String? _winnerId;
  bool _loading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _listenForResults();
  }

  void _listenForResults() {
    _sub = FirebaseFirestore.instance
        .collection('quiz_lobbies')
        .doc(widget.lobbyId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data()!;
      if (data['status'] == 'finished') {
        setState(() {
          _rankedResults = List<Map<String, dynamic>>.from(
              data['rankedResults'] ?? []);
          _winnerId = data['winnerId'];
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get _isWinner => _winnerId == widget.myUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Trophy / result header
                    const SizedBox(height: 16),
                    _isWinner
                        ? _WinBanner(prize: widget.prize)
                        : _LossBanner(),
                    const SizedBox(height: 32),

                    // Rankings
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Final Rankings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._rankedResults.asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final result = entry.value;
                      final isMe = result['uid'] == widget.myUid;
                      final isWinner = result['uid'] == _winnerId;
                      return _RankCard(
                        rank: rank,
                        username: result['username'] ?? 'Player',
                        score: result['score'] ?? 0,
                        correct: result['correctAnswers'] ?? 0,
                        wrong: result['wrongAnswers'] ?? 0,
                        totalTime: result['totalTimeSeconds'] ?? 0,
                        isMe: isMe,
                        isWinner: isWinner,
                      );
                    }),

                    const SizedBox(height: 32),

                    // Play again / home
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Pop back to mode selection
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Play Again',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                        child: Text(
                          'Back to Home',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 15,
                          ),
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

class _WinBanner extends StatelessWidget {
  final int prize;
  const _WinBanner({required this.prize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text(
            'You Won!',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₦$prize has been added to your wallet',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _LossBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text('😔', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text(
            'Better Luck Next Time',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep practicing and come back stronger!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final int rank;
  final String username;
  final int score;
  final int correct;
  final int wrong;
  final int totalTime;
  final bool isMe;
  final bool isWinner;

  const _RankCard({
    required this.rank,
    required this.username,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.totalTime,
    required this.isMe,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final rankColors = [
      const Color(0xFFFFD700),
      const Color(0xFFB0BEC5),
      const Color(0xFFFF8C69),
    ];
    final rankColor =
        rank <= 3 ? rankColors[rank - 1] : Colors.white.withOpacity(0.4);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF6C63FF).withOpacity(0.12)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? const Color(0xFF6C63FF).withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                isWinner ? '🥇' : '#$rank',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.w900,
                  fontSize: isWinner ? 18 : 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Color(0xFF8B85FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '✅ $correct correct  ❌ $wrong wrong  ⏱ ${totalTime}s',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Score
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'pts',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// Extension on QuizGameService to expose currentUid
extension on QuizGameService {
  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
}