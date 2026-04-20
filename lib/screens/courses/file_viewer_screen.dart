import 'dart:typed_data';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../utils/app_theme.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// ─────────────────────────────────────────────────────────────────────────────
// FileViewerScreen — opens every file type INSIDE the app
// PDF      → SfPdfViewer.network (streams directly in-app)
// Image    → photo_view   (pinch-zoom, pan)
// Video    → chewie + video_player
// Doc/PPT  → webview_flutter via Google Docs Viewer (embedded in-app)
// ─────────────────────────────────────────────────────────────────────────────
class FileViewerScreen extends StatefulWidget {
  final String fileUrl;
  final String title;
  final String fileType;

  const FileViewerScreen({
    super.key,
    required this.fileUrl,
    required this.title,
    required this.fileType,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  _Phase _phase = _Phase.loading;
  String  _error = '';
  String? _iframeViewId;

  // viewers
  VideoPlayerController? _vCtrl;
  ChewieController?      _cCtrl;
  WebViewController?     _webCtrl;
  Uint8List?             _pdfBytes;

  // ── type helpers ─────────────────────────────────────────────────────────
  String get _ext => widget.fileType.toLowerCase().replaceAll('.', '');

  bool get _isPdf   => _ext == 'pdf';
  bool get _isImage => ['jpg','jpeg','png','gif','webp','bmp','heic'].contains(_ext);
  bool get _isVideo => ['mp4','mov','avi','mkv','webm','3gp','m4v'].contains(_ext);
  
  // Supabase public URLs are used directly — no URL manipulation needed.
  String get _cleanUrl => widget.fileUrl;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _cCtrl?.dispose();
    _vCtrl?.dispose();
    super.dispose();
  }

  // ── master dispatcher ────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() { _phase = _Phase.loading; _error = ''; _pdfBytes = null; });
    try {
      if (_isPdf) {
        if (kIsWeb) {
          // On web: register an iframe to embed PDF directly — bypasses CORS entirely.
          final viewId = 'pdf-iframe-${DateTime.now().millisecondsSinceEpoch}';
          // ignore: undefined_prefixed_name
          ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
            final iframe = html.IFrameElement()
              ..src = _cleanUrl
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%'
              ..allow = 'fullscreen';
            return iframe;
          });
          _iframeViewId = viewId;
          setState(() => _phase = _Phase.ready);
        } else {
          setState(() => _phase = _Phase.ready);
        }
      } else if (_isImage) { 
        setState(() => _phase = _Phase.ready); 
      } else if (_isVideo) { 
        await _initVideo(); 
      } else { 
        await _initWebViewDoc(); 
      }
    } catch (e) {
      if (mounted) setState(() { _phase = _Phase.error; _error = e.toString(); });
    }
  }

  Future<void> _initVideo() async {
    _vCtrl = VideoPlayerController.networkUrl(Uri.parse(_cleanUrl));
    await _vCtrl!.initialize();
    _cCtrl = ChewieController(
      videoPlayerController: _vCtrl!,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor:     AppTheme.primaryColor,
        handleColor:     AppTheme.primaryColor,
        backgroundColor: Colors.white24,
        bufferedColor:   AppTheme.primaryColor.withOpacity(0.35),
      ),
    );
    if (mounted) setState(() => _phase = _Phase.ready);
  }

  Future<void> _initWebViewDoc() async {
    final docUrl = 'https://docs.google.com/viewer?url=${Uri.encodeComponent(_cleanUrl)}&embedded=true';
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _phase = _Phase.ready);
        },
        onWebResourceError: (err) {
          if (mounted && err.isForMainFrame == true) {
             setState(() { _phase = _Phase.error; _error = 'Viewer connection failed'; });
          }
        },
      ))
      ..loadRequest(Uri.parse(docUrl));
    
    // We stay in loading until onPageFinished fires.
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isAr   = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgBlack = _isVideo || _isImage;

    return Scaffold(
      backgroundColor: bgBlack ? Colors.black : Colors.grey.shade100,
      extendBodyBehindAppBar: _isImage || _isVideo,
      appBar: AppBar(
        backgroundColor: bgBlack ? Colors.black54 : Colors.white,
        foregroundColor: bgBlack ? Colors.white : Colors.black87,
        elevation: bgBlack ? 0 : 1,
        title: Text(widget.title,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: bgBlack ? const TextStyle(color: Colors.white) : const TextStyle(color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          color: bgBlack ? Colors.white : Colors.black87,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: switch (_phase) {
        _Phase.loading => _LoadingBody(isAr: isAr),
        _Phase.error   => _ErrorBody(error: _error, onRetry: _load, isAr: isAr, fileUrl: widget.fileUrl),
        _Phase.ready   => _buildContent(isAr, isDark),
      },
    );
  }

  Widget _buildContent(bool isAr, bool isDark) {
    // ── PDF — stream directly via network (No download required) ────────────
    if (_isPdf) {
      // Web: embed PDF directly via iframe — no CORS, no bytes download needed.
      if (kIsWeb && _iframeViewId != null) {
        return HtmlElementView(viewType: _iframeViewId!);
      }
      // Native: stream directly from network
      return SfPdfViewer.network(
        _cleanUrl,
        canShowScrollHead: false,
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          if (mounted) {
            setState(() { _phase = _Phase.error; _error = details.error; });
          }
        },
      );
    }

    // ── Image ────────────────────────────────────────────────────────────
    if (_isImage) {
      return PhotoView(
        imageProvider: NetworkImage(_cleanUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, event) => Center(child: CircularProgressIndicator(
          value: event?.expectedTotalBytes != null
              ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
              : null,
          color: AppTheme.primaryColor,
        )),
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 72, color: Colors.white38),
        ),
      );
    }

    // ── Video ────────────────────────────────────────────────────────────
    if (_isVideo && _cCtrl != null) {
      return Container(
        color: Colors.black,
        child: Center(child: Chewie(controller: _cCtrl!)),
      );
    }

    // ── Documents (WebView) ──────────────────────────────────────────────
    if (_webCtrl != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _webCtrl!),
          // Google Docs viewer sometimes loads blank if network is slow, but we rely on onPageFinished
        ]
      );
    }

    return _ErrorBody(error: isAr ? 'نوع الملف غير معروف' : 'Unknown file type', onRetry: _load, isAr: isAr, fileUrl: widget.fileUrl);
  }
}

