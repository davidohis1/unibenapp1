import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../constants/app_constants.dart';
import '../../../models/course_model.dart';
import '../../../models/course_review_model.dart';
import '../../../services/course_service.dart';
import '../../../services/auth_service.dart';

class AddReviewScreen extends StatefulWidget {
  final CourseModel course;

  const AddReviewScreen({
    Key? key,
    required this.course,
  }) : super(key: key);

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final CourseService _courseService = CourseService();
  final AuthService _authService = AuthService();
  final TextEditingController _tipsController = TextEditingController();

  int _difficulty = 3;
  ExamFormat _examFormat = ExamFormat.mixed;
  CAType _caType = CAType.mixed;
  Set<LecturerBehavior> _selectedBehaviors = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _tipsController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please sign in to submit a review'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final username = userDoc.data()?['username'] ?? 'Anonymous';

      final reviewId =
          FirebaseFirestore.instance.collection('course_reviews').doc().id;
      final review = CourseReviewModel(
        id: reviewId,
        courseId: widget.course.id,
        userId: user.uid,
        username: username,
        difficulty: _difficulty,
        examFormat: _examFormat,
        caType: _caType,
        lecturerBehaviors: _selectedBehaviors.toList(),
        tips: _tipsController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _courseService.addReview(review);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review submitted successfully!'),
          backgroundColor: AppColors.primaryPurple,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit review: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Review',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course.code,
                    style: GoogleFonts.poppins(
                      color: AppColors.primaryPurple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.course.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            Text(
              'Course Difficulty',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final level = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => _difficulty = level),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _difficulty == level
                          ? AppColors.primaryPurple
                          : Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _difficulty == level
                            ? AppColors.primaryPurple
                            : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '$level',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Very Easy',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Very Hard',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),

            Text(
              'Exam Format',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip('Mostly Theory', ExamFormat.mostlyTheory),
                _buildChoiceChip('Mostly Calculations', ExamFormat.mostlyCalculations),
                _buildChoiceChip('Mixed', ExamFormat.mixed),
                _buildChoiceChip('Repeated Past Questions', ExamFormat.repeatedPastQuestions),
              ],
            ),
            SizedBox(height: 24),

            Text(
              'CA Type',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCAChip('Assignment', CAType.assignment),
                _buildCAChip('Test', CAType.test),
                _buildCAChip('Presentation', CAType.presentation),
                _buildCAChip('Project', CAType.project),
                _buildCAChip('Mixed', CAType.mixed),
              ],
            ),
            SizedBox(height: 24),

            Text(
              'Lecturer Behavior',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildBehaviorChip('Strict', LecturerBehavior.strict),
                _buildBehaviorChip('Friendly', LecturerBehavior.friendly),
                _buildBehaviorChip('Reads Slides', LecturerBehavior.readsSlides),
                _buildBehaviorChip('Interactive', LecturerBehavior.interactive),
                _buildBehaviorChip('Gives Surprise Tests', LecturerBehavior.givesSurpriseTests),
              ],
            ),
            SizedBox(height: 24),

            Text(
              'Tips (Optional)',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _tipsController,
              style: GoogleFonts.poppins(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share any tips or advice for future students...',
                hintStyle: GoogleFonts.poppins(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                ),
              ),
            ),
            SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Submit Review',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, ExamFormat format) {
    final isSelected = _examFormat == format;
    return GestureDetector(
      onTap: () => setState(() => _examFormat = format),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryPurple : Colors.white24,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCAChip(String label, CAType type) {
    final isSelected = _caType == type;
    return GestureDetector(
      onTap: () => setState(() => _caType = type),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryPurple : Colors.white24,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBehaviorChip(String label, LecturerBehavior behavior) {
    final isSelected = _selectedBehaviors.contains(behavior);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedBehaviors.remove(behavior);
          } else {
            _selectedBehaviors.add(behavior);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryPurple : Colors.white24,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}