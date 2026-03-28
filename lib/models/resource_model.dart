import 'package:cloud_firestore/cloud_firestore.dart';

class ResourceModel {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar;
  final String title;
  final String description;
  final List<String> fileUrls;
  final List<String> fileTypes; // 'pdf', 'image', 'doc', 'ppt', etc.
  final String department;
  final String faculty;
  final int level;
  final String semester;
  final String courseCode;
  final String? courseTitle;
  final List<String> tags;
  final DateTime createdAt;
  final int downloads;
  final int views;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;

  ResourceModel({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.title,
    required this.description,
    this.fileUrls = const [],
    this.fileTypes = const [],
    required this.department,
    required this.faculty,
    required this.level,
    required this.semester,
    required this.courseCode,
    this.courseTitle,
    this.tags = const [],
    required this.createdAt,
    this.downloads = 0,
    this.views = 0,
    this.status = 'approved',
    this.rejectionReason,
  });

  factory ResourceModel.fromMap(Map<String, dynamic> map) {
    return ResourceModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Anonymous',
      userAvatar: map['userAvatar'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      fileUrls: List<String>.from(map['fileUrls'] ?? []),
      fileTypes: List<String>.from(map['fileTypes'] ?? []),
      department: map['department'] ?? '',
      faculty: map['faculty'] ?? '',
      level: map['level']?.toInt() ?? 100,
      semester: map['semester'] ?? 'First',
      courseCode: map['courseCode'] ?? '',
      courseTitle: map['courseTitle'],
      tags: List<String>.from(map['tags'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      downloads: map['downloads']?.toInt() ?? 0,
      views: map['views']?.toInt() ?? 0,
      status: map['status'] ?? 'approved',
      rejectionReason: map['rejectionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'title': title,
      'description': description,
      'fileUrls': fileUrls,
      'fileTypes': fileTypes,
      'department': department,
      'faculty': faculty,
      'level': level,
      'semester': semester,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'downloads': downloads,
      'views': views,
      'status': status,
      'rejectionReason': rejectionReason,
    };
  }

  bool get hasFiles => fileUrls.isNotEmpty;
  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  String get fileTypeIcon {
    if (fileTypes.isEmpty) return '📄';
    final mainType = fileTypes.first;
    switch (mainType) {
      case 'pdf': return '📕';
      case 'image': return '🖼️';
      case 'doc': case 'docx': return '📝';
      case 'ppt': case 'pptx': return '📊';
      case 'xls': case 'xlsx': return '📈';
      default: return '📄';
    }
  }
}