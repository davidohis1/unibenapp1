import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class MediaUploadResult {
  final String url;
  final String thumbnailUrl;
  final String type;
  final int size;
   
  MediaUploadResult({
    required this.url,
    required this.thumbnailUrl,
    required this.type,
    required num size,
  }): size = size.round();
}

class StorageService {
  /// Base URL for your PHP backend
  static const String baseUrl = 'http://davidohiwerei.name.ng/school';
  final Uuid _uuid = const Uuid();
  final String _storageZone = 'avidapp';
  final String _accessKey = '9c20f2f7-50a4-4526-8d2140f42b48-d46c-407e';
  final String _pullZoneUrl = 'https://avidapp1.b-cdn.net';
  final String _uploadUrl = 'https://jh.storage.bunnycdn.com';

  // Bunny Stream Configuration
  final String _streamLibraryId = '602877';
  final String _streamApiKey = '28115edf-4126-4a00-ab434e572e09-846d-48df';
  final String _streamCdnHostname = 'vz-9a97561f-3a0.b-cdn.net'; // e.g. vz-xxxxxx.b-


  /// Upload multiple media files (images/videos) using XFile
  
  /// Upload single media file from XFile
  Future<MediaUploadResult?> uploadMediaFromXFile(
  XFile file,
  String folder, {
  required String type,
}) async {
  try {
    final bytes = await file.readAsBytes();

    if (type == 'video') {
      // Use Bunny Stream for videos
      // Step 1: Create video object
      final createResponse = await http.post(
        Uri.parse('https://video.bunnycdn.com/library/$_streamLibraryId/videos'),
        headers: {
          'AccessKey': _streamApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'title': file.name}),
      );

      if (createResponse.statusCode != 200) {
        throw Exception('Failed to create video: ${createResponse.body}');
      }

      final videoId = jsonDecode(createResponse.body)['guid'];

      // Step 2: Upload video bytes
      final uploadResponse = await http.put(
        Uri.parse(
          'https://video.bunnycdn.com/library/$_streamLibraryId/videos/$videoId',
        ),
        headers: {
          'AccessKey': _streamApiKey,
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );

      if (uploadResponse.statusCode != 200) {
        throw Exception('Failed to upload video: ${uploadResponse.body}');
      }

      // Return embed URL for storage, direct URL for playback
      final videoUrl =
          'https://$_streamCdnHostname/$videoId/play_720p.mp4';
      return MediaUploadResult(
        url: videoUrl,
        thumbnailUrl: 'https://video.bunnycdn.com/$_streamLibraryId/$videoId/thumbnail.jpg',
        type: 'video',
        size: bytes.length,
      );
    } else {
      // Use Bunny Storage for images/audio
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${file.name}';
      final path = '$folder/$fileName';
      final url = '$_uploadUrl/$_storageZone/$path';

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'AccessKey': _accessKey,
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );

      if (response.statusCode != 201) {
        throw Exception('Upload failed: ${response.body}');
      }

      final cdnUrl = '$_pullZoneUrl/$path';
      return MediaUploadResult(
        url: cdnUrl,
        thumbnailUrl: cdnUrl, // same URL for images, no separate thumbnail
        type: type,
        size: bytes.length,
      );
    }
  } catch (e) {
    print('Error uploading media: $e');
    rethrow;
  }
}

Future<List<MediaUploadResult>> uploadMultipleMedia(
  List<XFile> files,
  String folder, {
  List<String>? types, // keep it nullable to match existing signature
}) async {
  final results = <MediaUploadResult>[];
  for (int i = 0; i < files.length; i++) {
    // fallback to 'image' if types is null
    final type = types != null ? types[i] : 'image';
    final result = await uploadMediaFromXFile(
      files[i],
      folder,
      type: type,
    );
    if (result != null) results.add(result);
  }
  return results;
}

  /// Backwards-compatible: Upload from File list
  Future<List<MediaUploadResult>> uploadMediaFromFiles(
    List<File> files,
    String folder, {
    List<String>? types,
  }) async {
    final xfiles = files.map((f) => XFile(f.path)).toList();
    return await uploadMultipleMedia(xfiles, folder, types: types);
  }

  /// Backwards-compatible: Upload single File
  Future<MediaUploadResult?> uploadMedia(
    File file,
    String folder, {
    String type = 'image',
  }) async {
    final xfile = XFile(file.path);
    return await uploadMediaFromXFile(xfile, folder, type: type);
  }

  /// Backwards-compatible: Upload images only (for existing code)
  Future<List<String>> uploadImages(List<File> files, String folder) async {
    final results = await uploadMediaFromFiles(files, folder, types: List.filled(files.length, 'image'));
    return results.map((result) => result.url).toList();
  }

  /// Backwards-compatible: Upload single image
  Future<String?> uploadImage(File file, String folder) async {
    final result = await uploadMedia(file, folder, type: 'image');
    return result?.url;
  }

  /// Upload videos only
  Future<List<String>> uploadVideos(List<File> files, String folder) async {
    final results = await uploadMediaFromFiles(files, folder, types: List.filled(files.length, 'video'));
    return results.map((result) => result.url).toList();
  }

  /// Upload single video
  Future<String?> uploadVideo(File file, String folder) async {
    final result = await uploadMedia(file, folder, type: 'video');
    return result?.url;
  }

  /// Helper: Get media type from filename
  String _getMediaTypeFromName(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'wmv', 'flv'];
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    
    if (videoExtensions.contains(ext)) return 'video';
    if (imageExtensions.contains(ext)) return 'image';
    return 'file';
  }

  /// Helper: Get content type for HTTP header
  MediaType _getContentType(String type, String extension) {
    switch (type) {
      case 'video':
        switch (extension) {
          case 'mp4': return MediaType('video', 'mp4');
          case 'mov': return MediaType('video', 'quicktime');
          case 'avi': return MediaType('video', 'avi');
          default: return MediaType('video', 'video');
        }
      case 'audio':
        switch (extension) {
          case 'mp3': return MediaType('audio', 'mpeg');
          case 'wav': return MediaType('audio', 'wav');
          default: return MediaType('audio', 'audio');
        }
      case 'image':
      default:
        switch (extension) {
          case 'png': return MediaType('image', 'png');
          case 'gif': return MediaType('image', 'gif');
          case 'webp': return MediaType('image', 'webp');
          default: return MediaType('image', 'jpeg');
        }
    }
  }

  /// Generate thumbnail for local video file (mobile only)
  Future<String?> generateVideoThumbnail(String videoPath) async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 360,
        quality: 75,
      );
      return thumbnail;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Delete media from server
  Future<bool> deleteMedia(String url) async {
    try {
      // Extract filename from URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length < 3) {
        print('Invalid URL format for deletion: $url');
        return false;
      }

      // Get folder and filename
      final folder = pathSegments[pathSegments.length - 2];
      final filename = pathSegments.last;
      
      // Send delete request to PHP backend
      final response = await http.post(
        Uri.parse('$baseUrl/delete_media.php'),
        body: {
          'action': 'delete_media',
          'folder': folder,
          'filename': filename,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['success'] == true;
      }
      
      return false;
    } catch (e) {
      print('Error deleting media: $e');
      return false;
    }
  }

  /// Delete multiple media files
  Future<void> deleteMultipleMedia(List<String> urls) async {
    for (final url in urls) {
      try {
        await deleteMedia(url);
      } catch (e) {
        print('Error deleting media $url: $e');
      }
    }
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