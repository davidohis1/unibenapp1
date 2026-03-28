import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants/app_constants.dart';
import 'add_course_screen.dart';

class AddCourseScreen extends StatefulWidget {
  final VoidCallback? onCourseAdded;
  
  const AddCourseScreen({Key? key, this.onCourseAdded}) : super(key: key);

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final List<int> _levels = [100, 200, 300, 400, 500];
  final List<String> _semesters = ['First', 'Second'];
  
  int _selectedLevel = 100;
  String _selectedSemester = 'First';
  int _selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  List<Map<String, dynamic>> _academicSessions = [];
  double _semesterGPA = 0.0;
  double _cumulativeGPA = 0.0;
  int _totalUnits = 0;
  int _totalPoints = 0;

  final Map<String, double> _gradePoints = {
    'A': 5.0, 'B': 4.0, 'C': 3.0, 'D': 2.0, 'E': 1.0, 'F': 0.0
  };

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final courses = await _getAllCourses();
    setState(() {
      _courses = courses;
      _filterCourses();
      _calculateGPA();
      _getAcademicSessions();
    });
  }

  Future<List<Map<String, dynamic>>> _getAllCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final courseKeys = prefs.getStringList('course_keys') ?? [];
    final List<Map<String, dynamic>> courses = [];

    for (final key in courseKeys) {
      final courseCode = prefs.getString('${key}_code');
      final courseTitle = prefs.getString('${key}_title');
      final creditUnits = prefs.getInt('${key}_units');
      final grade = prefs.getString('${key}_grade');
      final level = prefs.getInt('${key}_level');
      final semester = prefs.getString('${key}_semester');
      final year = prefs.getInt('${key}_year');

      if (courseCode != null && courseTitle != null && creditUnits != null && 
          grade != null && level != null && semester != null && year != null) {
        
        courses.add({
          'id': key,
          'courseCode': courseCode,
          'courseTitle': courseTitle,
          'creditUnits': creditUnits,
          'grade': grade,
          'gradePoint': _gradePoints[grade] ?? 0.0,
          'level': level,
          'semester': semester,
          'year': year,
        });
      }
    }

    // Sort by year (newest first), then level, then semester
    courses.sort((a, b) {
      if (a['year'] != b['year']) return b['year'].compareTo(a['year']);
      if (a['level'] != b['level']) return b['level'].compareTo(a['level']);
      return b['semester'].compareTo(a['semester']);
    });

    return courses;
  }

  void _filterCourses() {
    _filteredCourses = _courses.where((course) => 
      course['level'] == _selectedLevel && 
      course['semester'] == _selectedSemester &&
      course['year'] == _selectedYear
    ).toList();
  }

  void _calculateGPA() {
    double semesterTotalPoints = 0;
    int semesterTotalUnits = 0;
    double cumulativeTotalPoints = 0;
    int cumulativeTotalUnits = 0;

    for (final course in _filteredCourses) {
      final gradePoint = course['gradePoint'] as double;
      final units = course['creditUnits'] as int;
      semesterTotalPoints += gradePoint * units;
      semesterTotalUnits += units;
    }

    for (final course in _courses) {
      final gradePoint = course['gradePoint'] as double;
      final units = course['creditUnits'] as int;
      cumulativeTotalPoints += gradePoint * units;
      cumulativeTotalUnits += units;
    }

    setState(() {
      _semesterGPA = semesterTotalUnits > 0 ? 
          double.parse((semesterTotalPoints / semesterTotalUnits).toStringAsFixed(2)) : 0.0;
      _cumulativeGPA = cumulativeTotalUnits > 0 ? 
          double.parse((cumulativeTotalPoints / cumulativeTotalUnits).toStringAsFixed(2)) : 0.0;
      _totalUnits = cumulativeTotalUnits;
      _totalPoints = cumulativeTotalPoints.toInt();
    });
  }

  void _getAcademicSessions() {
    final sessions = <String, Map<String, dynamic>>{};
    
    for (final course in _courses) {
      final key = '${course['year']}-${course['level']}-${course['semester']}';
      
      if (!sessions.containsKey(key)) {
        sessions[key] = {
          'year': course['year'],
          'level': course['level'],
          'semester': course['semester'],
          'display': '${course['semester']} Semester ${course['level']}L (${course['year']})',
        };
      }
    }
    
    _academicSessions = sessions.values.toList()
      ..sort((a, b) {
        if (a['year'] != b['year']) return b['year'].compareTo(a['year']);
        if (a['level'] != b['level']) return b['level'].compareTo(a['level']);
        return b['semester'].compareTo(a['semester']);
      });

    if (_academicSessions.isNotEmpty) {
      setState(() {
        _selectedYear = _academicSessions.first['year'];
        _selectedLevel = _academicSessions.first['level'];
        _selectedSemester = _academicSessions.first['semester'];
        _filterCourses();
        _calculateGPA();
      });
    }
  }

  Future<void> _deleteCourse(String courseId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text('Are you sure you want to delete this course?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Remove course data
        await prefs.remove('${courseId}_code');
        await prefs.remove('${courseId}_title');
        await prefs.remove('${courseId}_units');
        await prefs.remove('${courseId}_grade');
        await prefs.remove('${courseId}_level');
        await prefs.remove('${courseId}_semester');
        await prefs.remove('${courseId}_year');
        
        // Remove from course list
        final keys = await prefs.getStringList('course_keys') ?? [];
        keys.remove(courseId);
        await prefs.setStringList('course_keys', keys);
        
        // Reload courses
        await _loadCourses();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course deleted successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _changeSession(Map<String, dynamic> session) {
    setState(() {
      _selectedYear = session['year'];
      _selectedLevel = session['level'];
      _selectedSemester = session['semester'];
      _filterCourses();
      _calculateGPA();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text('GPA Calculator', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddCourseScreen(
                onCourseAdded: _loadCourses,
              )),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // GPA Cards
          _buildGPACards(),
          
          // Session Selector
          if (_academicSessions.isNotEmpty) _buildSessionSelector(),
          
          // Courses List
          Expanded(
            child: _filteredCourses.isEmpty 
                ? _buildEmptyState()
                : _buildCoursesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddCourseScreen(
            onCourseAdded: _loadCourses,
          )),
        ),
        backgroundColor: AppColors.primaryPurple,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGPACards() {
    Color getGPAColor(double gpa) {
      if (gpa >= 4.5) return AppColors.successGreen;
      if (gpa >= 3.5) return Colors.green;
      if (gpa >= 2.5) return Colors.orange;
      return AppColors.errorRed;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Semester GPA
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'SEMESTER GPA',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _semesterGPA.toStringAsFixed(2),
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: getGPAColor(_semesterGPA),
                    ),
                  ),
                  Text(
                    '${_selectedSemester} Semester ${_selectedLevel}L',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Cumulative GPA
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryPurple, AppColors.primaryPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'CUMULATIVE GPA',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _cumulativeGPA.toStringAsFixed(2),
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${_totalUnits} Units • ${_courses.length} Courses',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
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

  Widget _buildSessionSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            'Academic Sessions',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _academicSessions.length,
              itemBuilder: (context, index) {
                final session = _academicSessions[index];
                final isSelected = 
                  session['year'] == _selectedYear &&
                  session['level'] == _selectedLevel &&
                  session['semester'] == _selectedSemester;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      session['display'],
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isSelected ? AppColors.white : AppColors.grey,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) => _changeSession(session),
                    selectedColor: AppColors.primaryPurple,
                    backgroundColor: AppColors.lightGrey,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Courses (${_filteredCourses.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedSemester} Semester ${_selectedLevel}L',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredCourses.length,
              itemBuilder: (context, index) {
                final course = _filteredCourses[index];
                return _buildCourseItem(course);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseItem(Map<String, dynamic> course) {
    Color getGradeColor(String grade) {
      switch (grade) {
        case 'A': return AppColors.successGreen;
        case 'B': return Colors.green;
        case 'C': return Colors.orange;
        case 'D': return Colors.orange.shade800;
        case 'E': return AppColors.errorRed;
        case 'F': return Colors.red.shade900;
        default: return AppColors.grey;
      }
    }

    final points = (course['gradePoint'] as double) * (course['creditUnits'] as int);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Grade Circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: getGradeColor(course['grade']).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: getGradeColor(course['grade'])),
            ),
            child: Center(
              child: Text(
                course['grade'],
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: getGradeColor(course['grade']),
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Course Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course['courseCode'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  course['courseTitle'],
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Units and Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${course['creditUnits']} Unit${course['creditUnits'] > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.grey,
                ),
              ),
              Text(
                '${points.toStringAsFixed(1)} Points',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryPurple,
                ),
              ),
            ],
          ),
          // Delete Button
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
            onPressed: () => _deleteCourse(course['id']),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school, size: 80, color: AppColors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No courses added yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first course to calculate GPA',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddCourseScreen(
                onCourseAdded: _loadCourses,
              )),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(
              'Add First Course',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}