import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class StorageService {
  // Bunny.net Configuration
  final String _storageZone = 'unibenmeet';
  final String _accessKey = '8dc7a526-d5de-43cc-baac55789bab-2fae-46c8';
  final String _pullZoneUrl = 'https://unibenmeet.b-cdn.net';
  final String _uploadUrl = 'https://uk.storage.bunnycdn.com';

  /// Upload images directly to Bunny.net
  Future<List<String>> uploadImages(List<File> files, String folder) async {
    if (files.isEmpty) throw Exception('No images selected');

    List<String> uploadedUrls = [];
    List<String> errors = [];

    for (int i = 0; i < files.length; i++) {
      try {
        final file = files[i];
        
        // Read bytes
        final Uint8List bytes = await file.readAsBytes();
        
        // Generate unique filename
        final ext = file.path.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${i}.$ext';
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
          print('[Bunny] Uploaded: $publicUrl');
        } else {
          errors.add('Failed to upload ${file.path}: HTTP ${uploadResponse.statusCode}');
          print('[Bunny] Upload failed: ${uploadResponse.statusCode} - ${uploadResponse.body}');
        }
      } catch (e) {
        errors.add('Error uploading ${files[i].path}: $e');
        print('[Bunny] Error: $e');
      }
    }

    if (uploadedUrls.isEmpty) {
      throw Exception('No images were uploaded successfully.\nErrors: ${errors.join('\n')}');
    }

    return uploadedUrls;
  }

  /// Upload videos (same as images for Bunny.net)
  Future<List<String>> uploadVideos(List<File> files, String folder) async {
    return uploadImages(files, folder); // Same method works for videos
  }

  /// Delete file from Bunny.net
  Future<void> deleteFile(String url) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(url);
      final path = uri.path; // This gives /folder/filename.jpg
      
      final response = await http.delete(
        Uri.parse('$_uploadUrl/$_storageZone$path'),
        headers: {
          'AccessKey': _accessKey,
        },
      );

      if (response.statusCode != 200) {
        print('[Bunny] Delete failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[Bunny] Delete error: $e');
    }
  }

  // Keep for backward compatibility
  Future<void> deleteMedia(String url) async {
    return deleteFile(url);
  }

  // Single image upload (for backward compatibility)
  Future<String?> uploadImage(File file, String folder) async {
    try {
      final urls = await uploadImages([file], folder);
      return urls.isNotEmpty ? urls.first : null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Single video upload (for backward compatibility)
  Future<String?> uploadVideo(File file, String folder) async {
    return uploadImage(file, folder);
  }

  /// Upload XFiles directly (for web compatibility)
Future<List<String>> uploadXFiles(List<XFile> xfiles, String folder) async {
  if (xfiles.isEmpty) throw Exception('No images selected');

  List<String> uploadedUrls = [];
  List<String> errors = [];

  for (int i = 0; i < xfiles.length; i++) {
    try {
      final xfile = xfiles[i];
      
      // Read bytes (works on web too!)
      final Uint8List bytes = await xfile.readAsBytes();
      
      // Generate unique filename
      final ext = xfile.name.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${i}.$ext';
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
        final publicUrl = '$_pullZoneUrl$uploadPath';
        uploadedUrls.add(publicUrl);
        print('[Bunny] Uploaded: $publicUrl');
      } else {
        errors.add('Failed to upload ${xfile.name}: HTTP ${uploadResponse.statusCode}');
      }
    } catch (e) {
      errors.add('Error uploading ${xfiles[i].name}: $e');
    }
  }

  if (uploadedUrls.isEmpty) {
    throw Exception('No images were uploaded successfully.\nErrors: ${errors.join('\n')}');
  }

  return uploadedUrls;
}
}