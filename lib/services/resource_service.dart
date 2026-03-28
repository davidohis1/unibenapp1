import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/resource_model.dart';
import 'storage_service.dart';
import 'auth_service.dart';

class ResourceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  CollectionReference get _resourcesCollection => 
      _firestore.collection('resources');

  // Nigerian universities sample data
  final List<String> _faculties = [
    'Faculty of Engineering',
    'Faculty of Sciences',
    'Faculty of Social Sciences',
    'Faculty of Arts',
    'Faculty of Education',
    'Faculty of Law',
    'Faculty of Management Sciences',
    'Faculty of Pharmacy',
    'Faculty of Medicine',
  ];

  final Map<String, List<String>> _departmentsByFaculty = {
    'Faculty of Engineering': [
      'Computer Engineering',
      'Electrical Engineering',
      'Mechanical Engineering',
      'Civil Engineering',
      'Chemical Engineering',
    ],
    'Faculty of Sciences': [
      'Computer Science',
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biochemistry',
      'Microbiology',
    ],
    'Faculty of Social Sciences': [
      'Economics',
      'Sociology',
      'Psychology',
      'Political Science',
      'Mass Communication',
    ],
    'Faculty of Arts': [
      'English & Literature',
      'History & International Studies',
      'Linguistics',
      'Philosophy',
      'Theatre Arts',
    ],
    'Faculty of Education': [
      'Education Foundation',
      'Science Education',
      'Arts Education',
      'Educational Management',
    ],
    'Faculty of Law': [
      'Private & Property Law',
      'Public & International Law',
      'Commercial Law',
    ],
    'Faculty of Management Sciences': [
      'Accounting',
      'Business Administration',
      'Banking & Finance',
      'Marketing',
    ],
    'Faculty of Pharmacy': [
      'Pharmaceutics',
      'Pharmacology',
      'Clinical Pharmacy',
    ],
    'Faculty of Medicine': [
      'Medicine & Surgery',
      'Nursing',
      'Medical Laboratory Science',
    ],
  };

  final List<int> _levels = [100, 200, 300, 400, 500];
  final List<String> _semesters = ['First', 'Second'];

  List<String> get faculties => _faculties;
  Map<String, List<String>> get departmentsByFaculty => _departmentsByFaculty;
  List<int> get levels => _levels;
  List<String> get semesters => _semesters;

  // Create resource
  Future<String> createResource({
    required String title,
    required String description,
    List<String> fileUrls = const [],
    List<String> fileTypes = const [],
    required String department,
    required String faculty,
    required int level,
    required String semester,
    required String courseCode,
    String? courseTitle,
    List<String> tags = const [],
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not logged in');

      final userData = await _authService.getUserData(user.uid);
      final resourceId = _uuid.v4();

      final resource = ResourceModel(
        id: resourceId,
        userId: user.uid,
        username: userData?.username ?? 'Student',
        userAvatar: userData?.profileImageUrl,
        title: title,
        description: description,
        fileUrls: fileUrls,
        fileTypes: fileTypes,
        department: department,
        faculty: faculty,
        level: level,
        semester: semester,
        courseCode: courseCode.toUpperCase(),
        courseTitle: courseTitle,
        tags: tags,
        createdAt: DateTime.now(),
        status: 'approved', // Auto-approve for now
      );

      await _resourcesCollection.doc(resourceId).set(resource.toMap());
      return resourceId;
    } catch (e) {
      throw Exception('Failed to create resource: $e');
    }
  }

  // Get all approved resources (with filters)
  Stream<List<ResourceModel>> getResourcesStream({
    String? faculty,
    String? department,
    int? level,
    String? semester,
    String? searchQuery,
  }) {
    Query query = _resourcesCollection
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true);

    if (faculty != null && faculty.isNotEmpty) {
      query = query.where('faculty', isEqualTo: faculty);
    }
    
    if (department != null && department.isNotEmpty) {
      query = query.where('department', isEqualTo: department);
    }
    
    if (level != null) {
      query = query.where('level', isEqualTo: level);
    }
    
    if (semester != null && semester.isNotEmpty) {
      query = query.where('semester', isEqualTo: semester);
    }

    return query.snapshots().map((snapshot) {
      List<ResourceModel> resources = snapshot.docs
          .map((doc) => ResourceModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Apply search filter if query exists
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        resources = resources.where((resource) {
          return resource.title.toLowerCase().contains(query) ||
                 resource.description.toLowerCase().contains(query) ||
                 resource.courseCode.toLowerCase().contains(query) ||
                 resource.department.toLowerCase().contains(query) ||
                 resource.faculty.toLowerCase().contains(query) ||
                 resource.tags.any((tag) => tag.toLowerCase().contains(query));
        }).toList();
      }

      return resources;
    });
  }

  // Get user's resources
  Stream<List<ResourceModel>> getUserResources() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _resourcesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ResourceModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Increment view count
  Future<void> incrementViews(String resourceId) async {
    try {
      await _resourcesCollection.doc(resourceId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing views: $e');
    }
  }

  // Increment download count
  Future<void> incrementDownloads(String resourceId) async {
    try {
      await _resourcesCollection.doc(resourceId).update({
        'downloads': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing downloads: $e');
    }
  }

  // Delete resource
  Future<void> deleteResource(String resourceId) async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Not authorized');

      final resourceDoc = await _resourcesCollection.doc(resourceId).get();
      if (!resourceDoc.exists) return;

      final resource = ResourceModel.fromMap(resourceDoc.data() as Map<String, dynamic>);
      if (resource.userId != userId) throw Exception('Not authorized');

      await _resourcesCollection.doc(resourceId).delete();
    } catch (e) {
      throw Exception('Failed to delete resource: $e');
    }
  }

  // Get popular resources
  Stream<List<ResourceModel>> getPopularResources({int limit = 10}) {
    return _resourcesCollection
        .where('status', isEqualTo: 'approved')
        .orderBy('downloads', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ResourceModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Get departments for a faculty
  List<String> getDepartmentsForFaculty(String faculty) {
    return _departmentsByFaculty[faculty] ?? [];
  }

  // Get common courses (sample data)
  List<String> getCommonCourses(String department) {
    final courses = {
      'Computer Science': ['CSC 101', 'CSC 102', 'CSC 201', 'CSC 202', 'CSC 301'],
      'Computer Engineering': ['CEN 101', 'CEN 102', 'CEN 201', 'CEN 202'],
      'Electrical Engineering': ['EEE 101', 'EEE 102', 'EEE 201', 'EEE 202'],
      'Mathematics': ['MTH 101', 'MTH 102', 'MTH 201', 'MTH 202'],
      'Physics': ['PHY 101', 'PHY 102', 'PHY 201', 'PHY 202'],
      'Chemistry': ['CHM 101', 'CHM 102', 'CHM 201', 'CHM 202'],
      'Economics': ['ECO 101', 'ECO 102', 'ECO 201', 'ECO 202'],
      'Accounting': ['ACC 101', 'ACC 102', 'ACC 201', 'ACC 202'],
    };
    return courses[department] ?? ['Course Code'];
  }
}