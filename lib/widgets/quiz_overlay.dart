import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/quiz_model.dart';
import '../constants/app_constants.dart';
import '../services/firebase_service.dart';

class QuizOverlay extends StatefulWidget {
  final Quiz quiz;
  final VoidCallback onClose;
  final FirebaseService firebaseService;

  const QuizOverlay({
    Key? key,
    required this.quiz,
    required this.onClose,
    required this.firebaseService,
  }) : super(key: key);

  @override
  State<QuizOverlay> createState() => _QuizOverlayState();
}

class _QuizOverlayState extends State<QuizOverlay> {
  late List<QuizQuestion> _questions;
  int _currentQuestionIndex = 0;
  bool _showResults = false;
  bool _quizCompleted = false;
  int _score = 0;
  final Map<int, String> _selectedAnswers = {};

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.quiz.questions);
  }

  void _selectAnswer(String answer) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = answer;
      _questions[_currentQuestionIndex].selectedAnswer = answer;
    });

    // Save to Firebase
    widget.firebaseService.updateQuizQuestion(
      widget.quiz.id,
      _currentQuestionIndex,
      answer,
    );
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _submitQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _submitQuiz() {
    // Calculate score
    int correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctAnswer) {
        correctCount++;
      }
    }

    setState(() {
      _score = correctCount;
      _showResults = true;
      _quizCompleted = true;
    });

    // Save results to Firebase
    widget.firebaseService.updateQuizResults(
      widget.quiz.id,
      _score,
      true,
    );
  }

  void _resetQuiz() {
    setState(() {
      _selectedAnswers.clear();
      _currentQuestionIndex = 0;
      _showResults = false;
      _quizCompleted = false;
      _score = 0;
      for (var q in _questions) {
        q.selectedAnswer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quiz Time!',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                        if (!_quizCompleted)
                          Text(
                            'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.white.withOpacity(0.9),
                            ),
                          ),
                        if (_quizCompleted)
                          Text(
                            'Score: $_score/${_questions.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.white.withOpacity(0.9),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.white),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _showResults ? _buildResults() : _buildQuestion(),
            ),

            // Footer
            if (!_showResults)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentQuestionIndex > 0)
                      TextButton(
                        onPressed: _previousQuestion,
                        child: Text(
                          'Previous',
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      )
                    else
                      const SizedBox(),
                    TextButton(
                      onPressed: _selectedAnswers.containsKey(_currentQuestionIndex)
                          ? _nextQuestion
                          : null,
                      child: Text(
                        _currentQuestionIndex == _questions.length - 1
                            ? 'Submit'
                            : 'Next',
                        style: GoogleFonts.poppins(
                          color: _selectedAnswers.containsKey(_currentQuestionIndex)
                              ? AppColors.primaryPurple
                              : AppColors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_showResults)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: _resetQuiz,
                      child: Text(
                        'Try Again',
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onClose,
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final question = _questions[_currentQuestionIndex];
    final hasSelected = _selectedAnswers.containsKey(_currentQuestionIndex);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              question.question,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Options
          ...question.options.entries.map((entry) {
            final isSelected = _selectedAnswers[_currentQuestionIndex] == entry.key;
            return GestureDetector(
              onTap: () => _selectAnswer(entry.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryPurple.withOpacity(0.1)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryPurple
                        : AppColors.borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.primaryPurple
                            : AppColors.lightGrey,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryPurple
                              : AppColors.borderColor,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          entry.key,
                          style: GoogleFonts.poppins(
                            color: isSelected
                                ? AppColors.white
                                : AppColors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isSelected
                              ? AppColors.primaryPurple
                              : AppColors.darkPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          if (hasSelected && _showResults)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.successGreen,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explanation:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.successGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.explanation,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.darkPurple,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Score Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Your Score',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryPurple,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$_score/${_questions.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _score == _questions.length
                      ? 'Perfect! Excellent work! 🎉'
                      : _score >= _questions.length ~/ 2
                          ? 'Good job! Keep studying! 👍'
                          : 'Keep practicing! You\'ll do better next time! 💪',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.darkPurple,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Question Review
          Text(
            'Review Answers',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          ..._questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final isCorrect = question.selectedAnswer == question.correctAnswer;
            final userAnswer = question.selectedAnswer ?? 'Not answered';
            final correctOption = question.options[question.correctAnswer] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Q${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.question,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (userAnswer != 'Not answered')
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Your answer: ',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.grey,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${question.selectedAnswer}) ${question.options[question.selectedAnswer] ?? ''}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Correct: ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${question.correctAnswer}) $correctOption',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.explanation,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}