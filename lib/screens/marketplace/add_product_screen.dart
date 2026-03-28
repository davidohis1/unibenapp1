import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../constants/app_constants.dart';
import '../../services/image_upload_service.dart';
import '../../services/auth_service.dart';
import '../../models/product_model.dart';
import '../../models/service_model.dart';

class AddProductScreen extends StatefulWidget {
  final bool isService;
  const AddProductScreen({Key? key, this.isService = false}) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController       = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController       = TextEditingController();
  final _phoneController       = TextEditingController();
  final _whatsappController    = TextEditingController();
  final _locationController    = TextEditingController();

  final ImageUploadService _uploadService = ImageUploadService();
  final AuthService        _authService   = AuthService();
  final ImagePicker        _picker        = ImagePicker();

  String       _selectedCategory = 'Electronics';
  String       _selectedCondition = 'Good';
  List<XFile>  _selectedImages   = [];   // ← XFile, NOT dart:io File
  bool         _isLoading        = false;
  double       _uploadProgress   = 0.0;

  final List<String> _productCategories  = ['Electronics','Books','Clothing','Furniture','Sports','Other'];
  final List<String> _serviceCategories  = ['Tutoring','Assignment Help','Typing','Graphic Design','Programming','Other'];
  final List<String> _conditions         = ['New','Like New','Good','Fair'];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.isService ? _serviceCategories[0] : _productCategories[0];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ── Pick images ──────────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    final List<XFile> picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(picked);
        if (_selectedImages.length > 10) {
          _selectedImages = _selectedImages.sublist(0, 10);
        }
      });
    }
  }

  void _removeImage(int index) => setState(() => _selectedImages.removeAt(index));

  // ── Submit ───────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      _showError('Please add at least one image.');
      return;
    }

    setState(() { _isLoading = true; _uploadProgress = 0.1; });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('Not logged in.');

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) throw Exception('User profile not found.');

      setState(() => _uploadProgress = 0.3);

      // ── Upload images to PHP backend ────────────────────────────────────────
      final folder    = widget.isService ? 'services' : 'products';
      final imageUrls = await _uploadService.uploadXFiles(_selectedImages, folder);

      setState(() => _uploadProgress = 0.75);

      // ── Save to Firestore ───────────────────────────────────────────────────
      final id = const Uuid().v4();

      if (widget.isService) {
        final service = ServiceModel(
          id:             id,
          sellerId:       user.uid,
          sellerName:     userData.username,
          sellerImageUrl: userData.profileImageUrl ?? '',
          title:          _titleController.text.trim(),
          description:    _descriptionController.text.trim(),
          price:          double.parse(_priceController.text.trim()),
          category:       _selectedCategory,
          phoneNumber:    _phoneController.text.trim(),
          whatsappNumber: _whatsappController.text.trim(),
          location:       _locationController.text.trim(),
          imageUrls:      imageUrls,
          createdAt:      DateTime.now(),
        );
        await FirebaseFirestore.instance
            .collection(AppConstants.servicesCollection)
            .doc(id)
            .set(service.toMap());
      } else {
        final product = ProductModel(
          id:             id,
          sellerId:       user.uid,
          sellerName:     userData.username,
          sellerImageUrl: userData.profileImageUrl ?? '',
          title:          _titleController.text.trim(),
          description:    _descriptionController.text.trim(),
          price:          double.parse(_priceController.text.trim()),
          category:       _selectedCategory,
          imageUrls:      imageUrls,
          videoUrls:      [],
          condition:      _selectedCondition.toLowerCase().replaceAll(' ', '-'),
          phoneNumber:    _phoneController.text.trim(),
          whatsappNumber: _whatsappController.text.trim(),
          location:       _locationController.text.trim(),
          createdAt:      DateTime.now(),
        );
        await FirebaseFirestore.instance
            .collection(AppConstants.productsCollection)
            .doc(id)
            .set(product.toMap());
      }

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.isService ? "Service" : "Product"} posted successfully!'),
          backgroundColor: AppColors.successGreen,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() { _isLoading = false; _uploadProgress = 0.0; });
    }
  }

  // ── Full-text error dialog ───────────────────────────────────────────────────
  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: SingleChildScrollView(
          child: SelectableText(message, style: const TextStyle(fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text(
          widget.isService ? 'Add Service' : 'Add Product',
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

            // Progress indicator
            if (_isLoading) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Uploading… ${(_uploadProgress * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: AppColors.lightGrey,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            _buildImageSection(),
            const SizedBox(height: 24),

            _field(controller: _titleController,       label: 'Title',          hint: widget.isService ? 'e.g., Math Tutoring' : 'e.g., iPhone 12 Pro'),
            const SizedBox(height: 16),
            _dropdown(label: 'Category', value: _selectedCategory, items: widget.isService ? _serviceCategories : _productCategories, onChanged: (v) => setState(() => _selectedCategory = v!)),
            const SizedBox(height: 16),
            if (!widget.isService) ...[
              _dropdown(label: 'Condition', value: _selectedCondition, items: _conditions, onChanged: (v) => setState(() => _selectedCondition = v!)),
              const SizedBox(height: 16),
            ],
            _field(controller: _priceController, label: 'Price (₦)', hint: '0.00', keyboard: TextInputType.number,
              validator: (v) { if (v!.isEmpty) return 'Required'; if (double.tryParse(v) == null) return 'Must be a number'; return null; }),
            const SizedBox(height: 16),
            _field(controller: _descriptionController, label: 'Description', hint: 'Describe your ${widget.isService ? "service" : "product"}', maxLines: 4),
            const SizedBox(height: 16),
            _field(controller: _locationController,    label: 'Location',    hint: 'e.g., Campus Area, Hostel Name'),
            const SizedBox(height: 16),
            _field(controller: _phoneController,       label: 'Phone Number',    hint: '08012345678', keyboard: TextInputType.phone),
            const SizedBox(height: 16),
            _field(controller: _whatsappController,    label: 'WhatsApp Number', hint: '08012345678', keyboard: TextInputType.phone),
            const SizedBox(height: 32),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                      )
                    : Text('Submit', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Image picker section ─────────────────────────────────────────────────────
  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Images', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              Text('${_selectedImages.length}/10', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Images are auto-resized and compressed to ~300 KB on the server.',
            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.grey),
          ),
          const SizedBox(height: 12),

          // Thumbnails
          if (_selectedImages.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, i) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.lightGrey,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _selectedImages[i].path,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                              _selectedImages[i].path,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image, color: AppColors.grey),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4, right: 12,
                        child: GestureDetector(
                          onTap: () => _removeImage(i),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: AppColors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _selectedImages.length < 10 ? _pickImages : null,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text('Add Images (max 10)', style: GoogleFonts.poppins(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable text field ──────────────────────────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboard,
          validator: validator ?? (v) => v!.isEmpty ? 'Required' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: AppColors.grey),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
          ),
        ),
      ],
    );
  }

  // ── Reusable dropdown ────────────────────────────────────────────────────────
  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor)),
          ),
        ),
      ],
    );
  }
}