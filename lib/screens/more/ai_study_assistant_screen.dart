import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../constants/app_constants.dart';
import '../../services/ai_service.dart';
import '../../services/firebase_service.dart';
import '../../models/ai_message_model.dart';
import '../../models/summary_model.dart';
import '../../models/quiz_model.dart';
import '../../widgets/quiz_overlay.dart';
import '../../widgets/summary_history_drawer.dart';

class AIStudyAssistantScreen extends StatefulWidget {
  final String? initialPdfUrl;
  final String? pdfTitle;

  const AIStudyAssistantScreen({
    Key? key,
    this.initialPdfUrl,
    this.pdfTitle,
  }) : super(key: key);

  @override
  State<AIStudyAssistantScreen> createState() => _AIStudyAssistantScreenState();
}

class _AIStudyAssistantScreenState extends State<AIStudyAssistantScreen> {
  final AIService _aiService = AIService();
  FirebaseService? _firebaseService;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final List<AIMessageModel> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  bool _isProcessing = false;
  bool _showQuizSection = false;
  Summary? _currentSummary;
  Quiz? _currentQuiz;
  late String _pdfUrl;

@override
void initState() {
  super.initState();
  _initializeFirebase();
  _pdfUrl = widget.initialPdfUrl ?? 'https://avidapp1.b-cdn.net/materials/CSC101/ff.pdf';
  _addWelcomeMessage();
}

  Future<void> _initializeFirebase() async {
  await Firebase.initializeApp();
  setState(() {
    _firebaseService = FirebaseService();
  });
}

