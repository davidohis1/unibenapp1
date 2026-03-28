import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class VotingModel {
  final String id;
  final String creatorId;
  final String creatorName;
  final String title; // Main event title (e.g., "Freshers' Night 2024")
  final List<VotingCategory> categories;
  final DateTime createdAt;
  final DateTime? endDate;
  final bool isActive;
  final String shareableLink;
  
  // Access Control Fields
  final VotingAccess accessType; // general, faculty, department
  final String? restrictedFaculty; // If accessType is faculty
  final String? restrictedDepartment; // If accessType is department

  VotingModel({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.categories,
    required this.createdAt,
    this.endDate,
    this.isActive = true,
    required this.shareableLink,
    
    // Access Control
    this.accessType = VotingAccess.general,
    this.restrictedFaculty,
    this.restrictedDepartment,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'title': title,
      'categories': categories.map((c) => c.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isActive': isActive,
      'shareableLink': shareableLink,
      
      // Access Control
      'accessType': accessType.toString().split('.').last,
      'restrictedFaculty': restrictedFaculty,
      'restrictedDepartment': restrictedDepartment,
    };
  }

  factory VotingModel.fromMap(Map<String, dynamic> map) {
    return VotingModel(
      id: map['id'] ?? '',
      creatorId: map['creatorId'] ?? '',
      creatorName: map['creatorName'] ?? '',
      title: map['title'] ?? '',
      categories: (map['categories'] as List? ?? [])
          .map((c) => VotingCategory.fromMap(c))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] ?? true,
      shareableLink: map['shareableLink'] ?? '',
      
      // Access Control
      accessType: _parseAccessType(map['accessType']),
      restrictedFaculty: map['restrictedFaculty'],
      restrictedDepartment: map['restrictedDepartment'],
    );
  }

  static VotingAccess _parseAccessType(String? type) {
    switch (type) {
      case 'faculty':
        return VotingAccess.faculty;
      case 'department':
        return VotingAccess.department;
      default:
        return VotingAccess.general;
    }
  }

  bool canUserVote(UserModel user) {
    if (accessType == VotingAccess.general) return true;
    if (!user.isVerified) return false; // Must be verified student
    
    if (accessType == VotingAccess.faculty) {
      return user.faculty == restrictedFaculty;
    }
    
    if (accessType == VotingAccess.department) {
      return user.department == restrictedDepartment;
    }
    
    return false;
  }

  String get accessDescription {
    switch (accessType) {
      case VotingAccess.general:
        return 'Open to all students';
      case VotingAccess.faculty:
        return 'Only for $restrictedFaculty students';
      case VotingAccess.department:
        return 'Only for $restrictedDepartment students';
    }
  }

  int get totalVotes {
    return categories.fold(0, (sum, category) {
      return sum + category.contestants.fold(0, (s, c) => s + c.votes);
    });
  }
}

enum VotingAccess { general, faculty, department }

class VotingCategory {
  final String id;
  final String name;
  final String? description;
  final List<Contestant> contestants;

  VotingCategory({
    required this.id,
    required this.name,
    this.description,
    required this.contestants,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'contestants': contestants.map((c) => c.toMap()).toList(),
    };
  }

  factory VotingCategory.fromMap(Map<String, dynamic> map) {
    return VotingCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      contestants: (map['contestants'] as List? ?? [])
          .map((c) => Contestant.fromMap(c))
          .toList(),
    );
  }

  int get totalVotes {
    return contestants.fold(0, (sum, c) => sum + c.votes);
  }
}

class Contestant {
  final String id;
  final String name;
  final String? tag;
  final String? imageUrl;
  final int votes;
  final List<String> voters;

  Contestant({
    required this.id,
    required this.name,
    this.tag,
    this.imageUrl,
    this.votes = 0,
    this.voters = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tag': tag,
      'imageUrl': imageUrl,
      'votes': votes,
      'voters': voters,
    };
  }

  factory Contestant.fromMap(Map<String, dynamic> map) {
    return Contestant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      tag: map['tag'],
      imageUrl: map['imageUrl'],
      votes: map['votes'] ?? 0,
      voters: List<String>.from(map['voters'] ?? []),
    );
  }
}