import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cross_file/cross_file.dart';
import '../../constants/app_constants.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../models/voting_model.dart';
import '../../models/user_model.dart';

class AddVotingScreen extends StatefulWidget {
  const AddVotingScreen({Key? key}) : super(key: key);

  @override
  State<AddVotingScreen> createState() => _AddVotingScreenState();
}

class _AddVotingScreenState extends State<AddVotingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  
  // Voting Access Control
  VotingAccess _selectedAccess = VotingAccess.general;
  String? _selectedFaculty;
  String? _selectedDepartment;
  
  DateTime? _endDate;
  List<CategoryInput> _categories = [];
  bool _isLoading = false;

  // Predefined lists (you can move these to constants)
  final List<String> _faculties = [
    'Faculty of Science',
    'Faculty of Arts',
    'Faculty of Engineering',
    'Faculty of Social Sciences',
    'Faculty of Law',
    'Faculty of Medicine',
    'Faculty of Education',
    'Faculty of Pharmacy',
    'Faculty of Management Sciences',
    'Faculty of Environmental Sciences',
  ];

  final Map<String, List<String>> _departments = {
    'Faculty of Science': [
      'Computer Science',
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
      'Biochemistry',
      'Microbiology',
      'Geology',
      'Statistics',
    ],
    'Faculty of Arts': [
      'English',
      'History',
      'Philosophy',
      'Linguistics',
      'Theatre Arts',
      'Religious Studies',
    ],
    'Faculty of Engineering': [
      'Civil Engineering',
      'Mechanical Engineering',
      'Electrical Engineering',
      'Computer Engineering',
      'Chemical Engineering',
      'Petroleum Engineering',
    ],
    'Faculty of Social Sciences': [
      'Economics',
      'Political Science',
      'Sociology',
      'Psychology',
      'Geography',
      'Mass Communication',
    ],
    'Faculty of Law': ['Law'],
    'Faculty of Medicine': ['Medicine and Surgery', 'Dentistry', 'Nursing'],
    'Faculty of Education': [
      'Arts Education',
      'Science Education',
      'Educational Management',
      'Guidance and Counseling',
    ],
    'Faculty of Pharmacy': ['Pharmacy'],
    'Faculty of Management Sciences': [
      'Business Administration',
      'Accounting',
      'Banking and Finance',
      'Marketing',
      'Public Administration',
    ],
    'Faculty of Environmental Sciences': [
      'Architecture',
      'Estate Management',
      'Urban Planning',
      'Surveying',
    ],
  };

  @override
  void dispose() {
    _titleController.dispose();
    for (var category in _categories) {
      category.nameController.dispose();
      category.descriptionController.dispose();
      for (var contestant in category.contestants) {
        contestant.nameController.dispose();
        contestant.tagController.dispose();
      }
    }
    super.dispose();
  }

  void _addCategory() {
    setState(() {
      _categories.add(CategoryInput());
    });
  }

  void _removeCategory(int index) {
    setState(() {
      _categories[index].dispose();
      _categories.removeAt(index);
    });
  }

  void _addContestant(int categoryIndex) {
    setState(() {
      _categories[categoryIndex].contestants.add(ContestantInput());
    });
  }

  void _removeContestant(int categoryIndex, int contestantIndex) {
    setState(() {
      _categories[categoryIndex].contestants[contestantIndex].dispose();
      _categories[categoryIndex].contestants.removeAt(contestantIndex);
    });
  }

  Future<void> _pickImageForContestant(int categoryIndex, int contestantIndex) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1080,
    );
    
    if (image != null) {
      setState(() {
        if (kIsWeb) {
          _categories[categoryIndex].contestants[contestantIndex].xImage = image;
        } else {
          _categories[categoryIndex].contestants[contestantIndex].image = File(image.path);
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryPurple,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _submitVoting() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one category')),
      );
      return;
    }

    // Validate each category has at least 2 contestants
    for (int i = 0; i < _categories.length; i++) {
      if (_categories[i].contestants.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "${_categories[i].nameController.text}" needs at least 2 contestants'),
          ),
        );
        return;
      }
    }

    // Validate access control selections
    if (_selectedAccess == VotingAccess.faculty && _selectedFaculty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a faculty')),
      );
      return;
    }

    if (_selectedAccess == VotingAccess.department && _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not logged in');

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) throw Exception('User data not found');

      // Process all categories and upload images
      List<VotingCategory> votingCategories = [];

      for (var categoryInput in _categories) {
        List<Contestant> contestants = [];

        for (var contestantInput in categoryInput.contestants) {
          String? imageUrl;

          // Upload image if exists
          if (kIsWeb && contestantInput.xImage != null) {
            final urls = await _storageService.uploadXFiles(
              [contestantInput.xImage!],
              'voting_contestants',
            );
            imageUrl = urls.isNotEmpty ? urls.first : null;
          } else if (!kIsWeb && contestantInput.image != null) {
            final urls = await _storageService.uploadImages(
              [contestantInput.image!],
              'voting_contestants',
            );
            imageUrl = urls.isNotEmpty ? urls.first : null;
          }

          contestants.add(Contestant(
            id: const Uuid().v4(),
            name: contestantInput.nameController.text.trim(),
            tag: contestantInput.tagController.text.trim().isEmpty 
                ? null 
                : contestantInput.tagController.text.trim(),
            imageUrl: imageUrl,
          ));
        }

        votingCategories.add(VotingCategory(
          id: const Uuid().v4(),
          name: categoryInput.nameController.text.trim(),
          description: categoryInput.descriptionController.text.trim().isEmpty
              ? null
              : categoryInput.descriptionController.text.trim(),
          contestants: contestants,
        ));
      }

      final id = const Uuid().v4();
      final shareableLink = 'campusconnect://voting/$id';

      // Create voting with access control
      final voting = VotingModel(
        id: id,
        creatorId: user.uid,
        creatorName: userData.username,
        title: _titleController.text.trim(),
        categories: votingCategories,
        createdAt: DateTime.now(),
        endDate: _endDate,
        shareableLink: shareableLink,
        
        // Access Control
        accessType: _selectedAccess,
        restrictedFaculty: _selectedFaculty,
        restrictedDepartment: _selectedDepartment,
      );

      await FirebaseFirestore.instance
          .collection(AppConstants.votingCollection)
          .doc(id)
          .set(voting.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voting created successfully!'),
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
        title: Text(
          'Create Voting',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                    'Event Information',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  _buildTextField(
                    controller: _titleController,
                    label: 'Event Title',
                    hint: 'e.g., Freshers\' Night 2024',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // End Date
                  _buildEndDatePicker(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Access Control Section
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
                    'Who Can Vote?',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Access Type Radio Buttons
                  _buildAccessRadio(),
                  
                  if (_selectedAccess == VotingAccess.faculty) ...[
                    const SizedBox(height: 16),
                    _buildFacultyDropdown(),
                  ],
                  
                  if (_selectedAccess == VotingAccess.department) ...[
                    const SizedBox(height: 16),
                    _buildFacultyDropdown(),
                    const SizedBox(height: 12),
                    _buildDepartmentDropdown(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Categories Section
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Categories',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add, color: AppColors.primaryPurple),
                        label: Text(
                          'Add Category',
                          style: GoogleFonts.poppins(color: AppColors.primaryPurple),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (_categories.isEmpty)
                    _buildEmptyCategories(),
                  
                  ...List.generate(_categories.length, (index) {
                    return _buildCategoryCard(index);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitVoting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.white)
                    : Text(
                        'Create Voting',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessRadio() {
    return Column(
      children: [
        RadioListTile<VotingAccess>(
          title: Text('Open to all students', style: GoogleFonts.poppins()),
          value: VotingAccess.general,
          groupValue: _selectedAccess,
          activeColor: AppColors.primaryPurple,
          onChanged: (value) {
            setState(() {
              _selectedAccess = value!;
              _selectedFaculty = null;
              _selectedDepartment = null;
            });
          },
        ),
        RadioListTile<VotingAccess>(
          title: Text('Restrict to Faculty', style: GoogleFonts.poppins()),
          value: VotingAccess.faculty,
          groupValue: _selectedAccess,
          activeColor: AppColors.primaryPurple,
          onChanged: (value) {
            setState(() {
              _selectedAccess = value!;
              _selectedDepartment = null;
            });
          },
        ),
        RadioListTile<VotingAccess>(
          title: Text('Restrict to Department', style: GoogleFonts.poppins()),
          value: VotingAccess.department,
          groupValue: _selectedAccess,
          activeColor: AppColors.primaryPurple,
          onChanged: (value) {
            setState(() {
              _selectedAccess = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFacultyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Faculty',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedFaculty,
          hint: Text('Choose faculty', style: GoogleFonts.poppins()),
          items: _faculties.map((faculty) {
            return DropdownMenuItem(
              value: faculty,
              child: Text(faculty, style: GoogleFonts.poppins()),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedFaculty = value;
              _selectedDepartment = null;
            });
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.lightGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: _selectedAccess == VotingAccess.faculty
              ? (v) => v == null ? 'Required' : null
              : null,
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown() {
    if (_selectedFaculty == null) return const SizedBox();

    final departments = _departments[_selectedFaculty] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Department',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDepartment,
          hint: Text('Choose department', style: GoogleFonts.poppins()),
          items: departments.map((dept) {
            return DropdownMenuItem(
              value: dept,
              child: Text(dept, style: GoogleFonts.poppins()),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedDepartment = value;
            });
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.lightGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: _selectedAccess == VotingAccess.department
              ? (v) => v == null ? 'Required' : null
              : null,
        ),
      ],
    );
  }

  Widget _buildEndDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'End Date (Optional)',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectEndDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.grey),
                const SizedBox(width: 12),
                Text(
                  _endDate != null
                      ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                      : 'Select end date',
                  style: GoogleFonts.poppins(
                    color: _endDate != null ? AppColors.black : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCategories() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.category_outlined, size: 48, color: AppColors.grey.withOpacity(0.5)),
          const SizedBox(height: 8),
          Text(
            'No categories added yet',
            style: GoogleFonts.poppins(color: AppColors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'Click "Add Category" to get started',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(int index) {
    final category = _categories[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          // Category Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Category ${index + 1}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.errorRed),
                  onPressed: () => _removeCategory(index),
                ),
              ],
            ),
          ),

          // Category Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Category Name
                TextFormField(
                  controller: category.nameController,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g., Best Dressed Male',
                    labelStyle: GoogleFonts.poppins(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),

                // Category Description (Optional)
                TextFormField(
                  controller: category.descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'e.g., Criteria for this category',
                    labelStyle: GoogleFonts.poppins(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // Contestants Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Contestants',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _addContestant(index),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        'Add Contestant',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Contestants List
                if (category.contestants.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No contestants added',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.grey),
                    ),
                  )
                else
                  ...List.generate(category.contestants.length, (cIndex) {
                    return _buildContestantCard(index, cIndex);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContestantCard(int categoryIndex, int contestantIndex) {
    final contestant = _categories[categoryIndex].contestants[contestantIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          // Image Picker
          GestureDetector(
            onTap: () => _pickImageForContestant(categoryIndex, contestantIndex),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(8),
                image: _getContestantImage(contestant),
              ),
              child: _getContestantImage(contestant) == null
                  ? const Icon(Icons.add_photo_alternate, color: AppColors.grey)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          
          // Fields
          Expanded(
            child: Column(
              children: [
                TextFormField(
                  controller: contestant.nameController,
                  decoration: InputDecoration(
                    hintText: 'Contestant name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: contestant.tagController,
                  decoration: InputDecoration(
                    hintText: 'Tag/Department (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          
          // Delete Button
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.errorRed, size: 20),
            onPressed: () => _removeContestant(categoryIndex, contestantIndex),
          ),
        ],
      ),
    );
  }

  DecorationImage? _getContestantImage(ContestantInput contestant) {
    if (kIsWeb && contestant.xImage != null) {
      return DecorationImage(
        image: NetworkImage(contestant.xImage!.path),
        fit: BoxFit.cover,
      );
    } else if (!kIsWeb && contestant.image != null) {
      return DecorationImage(
        image: FileImage(contestant.image!),
        fit: BoxFit.cover,
      );
    }
    return null;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: AppColors.grey),
            filled: true,
            fillColor: AppColors.lightGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

// Input Classes
class CategoryInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  List<ContestantInput> contestants = [];

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    for (var c in contestants) {
      c.dispose();
    }
  }
}

class ContestantInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController tagController = TextEditingController();
  File? image;
  XFile? xImage; // For web

  void dispose() {
    nameController.dispose();
    tagController.dispose();
  }
}