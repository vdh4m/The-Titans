import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../utils/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _picker  = ImagePicker();
  final _ctrl    = TextEditingController();
  File?  _image;
  bool   _scanning = false;
  bool   _editMode = false;
  String _status   = '';
  String _script   = 'latin';   // 'latin' or 'chinese' — Arabic uses latin recognizer

  static const _scripts = [
    ('latin',   '🔤 Latin / Arabic / Devanagari'),
    ('chinese', '🀄 Chinese / Japanese / Korean'),
  ];

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _scan(ImageSource src) async {
    try {
      final picked = await _picker.pickImage(
          source: src, imageQuality: 92, maxWidth: 2048);
      if (picked == null) return;

      setState(() { _image = File(picked.path); _scanning = true;
          _status = 'Recognizing text...'; _ctrl.text = ''; });

      final inputImage = InputImage.fromFilePath(picked.path);

      // Choose recognizer script
      final script = _script == 'chinese'
          ? TextRecognitionScript.chinese
          : TextRecognitionScript.latin;

      final recognizer = TextRecognizer(script: script);
      final result     = await recognizer.processImage(inputImage);
      await recognizer.close();

      // Build text preserving paragraph breaks
      final text = result.blocks.map((b) =>
          b.lines.map((l) => l.text).join('\n')
      ).join('\n\n');

      if (mounted) {
        setState(() {
        _ctrl.text = text.isEmpty ? '⚠️ No text found in image.' : text;
        _scanning  = false;
        _editMode  = false;
        _status    = text.isEmpty
            ? 'No text detected'
            : '✅ ${result.blocks.length} blocks · '
              '${text.split(' ').length} words';
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _scanning = false;
        _status   = '❌ Error: $e';
      });
      }
    }
  }

  void _copy() {
    if (_ctrl.text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _ctrl.text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ Text copied'),
      backgroundColor: Color(0xFF06D6A0),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _savePdf() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _status = 'Building PDF...');
    try {
      final dir  = await Directory.systemTemp.createTemp('scan_');
      final path = '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await _writePdf(path, _ctrl.text);
      setState(() => _status = '✅ PDF saved');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('PDF: $path'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      setState(() => _status = '❌ PDF error: $e');
    }
  }

  Future<void> _writePdf(String path, String text) async {
    // Minimal valid PDF (text only, no external package)
    final lines = text.split('\n');
    final buf   = StringBuffer()
      ..writeln('BT /F1 11 Tf 40 760 Td 14 TL');
    for (final line in lines) {
      final safe = line
          .replaceAll(r'\', r'\\')
          .replaceAll('(', r'\(')
          .replaceAll(')', r'\)')
          .replaceAll('\r', '');
      buf.writeln('($safe) Tj T*');
    }
    buf.writeln('ET');
    final stream      = buf.toString();
    final streamLen   = stream.length;
    final pdfContent  = '''%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/MediaBox[0 0 595 842]/Parent 2 0 R/Resources<</Font<</F1 4 0 R>>>>>>endobj
4 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj
5 0 obj<</Length $streamLen>>
stream
$stream
endstream endobj
xref 0 6
0000000000 65535 f 
trailer<</Size 6/Root 1 0 R>>
startxref 9
%%EOF''';
    await File(path).writeAsString(pdfContent);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('📷 Scanner',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_ctrl.text.isNotEmpty && !_scanning) ...[
            IconButton(
              icon: Icon(_editMode ? Icons.check_rounded : Icons.edit_rounded,
                  color: AppTheme.primaryColor),
              onPressed: () => setState(() => _editMode = !_editMode),
            ),
            IconButton(
                icon: const Icon(Icons.copy_rounded),
                onPressed: _copy),
            IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.red),
                onPressed: _savePdf),
          ],
        ],
      ),
      body: Column(children: [
        // ── Source buttons ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(children: [
            Expanded(child: _SrcBtn(
              icon: Icons.camera_alt_rounded,
              label: 'Camera',
              sub: 'Scan board / book',
              color: AppTheme.primaryColor,
              onTap: () => _scan(ImageSource.camera),
            )),
            const SizedBox(width: 10),
            Expanded(child: _SrcBtn(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              sub: 'From photos',
              color: const Color(0xFF7209B7),
              onTap: () => _scan(ImageSource.gallery),
            )),
          ]),
        ),

        // ── Script selector ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            const Icon(Icons.language_rounded, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            const Text('Script:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _script,
                isExpanded: true,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                items: _scripts.map((s) => DropdownMenuItem(
                    value: s.$1, child: Text(s.$2))).toList(),
                onChanged: (v) => setState(() => _script = v!),
              ),
            )),
          ]),
        ),

        // ── Status ──────────────────────────────────────────────────
        if (_status.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _status.startsWith('❌')
                  ? Colors.red.withOpacity(0.08)
                  : AppTheme.primaryColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_status,
                style: TextStyle(fontSize: 12,
                    color: _status.startsWith('❌') ? Colors.red
                        : AppTheme.primaryColor,
                    fontWeight: FontWeight.w600)),
          ),

        // ── Content ─────────────────────────────────────────────────
        Expanded(child: _scanning
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Scanning...', style: TextStyle(fontWeight: FontWeight.w600)),
            ]))
          : _image == null
            ? _EmptyState()
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Image thumbnail
                Container(
                  width: 110,
                  margin: const EdgeInsets.fromLTRB(12, 4, 6, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_image!, fit: BoxFit.cover),
                  ),
                ),
                // Text result
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(6, 4, 12, 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1730) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2)),
                    ),
                    child: _editMode
                      ? TextField(
                          controller: _ctrl,
                          maxLines: null, expands: true,
                          style: const TextStyle(fontSize: 13, height: 1.5),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(12),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            _ctrl.text,
                            style: const TextStyle(fontSize: 13, height: 1.6),
                          ),
                        ),
                  ),
                ),
              ]),
        ),
      ]),
    );
  }
}

class _SrcBtn extends StatelessWidget {
  final IconData icon; final String label, sub; final Color color;
  final VoidCallback onTap;
  const _SrcBtn({required this.icon, required this.label, required this.sub,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1730) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1),
              blurRadius: 8, offset: const Offset(0,3))],
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800,
              color: color, fontSize: 13)),
          Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('📷', style: TextStyle(fontSize: 72)),
      const SizedBox(height: 16),
      const Text('Scan Any Text', style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 20)),
      const SizedBox(height: 8),
      Text(
        'Supports: English, Arabic, French,\nChinese, Japanese, and more.',
        style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
        textAlign: TextAlign.center,
      ),
    ]),
  ));
}