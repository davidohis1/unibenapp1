import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import '../../constants/app_constants.dart';
import '../../services/post_service.dart';
import '../../services/storageservice.dart';
import 'dart:async';

class CreatePostScreen extends StatefulWidget {
  final VoidCallback? onPostCreated;

  const CreatePostScreen({Key? key, this.onPostCreated}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final PostService _postService = PostService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  List<XFile> _selectedMedia = [];
  List<String> _mediaTypes = []; // 'image' or 'video'
  List<String> _selectedTags = [];
  bool _isAnonymous = false;
  bool _isLoading = false;
  html.File? _selectedAudioWeb;
  File? _selectedAudioMobile;
  VideoPlayerController? _videoPreviewController;
  AudioPlayer? _audioPreviewPlayer;
  bool _isVideoPlaying = false;
  bool _isAudioPlaying = false;

  bool get _isWeb => kIsWeb; // Check if running on web

  @override
  void initState() {
    super.initState();
    _audioPreviewPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagsController.dispose();
    _videoPreviewController?.dispose();
    _audioPreviewPlayer?.dispose();
    super.dispose();
  }

  Future<void> _toggleAudioPlayback() async {
  if (_isWeb) {
    // Audio playback not supported on web
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audio playback not supported on web')),
    );
    return;
  }

  if (_selectedAudioMobile == null) return;

  setState(() {
    if (_isAudioPlaying) {
      _audioPreviewPlayer?.pause();
      _isAudioPlaying = false;
    } else {
      try {
        _audioPreviewPlayer?.play(DeviceFileSource(_selectedAudioMobile!.path));
        _isAudioPlaying = true;
      } catch (e) {
        print('Error playing audio: $e');
        _isAudioPlaying = false;
      }
    }
  });
}

