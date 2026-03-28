import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../../constants/app_constants.dart';
import '../../../models/quiz_game_model.dart';
import '../../../models/quiz_question_model.dart';
import '../../../services/quiz_game_service.dart';
import '../../../services/auth_service.dart';
import 'game_leaderboard_screen.dart';

class QuizPlayScreen extends StatefulWidget {
  final QuizGameModel game;

  const QuizPlayScreen({
    Key? key,
    required this.game,
  }) : super(key: key);

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  final QuizGameService _gameService = QuizGameService();
  final AuthService _authService = AuthService();

  List<QuizQuestionModel> _questions = [];
  int _currentQuestionIndex = 0;
  int _timeLeft = 7;
  Timer? _timer;
  bool _isLoading = true;
  bool _hasAnswered = false;
  int? _selectedAnswer;
  int _score = 0;
  int _correctAnswers = 0;
  int _currentStreak = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      final questions = await _gameService.getUserQuestions(widget.game.id, userId);
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
      _startTimer();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading questions: $e'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _timeLeft = 7;
      _hasAnswered = false;
      _selectedAnswer = null;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        if (!_hasAnswered) {
          _submitAnswer(-1); // Time expired, no answer
        }
      }
    });
  }

  Future<void> _submitAnswer(int answerIndex) async {
    if (_hasAnswered || _isSubmitting) return;

    setState(() {
      _hasAnswered = true;
      _selectedAnswer = answerIndex;
      _isSubmitting = true;
    });

    _timer?.cancel();

    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = answerIndex == currentQuestion.correctAnswerIndex;

    // Calculate score locally
    if (isCorrect) {
      _correctAnswers++;
      _currentStreak++;
      _score += 3; // Base points
      
      // Streak bonus
      if (_currentStreak >= 2) {
        _score += _currentStreak - 1;
      }
    } else {
      _score -= 1;
      _currentStreak = 0;
    }

    try {
      await _gameService.submitAnswer(
        gameId: widget.game.id,
        userId: userId,
        questionIndex: _currentQuestionIndex,
        selectedAnswer: answerIndex,
        isCorrect: isCorrect,
      );

      // Show feedback
      await Future.delayed(Duration(milliseconds: 800));

      setState(() => _isSubmitting = false);

      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() => _currentQuestionIndex++);
        _startTimer();
      } else {
        _completeQuiz();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _completeQuiz() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      await _gameService.completeQuiz(widget.game.id, userId);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 60),
              SizedBox(height: 12),
              Text(
                'Quiz Complete!',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow('Final Score', '$_score points', AppColors.primaryPurple),
              SizedBox(height: 8),
              _buildStatRow('Correct Answers', '$_correctAnswers/20', Colors.green),
              SizedBox(height: 8),
              _buildStatRow('Wrong Answers', '${20 - _correctAnswers}/20', Colors.red),
              SizedBox(height: 16),
              Text(
                'Check the leaderboard to see your rank!',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close quiz screen
              },
              child: Text(
                'Back to Lobby',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameLeaderboardScreen(game: widget.game),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'View Leaderboard',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing quiz: $e')),
      );
    }
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getTimerColor() {
    if (_timeLeft <= 2) return Colors.red;
    if (_timeLeft <= 4) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No questions available',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color(0xFF1E1E1E),
            title: Text(
              'Exit Quiz?',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            content: Text(
              'Your progress will be lost if you exit now.',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Stay', style: GoogleFonts.poppins(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Exit', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          ),
        );
        return shouldExit ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Header with progress
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question ${_currentQuestionIndex + 1}/20',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Score: $_score points',
                              style: GoogleFonts.poppins(
                                color: AppColors.primaryPurple,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Timer
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: _getTimerColor().withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getTimerColor(),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$_timeLeft',
                              style: GoogleFonts.poppins(
                                color: _getTimerColor(),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (_currentQuestionIndex + 1) / 20,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    if (_currentStreak > 0) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department, color: Colors.amber, size: 16),
                            SizedBox(width: 6),
                            Text(
                              '$_currentStreak Streak!',
                              style: GoogleFonts.poppins(
                                color: Colors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Question
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    currentQuestion.question,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              SizedBox(height: 32),

              // Options
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  itemCount: currentQuestion.options.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedAnswer == index;
                    final isCorrect = index == currentQuestion.correctAnswerIndex;
                    
                    Color? backgroundColor;
                    Color? borderColor;
                    
                    if (_hasAnswered) {
                      if (isCorrect) {
                        backgroundColor = Colors.green.withOpacity(0.2);
                        borderColor = Colors.green;
                      } else if (isSelected && !isCorrect) {
                        backgroundColor = Colors.red.withOpacity(0.2);
                        borderColor = Colors.red;
                      }
                    }

                    return GestureDetector(
                      onTap: _hasAnswered || _isSubmitting ? null : () => _submitAnswer(index),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: backgroundColor ?? Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: borderColor ?? AppColors.primaryPurple.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: borderColor?.withOpacity(0.2) ?? AppColors.primaryPurple.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + index), // A, B, C, D
                                  style: GoogleFonts.poppins(
                                    color: borderColor ?? AppColors.primaryPurple,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                currentQuestion.options[index],
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (_hasAnswered && isCorrect)
                              Icon(Icons.check_circle, color: Colors.green, size: 24),
                            if (_hasAnswered && isSelected && !isCorrect)
                              Icon(Icons.cancel, color: Colors.red, size: 24),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}