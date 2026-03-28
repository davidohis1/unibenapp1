import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cross_file/cross_file.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel userData;
  const EditProfileScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  
  // Academic Fields
  final _matricController = TextEditingController();
  final _facultyController = TextEditingController();
  final _departmentController = TextEditingController();
  
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  
  File? _profileImage;
  XFile? _profileXImage; // For web
  File? _studentProof;
  XFile? _studentProofXImage; // For web
  
  bool _isLoading = false;
  String? _profileImageUrl;
  String? _studentProofUrl;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.userData.username;
    _bioController.text = widget.userData.bio ?? '';
    
    // Academic Fields
    _matricController.text = widget.userData.matricNumber ?? '';
    _facultyController.text = widget.userData.faculty ?? '';
    _departmentController.text = widget.userData.department ?? '';
    
    _profileImageUrl = widget.userData.profileImageUrl;
    _studentProofUrl = widget.userData.studentProofUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _matricController.dispose();
    _facultyController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isProfile) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1080,
    );
    
    if (image != null) {
      setState(() {
        if (kIsWeb) {
          if (isProfile) {
            _profileXImage = image;
          } else {
            _studentProofXImage = image;
          }
        } else {
          if (isProfile) {
            _profileImage = File(image.path);
          } else {
            _studentProof = File(image.path);
          }
        }
      });
    }
  }

  void _showImageSourceDialog(bool isProfile) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Gallery', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isProfile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text('Camera', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isProfile);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Upload profile image if changed
      if (_profileImage != null || _profileXImage != null) {
        if (kIsWeb && _profileXImage != null) {
          final urls = await _storageService.uploadXFiles(
            [_profileXImage!],
            'profile_images',
          );
          _profileImageUrl = urls.first;
        } else if (_profileImage != null) {
          final urls = await _storageService.uploadImages(
            [_profileImage!],
            'profile_images',
          );
          _profileImageUrl = urls.first;
        }
      }

      // Upload student proof if changed
      if (_studentProof != null || _studentProofXImage != null) {
        if (kIsWeb && _studentProofXImage != null) {
          final urls = await _storageService.uploadXFiles(
            [_studentProofXImage!],
            'student_proofs',
          );
          _studentProofUrl = urls.first;
        } else if (_studentProof != null) {
          final urls = await _storageService.uploadImages(
            [_studentProof!],
            'student_proofs',
          );
          _studentProofUrl = urls.first;
        }
      }

      // Update user data in Firestore
      final updatedUser = widget.userData.copyWith(
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        profileImageUrl: _profileImageUrl,
        matricNumber: _matricController.text.trim().isEmpty ? null : _matricController.text.trim(),
        faculty: _facultyController.text.trim().isEmpty ? null : _facultyController.text.trim(),
        department: _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
        studentProofUrl: _studentProofUrl,
        // Reset verification if proof changed
        isVerified: (_studentProof != null || _studentProofXImage != null) ? false : widget.userData.isVerified,
      );

      await _authService.updateUserData(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: Text(
              'Save',
              style: GoogleFonts.poppins(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Image Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _showImageSourceDialog(true),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
                          backgroundImage: _getProfileImage(),
                          child: _getProfileImage() == null
                              ? const Icon(Icons.person, size: 60, color: AppColors.primaryPurple)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryPurple,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: AppColors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to change profile picture',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Basic Info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Basic Information',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Username
                  _buildTextField(
                    controller: _usernameController,
                    label: 'Username',
                    hint: 'Enter your username',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Bio
                  _buildTextField(
                    controller: _bioController,
                    label: 'Bio',
                    hint: 'Tell us about yourself',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Academic Info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Academic Information',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.userData.isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 12, color: AppColors.successGreen),
                              const SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppColors.successGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Matric Number
                  _buildTextField(
                    controller: _matricController,
                    label: 'Matric Number',
                    hint: 'e.g., 2021/123456',
                  ),
                  const SizedBox(height: 16),
                  
                  // Faculty
                  _buildTextField(
                    controller: _facultyController,
                    label: 'Faculty',
                    hint: 'e.g., Faculty of Science',
                  ),
                  const SizedBox(height: 16),
                  
                  // Department
                  _buildTextField(
                    controller: _departmentController,
                    label: 'Department',
                    hint: 'e.g., Computer Science',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Student Proof Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Proof of Student',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your admission letter, ID card, or any proof of studentship',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  GestureDetector(
                    onTap: () => _showImageSourceDialog(false),
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _studentProofUrl != null || _studentProof != null || _studentProofXImage != null
                              ? AppColors.successGreen
                              : AppColors.borderColor,
                          width: 2,
                        ),
                        image: _getStudentProofImage(),
                      ),
                      child: _getStudentProofImage() == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.upload_file,
                                  size: 40,
                                  color: AppColors.grey.withOpacity(0.5),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _studentProofUrl != null
                                      ? 'Tap to change proof'
                                      : 'Tap to upload proof',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppColors.grey,
                                  ),
                                ),
                                if (_studentProofUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Current proof uploaded',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppColors.successGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  if (_studentProofUrl != null && _studentProof == null && _studentProofXImage == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: AppColors.successGreen),
                          const SizedBox(width: 4),
                          Text(
                            'Proof uploaded. Upload new to replace.',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (kIsWeb) {
      if (_profileXImage != null) {
        return NetworkImage(_profileXImage!.path);
      }
    } else {
      if (_profileImage != null) {
        return FileImage(_profileImage!);
      }
    }
    if (_profileImageUrl != null) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  DecorationImage? _getStudentProofImage() {
    if (kIsWeb && _studentProofXImage != null) {
      return DecorationImage(
        image: NetworkImage(_studentProofXImage!.path),
        fit: BoxFit.cover,
      );
    } else if (!kIsWeb && _studentProof != null) {
      return DecorationImage(
        image: FileImage(_studentProof!),
        fit: BoxFit.cover,
      );
    } else if (_studentProofUrl != null) {
      return DecorationImage(
        image: NetworkImage(_studentProofUrl!),
        fit: BoxFit.cover,
      );
    }
    return null;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.grey,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.grey),
            filled: true,
            fillColor: AppColors.lightGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}