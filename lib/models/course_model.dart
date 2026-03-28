import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel {
  final String id;
  final String title;
  final String code;
  final String faculty;
  final String department;
  final String level;
  final DateTime createdAt;
  final String createdBy;
  final int totalReviews;
  final double averageDifficulty;
  final int materialCount;

  CourseModel({
    required this.id,
    required this.title,
    required this.code,
    required this.faculty,
    required this.department,
    required this.level,
    required this.createdAt,
    required this.createdBy,
    this.totalReviews = 0,
    this.averageDifficulty = 0.0,
    this.materialCount = 0,
  });

  factory CourseModel.fromMap(Map<String, dynamic> map) {
    return CourseModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      code: map['code'] ?? '',
      faculty: map['faculty'] ?? '',
      department: map['department'] ?? '',
      level: map['level'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      totalReviews: map['totalReviews']?.toInt() ?? 0,
      averageDifficulty: map['averageDifficulty']?.toDouble() ?? 0.0,
      materialCount: map['materialCount']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'code': code,
      'faculty': faculty,
      'department': department,
      'level': level,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'totalReviews': totalReviews,
      'averageDifficulty': averageDifficulty,
      'materialCount': materialCount,
    };
  }

  // Calculate difficulty score out of 100
  int get difficultyScore => (averageDifficulty * 20).round();

  String get difficultyLabel {
    if (averageDifficulty <= 1.5) return 'Very Easy';
    if (averageDifficulty <= 2.5) return 'Easy';
    if (averageDifficulty <= 3.5) return 'Moderate';
    if (averageDifficulty <= 4.5) return 'Hard';
    return 'Very Hard';
  }
}