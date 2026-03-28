import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/course_model.dart';
import '../models/course_material_model.dart';
import '../models/course_review_model.dart';
import 'package:file_picker/file_picker.dart';

class CourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Bunny.net Configuration
  final String _storageZone = 'avidapp'; // Replace with your storage zone
  final String _accessKey = '9c20f2f7-50a4-4526-8d2140f42b48-d46c-407e'; // Replace with your access key
  final String _pullZoneUrl = 'https://avidapp1.b-cdn.net'; // Replace with your pull zone URL
  final String _uploadUrl = 'https://jh.storage.bunnycdn.com'; // Bunny.net storage API URL

  // ============== COURSE MANAGEMENT ==============

  // Check if course code exists
  Future<bool> courseCodeExists(String code) async {
    try {
      final snapshot = await _firestore
          .collection('courses')
          .where('code', isEqualTo: code.toUpperCase())
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking course code: $e');
      return false;
    }
  }

  // Add new course
  Future<void> addCourse(CourseModel course) async {
    try {
      // Check if course code already exists
      final exists = await courseCodeExists(course.code);
      if (exists) {
        throw Exception('Course code already exists');
      }

      await _firestore.collection('courses').doc(course.id).set(course.toMap());
    } catch (e) {
      print('Error adding course: $e');
      rethrow;
    }
  }

  // Get all courses
  Stream<List<CourseModel>> getCourses() {
    return _firestore
        .collection('courses')
        .orderBy('title')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => CourseModel.fromMap(doc.data())).toList());
  }

  // Get course by ID
  Future<CourseModel?> getCourseById(String courseId) async {
    try {
      final doc = await _firestore.collection('courses').doc(courseId).get();
      if (doc.exists) {
        return CourseModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting course: $e');
      return null;
    }
  }

  // Update course statistics
  Future<void> updateCourseStats(String courseId) async {
    try {
      // Get all reviews for this course
      final reviews = await _firestore
          .collection('course_reviews')
          .where('courseId', isEqualTo: courseId)
          .get();

      if (reviews.docs.isEmpty) {
        await _firestore.collection('courses').doc(courseId).update({
          'totalReviews': 0,
          'averageDifficulty': 0.0,
        });
        return;
      }

      // Calculate average difficulty
      double totalDifficulty = 0;
      for (var doc in reviews.docs) {
        totalDifficulty += (doc.data()['difficulty'] ?? 0).toDouble();
      }
      final avgDifficulty = totalDifficulty / reviews.docs.length;

      // Get material count
      final materials = await _firestore
          .collection('course_materials')
          .where('courseId', isEqualTo: courseId)
          .get();

      await _firestore.collection('courses').doc(courseId).update({
        'totalReviews': reviews.docs.length,
        'averageDifficulty': avgDifficulty,
        'materialCount': materials.docs.length,
      });
    } catch (e) {
      print('Error updating course stats: $e');
    }
  }

  // ============== MATERIALS MANAGEMENT WITH BUNNY.NET ==============

  // Upload material to Bunny.net
  Future<List<String>> uploadMaterialFiles({
  required List<PlatformFile> files,
  required String fileType,
  required String courseCode,
}) async {
  try {
    List<String> uploadedUrls = [];

    for (var file in files) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${courseCode}_${timestamp}_${file.name}';
      final path = 'materials/$courseCode/$fileName';

      // Bunny.net Storage API requires a raw PUT with bytes in body
      final url = '$_uploadUrl/$_storageZone/$path';

      // Get file bytes
      Uint8List fileBytes;
      if (kIsWeb) {
        fileBytes = file.bytes!;
      } else {
        fileBytes = await File(file.path!).readAsBytes();
      }

      // Use http.put with raw bytes — NOT MultipartRequest
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'AccessKey': _accessKey,
          'Content-Type': 'application/octet-stream',
        },
        body: fileBytes,
      );

      if (response.statusCode == 201) {
        final cdnUrl = '$_pullZoneUrl/$path';
        uploadedUrls.add(cdnUrl);
        print('Uploaded to Bunny.net: $cdnUrl');
      } else {
        throw Exception(
          'Upload failed with status ${response.statusCode}: ${response.body}',
        );
      }
    }

    return uploadedUrls;
  } catch (e) {
    print('Error uploading to Bunny.net: $e');
    rethrow;
  }
}

  // Add material
  Future<void> addMaterial(CourseMaterialModel material) async {
    try {
      await _firestore
          .collection('course_materials')
          .doc(material.id)
          .set(material.toMap());

      // Update course material count
      await updateCourseStats(material.courseId);
    } catch (e) {
      print('Error adding material: $e');
      rethrow;
    }
  }

  // Get materials for a course
  Stream<List<CourseMaterialModel>> getCourseMaterials(String courseId) {
    return _firestore
        .collection('course_materials')
        .where('courseId', isEqualTo: courseId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CourseMaterialModel.fromMap(doc.data()))
            .toList());
  }

  // Toggle material like
  Future<void> toggleMaterialLike(String materialId, String userId) async {
    try {
      final materialRef =
          _firestore.collection('course_materials').doc(materialId);
      final doc = await materialRef.get();

      if (!doc.exists) return;

      final likedBy = List<String>.from(doc.data()?['likedBy'] ?? []);

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
      }

      await materialRef.update({'likedBy': likedBy});
    } catch (e) {
      print('Error toggling material like: $e');
      rethrow;
    }
  }

  // Increment download count
  Future<void> incrementDownloadCount(String materialId) async {
    try {
      await _firestore.collection('course_materials').doc(materialId).update({
        'downloadCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing download count: $e');
    }
  }

  // ============== REVIEWS MANAGEMENT ==============

  // Add review
  Future<void> addReview(CourseReviewModel review) async {
    try {
      await _firestore
          .collection('course_reviews')
          .doc(review.id)
          .set(review.toMap());

      // Update course stats
      await updateCourseStats(review.courseId);
    } catch (e) {
      print('Error adding review: $e');
      rethrow;
    }
  }

  // Get reviews for a course
  Stream<List<CourseReviewModel>> getCourseReviews(String courseId) {
    return _firestore
        .collection('course_reviews')
        .where('courseId', isEqualTo: courseId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CourseReviewModel.fromMap(doc.data()))
            .toList());
  }

  // Toggle review helpful
  Future<void> toggleReviewHelpful(String reviewId, String userId) async {
    try {
      final reviewRef = _firestore.collection('course_reviews').doc(reviewId);
      final doc = await reviewRef.get();

      if (!doc.exists) return;

      final helpfulBy = List<String>.from(doc.data()?['helpfulBy'] ?? []);

      if (helpfulBy.contains(userId)) {
        helpfulBy.remove(userId);
      } else {
        helpfulBy.add(userId);
      }

      await reviewRef.update({'helpfulBy': helpfulBy});
    } catch (e) {
      print('Error toggling review helpful: $e');
      rethrow;
    }
  }

  // Get aggregated insights for a course
  Future<Map<String, dynamic>> getCourseInsights(String courseId) async {
    try {
      final reviews = await _firestore
          .collection('course_reviews')
          .where('courseId', isEqualTo: courseId)
          .get();

      if (reviews.docs.isEmpty) {
        return {
          'totalReviews': 0,
          'averageDifficulty': 0.0,
          'examFormats': {},
          'caTypes': {},
          'lecturerBehaviors': {},
        };
      }

      Map<String, int> examFormats = {};
      Map<String, int> caTypes = {};
      Map<String, int> lecturerBehaviors = {};
      double totalDifficulty = 0;

      for (var doc in reviews.docs) {
        final data = doc.data();
        totalDifficulty += (data['difficulty'] ?? 0).toDouble();

        // Count exam formats
        final examFormat = data['examFormat'] ?? 'mixed';
        examFormats[examFormat] = (examFormats[examFormat] ?? 0) + 1;

        // Count CA types
        final caType = data['caType'] ?? 'mixed';
        caTypes[caType] = (caTypes[caType] ?? 0) + 1;

        // Count lecturer behaviors
        final behaviors = List<String>.from(data['lecturerBehaviors'] ?? []);
        for (var behavior in behaviors) {
          lecturerBehaviors[behavior] =
              (lecturerBehaviors[behavior] ?? 0) + 1;
        }
      }

      return {
        'totalReviews': reviews.docs.length,
        'averageDifficulty': totalDifficulty / reviews.docs.length,
        'examFormats': examFormats,
        'caTypes': caTypes,
        'lecturerBehaviors': lecturerBehaviors,
      };
    } catch (e) {
      print('Error getting course insights: $e');
      return {
        'totalReviews': 0,
        'averageDifficulty': 0.0,
        'examFormats': {},
        'caTypes': {},
        'lecturerBehaviors': {},
      };
    }
  }

  // Check if user has reviewed a course
  Future<bool> hasUserReviewedCourse(String courseId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('course_reviews')
          .where('courseId', isEqualTo: courseId)
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking user review: $e');
      return false;
    }
  }
}