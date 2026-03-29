import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ImageUploadService {
  // Bunny.net Configuration
  final String _storageZone = 'unibenmeet';
  final String _accessKey = '8dc7a526-d5de-43cc-baac55789bab-2fae-46c8';
  final String _pullZoneUrl = 'https://unibenmeet.b-cdn.net';
  final String _uploadUrl = 'https://uk.storage.bunnycdn.com';

  /// Upload images directly to Bunny.net
  Future<List<String>> uploadXFiles(List<XFile> xfiles, String folder) async {
    if (xfiles.isEmpty) throw Exception('No images selected');

    List<String> uploadedUrls = [];
    List<String> errors = [];

    for (int i = 0; i < xfiles.length; i++) {
      try {
        final xfile = xfiles[i];
        
        // Read bytes
        final Uint8List bytes = await xfile.readAsBytes();
        
        // Generate unique filename
        final ext = xfile.name.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${i}_${xfile.name}';
        final uploadPath = '/$folder/$fileName';
        
        // Upload to Bunny.net
        final uploadResponse = await http.put(
          Uri.parse('$_uploadUrl/$_storageZone$uploadPath'),
          headers: {
            'AccessKey': _accessKey,
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        );

        if (uploadResponse.statusCode == 201) {
          // Success - add the public URL
          final publicUrl = '$_pullZoneUrl$uploadPath';
          uploadedUrls.add(publicUrl);
          debugPrint('[Bunny] Uploaded: $publicUrl');
        } else {
          errors.add('Failed to upload ${xfile.name}: HTTP ${uploadResponse.statusCode}');
          debugPrint('[Bunny] Upload failed: ${uploadResponse.statusCode} - ${uploadResponse.body}');
        }
      } catch (e) {
        errors.add('Error uploading ${xfiles[i].name}: $e');
        debugPrint('[Bunny] Error: $e');
      }
    }

    if (uploadedUrls.isEmpty) {
      throw Exception('No images were uploaded successfully.\nErrors: ${errors.join('\n')}');
    }

    if (errors.isNotEmpty) {
      debugPrint('[Bunny] Partial errors: $errors');
    }

    return uploadedUrls;
  }

  /// Backwards-compatible wrapper that accepts a list of `File` objects.
  Future<List<String>> uploadImages(List<File> files, String folder) async {
    final xfiles = files.map((f) => XFile(f.path)).toList();
    return await uploadXFiles(xfiles, folder);
  }

  /// Optional: Delete an image from Bunny.net
  Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(imageUrl);
      final path = uri.path; // This gives /folder/filename.jpg
      
      final response = await http.delete(
        Uri.parse('$_uploadUrl/$_storageZone$path'),
        headers: {
          'AccessKey': _accessKey,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Bunny] Delete error: $e');
      return false;
    }
  }
}