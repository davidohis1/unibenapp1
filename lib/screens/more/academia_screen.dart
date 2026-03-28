import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import 'ai_study_assistant_screen.dart';
import 'academia/gpa_calculator_screen.dart';  // Add this import
import 'academia/reminder_page.dart';
import 'academia/resources_screen.dart'; // Add this import
import 'academia/chess_lobby_screen.dart'; // Add this import

class AcademiaScreen extends StatefulWidget {
  const AcademiaScreen({Key? key}) : super(key: key);

  @override
  State<AcademiaScreen> createState() => _AcademiaScreenState();
}

class _AcademiaScreenState extends State<AcademiaScreen> {
  // Exam date - March 6th of current year
  DateTime get _examDate => DateTime(DateTime.now().year, 3, 6);
  
  // News items
  final List<Map<String, dynamic>> _newsItems = [
    {
      'title': 'New Library Resources Available',
      'description': 'Access 500+ e-books and journals through the digital library portal',
      'icon': Icons.library_books,
      'color': Colors.blue,
      'date': '2 days ago',
    },
    {
      'title': 'Final Year Project Submission',
      'description': 'Deadline extended to March 15th for all departments',
      'icon': Icons.assignment,
      'color': Colors.orange,
      'date': '1 week ago',
    },
    {
      'title': 'Scholarship Opportunities',
      'description': 'Apply for MTN Foundation Scholarship before February 28th',
      'icon': Icons.school,
      'color': Colors.green,
      'date': '3 days ago',
    },
    {
      'title': 'Virtual Lab Access',
      'description': 'Science students can now access virtual labs 24/7',
      'icon': Icons.science,
      'color': Colors.purple,
      'date': '5 days ago',
    },
  ];

  final List<Map<String, dynamic>> _academiaTools = [
    {
      'title': 'GPA Calculator',
      'icon': Icons.calculate,
      'color': AppColors.primaryPurple,
      'route': '/gpa_calculator',
      'description': 'Calculate your CGPA and track grades',
    },
    {
      'title': 'AI Assistant',
      'icon': Icons.smart_toy,
      'color': Colors.blue,
      'route': '/ai_assistant',
      'description': 'Get summaries & explanations',
    },
    {
      'title': 'Reminders',
      'icon': Icons.notifications,
      'color': Colors.orange,
      'route': '/reminders',
      'description': 'Set study & assignment alerts',
    },
    {
      'title': 'Timetable',
      'icon': Icons.schedule,
      'color': Colors.green,
      'route': '/timetable',
      'description': 'Create & manage class schedule',
    },
    {
      'title': 'Resources',
      'icon': Icons.folder,
      'color': Colors.purple,
      'route': '/resources',
      'description': 'Study materials & past questions',
    },
    {
      'title': 'Play Chess',
      'icon': Icons.check_circle,
      'color': Colors.red,
      'route': '/play_chess',
      'description': 'Monitor academic progress',
    },
  ];

  String get _timeUntilExam {
    final now = DateTime.now();
    final difference = _examDate.difference(now);
    
    if (difference.isNegative) {
      final yearsPassed = now.year - _examDate.year;
      return '${yearsPassed == 1 ? 'Last year' : '$yearsPassed years ago'}';
    }
    
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    
    if (days > 30) {
      final months = (days / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ${days % 30} day${days % 30 > 1 ? 's' : ''}';
    } else if (days > 0) {
      return '$days day${days > 1 ? 's' : ''} $hours hour${hours > 1 ? 's' : ''}';
    } else {
      return '$hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}';
    }
  }

  double get _examProgress {
    final now = DateTime.now();
    final semesterStart = DateTime(DateTime.now().year, 1, 1); // January 1st
    final totalDays = _examDate.difference(semesterStart).inDays;
    final daysPassed = now.difference(semesterStart).inDays;
    
    if (daysPassed <= 0) return 0.0;
    if (daysPassed >= totalDays) return 1.0;
    
    return daysPassed / totalDays;
  }

  @override
  Widget build(BuildContext context) {
    final daysUntilExam = _examDate.difference(DateTime.now()).inDays;
    final isExamPast = daysUntilExam < 0;

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text('Academia Hub', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Exam Countdown Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isExamPast
                      ? [Colors.grey.shade800, Colors.grey.shade600]
                      : [AppColors.primaryPurple, AppColors.primaryPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExamPast ? Icons.check_circle : Icons.timer,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isExamPast ? 'Exams Completed' : 'Exam Countdown',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              DateFormat('MMMM d, yyyy').format(_examDate),
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isExamPast ? 'Exams were on March 6th' : _timeUntilExam,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!isExamPast) ...[
                    const SizedBox(height: 15),
                    LinearProgressIndicator(
                      value: _examProgress,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      color: Colors.white,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Semester Start',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '${(_examProgress * 100).toStringAsFixed(0)}% Complete',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Exam Day',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Quick Tools Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Quick Tools',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_academiaTools.length} tools',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: _academiaTools.length,
              itemBuilder: (context, index) {
                final tool = _academiaTools[index];
                return _buildToolCard(tool, context);
              },
            ),

            // Campus News Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.newspaper,
                          color: AppColors.primaryPurple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Campus News',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Updates',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._newsItems.map((news) => _buildNewsItem(news)).toList(),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        'View All News →',
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Study Tips Card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.successGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lightbulb,
                      color: AppColors.successGreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Study Tip of the Day',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.successGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use the Pomodoro technique: 25 minutes focused study, 5 minutes break. Repeat 4 times, then take a longer break.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.grey,
                          ),
                        ),
                      ],
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

  Widget _buildToolCard(Map<String, dynamic> tool, BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (tool['route'] == '/ai_assistant') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AIStudyAssistantScreen()),
          );
        }else if (tool['route'] == '/reminders') { // Add this
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReminderPage()),
          );
        } else if (tool['route'] == '/gpa_calculator') { // Add this
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddCourseScreen()),
          );
        } else if (tool['route'] == '/resources') { // Add this
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ResourcesScreen()),
          );
        }else if (tool['route'] == '/play_chess') { // Add this
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChessLobbyScreen()),
          );
        }  else {
          _showComingSoon(tool['title']);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (tool['color'] as Color).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                tool['icon'] as IconData,
                color: tool['color'] as Color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tool['title'],
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              tool['description'],
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: AppColors.grey,
                
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsItem(Map<String, dynamic> news) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (news['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              news['icon'] as IconData,
              color: news['color'] as Color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  news['title'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  news['description'],
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            news['date'],
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: AppColors.primaryPurple,
      ),
    );
  }
}