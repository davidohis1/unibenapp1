import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_constants.dart';
import '../../../models/course_model.dart';
import '../../../models/course_material_model.dart';
import '../../../models/course_review_model.dart';
import '../../../services/course_service.dart';
import '../../../services/auth_service.dart';
import 'add_material_screen.dart';
import 'add_review_screen.dart';
import 'view_material_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;

  const CourseDetailScreen({
    Key? key,
    required this.course,
  }) : super(key: key);

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  final CourseService _courseService = CourseService();
  final AuthService _authService = AuthService();
  late TabController _tabController;
  CourseModel? _updatedCourse; // Store updated course data
  bool _isLoadingStats = false;
  // Add these variables with your existing state variables
  List<CourseMaterialModel> _cachedMaterials = [];
  List<CourseReviewModel> _cachedReviews = [];
  bool _isInitialMaterialLoad = true;
  bool _isInitialReviewLoad = true;

  Map<String, dynamic> _insights = {};
  bool _hasUserReviewed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInsights();
    _checkUserReview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
  setState(() => _isLoadingStats = true);
  try {
    final insights = await _courseService.getCourseInsights(widget.course.id);
    final updatedCourse = await _courseService.getCourseById(widget.course.id);
    if (mounted) {
      setState(() {
        _insights = insights;
        _updatedCourse = updatedCourse;
        _isLoadingStats = false;
      });
    }
  } catch (e) {
    if (mounted) setState(() => _isLoadingStats = false);
  }
}

  Future<void> _checkUserReview() async {
  final userId = _authService.currentUser?.uid;
  if (userId == null) return;
  
  try {
    final hasReviewed =
        await _courseService.hasUserReviewedCourse(widget.course.id, userId);
    if (mounted) {
      setState(() {
        _hasUserReviewed = hasReviewed;
      });
    }
  } catch (e) {
    print('Error checking review: $e');
  }
}

  Color _getDifficultyColor(double difficulty) {
    if (difficulty <= 1.5) return Colors.green;
    if (difficulty <= 2.5) return Colors.lightGreen;
    if (difficulty <= 3.5) return Colors.orange;
    if (difficulty <= 4.5) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildHeader() {
  final course = _updatedCourse ?? widget.course;
  
  return Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Color(0xFF1A1A1A),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    course.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (course.totalReviews > 0)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getDifficultyColor(course.averageDifficulty)
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getDifficultyColor(course.averageDifficulty),
                    width: 2,
                  ),
                ),
                child: _isLoadingStats
                    ? SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          color: AppColors.primaryPurple,
                          strokeWidth: 2,
                        ),
                      )
                    : Column(
                        children: [
                          Text(
                            '${course.difficultyScore}',
                            style: GoogleFonts.poppins(
                              color: _getDifficultyColor(course.averageDifficulty),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '/100',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            course.difficultyLabel,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
          ],
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildInfoChip(Icons.school, course.faculty),
            _buildInfoChip(Icons.business, course.department),
            _buildInfoChip(Icons.grade, 'Level ${course.level}'),
            _buildInfoChip(
                Icons.star, '${course.totalReviews} reviews'),
            _buildInfoChip(
                Icons.folder, '${course.materialCount} materials'),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    if (_insights.isEmpty || _insights['totalReviews'] == 0) {
      return Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.insights, size: 60, color: Colors.white54),
              SizedBox(height: 12),
              Text(
                'No insights yet',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Be the first to review this course!',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final examFormats = _insights['examFormats'] as Map<String, int>;
    final caTypes = _insights['caTypes'] as Map<String, int>;
    final behaviors = _insights['lecturerBehaviors'] as Map<String, int>;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam Format
          if (examFormats.isNotEmpty) ...[
            _buildInsightSection(
              'Exam Format',
              Icons.assignment,
              examFormats.entries.map((e) {
                return _buildInsightBar(
                  _formatExamType(e.key),
                  e.value,
                  _insights['totalReviews'],
                );
              }).toList(),
            ),
            SizedBox(height: 20),
          ],

          // CA Type
          if (caTypes.isNotEmpty) ...[
            _buildInsightSection(
              'Continuous Assessment',
              Icons.quiz,
              caTypes.entries.map((e) {
                return _buildInsightBar(
                  _formatCAType(e.key),
                  e.value,
                  _insights['totalReviews'],
                );
              }).toList(),
            ),
            SizedBox(height: 20),
          ],

          // Lecturer Behaviors
          if (behaviors.isNotEmpty) ...[
            _buildInsightSection(
              'Lecturer Behavior',
              Icons.person,
              behaviors.entries.map((e) {
                return _buildInsightBar(
                  _formatBehavior(e.key),
                  e.value,
                  _insights['totalReviews'],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightSection(
      String title, IconData icon, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryPurple, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInsightBar(String label, int count, int total) {
    final percentage = (count / total * 100).round();
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              Text(
                '$percentage%',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: count / total,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple),
            ),
          ),
        ],
      ),
    );
  }

  String _formatExamType(String type) {
    switch (type.toLowerCase()) {
      case 'mostlytheory':
        return 'Mostly Theory';
      case 'mostlycalculations':
        return 'Mostly Calculations';
      case 'repeatedpastquestions':
        return 'Repeated Past Questions';
      default:
        return 'Mixed';
    }
  }

  String _formatCAType(String type) {
    switch (type.toLowerCase()) {
      case 'assignment':
        return 'Assignment';
      case 'test':
        return 'Test';
      case 'presentation':
        return 'Presentation';
      case 'project':
        return 'Project';
      default:
        return 'Mixed';
    }
  }

  String _formatBehavior(String behavior) {
    switch (behavior.toLowerCase()) {
      case 'strict':
        return 'Strict';
      case 'friendly':
        return 'Friendly';
      case 'readsslides':
        return 'Reads Slides';
      case 'interactive':
        return 'Interactive';
      case 'givessurprisetests':
        return 'Gives Surprise Tests';
      default:
        return behavior;
    }
  }

  Widget _buildMaterialsList() {
  return StreamBuilder<List<CourseMaterialModel>>(
    stream: _courseService.getCourseMaterials(widget.course.id),
    builder: (context, snapshot) {
      // Update cache when we have data
      if (snapshot.hasData && snapshot.data != null) {
        _cachedMaterials = snapshot.data!;
        if (_isInitialMaterialLoad) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isInitialMaterialLoad = false);
          });
        }
      }

      // Show loading only on first load
      if (_isInitialMaterialLoad && _cachedMaterials.isEmpty) {
        return Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        );
      }

      // Show cached data or error/empty states
      if (_cachedMaterials.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open,
                  size: 80,
                  color: Colors.grey.withOpacity(0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'No materials yet',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to upload!',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _cachedMaterials.length,
        itemBuilder: (context, index) {
          return _buildMaterialCard(_cachedMaterials[index]);
        },
      );
    },
  );
}

  Widget _buildMaterialCard(CourseMaterialModel material) {
    final userId = _authService.currentUser?.uid;
    final isLiked = userId != null && material.isLikedBy(userId);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewMaterialScreen(material: material),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
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
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    material.fileType == 'pdf'
                        ? Icons.picture_as_pdf
                        : Icons.image,
                    color: AppColors.primaryPurple,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'By ${material.uploaderName}',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (material.description.isNotEmpty) ...[
              SizedBox(height: 12),
              Text(
                material.description,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                _buildMaterialStat(
                    Icons.download, material.downloadCount.toString()),
                SizedBox(width: 16),
                GestureDetector(
                  onTap: () async {
                    if (userId != null) {
                      await _courseService.toggleMaterialLike(
                          material.id, userId);
                    }
                  },
                  child: _buildMaterialStat(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    material.likeCount.toString(),
                    color: isLiked ? Colors.red : null,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getMaterialTypeLabel(material.type),
                    style: GoogleFonts.poppins(
                      color: AppColors.primaryPurple,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialStat(IconData icon, String count, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color ?? Colors.white70, size: 18),
        SizedBox(width: 4),
        Text(
          count,
          style: GoogleFonts.poppins(
            color: color ?? Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getMaterialTypeLabel(CourseMaterialType type) {
    switch (type) {
      case CourseMaterialType.pastQuestion:
        return 'Past Question';
      case CourseMaterialType.lecture:
        return 'Lecture';
      case CourseMaterialType.assignment:
        return 'Assignment';
      case CourseMaterialType.textbook:
        return 'Textbook';
      default:
        return 'Other';
    }
  }

  Widget _buildReviewsList() {
  return Column(
    children: [
      // Insights section - outside StreamBuilder
      if ((_updatedCourse ?? widget.course).totalReviews > 0)
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildInsights(),
        ),
      
      // Reviews list
      Expanded(
        child: StreamBuilder<List<CourseReviewModel>>(
          stream: _courseService.getCourseReviews(widget.course.id),
          builder: (context, snapshot) {
            // Update cache when we have data
            if (snapshot.hasData && snapshot.data != null) {
              _cachedReviews = snapshot.data!;
              if (_isInitialReviewLoad) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _isInitialReviewLoad = false);
                });
              }
            }

            // Show loading only on first load
            if (_isInitialReviewLoad && _cachedReviews.isEmpty) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primaryPurple),
              );
            }

            // Show cached data or empty state
            if (_cachedReviews.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 80,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No reviews yet',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Share your experience!',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cachedReviews.length,
              itemBuilder: (context, index) {
                return _buildReviewCard(_cachedReviews[index]);
              },
            );
          },
        ),
      ),
    ],
  );
}

  Widget _buildReviewCard(CourseReviewModel review) {
    final userId = _authService.currentUser?.uid;
    final isHelpful = userId != null && review.isHelpfulBy(userId);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryPurple.withOpacity(0.3),
                child: Text(
                  review.username[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.username,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDifficultyColor(review.difficulty.toDouble())
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getDifficultyColor(review.difficulty.toDouble()),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.signal_cellular_alt,
                      size: 14,
                      color: _getDifficultyColor(review.difficulty.toDouble()),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${review.difficulty}/5',
                      style: GoogleFonts.poppins(
                        color: _getDifficultyColor(review.difficulty.toDouble()),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildReviewTag(_formatExamType(
                  _examFormatToString(review.examFormat))),
              _buildReviewTag(_formatCAType(
                  _caTypeToString(review.caType))),
              ...review.lecturerBehaviors.map((b) => _buildReviewTag(
                  _formatBehavior(
                      _lecturerBehaviorToString(b)))),
            ],
          ),
          if (review.tips.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb,
                          color: Colors.amber, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Tip:',
                        style: GoogleFonts.poppins(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    review.tips,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  if (userId != null) {
                    await _courseService.toggleReviewHelpful(
                        review.id, userId);
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      isHelpful ? Icons.thumb_up : Icons.thumb_up_outlined,
                      color: isHelpful
                          ? AppColors.primaryPurple
                          : Colors.white70,
                      size: 18,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${review.helpfulCount} helpful',
                      style: GoogleFonts.poppins(
                        color: isHelpful
                            ? AppColors.primaryPurple
                            : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTag(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 11,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.course.code,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryPurple,
            indicatorWeight: 3,
            labelColor: AppColors.primaryPurple,
            unselectedLabelColor: Colors.white70,
            labelStyle: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: 'Materials'),
              Tab(text: 'Reviews'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMaterialsList(),
                _buildReviewsList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    FloatingActionButton(
      heroTag: 'add_review',
      onPressed: _hasUserReviewed
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddReviewScreen(course: widget.course),
                ),
              );
              await _loadInsights(); // Refresh after adding
              await _checkUserReview();
            },
      backgroundColor: _hasUserReviewed
          ? Colors.grey
          : AppColors.primaryPurple,
      child: Icon(Icons.rate_review, color: Colors.white),
    ),
    SizedBox(height: 12),
    FloatingActionButton(
      heroTag: 'add_material',
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AddMaterialScreen(course: widget.course),
          ),
        );
        await _loadInsights(); // Refresh after adding
      },
      backgroundColor: AppColors.primaryPurple,
      child: Icon(Icons.upload_file, color: Colors.white),
    ),
  ],
),
    );
  }
  String _examFormatToString(ExamFormat format) {
  switch (format) {
    case ExamFormat.mostlyTheory:
      return 'mostlytheory';
    case ExamFormat.mostlyCalculations:
      return 'mostlycalculations';
    case ExamFormat.repeatedPastQuestions:
      return 'repeatedpastquestions';
    default:
      return 'mixed';
  }
}

String _caTypeToString(CAType type) {
  switch (type) {
    case CAType.assignment:
      return 'assignment';
    case CAType.test:
      return 'test';
    case CAType.presentation:
      return 'presentation';
    case CAType.project:
      return 'project';
    default:
      return 'mixed';
  }
}

String _lecturerBehaviorToString(LecturerBehavior behavior) {
  switch (behavior) {
    case LecturerBehavior.strict:
      return 'strict';
    case LecturerBehavior.friendly:
      return 'friendly';
    case LecturerBehavior.readsSlides:
      return 'readsslides';
    case LecturerBehavior.interactive:
      return 'interactive';
    case LecturerBehavior.givesSurpriseTests:
      return 'givessurprisetests';
  }
}
}