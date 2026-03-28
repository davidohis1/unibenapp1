import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_constants.dart';
import '../../../models/course_model.dart';
import '../../../services/course_service.dart';
import '../../../services/auth_service.dart';
import 'add_course_screen.dart';
import 'course_detail_screen.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({Key? key}) : super(key: key);

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final CourseService _courseService = CourseService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedFaculty = 'All';
  String _selectedDepartment = 'All';
  String _selectedLevel = 'All';

  final List<String> _faculties = [
    'All',
    'Engineering',
    'Sciences',
    'Arts',
    'Social Sciences',
    'Medicine',
    'Law',
  ];

  final Map<String, List<String>> _departments = {
    'All': ['All'],
    'Engineering': ['All', 'Computer Engineering', 'Electrical Engineering', 'Mechanical Engineering', 'Civil Engineering'],
    'Sciences': ['All', 'Computer Science', 'Mathematics', 'Physics', 'Chemistry', 'Biology'],
    'Arts': ['All', 'English', 'History', 'Philosophy', 'Languages'],
    'Social Sciences': ['All', 'Economics', 'Sociology', 'Political Science', 'Psychology'],
    'Medicine': ['All', 'Medicine and Surgery', 'Nursing', 'Pharmacy'],
    'Law': ['All', 'Law'],
  };

  final List<String> _levels = [
    'All',
    '100',
    '200',
    '300',
    '400',
    '500',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CourseModel> _filterCourses(List<CourseModel> courses) {
    return courses.where((course) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          course.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          course.code.toLowerCase().contains(_searchQuery.toLowerCase());

      // Faculty filter
      final matchesFaculty =
          _selectedFaculty == 'All' || course.faculty == _selectedFaculty;

      // Department filter
      final matchesDepartment = _selectedDepartment == 'All' ||
          course.department == _selectedDepartment;

      // Level filter
      final matchesLevel =
          _selectedLevel == 'All' || course.level == _selectedLevel;

      return matchesSearch &&
          matchesFaculty &&
          matchesDepartment &&
          matchesLevel;
    }).toList();
  }

  Color _getDifficultyColor(double difficulty) {
    if (difficulty <= 1.5) return Colors.green;
    if (difficulty <= 2.5) return Colors.lightGreen;
    if (difficulty <= 3.5) return Colors.orange;
    if (difficulty <= 4.5) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Faculty Filter
          _buildFilterDropdown(
            label: 'Faculty',
            value: _selectedFaculty,
            items: _faculties,
            onChanged: (value) {
              setState(() {
                _selectedFaculty = value!;
                _selectedDepartment = 'All';
              });
            },
          ),
          SizedBox(width: 12),

          // Department Filter
          _buildFilterDropdown(
            label: 'Department',
            value: _selectedDepartment,
            items: _departments[_selectedFaculty] ?? ['All'],
            onChanged: (value) {
              setState(() {
                _selectedDepartment = value!;
              });
            },
          ),
          SizedBox(width: 12),

          // Level Filter
          _buildFilterDropdown(
            label: 'Level',
            value: _selectedLevel,
            items: _levels,
            onChanged: (value) {
              setState(() {
                _selectedLevel = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: Color(0xFF1A1A1A),
          icon: Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text('$label: $item'),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCourseCard(CourseModel course) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailScreen(course: course),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryPurple.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.code,
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryPurple,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        course.title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Difficulty Score
                if (course.totalReviews > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(course.averageDifficulty)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getDifficultyColor(course.averageDifficulty),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${course.difficultyScore}',
                          style: GoogleFonts.poppins(
                            color: _getDifficultyColor(course.averageDifficulty),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '/100',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),

            // Course Info
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildInfoChip(Icons.school, course.department),
                _buildInfoChip(Icons.grade, 'Level ${course.level}'),
                if (course.totalReviews > 0)
                  _buildInfoChip(
                    Icons.star,
                    '${course.totalReviews} ${course.totalReviews == 1 ? 'review' : 'reviews'}',
                  ),
                if (course.materialCount > 0)
                  _buildInfoChip(
                    Icons.folder,
                    '${course.materialCount} ${course.materialCount == 1 ? 'material' : 'materials'}',
                  ),
              ],
            ),

            if (course.totalReviews > 0) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.assessment, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Difficulty: ${course.difficultyLabel}',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        title: Text(
          'Course Resources',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFF1A1A1A),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search courses...',
                hintStyle: GoogleFonts.poppins(color: Colors.white54),
                prefixIcon: Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Filters
          SizedBox(height: 8),
          _buildFilterChips(),
          SizedBox(height: 8),
          Divider(color: Colors.grey.withOpacity(0.3), height: 1),

          // Courses List
          Expanded(
            child: StreamBuilder<List<CourseModel>>(
              stream: _courseService.getCourses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryPurple),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 80,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No courses yet',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Be the first to add a course!',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final filteredCourses = _filterCourses(snapshot.data!);

                if (filteredCourses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No courses found',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredCourses.length,
                  itemBuilder: (context, index) {
                    return _buildCourseCard(filteredCourses[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddCourseScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primaryPurple,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Course',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}