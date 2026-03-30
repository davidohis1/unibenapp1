import 'dart:async';
import 'package:flutter/material.dart';
import 'quiz_game_service.dart';
import 'quiz_result_screen.dart';

class QuizGameScreen extends StatefulWidget {
  final String lobbyId;
  final int playerMode;
  final List<QuizQuestion> questions;
  final int prize;

  const QuizGameScreen({
    Key? key,
    required this.lobbyId,
    required this.playerMode,
    required this.questions,
    required this.prize,
  }) : super(key: key);

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen>
    with TickerProviderStateMixin {
  final QuizGameService _service = QuizGameService();

  int _currentIndex = 0;
  int _questionSecondsLeft = QuizGameService.SECONDS_PER_QUESTION;
  int _totalSecondsElapsed = 0;
  int _totalScore = 0;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  String? _selectedOption;
  bool _answered = false;
  bool _gameFinished = false;
  bool _waitingForOthers = false;

  Timer? _questionTimer;
  Timer? _totalTimer;

  // Per-question start time (to compute seconds taken)
  DateTime? _questionStartTime;

  late AnimationController _progressController;
  late AnimationController _questionFadeController;
  late Animation<double> _questionFadeAnim;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration:
          Duration(seconds: QuizGameService.SECONDS_PER_QUESTION),
    );
    _questionFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _questionFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _questionFadeController, curve: Curves.easeIn),
    );
    _startTotalTimer();
    _startQuestion();
  }

  void _startTotalTimer() {
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_gameFinished) {
        setState(() => _totalSecondsElapsed++);
      }
    });
  }

  void _startQuestion() {
    _answered = false;
    _selectedOption = null;
    _questionSecondsLeft = QuizGameService.SECONDS_PER_QUESTION;
    _questionStartTime = DateTime.now();
    _progressController.forward(from: 0);
    _questionFadeController.forward(from: 0);

    _questionTimer?.cancel();
    _questionTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _questionSecondsLeft--;
      });
      if (_questionSecondsLeft <= 0) {
        timer.cancel();
        _onTimeUp();
      }
    });
  }

  void _onTimeUp() {
    if (_answered) return;
    // No answer = wrong
    setState(() {
      _answered = true;
      _wrongAnswers++;
      _totalScore += _service.calculateQuestionScore(false, QuizGameService.SECONDS_PER_QUESTION);
    });
    Future.delayed(const Duration(milliseconds: 600), _nextQuestion);
  }

  void _onOptionSelected(String option) {
    if (_answered) return;
    _questionTimer?.cancel();

    final secondsTaken = DateTime.now().difference(_questionStartTime!).inSeconds;
    final current = widget.questions[_currentIndex];
    final isCorrect = option == current.correctAnswer;
    final questionScore = _service.calculateQuestionScore(isCorrect, secondsTaken);

    setState(() {
      _answered = true;
      _selectedOption = option;
      if (isCorrect) {
        _correctAnswers++;
      } else {
        _wrongAnswers++;
      }
      _totalScore += questionScore;
    });

    Future.delayed(const Duration(milliseconds: 700), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    if (_currentIndex + 1 >= widget.questions.length) {
      _finishGame();
    } else {
      setState(() {
        _currentIndex++;
      });
      _startQuestion();
    }
  }

  Future<void> _finishGame() async {
    _questionTimer?.cancel();
    _totalTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _gameFinished = true;
      _waitingForOthers = true;
    });

    await _service.submitResult(
      lobbyId: widget.lobbyId,
      totalScore: _totalScore,
      totalTimeSeconds: _totalSecondsElapsed,
      correctAnswers: _correctAnswers,
      wrongAnswers: _wrongAnswers,
    );

    // Listen for all results to be in, then finalize
    _service.streamLobby(widget.lobbyId).listen((snapshot) async {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final results = Map<String, dynamic>.from(data['results'] ?? {});
      final playerMode = data['playerMode'] as int;

      if (results.length >= playerMode) {
        await _service.finalizeGame(widget.lobbyId);
      }

      if (data['status'] == 'finished' && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuizResultScreen(
              lobbyId: widget.lobbyId,
              myUid: _service.currentUid,
              myScore: _totalScore,
              totalTimeSeconds: _totalSecondsElapsed,
              correctAnswers: _correctAnswers,
              wrongAnswers: _wrongAnswers,
              prize: widget.prize,
              playerMode: widget.playerMode,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _totalTimer?.cancel();
    _progressController.dispose();
    _questionFadeController.dispose();
    super.dispose();
  }

  Color _optionColor(String option) {
    if (!_answered) return Colors.white.withOpacity(0.07);
    final current = widget.questions[_currentIndex];
    if (option == current.correctAnswer) return Colors.green.withOpacity(0.25);
    if (option == _selectedOption) return Colors.red.withOpacity(0.25);
    return Colors.white.withOpacity(0.04);
  }

  Color _optionBorder(String option) {
    if (!_answered) return Colors.white.withOpacity(0.12);
    final current = widget.questions[_currentIndex];
    if (option == current.correctAnswer) return Colors.greenAccent;
    if (option == _selectedOption) return Colors.redAccent;
    return Colors.white.withOpacity(0.08);
  }

  @override
  Widget build(BuildContext context) {
    if (_waitingForOthers) {
      return _WaitingScreen(
        score: _totalScore,
        correct: _correctAnswers,
        wrong: _wrongAnswers,
        totalTime: _totalSecondsElapsed,
      );
    }

    final current = widget.questions[_currentIndex];
    final options = [
      MapEntry('A', current.optionA),
      MapEntry('B', current.optionB),
      MapEntry('C', current.optionC),
      MapEntry('D', current.optionD),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: question counter + total time
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  // Question counter
                  Text(
                    '${_currentIndex + 1}/${widget.questions.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  // Total timer
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Color(0xFF6C63FF), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(_totalSecondsElapsed),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) {
                  final progress = _questionSecondsLeft /
                      QuizGameService.SECONDS_PER_QUESTION;
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 0.4
                                ? const Color(0xFF6C63FF)
                                : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$_questionSecondsLeft s',
                            style: TextStyle(
                              color: _questionSecondsLeft <= 3
                                  ? Colors.orange
                                  : Colors.white.withOpacity(0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Question
            FadeTransition(
              opacity: _questionFadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    current.question,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Options
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _questionFadeAnim,
                  child: GridView.count(
                    crossAxisCount: 1,
                    childAspectRatio: 5.5,
                    mainAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    children: options.map((entry) {
                      return GestureDetector(
                        onTap: () => _onOptionSelected(entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 0),
                          decoration: BoxDecoration(
                            color: _optionColor(entry.key),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _optionBorder(entry.key),
                              width: _answered &&
                                      (entry.key ==
                                              widget.questions[_currentIndex]
                                                  .correctAnswer ||
                                          entry.key == _selectedOption)
                                  ? 1.5
                                  : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (_answered &&
                                  entry.key ==
                                      widget.questions[_currentIndex]
                                          .correctAnswer)
                                const Icon(Icons.check_circle,
                                    color: Colors.greenAccent, size: 20)
                              else if (_answered &&
                                  entry.key == _selectedOption)
                                const Icon(Icons.cancel,
                                    color: Colors.redAccent, size: 20),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _WaitingScreen extends StatelessWidget {
  final int score;
  final int correct;
  final int wrong;
  final int totalTime;

  const _WaitingScreen({
    required this.score,
    required this.correct,
    required this.wrong,
    required this.totalTime,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF6C63FF),
              ),
              const SizedBox(height: 32),
              const Text(
                'You\'re done! 🎉',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Waiting for other players to finish...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _StatRow(label: 'Your Score', value: '$score pts'),
              const SizedBox(height: 12),
              _StatRow(label: 'Correct', value: '$correct / 15'),
              const SizedBox(height: 12),
              _StatRow(label: 'Wrong', value: '$wrong'),
              const SizedBox(height: 12),
              _StatRow(
                  label: 'Total Time',
                  value:
                      '${totalTime ~/ 60}:${(totalTime % 60).toString().padLeft(2, '0')}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      ),
    );
  }
}