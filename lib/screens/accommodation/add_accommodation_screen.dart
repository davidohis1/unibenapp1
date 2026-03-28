import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../constants/app_constants.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../models/accommodation_model.dart';
import 'package:http/http.dart' as http; // Add this
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cross_file/cross_file.dart'; // Add this for XFile

class AddAccommodationScreen extends StatefulWidget {
  const AddAccommodationScreen({Key? key}) : super(key: key);

  @override
  State<AddAccommodationScreen> createState() => _AddAccommodationScreenState();
}

class _AddAccommodationScreenState extends State<AddAccommodationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  
  String _selectedType = 'Single Room';
  int _bedrooms = 1;
  int _bathrooms = 1;
  bool _hasTiles = false;
  bool _hasWater = false;
  bool _hasLight = false;
  List<String> _selectedFeatures = [];
  List<File> _selectedImages = [];
  List<XFile> _selectedXImages = [];
  List<File> _selectedVideos = [];
  bool _isLoading = false;

  final List<String> _accommodationTypes = [
    'Single Room',
    'Self Contain',
    'Bedroom Flat',
  ];

  final List<String> _availableFeatures = [
    'Kitchen',
    'Parking',
    'Security',
    'Balcony',
    'Wardrobe',
    'Air Conditioning',
    'WiFi',
    'Generator',
    'Fence',
    'Quiet Area',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
  final List<XFile> images = await _picker.pickMultiImage(
    imageQuality: 85,
    maxWidth: 1920,
  );
  
  if (images.isNotEmpty) {
    if (kIsWeb) {
      // For web - we need to handle differently
      setState(() {
        // On web, we store XFile references, not File objects
        _selectedXImages.addAll(images);
      });
    } else {
      // For mobile - convert to File
      setState(() {
        _selectedImages.addAll(images.map((img) => File(img.path)));
      });
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${images.length} image(s) selected'),
        backgroundColor: AppColors.successGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

  Future<void> _pickVideos() async {
  final XFile? video = await _picker.pickVideo(
    source: ImageSource.gallery,
    maxDuration: const Duration(minutes: 5), // Limit video duration
  );
  
  if (video != null) {
    setState(() {
      _selectedVideos.add(File(video.path));
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video selected'),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }
}

  void _removeImage(int index) {
    setState(() {
      if (kIsWeb) {
        _selectedXImages.removeAt(index);
      } else {
        _selectedImages.removeAt(index);
      }
    });
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
    });
  }

  void _toggleFeature(String feature) {
    setState(() {
      if (_selectedFeatures.contains(feature)) {
        _selectedFeatures.remove(feature);
      } else {
        _selectedFeatures.add(feature);
      }
    });
  }

  Future<void> _submitAccommodation() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (kIsWeb ? _selectedXImages.isEmpty : _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not logged in');

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) throw Exception('User data not found');

      // Upload images
      // Upload images to Bunny.net
// Upload images to Bunny.net
      List<String> imageUrls;
      try {
        if (kIsWeb) {
          // For web, use XFiles
          imageUrls = await _storageService.uploadXFiles(
            _selectedXImages,
            'accommodations',
          );
        } else {
          // For mobile, use Files
          imageUrls = await _storageService.uploadImages(
            _selectedImages,
            'accommodations',
          );
        }
        
        if (imageUrls.isEmpty) {
          throw Exception('Failed to upload images');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image upload failed: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Upload videos
      List<String> videoUrls = [];
      if (_selectedVideos.isNotEmpty) {
        videoUrls = await _storageService.uploadVideos(
          _selectedVideos,
          'accommodations',
        );
      }

      final id = const Uuid().v4();

      // Create accommodation
      final accommodation = AccommodationModel(
        id: id,
        ownerId: user.uid,
        ownerName: userData.username,
        ownerImageUrl: userData.profileImageUrl ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        location: _locationController.text.trim(),
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        whatsappNumber: _whatsappController.text.trim(),
        features: _selectedFeatures,
        imageUrls: imageUrls,
        videoUrls: videoUrls,
        bedrooms: _bedrooms,
        bathrooms: _bathrooms,
        type: _selectedType.toLowerCase().replaceAll(' ', '-'),
        hasTiles: _hasTiles,
        hasWater: _hasWater,
        hasLight: _hasLight,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection(AppConstants.accommodationsCollection)
          .doc(id)
          .set(accommodation.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accommodation posted successfully!'),
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
          'Add Accommodation',
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
            // Images Section
            _buildMediaSection(),
            const SizedBox(height: 24),

            // Title
            _buildTextField(
              controller: _titleController,
              label: 'Title',
              hint: 'e.g., Spacious Single Room near Campus',
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Type
            _buildDropdown(
              label: 'Type',
              value: _selectedType,
              items: _accommodationTypes,
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 16),

            // Bedrooms and Bathrooms
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    label: 'Bedrooms',
                    value: _bedrooms,
                    onChanged: (v) => setState(() => _bedrooms = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberField(
                    label: 'Bathrooms',
                    value: _bathrooms,
                    onChanged: (v) => setState(() => _bathrooms = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Price
            _buildTextField(
              controller: _priceController,
              label: 'Price per Month (\$)',
              hint: '0.00',
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v!.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid price';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Utilities
            _buildUtilitiesSection(),
            const SizedBox(height: 16),

            // Features
            _buildFeaturesSection(),
            const SizedBox(height: 16),

            // Description
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe the accommodation in detail',
              maxLines: 4,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Location
            _buildTextField(
              controller: _locationController,
              label: 'Location',
              hint: 'e.g., Permanent Site, Ugbowo',
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Address
            _buildTextField(
              controller: _addressController,
              label: 'Full Address',
              hint: 'e.g., No. 45, University Road, Benin City',
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Phone Number
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: '08012345678',
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // WhatsApp Number
            _buildTextField(
              controller: _whatsappController,
              label: 'WhatsApp Number',
              hint: '08012345678',
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitAccommodation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.white)
                    : Text(
                        'Post Accommodation',
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

  Widget _buildMediaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Media',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Images
          // Images
      if (kIsWeb ? _selectedXImages.isNotEmpty : _selectedImages.isNotEmpty)
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: kIsWeb ? _selectedXImages.length : _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: kIsWeb
                            ? NetworkImage(_selectedXImages[index].path) as ImageProvider
                            : FileImage(_selectedImages[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.errorRed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

          const SizedBox(height: 12),

          // Add buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.image),
                  label: Text(
                    'Add Images',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                    side: const BorderSide(color: AppColors.primaryPurple),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickVideos,
                  icon: const Icon(Icons.videocam),
                  label: Text(
                    'Add Video',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                    side: const BorderSide(color: AppColors.primaryPurple),
                  ),
                ),
              ),
            ],
          ),

          // Videos
          if (_selectedVideos.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...List.generate(_selectedVideos.length, (index) {
              return ListTile(
                leading: const Icon(Icons.videocam, color: AppColors.primaryPurple),
                title: Text('Video ${index + 1}', style: GoogleFonts.poppins(fontSize: 14)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.errorRed),
                  onPressed: () => _removeVideo(index),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildUtilitiesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Utilities',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          CheckboxListTile(
            title: Text('Tiled Floor', style: GoogleFonts.poppins()),
            value: _hasTiles,
            onChanged: (v) => setState(() => _hasTiles = v!),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primaryPurple,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            title: Text('Water Supply', style: GoogleFonts.poppins()),
            value: _hasWater,
            onChanged: (v) => setState(() => _hasWater = v!),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primaryPurple,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            title: Text('Electricity', style: GoogleFonts.poppins()),
            value: _hasLight,
            onChanged: (v) => setState(() => _hasLight = v!),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primaryPurple,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Features',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableFeatures.map((feature) {
              final isSelected = _selectedFeatures.contains(feature);
              return FilterChip(
                label: Text(feature),
                selected: isSelected,
                onSelected: (selected) => _toggleFeature(feature),
                selectedColor: AppColors.primaryPurple.withOpacity(0.2),
                checkmarkColor: AppColors.primaryPurple,
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isSelected ? AppColors.primaryPurple : AppColors.grey,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required int value,
    required Function(int) onChanged,
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
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: value > 1 ? () => onChanged(value - 1) : null,
                color: AppColors.primaryPurple,
              ),
              Text(
                value.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => onChanged(value + 1),
                color: AppColors.primaryPurple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
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
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: AppColors.grey),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
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
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderColor),
            ),
          ),
        ),
      ],
    );
  }
}