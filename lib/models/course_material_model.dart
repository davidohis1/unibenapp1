import 'package:cloud_firestore/cloud_firestore.dart';

enum CourseMaterialType {
  pastQuestion,
  lecture,
  assignment,
  textbook,
  other,
}

class CourseMaterialModel {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final CourseMaterialType type;
  final List<String> fileUrls;
  final String fileType; // 'pdf' or 'image'
  final String uploadedBy;
  final String uploaderName;
  final DateTime uploadedAt;
  final int downloadCount;
  final List<String> likedBy;

  CourseMaterialModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.description = '',
    required this.type,
    required this.fileUrls,
    required this.fileType,
    required this.uploadedBy,
    required this.uploaderName,
    required this.uploadedAt,
    this.downloadCount = 0,
    this.likedBy = const [],
  });

  factory CourseMaterialModel.fromMap(Map<String, dynamic> map) {
    return CourseMaterialModel(
      id: map['id'] ?? '',
      courseId: map['courseId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: _typeFromString(map['type'] ?? 'other'),
      fileUrls: List<String>.from(map['fileUrls'] ?? []),
      fileType: map['fileType'] ?? 'pdf',
      uploadedBy: map['uploadedBy'] ?? '',
      uploaderName: map['uploaderName'] ?? '',
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      downloadCount: map['downloadCount']?.toInt() ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'description': description,
      'type': _typeToString(type),
      'fileUrls': fileUrls,
      'fileType': fileType,
      'uploadedBy': uploadedBy,
      'uploaderName': uploaderName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'downloadCount': downloadCount,
      'likedBy': likedBy,
    };
  }

  static CourseMaterialType _typeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'pastquestion':
        return CourseMaterialType.pastQuestion;
      case 'lecture':
        return CourseMaterialType.lecture;
      case 'assignment':
        return CourseMaterialType.assignment;
      case 'textbook':
        return CourseMaterialType.textbook;
      default:
        return CourseMaterialType.other;
    }
  }

  static String _typeToString(CourseMaterialType type) {
    switch (type) {
      case CourseMaterialType.pastQuestion:
        return 'pastquestion';
      case CourseMaterialType.lecture:
        return 'lecture';
      case CourseMaterialType.assignment:
        return 'assignment';
      case CourseMaterialType.textbook:
        return 'textbook';
      default:
        return 'other';
    }
  }

  int get likeCount => likedBy.length;
  
  bool isLikedBy(String userId) => likedBy.contains(userId);
}