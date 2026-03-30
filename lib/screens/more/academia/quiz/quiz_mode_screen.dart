import 'package:flutter/material.dart';
import 'quiz_lobby_screen.dart';
import 'quiz_game_service.dart';

class QuizModeScreen extends StatelessWidget {
  const QuizModeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(height: 32),
              // Header
              const Text(
                'Quiz\nBattle',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Answer fast. Answer right. Win big.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 48),

              // Entry fee info
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFFFFD700), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Entry fee: ₦${QuizGameService.ENTRY_FEE} per game • 15 questions • 10s each',
                        style: TextStyle(
                          color: const Color(0xFFFFD700).withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 2-Player card
              _ModeCard(
                playerCount: 2,
                prize: QuizGameService.PRIZE_2P,
                description: '1v1 — Winner takes all',
                icon: Icons.people,
                gradientColors: const [Color(0xFF6C63FF), Color(0xFF3D35CC)],
                accentColor: const Color(0xFF8B85FF),
                onTap: () => _handleJoinLobby(context, 2),
              ),
              const SizedBox(height: 20),

              // 4-Player card
              _ModeCard(
                playerCount: 4,
                prize: QuizGameService.PRIZE_4P,
                description: '4-way battle — Top scorer wins',
                icon: Icons.group,
                gradientColors: const [Color(0xFFFF6B35), Color(0xFFCC3A00)],
                accentColor: const Color(0xFFFF8C5A),
                onTap: () => _handleJoinLobby(context, 4),
              ),

              const Spacer(),

              // Scoring system
              _ScoringInfo(),
            ],
          ),
        ),
      ),
    );
  }

  void _handleJoinLobby(BuildContext context, int playerMode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizLobbyScreen(playerMode: playerMode),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final int playerCount;
  final int prize;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final Color accentColor;
  final VoidCallback onTap;

  const _ModeCard({
    required this.playerCount,
    required this.prize,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$playerCount Players',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₦$prize',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'prize',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoringInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scoring System',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ScoreBadge(label: 'Correct', value: 'Up to 100pts', color: Colors.greenAccent),
              const SizedBox(width: 10),
              _ScoreBadge(label: 'Wrong', value: '-25pts', color: Colors.redAccent),
              const SizedBox(width: 10),
              _ScoreBadge(label: 'Tiebreak', value: 'Total time', color: Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Faster correct answers score more points.',
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

class _ScoreBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ScoreBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}