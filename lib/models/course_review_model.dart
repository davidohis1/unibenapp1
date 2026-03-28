import 'package:cloud_firestore/cloud_firestore.dart';

enum ExamFormat {
  mostlyTheory,
  mostlyCalculations,
  mixed,
  repeatedPastQuestions,
}

enum CAType {
  assignment,
  test,
  presentation,
  project,
  mixed,
}

enum LecturerBehavior {
  strict,
  friendly,
  readsSlides,
  interactive,
  givesSurpriseTests,
}

class CourseReviewModel {
  final String id;
  final String courseId;
  final String userId;
  final String username;
  final int difficulty; // 1-5
  final ExamFormat examFormat;
  final CAType caType;
  final List<LecturerBehavior> lecturerBehaviors;
  final String tips;
  final DateTime createdAt;
  final List<String> helpfulBy; // Users who found this helpful

  CourseReviewModel({
    required this.id,
    required this.courseId,
    required this.userId,
    required this.username,
    required this.difficulty,
    required this.examFormat,
    required this.caType,
    required this.lecturerBehaviors,
    this.tips = '',
    required this.createdAt,
    this.helpfulBy = const [],
  });

  factory CourseReviewModel.fromMap(Map<String, dynamic> map) {
    return CourseReviewModel(
      id: map['id'] ?? '',
      courseId: map['courseId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      difficulty: map['difficulty']?.toInt() ?? 3,
      examFormat: _examFormatFromString(map['examFormat'] ?? 'mixed'),
      caType: _caTypeFromString(map['caType'] ?? 'mixed'),
      lecturerBehaviors: (map['lecturerBehaviors'] as List<dynamic>?)
              ?.map((b) => _lecturerBehaviorFromString(b.toString()))
              .toList() ??
          [],
      tips: map['tips'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      helpfulBy: List<String>.from(map['helpfulBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'userId': userId,
      'username': username,
      'difficulty': difficulty,
      'examFormat': _examFormatToString(examFormat),
      'caType': _caTypeToString(caType),
      'lecturerBehaviors':
          lecturerBehaviors.map((b) => _lecturerBehaviorToString(b)).toList(),
      'tips': tips,
      'createdAt': Timestamp.fromDate(createdAt),
      'helpfulBy': helpfulBy,
    };
  }

  static ExamFormat _examFormatFromString(String format) {
    switch (format.toLowerCase()) {
      case 'mostlytheory':
        return ExamFormat.mostlyTheory;
      case 'mostlycalculations':
        return ExamFormat.mostlyCalculations;
      case 'repeatedpastquestions':
        return ExamFormat.repeatedPastQuestions;
      default:
        return ExamFormat.mixed;
    }
  }

  static String _examFormatToString(ExamFormat format) {
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

  static CAType _caTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'assignment':
        return CAType.assignment;
      case 'test':
        return CAType.test;
      case 'presentation':
        return CAType.presentation;
      case 'project':
        return CAType.project;
      default:
        return CAType.mixed;
    }
  }

  static String _caTypeToString(CAType type) {
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

  static LecturerBehavior _lecturerBehaviorFromString(String behavior) {
    switch (behavior.toLowerCase()) {
      case 'strict':
        return LecturerBehavior.strict;
      case 'friendly':
        return LecturerBehavior.friendly;
      case 'readsslides':
        return LecturerBehavior.readsSlides;
      case 'interactive':
        return LecturerBehavior.interactive;
      case 'givessurprisetests':
        return LecturerBehavior.givesSurpriseTests;
      default:
        return LecturerBehavior.friendly;
    }
  }

  static String _lecturerBehaviorToString(LecturerBehavior behavior) {
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

  int get helpfulCount => helpfulBy.length;
  
  bool isHelpfulBy(String userId) => helpfulBy.contains(userId);
}