  void _addWelcomeMessage() {
    final welcomeMessage = AIMessageModel.system(
      '''👋 Welcome to NaijaCampus AI!

I can help you with:
📚 Summarizing PDF lecture notes
❓ Answering questions about documents
📝 Generating quiz questions
💡 Study tips for Nigerian students

Click the button below to start with your PDF!''',
    );
    _messages.add(welcomeMessage);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addMessage(AIMessageModel message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  Future<void> _processPdf() async {
    // Add user message
    final userMessage = AIMessageModel.user(
      content: '📄 Please process this PDF: $_pdfUrl',
    );
    _addMessage(userMessage);

    // Add loading message
    final loadingMessage = AIMessageModel.ai(
      content: '📥 Downloading PDF and extracting text...',
      isProcessing: true,
    );
    _addMessage(loadingMessage);

    setState(() {
      _isProcessing = true;
      _showQuizSection = false;
    });

    try {
      // Process PDF
      final result = await _aiService.processPdfFromUrl(_pdfUrl);
      
      // Remove loading message
      setState(() {
        _messages.removeLast();
      });

      if (result.containsKey('error')) {
        _addMessage(AIMessageModel.ai(
          content: '❌ ${result['error']}',
        ));
      } else {
        // Parse quiz questions
        final quizQuestions = _aiService.parseQuizFromResponse(result['quiz']);
        
        // Save summary to Firebase
        final summary = await _firebaseService!.saveSummary(
          pdfUrl: _pdfUrl,
          title: 'Summary ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          content: result['summary'],
          chunksProcessed: result['chunks_processed'] ?? 0,
        );

        // Save quiz to Firebase
        final quiz = await _firebaseService!.saveQuiz(
          pdfUrl: _pdfUrl,
          summaryId: summary.id,
          questions: quizQuestions,
        );

        setState(() {
          _currentSummary = summary;
          _currentQuiz = quiz;
          _showQuizSection = true;
        });

        // Add summary message
        _addMessage(AIMessageModel.ai(
          content: '📚 **PDF Summary**\n\n${result['summary']}',
        ));

        // Add success message
        _addMessage(AIMessageModel.ai(
          content: '✅ PDF processed successfully! ${result['chunks_processed']} sections analyzed.\n\n📝 ${quizQuestions.length} quiz questions generated and saved.',
        ));
      }
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(AIMessageModel.ai(
          content: '❌ Error: $e',
        ));
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    // Add user question
    _addMessage(AIMessageModel.user(content: '❓ $question'));
    
    // Add loading
    final loadingMessage = AIMessageModel.ai(
      content: '🔍 Searching document for answer...',
      isProcessing: true,
    );
    _addMessage(loadingMessage);

    try {
      final answer = await _aiService.askQuestion(question);
      
      setState(() {
        _messages.removeLast();
        _messages.add(AIMessageModel.ai(content: '💡 $answer'));
      });
      
      _questionController.clear();
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(AIMessageModel.ai(content: '❌ Error: $e'));
      });
    }
  }

  void _showQuiz() {
  if (_currentQuiz != null && _firebaseService != null) {
    showDialog(
      context: context,
      builder: (context) => QuizOverlay(
        quiz: _currentQuiz!,
        firebaseService: _firebaseService!,
        onClose: () => Navigator.pop(context),
      ),
    );
  } else if (_currentQuiz != null) {
    // Show quiz without Firebase (read-only mode)
    showDialog(
      context: context,
      builder: (context) => QuizOverlay(
        quiz: _currentQuiz!,
        firebaseService: FirebaseService(), // Create temporary instance
        onClose: () => Navigator.pop(context),
      ),
    );
  }
}

 

  void _onSelectSummary(Summary summary) {
    Navigator.pop(context); // Close drawer
    setState(() {
      _currentSummary = summary;
    });
    
    // Add summary to chat
    _addMessage(AIMessageModel.ai(
      content: '📚 **Previous Summary**\n\n${summary.content}',
    ));
  }

  void _onSelectQuiz(Quiz quiz) {
    Navigator.pop(context); // Close drawer
    setState(() {
      _currentQuiz = quiz;
    });
    
    // Show quiz
    _showQuiz();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text(
          'NaijaCampus AI',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              tooltip: 'View History',
            );
          },
        ),
        actions: [
          if (_aiService.hasProcessedPdf)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Reset session
                _aiService.resetSession();
                setState(() {
                  _currentSummary = null;
                  _currentQuiz = null;
                  _showQuizSection = false;
                });
              },
              tooltip: 'Reset Session',
            ),
        ],
      ),
     drawer: _firebaseService != null
        ? SummaryHistoryDrawer(
            pdfUrl: _pdfUrl,
            firebaseService: _firebaseService!,
            onSelectSummary: _onSelectSummary,
            onSelectQuiz: _onSelectQuiz,
          )
        : null,
      body: Column(
        children: [
          // PDF URL Display
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.primaryPurple.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.link, size: 16, color: AppColors.primaryPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PDF: $_pdfUrl',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.primaryPurple,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Main Action Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processPdf,
              icon: Icon(_isProcessing ? Icons.hourglass_empty : Icons.auto_awesome),
              label: Text(_isProcessing ? 'Processing...' : 'Summarize PDF & Generate Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Quiz Button (shows after processing)
          if (_showQuizSection && _currentQuiz != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _showQuiz,
                icon: const Icon(Icons.quiz),
                label: Text('Start Quiz (${_currentQuiz!.questions.length} questions)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Question Input (shows after PDF processing)
          if (_aiService.hasProcessedPdf)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.borderColor)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.lightGrey,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: _questionController,
                            decoration: InputDecoration(
                              hintText: 'Ask a question about the PDF...',
                              hintStyle: GoogleFonts.poppins(color: AppColors.grey),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onSubmitted: (_) => _askQuestion(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: AppColors.primaryPurple,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: _askQuestion,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💡 Ask anything about the document - the AI will find answers using RAG',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AIMessageModel message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: message.alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.bubbleColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender name
                if (message.type != MessageType.user)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderName,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                
                // Message content
                if (message.isProcessing)
                  Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message.content,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SelectableText(
                    message.content,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                
                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      return 'Today ${DateFormat('h:mm a').format(timestamp)}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('h:mm a').format(timestamp)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }
}