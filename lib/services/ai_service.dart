import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/quiz_model.dart';

class AIService {
  // Your PHP backend URL - CHANGE THIS
  final String _backendUrl = 'http://davidohiwerei.name.ng/school/ai.php';
  
  // Track processing state
  bool _hasProcessedPdf = false;
  String _currentPdfUrl = '';

  /// Download PDF from Bunny.net and extract text
  Future<String> _extractTextFromPdfUrl(String pdfUrl) async {
    try {
      // Download PDF from Bunny.net
      final response = await http.get(Uri.parse(pdfUrl));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }

      // Convert to bytes
      final Uint8List pdfBytes = response.bodyBytes;
      
      // Extract text using Syncfusion PDF
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();
      
      return text;
    } catch (e) {
      print('PDF extraction error: $e');
      rethrow;
    }
  }

  /// Process PDF from Bunny.net URL (Summarize + Generate Quiz)
  Future<Map<String, dynamic>> processPdfFromUrl(String pdfUrl) async {
    try {
      // Step 1: Extract text from PDF
      final extractedText = await _extractTextFromPdfUrl(pdfUrl);
      
      if (extractedText.isEmpty) {
        throw Exception('No text could be extracted from PDF');
      }

      // Step 2: Send to PHP backend for processing
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'process',
          'text': extractedText,
          'pdf_url': pdfUrl,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      
      if (data.containsKey('error')) {
        throw Exception(data['error']);
      }

      // Mark that we have processed a PDF
      _hasProcessedPdf = true;
      _currentPdfUrl = pdfUrl;

      return {
        'summary': data['summary'] ?? 'No summary generated',
        'quiz': data['quiz'] ?? 'No quiz generated',
        'chunks_processed': data['chunks_processed'] ?? 0,
      };
    } catch (e) {
      print('Process PDF error: $e');
      return {
        'error': e.toString(),
        'summary': 'Error processing PDF: $e',
        'quiz': '',
      };
    }
  }

  /// Ask a question about the processed PDF (RAG)
  Future<String> askQuestion(String question) async {
    try {
      if (!_hasProcessedPdf) {
        return 'Please process a PDF first before asking questions.';
      }

      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'ask',
          'question': question,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      
      if (data.containsKey('error')) {
        return data['error'];
      }

      return data['answer'] ?? 'No answer generated';
    } catch (e) {
      print('Ask question error: $e');
      return 'Error: $e';
    }
  }

  /// Generate additional quiz questions
  Future<String> generateMoreQuiz({int count = 10}) async {
    try {
      if (!_hasProcessedPdf) {
        return 'Please process a PDF first.';
      }

      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'generate_more_quiz',
          'count': count,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      return data['quiz'] ?? 'No quiz generated';
    } catch (e) {
      print('Generate quiz error: $e');
      return 'Error: $e';
    }
  }

  /// Reset the service (clear session)
  Future<void> resetSession() async {
    try {
      await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'reset'}),
      );
      _hasProcessedPdf = false;
      _currentPdfUrl = '';
    } catch (e) {
      print('Reset error: $e');
    }
  }

  // Add to AIService class
List<QuizQuestion> parseQuizFromResponse(String quizText) {
  List<QuizQuestion> questions = [];
  
  // Split by Q1, Q2, etc.
  final questionBlocks = quizText.split(RegExp(r'Q\d+:'));
  
  for (final block in questionBlocks) {
    if (block.trim().isEmpty) continue;
    
    String question = '';
    Map<String, String> options = {};
    String correctAnswer = '';
    String explanation = '';
    
    final lines = block.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (i == 0) {
        question = line;
      } else if (line.startsWith('A)') || line.startsWith('A.')) {
        options['A'] = line.substring(2).trim();
      } else if (line.startsWith('B)') || line.startsWith('B.')) {
        options['B'] = line.substring(2).trim();
      } else if (line.startsWith('C)') || line.startsWith('C.')) {
        options['C'] = line.substring(2).trim();
      } else if (line.startsWith('D)') || line.startsWith('D.')) {
        options['D'] = line.substring(2).trim();
      } else if (line.toLowerCase().contains('correct')) {
        final match = RegExp(r'[A-D]').firstMatch(line);
        if (match != null) {
          correctAnswer = match.group(0)!;
        }
      } else if (line.toLowerCase().contains('explanation')) {
        explanation = line.substring(line.indexOf(':') + 1).trim();
      }
    }
    
    if (question.isNotEmpty && options.isNotEmpty && correctAnswer.isNotEmpty) {
      questions.add(QuizQuestion(
        question: question,
        options: options,
        correctAnswer: correctAnswer,
        explanation: explanation.isNotEmpty ? explanation : 'No explanation provided',
      ));
    }
  }
  
  return questions;
}

  bool get hasProcessedPdf => _hasProcessedPdf;
  String get currentPdfUrl => _currentPdfUrl;
}