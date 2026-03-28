import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../constants/app_constants.dart';
import '../../../models/course_material_model.dart';
import '../../../services/course_service.dart';

import '../../../screens/more/ai_study_assistant_screen.dart'; // Adjust path as needed
import '../../../services/firebase_service.dart';
import 'package:firebase_core/firebase_core.dart';

class ViewMaterialScreen extends StatefulWidget {
  final CourseMaterialModel material;

  const ViewMaterialScreen({
    Key? key,
    required this.material,
  }) : super(key: key);

  @override
  State<ViewMaterialScreen> createState() => _ViewMaterialScreenState();
}

class _ViewMaterialScreenState extends State<ViewMaterialScreen> {
  final CourseService _courseService = CourseService();
  late PageController _pageController;
  int _currentPage = 0;

  // Carousel indicators
  Map<String, int> _currentCarouselIndex = {};

  // PDF state
  bool _isDownloading = false;
  double _downloadProgress = 0;
  File? _localPdfFile;        // offline-downloaded file (app-private)
  File? _localStoragePdfFile; // user-picked file from device storage
  bool _isLoadingPdf = true;

  // Syncfusion controller
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _courseService.incrementDownloadCount(widget.material.id);
    _currentCarouselIndex[widget.material.id] = 0;

    if (widget.material.fileType == 'pdf') {
      _checkOfflinePdf();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pdfViewerController.dispose();
    super.dispose();
  }

Future<bool> _hasExistingSummaries() async {
  try {
    await Firebase.initializeApp();
    final firebaseService = FirebaseService();
    final summaries = await firebaseService.getSummariesForPdf(widget.material.fileUrls.first).first;
    return summaries.isNotEmpty;
  } catch (e) {
    print('Error checking summaries: $e');
    return false;
  }
}
  // ─── Offline PDF helpers ───────────────────────────────────────────────────

