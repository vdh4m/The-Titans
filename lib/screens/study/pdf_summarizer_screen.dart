import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/course_material_picker.dart';
import '../payment/paywall_gate.dart';

class PdfSummarizerScreen extends StatefulWidget {
  const PdfSummarizerScreen({super.key});
  @override State<PdfSummarizerScreen> createState() => _PdfSummarizerScreenState();
}

class _PdfSummarizerScreenState extends State<PdfSummarizerScreen> {
  static const _apiKey = 'AIzaSyBFYmfZC_D-4vwigPrOM0MiPYYEZb4UdBM';

  String? _fileName;
  String? _summary;
  bool _loading = false;
  String? _error;
  String _summaryType = 'full';
  bool _useCourse = true; // toggle: course vs file picker
  // ignore: unused_field
  Uint8List? _pdfBytes;

  Future<void> _summarize(Uint8List pdfBytes, String fileName) async {
    final isAr = context.read<AppProvider>().isArabic;
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && !PaywallGate.canAccess(user, PremiumFeature.unlimitedAi)) {
      PaywallGate.showUpgradeSheet(context, feature: PremiumFeature.unlimitedAi);
      return;
    }
    setState(() { _error = null; _summary = null; _fileName = fileName; _loading = true; });

    final promptMap = {
      'full':    isAr
        ? 'لخص هذا المستند بشكل شامل ومنظم بالنقاط الرئيسية والتفاصيل المهمة. استخدم اللغة العربية.'
        : 'Provide a comprehensive structured summary with main points and important details. Use English.',
      'bullets': isAr
        ? 'لخص هذا المستند في نقاط مختصرة وواضحة. استخدم اللغة العربية.'
        : 'Summarize this document in clear bullet points. Use English.',
      'exam':    isAr
        ? 'استخرج أهم النقاط للمراجعة قبل الامتحان من هذا المستند. استخدم اللغة العربية.'
        : 'Extract the most important exam revision points from this document. Use English.',
    };

    try {
      final base64Pdf = base64Encode(pdfBytes);
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey',
      );
      final response = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [
          {'inline_data': {'mime_type': 'application/pdf', 'data': base64Pdf}},
          {'text': promptMap[_summaryType]},
        ]}], 'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 2048}}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        setState(() { _summary = text; _loading = false; });
      } else {
        setState(() { _error = 'Error ${response.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickFile() async {
    // ignore: unused_local_variable
    final isAr = context.read<AppProvider>().isArabic;
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && !PaywallGate.canAccess(user, PremiumFeature.unlimitedAi)) {
      PaywallGate.showUpgradeSheet(context, feature: PremiumFeature.unlimitedAi);
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    _pdfBytes = file.bytes;
    await _summarize(file.bytes!, file.name);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    // ignore: unused_local_variable
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('📖', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(isAr ? 'ملخص PDF' : 'PDF Summarizer', style: const TextStyle(color: Colors.white)),
        ]),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7209B7), AppTheme.primaryColor],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const Text('📖', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(isAr ? 'ملخص ذكي بالـ AI' : 'AI-Powered Summarizer',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              Text(isAr ? 'لخّص أي PDF من مواد كورساتك أو جهازك' : 'Summarize any PDF from your courses or device',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          const SizedBox(height: 20),

          // Summary type
          Text(isAr ? 'نوع الملخص' : 'Summary Type',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            _TypeChip(label: isAr ? 'شامل' : 'Full', value: 'full', selected: _summaryType,
              onTap: (v) => setState(() => _summaryType = v)),
            const SizedBox(width: 8),
            _TypeChip(label: isAr ? 'نقاط' : 'Bullets', value: 'bullets', selected: _summaryType,
              onTap: (v) => setState(() => _summaryType = v)),
            const SizedBox(width: 8),
            _TypeChip(label: isAr ? 'امتحان' : 'Exam', value: 'exam', selected: _summaryType,
              onTap: (v) => setState(() => _summaryType = v)),
          ]),
          const SizedBox(height: 20),

          // Source toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _useCourse = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _useCourse ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(isAr ? '📚 من الكورسات' : '📚 From Courses',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _useCourse ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              )),
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _useCourse = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_useCourse ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(isAr ? '📁 رفع ملف' : '📁 Upload File',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: !_useCourse ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              )),
            ]),
          ),
          const SizedBox(height: 20),

          // Source input
          if (_useCourse) ...[
            CourseMaterialPicker(
              onPdfSelected: (bytes, courseTitle, matTitle) {
                _pdfBytes = bytes;
                _summarize(bytes, '$courseTitle — $matTitle');
              },
            ),
            const SizedBox(height: 16),
          ] else ...[
            GestureDetector(
              onTap: _loading ? null : _pickFile,
              child: Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4), style: BorderStyle.solid)),
                child: Column(children: [
                  const Icon(Icons.upload_file_rounded, color: AppTheme.primaryColor, size: 36),
                  const SizedBox(height: 8),
                  Text(isAr ? 'اضغط لاختيار ملف PDF' : 'Tap to select a PDF',
                    style: const TextStyle(color: Colors.white70)),
                ])),
            ),
            const SizedBox(height: 16),
          ],

          // Loading
          if (_loading) ...[
            const Center(child: Column(children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 12),
              Text('AI is reading your document...', style: TextStyle(color: Colors.white54)),
            ])),
            const SizedBox(height: 20),
          ],

          // Error
          if (_error != null)
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: const TextStyle(color: Colors.red))),

          // Summary result
          if (_summary != null) ...[
            if (_fileName != null) ...[
              Row(children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(_fileName!, style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 12),
            ],
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2))),
              child: SelectableText(_summary!,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.7))),
          ],

          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label, value, selected;
  final ValueChanged<String> onTap;
  const _TypeChip({required this.label, required this.value, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onTap(value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected == value ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(
        color: selected == value ? Colors.white : AppTheme.primaryColor,
        fontWeight: FontWeight.w700, fontSize: 12)),
    ),
  );
}
