import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/summary_model.dart';
import '../models/quiz_model.dart';
import '../services/firebase_service.dart';
import '../constants/app_constants.dart';
import 'quiz_overlay.dart';

class SummaryHistoryDrawer extends StatelessWidget {
  final String pdfUrl;
  final FirebaseService firebaseService;
  final Function(Summary) onSelectSummary;
  final Function(Quiz) onSelectQuiz;

  const SummaryHistoryDrawer({
    Key? key,
    required this.pdfUrl,
    required this.firebaseService,
    required this.onSelectSummary,
    required this.onSelectQuiz,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Document Resources',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  pdfUrl.split('/').last,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.white.withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: AppColors.primaryPurple,
                    unselectedLabelColor: AppColors.grey,
                    indicatorColor: AppColors.primaryPurple,
                    tabs: const [
                      Tab(text: 'Summaries', icon: Icon(Icons.summarize)),
                      Tab(text: 'Quizzes', icon: Icon(Icons.quiz)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Summaries Tab
                        _buildSummariesList(),
                        // Quizzes Tab
                        _buildQuizzesList(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummariesList() {
    return StreamBuilder<List<Summary>>(
      stream: firebaseService.getSummariesForPdf(pdfUrl),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final summaries = snapshot.data!;

        if (summaries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: AppColors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No summaries yet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: AppColors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click "Summarize PDF" to create one',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: summaries.length,
          itemBuilder: (context, index) {
            final summary = summaries[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryPurple,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: AppColors.white),
                  ),
                ),
                title: Text(
                  summary.title.length > 30
                      ? '${summary.title.substring(0, 30)}...'
                      : summary.title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Created: ${_formatDate(summary.createdAt)}',
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                    Text(
                      'Viewed ${summary.timesViewed} times',
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      onPressed: () => onSelectSummary(summary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _showDeleteDialog(context, summary),
                    ),
                  ],
                ),
                onTap: () => onSelectSummary(summary),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuizzesList(BuildContext context) {
    return StreamBuilder<List<Quiz>>(
      stream: firebaseService.getQuizzesForPdf(pdfUrl),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final quizzes = snapshot.data!;

        if (quizzes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 64,
                  color: AppColors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No quizzes yet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: AppColors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a quiz from a summary',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: quizzes.length,
          itemBuilder: (context, index) {
            final quiz = quizzes[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: quiz.completed ? AppColors.successGreen : AppColors.primaryPurple,
                  child: Text(
                    '${quiz.questions.length}',
                    style: const TextStyle(color: AppColors.white, fontSize: 12),
                  ),
                ),
                title: Text(
                  'Quiz ${index + 1}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Created: ${_formatDate(quiz.createdAt)}',
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                    if (quiz.completed)
                      Text(
                        'Score: ${quiz.score}/${quiz.questions.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.successGreen,
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    quiz.completed ? Icons.replay : Icons.play_arrow,
                    color: AppColors.primaryPurple,
                  ),
                  onPressed: () => onSelectQuiz(quiz),
                ),
                onTap: () => onSelectQuiz(quiz),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  void _showDeleteDialog(BuildContext context, Summary summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Summary', style: GoogleFonts.poppins()),
        content: Text(
          'Are you sure you want to delete this summary and its associated quizzes?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await firebaseService.deleteSummary(summary.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Summary deleted')),
              );
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}