// ─── Loading Body ────────────────────────────────────────────────────────────
class _LoadingBody extends StatelessWidget {
  final bool isAr;
  const _LoadingBody({required this.isAr});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(40), child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor.withOpacity(0.15),
                       AppTheme.primaryColor.withOpacity(0.05)]),
            shape: BoxShape.circle,
          ),
          child: const Center(child: CircularProgressIndicator(
            color: AppTheme.primaryColor, strokeWidth: 3,
          )),
        ),
        const SizedBox(height: 24),
        Text(isAr ? 'جاري فتح الملف...' : 'Opening file...', 
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ],
    )),
  );
}

// ─── Error Body ──────────────────────────────────────────────────────────────
class _ErrorBody extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final bool isAr;
  final String fileUrl;
  const _ErrorBody({required this.error, required this.onRetry, required this.isAr, required this.fileUrl});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 88, height: 88,
          decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.error_outline_rounded, size: 44, color: Colors.red)),
        const SizedBox(height: 20),
        Text(isAr ? 'تعذر فتح الملف' : 'Could not open file',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        SelectableText(error.isEmpty ? 'Unknown Error' : error,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SelectableText('URL: $fileUrl',
              style: TextStyle(color: Colors.grey[500], fontSize: 9),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(180, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    )),
  );
}

enum _Phase { loading, ready, error }