  /// Returns the app-private path for this PDF (never appears in gallery/Files)
  Future<String> _getOfflinePdfPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = widget.material.title.replaceAll(RegExp(r'[^\w]'), '_');
    return '${dir.path}/offline_pdfs/${widget.material.id}_$safeTitle.pdf';
  }

  /// Check if the PDF has already been saved offline
  Future<void> _checkOfflinePdf() async {
    final path = await _getOfflinePdfPath();
    final file = File(path);
    if (await file.exists()) {
      setState(() {
        _localPdfFile = file;
        _isLoadingPdf = false;
      });
    } else {
      setState(() => _isLoadingPdf = false);
    }
  }

  /// Download PDF from Bunny CDN and store in app-private storage
  Future<void> _downloadForOffline() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final url = widget.material.fileUrls.first;
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (contentLength > 0) {
          setState(() {
            _downloadProgress = bytes.length / contentLength;
          });
        }
      }

      // Save to app-private directory
      final path = await _getOfflinePdfPath();
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);

      setState(() {
        _localPdfFile = file;
        _isDownloading = false;
        _downloadProgress = 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved for offline reading!'),
            backgroundColor: AppColors.primaryPurple,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Delete the offline copy
  Future<void> _deleteOfflineCopy() async {
    if (_localPdfFile == null) return;
    await _localPdfFile!.delete();
    setState(() => _localPdfFile = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offline copy removed.'),
          backgroundColor: Colors.grey[700],
        ),
      );
    }
  }

  /// Let the user pick a PDF from local storage
  Future<void> _pickLocalPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        setState(() => _localStoragePdfFile = File(path));
      }
    }
  }

  // ─── Material info dialog ──────────────────────────────────────────────────

  void _showMaterialInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: Text('Material Info',
            style: GoogleFonts.poppins(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Title', widget.material.title),
            _buildInfoRow('Type',
                widget.material.type.toString().split('.').last),
            _buildInfoRow('Uploaded by', widget.material.uploaderName),
            _buildInfoRow('Date', _formatDate(widget.material.uploadedAt)),
            _buildInfoRow('Downloads', '${widget.material.downloadCount}'),
            _buildInfoRow('Likes', '${widget.material.likeCount}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: GoogleFonts.poppins(color: AppColors.primaryPurple)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: GoogleFonts.poppins(
                    color: Colors.white70, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes} minutes ago';
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          // If user opened a local-storage PDF, show that name instead
          _localStoragePdfFile != null
              ? _localStoragePdfFile!.path.split('/').last
              : widget.material.title,
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
  // AI Summary Button - Only show for PDFs
  if (widget.material.fileType == 'pdf' && _localStoragePdfFile == null)
    FutureBuilder<bool>(
      future: _hasExistingSummaries(),
      builder: (context, snapshot) {
        final hasSummaries = snapshot.data == true;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                Icons.auto_awesome,
                color: hasSummaries ? AppColors.primaryPurple : Colors.white70,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AIStudyAssistantScreen(
                      initialPdfUrl: widget.material.fileUrls.first,
                      pdfTitle: widget.material.title,
                    ),
                  ),
                );
              },
              tooltip: hasSummaries ? 'View AI Summary (Saved)' : 'AI Summarize',
            ),
            if (hasSummaries)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  
  // Info button
  if (_localStoragePdfFile == null)
    IconButton(
      icon: Icon(Icons.info_outline, color: Colors.white70),
      onPressed: _showMaterialInfo,
    ),
],
      ),
      body: widget.material.fileType == 'pdf'
          ? _buildPDFViewer()
          : _buildImageViewer(),
    );
  }

  // ─── PDF Viewer ────────────────────────────────────────────────────────────

  Widget _buildPDFViewer() {
    return Column(
      children: [
        _buildPdfTopBar(),
        if (_isDownloading) _buildDownloadProgress(),
        Expanded(child: _buildPdfContent()),
      ],
    );
  }

  /// Top bar with offline download button + "open local PDF" button
  Widget _buildPdfTopBar() {
    return Container(
      color: Color(0xFF1A1A1A),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Offline status chip
          if (_localPdfFile != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.offline_pin, color: Colors.green, size: 14),
                  SizedBox(width: 4),
                  Text('Available offline',
                      style: GoogleFonts.poppins(
                          color: Colors.green, fontSize: 11)),
                ],
              ),
            ),

          Spacer(),

          // Open local PDF from storage
          TextButton.icon(
            onPressed: _pickLocalPdf,
            icon: Icon(Icons.folder_open,
                color: Colors.white70, size: 18),
            label: Text('Open from storage',
                style: GoogleFonts.poppins(
                    color: Colors.white70, fontSize: 12)),
          ),

          SizedBox(width: 8),

          // Download / Delete offline button
          if (_localStoragePdfFile == null) ...[
            if (_localPdfFile == null)
              IconButton(
                tooltip: 'Save for offline',
                icon: Icon(
                  _isDownloading
                      ? Icons.hourglass_bottom
                      : Icons.download_for_offline_outlined,
                  color: AppColors.primaryPurple,
                ),
                onPressed: _isDownloading ? null : _downloadForOffline,
              )
            else
              IconButton(
                tooltip: 'Remove offline copy',
                icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                onPressed: _deleteOfflineCopy,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadProgress() {
    return Container(
      color: Color(0xFF111111),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Downloading… ${(_downloadProgress * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
          SizedBox(height: 4),
          LinearProgressIndicator(
            value: _downloadProgress,
            backgroundColor: Colors.white12,
            valueColor:
                AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfContent() {
    if (_isLoadingPdf) {
      return Center(
          child:
              CircularProgressIndicator(color: AppColors.primaryPurple));
    }

    // Priority: local-storage pick > offline saved > network stream
    if (_localStoragePdfFile != null) {
      return _buildSyncfusionFile(_localStoragePdfFile!);
    }

    if (_localPdfFile != null) {
      return _buildSyncfusionFile(_localPdfFile!);
    }

    // Stream from Bunny CDN
    return _buildSyncfusionNetwork(widget.material.fileUrls.first);
  }

  Widget _buildSyncfusionFile(File file) {
    return SfPdfViewer.file(
      file,
      controller: _pdfViewerController,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        _showPdfError(details.error);
      },
    );
  }

  Widget _buildSyncfusionNetwork(String url) {
    return SfPdfViewer.network(
      url,
      controller: _pdfViewerController,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        _showPdfError(details.error);
      },
    );
  }

  void _showPdfError(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error loading PDF: $error'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Image Viewer (unchanged logic) ───────────────────────────────────────

  Widget _buildImageViewer() {
    if (widget.material.fileUrls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 80, color: Colors.white54),
            SizedBox(height: 16),
            Text('No images available',
                style: GoogleFonts.poppins(
                    color: Colors.white70, fontSize: 16)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.material.fileUrls.length,
          onPageChanged: (index) {
            setState(() {
              _currentCarouselIndex[widget.material.id] = index;
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            final imageUrl = widget.material.fileUrls[index];
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              boundaryMargin: EdgeInsets.all(20),
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                            color: AppColors.primaryPurple),
                        SizedBox(height: 12),
                        Text('Loading image...',
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image,
                            size: 60, color: Colors.white54),
                        SizedBox(height: 12),
                        Text('Failed to load image',
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 14)),
                        SizedBox(height: 8),
                        Text('URL: $imageUrl',
                            style: GoogleFonts.poppins(
                                color: Colors.white38, fontSize: 10),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Dots indicator
        if (widget.material.fileUrls.length > 1)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.material.fileUrls.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentCarouselIndex[widget.material.id] == index
                        ? AppColors.primaryPurple
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),

        // Page counter
        if (widget.material.fileUrls.length > 1)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primaryPurple.withOpacity(0.3)),
              ),
              child: Text(
                '${_currentCarouselIndex[widget.material.id]! + 1}/${widget.material.fileUrls.length}',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),

        // Zoom hint
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Text('Pinch to zoom',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}