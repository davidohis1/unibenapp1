import 'package:shared_preferences/shared_preferences.dart';

class GPAService {
  final List<String> _grades = ['A', 'B', 'C', 'D', 'E', 'F'];
  final Map<String, double> _gradePoints = {
    'A': 5.0, 'B': 4.0, 'C': 3.0, 'D': 2.0, 'E': 1.0, 'F': 0.0
  };

  // Save course to shared preferences
  Future<void> saveCourse({
    required String courseCode,
    required String courseTitle,
    required int creditUnits,
    required String grade,
    required int level,
    required String semester,
    required int academicYear,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create unique key for this course
      final courseKey = 'course_${DateTime.now().millisecondsSinceEpoch}';
      
      // Store course data
      
      await prefs.setString('${courseKey}_code', courseCode.toUpperCase());
      await prefs.setString('${courseKey}_title', courseTitle);
      await prefs.setInt('${courseKey}_units', creditUnits);
      await prefs.setString('${courseKey}_grade', grade.toUpperCase());
      await prefs.setInt('${courseKey}_level', level);
      await prefs.setString('${courseKey}_semester', semester);
      await prefs.setInt('${courseKey}_year', academicYear);
      
      // Add to course list
      final courses = await getCourseKeys();
      courses.add(courseKey);
      await prefs.setStringList('course_keys', courses);
      
    } catch (e) {
      throw Exception('Failed to save course: $e');
    }
  }

  // Get all course keys
  Future<List<String>> getCourseKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('course_keys') ?? [];
  }

  // Get all courses
  Future<List<Map<String, dynamic>>> getAllCourses() async {
    final List<Map<String, dynamic>> courses = [];
    final keys = await getCourseKeys();
    
    for (final key in keys) {
      final prefs = await SharedPreferences.getInstance();
      
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
          'academicYear': year,
        });
      }
    }
    
    // Sort by year, level, semester
    courses.sort((a, b) {
      if (a['academicYear'] != b['academicYear']) {
        return b['academicYear'].compareTo(a['academicYear']);
      }
      if (a['level'] != b['level']) {
        return b['level'].compareTo(a['level']);
      }
      return b['semester'].compareTo(a['semester']);
    });
    
    return courses;
  }

  // Get courses by level and semester
  Future<List<Map<String, dynamic>>> getCoursesBySemester(int level, String semester, int year) async {
    final allCourses = await getAllCourses();
    return allCourses.where((course) => 
      course['level'] == level && 
      course['semester'] == semester && 
      course['academicYear'] == year
    ).toList();
  }

  // Calculate GPA for specific semester
  Future<Map<String, dynamic>> calculateSemesterGPA(int level, String semester, int year) async {
    final courses = await getCoursesBySemester(level, semester, year);
    
    if (courses.isEmpty) {
      return {
        'gpa': 0.0,
        'totalUnits': 0,
        'totalPoints': 0.0,
        'courseCount': 0,
      };
    }

    double totalPoints = 0;
    int totalUnits = 0;

    for (final course in courses) {
      final gradePoint = course['gradePoint'] as double;
      final units = course['creditUnits'] as int;
      totalPoints += gradePoint * units;
      totalUnits += units;
    }

    final gpa = totalUnits > 0 ? totalPoints / totalUnits : 0.0;

    return {
      'gpa': double.parse(gpa.toStringAsFixed(2)),
      'totalUnits': totalUnits,
      'totalPoints': double.parse(totalPoints.toStringAsFixed(2)),
      'courseCount': courses.length,
    };
  }

  // Calculate CGPA (all semesters)
  Future<Map<String, dynamic>> calculateCGPA() async {
    final courses = await getAllCourses();
    
    if (courses.isEmpty) {
      return {
        'cgpa': 0.0,
        'totalUnits': 0,
        'totalPoints': 0.0,
        'semesterCount': 0,
      };
    }

    double totalPoints = 0;
    int totalUnits = 0;
    final semesters = <String>{};

    for (final course in courses) {
      final gradePoint = course['gradePoint'] as double;
      final units = course['creditUnits'] as int;
      totalPoints += gradePoint * units;
      totalUnits += units;
      semesters.add('${course['level']}-${course['semester']}-${course['academicYear']}');
    }

    final cgpa = totalUnits > 0 ? totalPoints / totalUnits : 0.0;

    return {
      'cgpa': double.parse(cgpa.toStringAsFixed(2)),
      'totalUnits': totalUnits,
      'totalPoints': double.parse(totalPoints.toStringAsFixed(2)),
      'semesterCount': semesters.length,
    };
  }

  // Delete a course
  Future<void> deleteCourse(String courseId) async {
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
      final keys = await getCourseKeys();
      keys.remove(courseId);
      await prefs.setStringList('course_keys', keys);
      
    } catch (e) {
      throw Exception('Failed to delete course: $e');
    }
  }

  // Get academic sessions
  Future<List<Map<String, dynamic>>> getAcademicSessions() async {
    final courses = await getAllCourses();
    final sessions = <String, Map<String, dynamic>>{};
    
    for (final course in courses) {
      final key = '${course['academicYear']}-${course['level']}-${course['semester']}';
      
      if (!sessions.containsKey(key)) {
        sessions[key] = {
          'academicYear': course['academicYear'],
          'level': course['level'],
          'semester': course['semester'],
          'display': '${course['semester']} Semester ${course['level']} Level (${course['academicYear']})',
        };
      }
    }
    
    return sessions.values.toList()
      ..sort((a, b) {
        if (a['academicYear'] != b['academicYear']) {
          return b['academicYear'].compareTo(a['academicYear']);
        }
        if (a['level'] != b['level']) {
          return b['level'].compareTo(a['level']);
        }
        return b['semester'].compareTo(a['semester']);
      });
  }

  // Clear all data (for testing)
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await getCourseKeys();
    
    for (final key in keys) {
      await prefs.remove('${key}_code');
      await prefs.remove('${key}_title');
      await prefs.remove('${key}_units');
      await prefs.remove('${key}_grade');
      await prefs.remove('${key}_level');
      await prefs.remove('${key}_semester');
      await prefs.remove('${key}_year');
    }
    
    await prefs.remove('course_keys');
  }
}