  Future<void> _pickMedia() async {
    try {
      final result = await showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    Icon(Icons.photo_library, color: AppColors.primaryPurple),
                title: Text('Pick Photos'),
                onTap: () {
                  Navigator.pop(context, 'photos');
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam, color: AppColors.primaryPurple),
                title: Text('Pick Video'),
                onTap: () {
                  Navigator.pop(context, 'video');
                },
              ),
              if (!_isWeb) // Audio picker doesn't work well on web
                ListTile(
                  leading:
                      Icon(Icons.audio_file, color: AppColors.primaryPurple),
                  title: Text('Pick Audio'),
                  onTap: () {
                    Navigator.pop(context, 'audio');
                  },
                ),
            ],
          ),
        ),
      );

      if (result == 'photos') {
        await _pickImages();
      } else if (result == 'video') {
        await _pickVideo();
      } else if (result == 'audio' && !_isWeb) {
        await _pickAudio();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
  if (_isWeb) {
    // Web implementation
    final html.InputElement input = html.InputElement(type: 'file')
      ..accept = 'image/*'
      ..multiple = true;

    input.click();

    await input.onChange.first;

    if (input.files != null && input.files!.isNotEmpty) {
      if (_selectedMedia.length + input.files!.length > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 media items allowed')),
        );
        return;
      }

      final newFiles = <XFile>[];
      final newTypes = <String>[];

      for (final file in input.files!) {
        // Check file size (50MB limit for web)
        if (file.size > 50 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name} exceeds 50MB limit')),
          );
          continue;
        }

        // FIX: Create XFile directly from web file
        try {
          // Read file as bytes using FileReader
          final reader = html.FileReader();
          final completer = Completer<Uint8List>();
          
          reader.onLoad.listen((event) {
            try {
              // FIX: Handle both ByteBuffer and ArrayBufferView
              dynamic result = reader.result;
              Uint8List bytes;
              
              if (result is ByteBuffer) {
                bytes = Uint8List.view(result);
              } else if (result is Uint8List) {
                bytes = result;
              } else if (result is List<int>) {
                bytes = Uint8List.fromList(result);
              } else {
                // Try to convert any result to bytes
                bytes = Uint8List.fromList(List<int>.from(result as List));
              }
              
              completer.complete(bytes);
            } catch (e) {
              completer.completeError(e);
            }
          });
          
          reader.onError.listen((event) {
            completer.completeError(Exception('Failed to read file'));
          });
          
          reader.readAsArrayBuffer(file);
          final bytes = await completer.future;

          // Create XFile from bytes
          final xfile = XFile.fromData(
            bytes,
            name: file.name,
            mimeType: file.type,
            length: bytes.length,
          );

          newFiles.add(xfile);
          newTypes.add('image');
        } catch (e) {
          print('Error processing file ${file.name}: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to process ${file.name}')),
          );
        }
      }

      if (newFiles.isNotEmpty) {
        setState(() {
          _selectedMedia.addAll(newFiles);
          _mediaTypes.addAll(newTypes);
        });
      }
    }
  } else {
    // Mobile implementation (unchanged)
    final List<XFile>? images = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );

    if (images != null && images.isNotEmpty) {
      if (_selectedMedia.length + images.length > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 media items allowed')),
        );
        return;
      }

      setState(() {
        _selectedMedia.addAll(images);
        _mediaTypes.addAll(List.filled(images.length, 'image'));
      });
    }
  }
}

  Future<void> _pickVideo() async {
  if (_isWeb) {
    // Web implementation
    final html.InputElement input = html.InputElement(type: 'file')
      ..accept = 'video/*';

    input.click();

    await input.onChange.first;

    if (input.files != null && input.files!.isNotEmpty) {
      final file = input.files!.first;

      // Check file size (50MB limit)
      if (file.size > 50 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video must be less than 50MB')),
        );
        return;
      }

      // FIX: Create XFile from web file
      try {
        final reader = html.FileReader();
        final completer = Completer<Uint8List>();
        
        reader.onLoad.listen((event) {
          try {
            dynamic result = reader.result;
            Uint8List bytes;
            
            if (result is ByteBuffer) {
              bytes = Uint8List.view(result);
            } else if (result is Uint8List) {
              bytes = result;
            } else {
              bytes = Uint8List.fromList(List<int>.from(result as List));
            }
            
            completer.complete(bytes);
          } catch (e) {
            completer.completeError(e);
          }
        });
        
        reader.onError.listen((event) {
          completer.completeError(Exception('Failed to read video file'));
        });
        
        reader.readAsArrayBuffer(file);
        final bytes = await completer.future;

        final xfile = XFile.fromData(
          bytes,
          name: file.name,
          mimeType: file.type,
          length: bytes.length,
        );

        setState(() {
          _selectedMedia.add(xfile);
          _mediaTypes.add('video');
        });
      } catch (e) {
        print('Error processing video: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process video file')),
        );
      }
    }
  } else {
    // Mobile implementation (unchanged)
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: Duration(seconds: 60),
    );

    if (video != null) {
      // Check file size (50MB limit)
      final file = File(video.path);
      final size = await file.length();
      if (size > 50 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video must be less than 50MB')),
        );
        return;
      }

      setState(() {
        _selectedMedia.add(video);
        _mediaTypes.add('video');
      });
    }
  }
}

  Future<void> _pickAudio() async {
    if (_isWeb) {
      // Audio doesn't work well on web, skip for now
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio upload not supported on web')),
      );
      return;
    } else {
      // Mobile implementation
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final size = await file.length();

        if (size > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio must be less than 10MB')),
          );
          return;
        }

        setState(() {
          _selectedAudioMobile = file;
        });
      }
    }
  }

  Future<List<File>> _convertXFilesToFiles(List<XFile> xfiles) async {
    final files = <File>[];

    for (final xfile in xfiles) {
      if (_isWeb) {
        // For web, we need to handle file differently
        // Since we can't create File from XFile on web,
        // we'll pass the bytes directly to upload
        final bytes = await xfile.readAsBytes();
        // Create a temporary file or handle differently
        // For now, we'll skip this conversion
        continue;
      } else {
        files.add(File(xfile.path));
      }
    }

    return files;
  }

  Future<void> _createPost() async {
  if (_contentController.text.trim().isEmpty && _selectedMedia.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post cannot be empty')),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    List<String> mediaUrls = [];
    List<String> mediaTypes = [];

    // Upload media if any - FIXED: Handle MediaUploadResult
    if (_selectedMedia.isNotEmpty) {
      print('Uploading ${_selectedMedia.length} media files...');
      
      // This returns List<MediaUploadResult>
      final List<MediaUploadResult> results = await _storageService.uploadMultipleMedia(
        _selectedMedia,  // Already XFile list
        'posts',
        types: _mediaTypes,
      );

      for (var result in results) {
        mediaUrls.add(result.url);
        mediaTypes.add(result.type);
        print('Uploaded: ${result.url} (${result.type})');
      }
    }

    // Upload audio if selected (mobile only)
    String? audioUrl;
    if (_selectedAudioMobile != null && !_isWeb) {
      try {
        final xfile = XFile(_selectedAudioMobile!.path);
        final audioResult = await _storageService.uploadMediaFromXFile(
          xfile,
          'audios',
          type: 'audio',
        );
        audioUrl = audioResult?.url;
        print('Audio uploaded: $audioUrl');
      } catch (e) {
        print('Error uploading audio: $e');
      }
    }

    // Create post
    if (mediaUrls.isNotEmpty || _contentController.text.trim().isNotEmpty) {
      await _postService.createPost(
        content: _contentController.text.trim(),
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
        audioUrl: audioUrl,
        tags: _selectedTags,
        isAnonymous: _isAnonymous,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        if (widget.onPostCreated != null) {
          widget.onPostCreated!();
        }

        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add content or media')),
      );
    }
  } catch (e) {
    print('Error creating post: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
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

  void _removeMedia(int index) {
    if (_mediaTypes[index] == 'video') {
      _videoPreviewController?.dispose();
      _videoPreviewController = null;
      _isVideoPlaying = false;
    }

    setState(() {
      _selectedMedia.removeAt(index);
      _mediaTypes.removeAt(index);
    });
  }

  void _removeAudio() {
    setState(() {
      if (_isWeb) {
        _selectedAudioWeb = null;
      } else {
        _selectedAudioMobile = null;
      }
      _isAudioPlaying = false;
    });
  }

  void _addTag() {
    final tag = _tagsController.text.trim();
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _tagsController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
  }

  Widget _buildMediaPreview() {
    if (_selectedMedia.isEmpty) return SizedBox.shrink();

    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedMedia.length,
        itemBuilder: (context, index) {
          final media = _selectedMedia[index];
          final type = _mediaTypes[index];

          return Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                margin: EdgeInsets.only(right: 10, bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.lightGrey,
                ),
                child: type == 'video'
                    ? Center(
                        child: Icon(Icons.videocam,
                            size: 40, color: AppColors.grey),
                      )
                    : FutureBuilder<Uint8List>(
                        future: media.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                            );
                          }
                          return Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryPurple,
                            ),
                          );
                        },
                      ),
              ),
              Positioned(
                top: 4,
                right: 14,
                child: GestureDetector(
                  onTap: () => _removeMedia(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
              if (type == 'video')
                Positioned(
                  bottom: 15,
                  left: 10,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.videocam, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Video',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAudioPreview() {
    if ((_isWeb && _selectedAudioWeb == null) ||
        (!_isWeb && _selectedAudioMobile == null)) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.lightPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              // Audio playback not implemented for web
              if (!_isWeb) {
                _toggleAudioPlayback();
              }
            },
            icon: Icon(
              _isAudioPlaying ? Icons.pause : Icons.play_arrow,
              color: AppColors.primaryPurple,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio File',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _isWeb
                      ? '${_selectedAudioWeb!.size / 1024 / 1024} MB'
                      : '${(_selectedAudioMobile!.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _removeAudio,
            icon: Icon(Icons.close, color: AppColors.errorRed),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._selectedTags.map((tag) {
              return Chip(
                label: Text('#$tag'),
                onDeleted: () => _removeTag(tag),
                deleteIconColor: AppColors.primaryPurple,
              );
            }).toList(),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _tagsController,
                decoration: InputDecoration(
                  hintText: 'Add tag...',
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.lightGrey,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text('Create Post',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: Icon(_isLoading ? Icons.hourglass_bottom : Icons.send),
            onPressed: _isLoading ? null : _createPost,
            tooltip: 'Post',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content
            TextField(
              controller: _contentController,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.all(16),
              ),
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            SizedBox(height: 20),

            // Media Preview
            if (_selectedMedia.isNotEmpty) ...[
              Text(
                'Media (${_selectedMedia.length}/10)',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 10),
              _buildMediaPreview(),
              SizedBox(height: 20),
            ],

            // Audio Preview
            if ((_isWeb && _selectedAudioWeb != null) ||
                (!_isWeb && _selectedAudioMobile != null)) ...[
              _buildAudioPreview(),
              SizedBox(height: 20),
            ],

            // Tags
            _buildTagsInput(),
            SizedBox(height: 20),

            // Options
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.add_photo_alternate,
                        color: AppColors.primaryPurple),
                    title: Text('Add Media', style: GoogleFonts.poppins()),
                    subtitle: Text(
                      _isWeb ? 'Photos or Videos' : 'Photos, Videos, or Audio',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.grey),
                    ),
                    onTap: _pickMedia,
                    enabled: !_isLoading,
                  ),
                  SwitchListTile(
                    title:
                        Text('Post Anonymously', style: GoogleFonts.poppins()),
                    subtitle: Text('Your name and avatar will be hidden',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.grey)),
                    value: _isAnonymous,
                    onChanged: _isLoading
                        ? null
                        : (value) => setState(() => _isAnonymous = value),
                    activeColor: AppColors.primaryPurple,
                  ),
                ],
              ),
            ),

            // File size warning
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Maximum file size: 50MB per video, 10MB per audio\nVideos longer than 60 seconds will be trimmed',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Web-specific warning
            if (_isWeb)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Note: Audio upload is not supported on web. Please use the mobile app for audio posts.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
