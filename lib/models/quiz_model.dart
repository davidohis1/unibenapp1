class QuizQuestion {
  final String question;
  final Map<String, String> options;
  final String correctAnswer;
  final String explanation;
  String? selectedAnswer;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.selectedAnswer,
  });

  factory QuizQuestion.fromGeminiResponse(String text) {
    // Parse Gemini's quiz format
    final lines = text.split('\n');
    String question = '';
    Map<String, String> options = {};
    String correctAnswer = '';
    String explanation = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.startsWith('Q') && line.contains(':')) {
        question = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.startsWith('A)') || line.startsWith('A.')) {
        options['A'] = line.substring(2).trim();
      } else if (line.startsWith('B)') || line.startsWith('B.')) {
        options['B'] = line.substring(2).trim();
      } else if (line.startsWith('C)') || line.startsWith('C.')) {
        options['C'] = line.substring(2).trim();
      } else if (line.startsWith('D)') || line.startsWith('D.')) {
        options['D'] = line.substring(2).trim();
      } else if (line.toLowerCase().contains('correct') && line.contains(':')) {
        correctAnswer = line.substring(line.indexOf(':') + 1).trim();
        // Extract just the letter if it's like "A" or "A)"
        if (correctAnswer.isNotEmpty) {
          correctAnswer = correctAnswer[0].toUpperCase();
        }
      } else if (line.toLowerCase().contains('explanation')) {
        explanation = line.substring(line.indexOf(':') + 1).trim();
      }
    }

    return QuizQuestion(
      question: question,
      options: options,
      correctAnswer: correctAnswer,
      explanation: explanation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'selectedAnswer': selectedAnswer,
    };
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? '',
      options: Map<String, String>.from(json['options'] ?? {}),
      correctAnswer: json['correctAnswer'] ?? '',
      explanation: json['explanation'] ?? '',
    )..selectedAnswer = json['selectedAnswer'];
  }

  bool get isCorrect => selectedAnswer == correctAnswer;
}

class Quiz {
  final String id;
  final String pdfUrl;
  final String summaryId;
  final List<QuizQuestion> questions;
  final DateTime createdAt;
  final int score;
  final bool completed;

  Quiz({
    required this.id,
    required this.pdfUrl,
    required this.summaryId,
    required this.questions,
    required this.createdAt,
    this.score = 0,
    this.completed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pdfUrl': pdfUrl,
      'summaryId': summaryId,
      'questions': questions.map((q) => q.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'score': score,
      'completed': completed,
    };
  }

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] ?? '',
      pdfUrl: json['pdfUrl'] ?? '',
      summaryId: json['summaryId'] ?? '',
      questions: (json['questions'] as List? ?? [])
          .map((q) => QuizQuestion.fromJson(q))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      score: json['score'] ?? 0,
      completed: json['completed'] ?? false,
    );
  }
}