import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String? profileImageUrl;
  final String? bio;
  
  // New Academic Fields
  final String? matricNumber;
  final String? faculty;
  final String? department;
  final String? studentProofUrl; // URL to uploaded admission letter/proof
  final bool isVerified; // Admin verification status
  
  final DateTime createdAt;
  final List<String> savedItems;
  final List<String> followers;
  final List<String> following;
  final double walletBalance;
  final int totalGamesPlayed;
  final int totalGamesWon;
  final double totalWinnings;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.profileImageUrl,
    this.bio,
    
    // New Academic Fields
    this.matricNumber,
    this.faculty,
    this.department,
    this.studentProofUrl,
    this.isVerified = false,
    
    required this.createdAt,
    this.savedItems = const [],
    this.followers = const [],
    this.following = const [],
    this.walletBalance = 0.0,
    this.totalGamesPlayed = 0,
    this.totalGamesWon = 0,
    this.totalWinnings = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      
      // New Academic Fields
      'matricNumber': matricNumber,
      'faculty': faculty,
      'department': department,
      'studentProofUrl': studentProofUrl,
      'isVerified': isVerified,
      
      'createdAt': Timestamp.fromDate(createdAt),
      'savedItems': savedItems,
      'followers': followers,
      'following': following,
      'walletBalance': walletBalance,
      'totalGamesPlayed': totalGamesPlayed,
      'totalGamesWon': totalGamesWon,
      'totalWinnings': totalWinnings,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      bio: map['bio'],
      
      // New Academic Fields
      matricNumber: map['matricNumber'],
      faculty: map['faculty'],
      department: map['department'],
      studentProofUrl: map['studentProofUrl'],
      isVerified: map['isVerified'] ?? false,
      
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      savedItems: List<String>.from(map['savedItems'] ?? []),
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      walletBalance: (map['walletBalance'] ?? 0).toDouble(),
      totalGamesPlayed: map['totalGamesPlayed'] ?? 0,
      totalGamesWon: map['totalGamesWon'] ?? 0,
      totalWinnings: (map['totalWinnings'] ?? 0).toDouble(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? profileImageUrl,
    String? bio,
    
    // New Academic Fields
    String? matricNumber,
    String? faculty,
    String? department,
    String? studentProofUrl,
    bool? isVerified,
    
    DateTime? createdAt,
    List<String>? savedItems,
    List<String>? followers,
    List<String>? following,
    double? walletBalance,
    int? totalGamesPlayed,
    int? totalGamesWon,
    double? totalWinnings,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      
      // New Academic Fields
      matricNumber: matricNumber ?? this.matricNumber,
      faculty: faculty ?? this.faculty,
      department: department ?? this.department,
      studentProofUrl: studentProofUrl ?? this.studentProofUrl,
      isVerified: isVerified ?? this.isVerified,
      
      createdAt: createdAt ?? this.createdAt,
      savedItems: savedItems ?? this.savedItems,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      walletBalance: walletBalance ?? this.walletBalance,
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      totalGamesWon: totalGamesWon ?? this.totalGamesWon,
      totalWinnings: totalWinnings ?? this.totalWinnings,
    );
  }
}