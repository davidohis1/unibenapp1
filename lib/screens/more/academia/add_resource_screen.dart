import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../constants/app_constants.dart';
import '../../../services/resource_service.dart';
import '../../../services/storage_service.dart';
import 'dart:io';

class AddResourceScreen extends StatefulWidget {
  const AddResourceScreen({Key? key}) : super(key: key);

  @override
  State<AddResourceScreen> createState() => _AddResourceScreenState();
}

class _AddResourceScreenState extends State<AddResourceScreen> {
  final ResourceService _resourceService = ResourceService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _courseCodeController = TextEditingController();
  final TextEditingController _courseTitleController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  List<XFile> _selectedFiles = [];
  List<String> _fileTypes = [];
  String _selectedFaculty = '';
  String _selectedDepartment = '';
  int _selectedLevel = 100;
  String _selectedSemester = 'First';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final faculties = _resourceService.faculties;
    if (faculties.isNotEmpty) {
      _selectedFaculty = faculties.first;
      _updateDepartments();
    }
  }

  void _updateDepartments() {
    setState(() {
      final depts = _resourceService.getDepartmentsForFaculty(_selectedFaculty);
      _selectedDepartment = depts.isNotEmpty ? depts.first : '';
    });
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'txt'
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            final xfile = XFile(file.path!);
            _selectedFiles.add(xfile);
            _fileTypes.add(_getFileType(file.extension ?? ''));
          }
        }
        setState(() {});
      }
    } catch (e) {
      _showError('Error picking files: $e');
    }
  }

  String _getFileType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'doc':
      case 'docx':
        return 'doc';
      case 'ppt':
      case 'pptx':
        return 'ppt';
      case 'xls':
      case 'xlsx':
        return 'xls';
      default:
        return 'file';
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      _fileTypes.removeAt(index);
    });
  }

  Future<void> _uploadResource() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFiles.isEmpty) {
      _showError('Please add at least one file');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert XFile to File using file paths
      final List<File> files = [];
      for (final xfile in _selectedFiles) {
        final file = File(xfile.path);
        files.add(file);
      }

      // Upload files
      final fileUrls = await _storageService.uploadImages(
        files,
        'resources',
      );

      // Create resource
      await _resourceService.createResource(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        fileUrls: fileUrls,
        fileTypes: _fileTypes,
        department: _selectedDepartment,
        faculty: _selectedFaculty,
        level: _selectedLevel,
        semester: _selectedSemester,
        courseCode: _courseCodeController.text.trim(),
        courseTitle: _courseCodeController.text.trim().isNotEmpty
            ? _courseTitleController.text.trim()
            : null,
        tags: _tagsController.text.trim().isNotEmpty
            ? _tagsController.text
                .trim()
                .split(',')
                .map((t) => t.trim())
                .toList()
            : [],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resource uploaded successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _courseCodeController.dispose();
    _courseTitleController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faculties = _resourceService.faculties;
    final departments =
        _resourceService.getDepartmentsForFaculty(_selectedFaculty);
    final levels = _resourceService.levels;
    final semesters = _resourceService.semesters;

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text('Upload Resource',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Basic Info
              _buildSection('Resource Information', [
                _buildTextField(_titleController, 'Title*',
                    'e.g., CSC 101 Past Questions 2023'),
                const SizedBox(height: 16),
                _buildTextField(_descriptionController, 'Description',
                    'Brief description of the resource',
                    maxLines: 4),
              ]),

              const SizedBox(height: 20),

              // Academic Info
              _buildSection('Academic Information', [
                // Faculty & Department
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown<String>(
                        value: _selectedFaculty,
                        label: 'Faculty*',
                        items: faculties,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedFaculty = value;
                              _updateDepartments();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown<String>(
                        value: _selectedDepartment,
                        label: 'Department*',
                        items: departments,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedDepartment = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Level & Semester
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown<int>(
                        value: _selectedLevel,
                        label: 'Level*',
                        items: levels,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedLevel = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown<String>(
                        value: _selectedSemester,
                        label: 'Semester*',
                        items: semesters,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedSemester = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Course Code & Title
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(_courseCodeController,
                          'Course Code*', 'e.g., CSC 101'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                          _courseTitleController, 'Course Title', 'Optional'),
                    ),
                  ],
                ),
              ]),

              const SizedBox(height: 20),

              // Tags Section
              _buildSection('Tags', [
                _buildTextField(
                  _tagsController,
                  'Tags (comma separated)',
                  'e.g., past-questions, exam, lecture-notes',
                ),
              ]),

              const SizedBox(height: 20),

              // Files Section
              _buildSection('Upload Files', [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 48,
                        color: AppColors.primaryPurple,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Upload Files',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PDF, Images, Word, PowerPoint, Excel',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Browse Files'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_selectedFiles.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          'Selected Files (${_selectedFiles.length})',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._selectedFiles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return _buildFileItem(file, index);
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _uploadResource,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(
                          'Upload Resource',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkPurple,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        filled: true,
        fillColor: AppColors.lightGrey,
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String label,
    required List<T> items,
    required Function(T?)? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        filled: true,
        fillColor: AppColors.lightGrey,
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(item.toString()),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.toString().isEmpty) {
          return 'Please select a $label';
        }
        return null;
      },
    );
  }

  Widget _buildFileItem(XFile file, int index) {
    final fileName = file.name;
    final fileType = _getFileType(fileName.split('.').last);

    return FutureBuilder<int>(
      future: file.length(),
      builder: (context, snapshot) {
        final fileSize = snapshot.hasData
            ? (snapshot.data! / 1024).toStringAsFixed(2)
            : '0.00';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getFileIcon(fileType),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$fileSize KB • ${fileType.toUpperCase()}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.errorRed),
                onPressed: () => _removeFile(index),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return '📄';
      case 'image':
        return '🖼️';
      case 'doc':
        return '📝';
      case 'ppt':
        return '📊';
      case 'xls':
        return '📈';
      default:
        return '📎';
    }
  }
}
