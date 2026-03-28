import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/summary_model.dart';
import '../models/quiz_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  final String _summariesCollection = 'summaries';
  final String _quizzesCollection = 'quizzes';

  // Save a new summary
  Future<Summary> saveSummary({
    required String pdfUrl,
    required String title,
    required String content,
    int chunksProcessed = 0,
  }) async {
    try {
      final summary = Summary(
        id: _firestore.collection(_summariesCollection).doc().id,
        pdfUrl: pdfUrl,
        title: title,
        content: content,
        createdAt: DateTime.now(),
        chunksProcessed: chunksProcessed,
      );

      await _firestore
          .collection(_summariesCollection)
          .doc(summary.id)
          .set(summary.toJson());

      return summary;
    } catch (e) {
      print('Error saving summary: $e');
      rethrow;
    }
  }

  // Save a quiz
  Future<Quiz> saveQuiz({
    required String pdfUrl,
    required String summaryId,
    required List<QuizQuestion> questions,
  }) async {
    try {
      final quiz = Quiz(
        id: _firestore.collection(_quizzesCollection).doc().id,
        pdfUrl: pdfUrl,
        summaryId: summaryId,
        questions: questions,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(_quizzesCollection)
          .doc(quiz.id)
          .set(quiz.toJson());

      // Update summary with quiz ID
      await _firestore
          .collection(_summariesCollection)
          .doc(summaryId)
          .update({
        'quizIds': FieldValue.arrayUnion([quiz.id])
      });

      return quiz;
    } catch (e) {
      print('Error saving quiz: $e');
      rethrow;
    }
  }

  // Update quiz with results
  Future<void> updateQuizResults(String quizId, int score, bool completed) async {
    try {
      await _firestore.collection(_quizzesCollection).doc(quizId).update({
        'score': score,
        'completed': completed,
      });
    } catch (e) {
      print('Error updating quiz: $e');
    }
  }

  // Update quiz question with selected answer
  Future<void> updateQuizQuestion(String quizId, int questionIndex, String selectedAnswer) async {
    try {
      final quizDoc = await _firestore.collection(_quizzesCollection).doc(quizId).get();
      if (!quizDoc.exists) return;

      final quiz = Quiz.fromJson(quizDoc.data()!);
      if (questionIndex < quiz.questions.length) {
        quiz.questions[questionIndex].selectedAnswer = selectedAnswer;
        
        await _firestore.collection(_quizzesCollection).doc(quizId).update({
          'questions': quiz.questions.map((q) => q.toJson()).toList(),
        });
      }
    } catch (e) {
      print('Error updating quiz question: $e');
    }
  }

  // Get all summaries for a PDF URL
  Stream<List<Summary>> getSummariesForPdf(String pdfUrl) {
    return _firestore
        .collection(_summariesCollection)
        .where('pdfUrl', isEqualTo: pdfUrl)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Summary.fromJson(doc.data());
          }).toList();
        });
  }

  // Get all quizzes for a PDF URL
  Stream<List<Quiz>> getQuizzesForPdf(String pdfUrl) {
    return _firestore
        .collection(_quizzesCollection)
        .where('pdfUrl', isEqualTo: pdfUrl)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Quiz.fromJson(doc.data());
          }).toList();
        });
  }

  // Get a specific quiz
  Future<Quiz?> getQuiz(String quizId) async {
    try {
      final doc = await _firestore.collection(_quizzesCollection).doc(quizId).get();
      if (doc.exists) {
        return Quiz.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting quiz: $e');
      return null;
    }
  }

  // Get a specific summary
  Future<Summary?> getSummary(String summaryId) async {
    try {
      final doc = await _firestore.collection(_summariesCollection).doc(summaryId).get();
      if (doc.exists) {
        // Increment view count
        await doc.reference.update({
          'timesViewed': FieldValue.increment(1)
        });
        
        return Summary.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting summary: $e');
      return null;
    }
  }

  // Delete a summary and its associated quizzes
  Future<void> deleteSummary(String summaryId) async {
    try {
      // Get summary to find associated quizzes
      final summary = await getSummary(summaryId);
      if (summary != null) {
        // Delete all associated quizzes
        for (final quizId in summary.quizIds) {
          await _firestore.collection(_quizzesCollection).doc(quizId).delete();
        }
        
        // Delete the summary
        await _firestore.collection(_summariesCollection).doc(summaryId).delete();
      }
    } catch (e) {
      print('Error deleting summary: $e');
    }
  }
}