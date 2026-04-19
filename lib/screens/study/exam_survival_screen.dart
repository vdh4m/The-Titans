import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
// ignore: unused_import
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/course_material_picker.dart';

class ExamSurvivalScreen extends StatefulWidget {
  const ExamSurvivalScreen({super.key});
  @override State<ExamSurvivalScreen> createState() => _ExamSurvivalScreenState();
}

class _ExamSurvivalScreenState extends State<ExamSurvivalScreen> {
  static const _apiKey = 'AIzaSyBFYmfZC_D-4vwigPrOM0MiPYYEZb4UdBM';
  Map<String, dynamic>? _survivalData;
  bool _loading = false;
  String? _selectedCourse;

  Future<void> _generateFromMaterial(Uint8List pdfBytes, String courseTitle, String matTitle) async {
    setState(() { _loading = true; _survivalData = null; _selectedCourse = courseTitle; });
    final isAr = context.read<AppProvider>().isArabic;

    final prompt = isAr
      ? '''أنت مساعد مذاكرة. الطالب امتحانه في مادة "$courseTitle" بعد 24 ساعة.
المستند المرفق هو مادة الامتحان.
استخرج منه بالتنسيق JSON فقط بدون backticks:
{
  "top10": ["أهم نقطة 1", "نقطة 2", ...10 نقاط أهم مفاهيم من المستند],
  "likely_questions": ["سؤال محتمل 1", "سؤال محتمل 2", ...5 أسئلة],
  "formulas": ["معادلة 1", "معادلة 2", ...أهم معادلات أو قوانين إن وجدت],
  "avoid_mistakes": ["خطأ شائع 1", "خطأ شائع 2", ...3 أخطاء شائعة],
  "last_advice": "نصيحة أخيرة للطالب قبل الامتحان"
}'''
      : '''You are a study assistant. The student has an exam in "$courseTitle" in 24 hours.
The attached document is the exam material.
Extract from it ONLY JSON no backticks:
{
  "top10": ["Point 1", "Point 2", ...10 most important concepts from the document],
  "likely_questions": ["Q1", "Q2", ...5 likely exam questions],
  "formulas": ["formula 1", ...key formulas or rules if any],
  "avoid_mistakes": ["Mistake 1", "Mistake 2", ...3 common mistakes],
  "last_advice": "Final advice for the student"
}''';

    try {
      final base64Pdf = base64Encode(pdfBytes);
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [
          {'inline_data': {'mime_type': 'application/pdf', 'data': base64Pdf}},
          {'text': prompt},
        ]}], 'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 2000}}),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        var text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '{}';
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();
        setState(() { _survivalData = jsonDecode(text); _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🚨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(isAr ? 'وضع الطوارئ' : 'Exam Survival', style: const TextStyle(color: Colors.white)),
        ]),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: _survivalData != null ? [
          TextButton.icon(
            onPressed: () => setState(() { _survivalData = null; _selectedCourse = null; }),
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white54),
            label: Text(isAr ? 'جديد' : 'New', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ] : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Header
          Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.red, Color(0xFFFF6B35)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(isAr ? 'باقي 24 ساعة على الامتحان!' : '24 Hours to Exam!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
              Text(isAr ? 'اختار المادة وهيعمل لك كل اللي تحتاجه' : 'Select your course material — AI does the rest',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ])),
          const SizedBox(height: 20),

          if (_survivalData == null) ...[
            // Course material picker
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3))),
              child: CourseMaterialPicker(
                onPdfSelected: _generateFromMaterial,
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 24),
              const Center(child: Column(children: [
                CircularProgressIndicator(color: Colors.red),
                SizedBox(height: 12),
                Text('AI is preparing your survival kit...', style: TextStyle(color: Colors.white54)),
              ])),
            ],
          ] else ...[
            // Course badge
            if (_selectedCourse != null) ...[
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.book_outlined, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selectedCourse!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis)),
                ])),
              const SizedBox(height: 16),
            ],

            _SurvivalSection(emoji: '🎯', color: Colors.red,
              title: isAr ? 'أهم 10 نقاط' : 'Top 10 Must-Know',
              items: List<String>.from(_survivalData!['top10'] ?? []), numbered: true),
            const SizedBox(height: 16),
            _SurvivalSection(emoji: '❓', color: const Color(0xFFFF9F1C),
              title: isAr ? 'أسئلة محتملة' : 'Likely Questions',
              items: List<String>.from(_survivalData!['likely_questions'] ?? []), numbered: false),
            const SizedBox(height: 16),
            if ((_survivalData!['formulas'] as List?)?.isNotEmpty == true)
              _SurvivalSection(emoji: '🔢', color: AppTheme.primaryColor,
                title: isAr ? 'معادلات أساسية' : 'Key Formulas',
                items: List<String>.from(_survivalData!['formulas'] ?? []), numbered: false, isFormula: true),
            const SizedBox(height: 16),
            _SurvivalSection(emoji: '⚠️', color: Colors.orange,
              title: isAr ? 'أخطاء شائعة اتجنبها' : 'Common Mistakes to Avoid',
              items: List<String>.from(_survivalData!['avoid_mistakes'] ?? []), numbered: false),
            const SizedBox(height: 16),
            Container(width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF06D6A0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF06D6A0).withOpacity(0.4), width: 1.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('💚', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(isAr ? 'نصيحة أخيرة' : 'Last Advice',
                    style: const TextStyle(color: Color(0xFF06D6A0), fontWeight: FontWeight.w800, fontSize: 15)),
                ]),
                const SizedBox(height: 10),
                Text(_survivalData!['last_advice'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6)),
              ])),
          ],
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class _SurvivalSection extends StatelessWidget {
  final String emoji, title; final Color color;
  final List<String> items; final bool numbered; final bool isFormula;
  const _SurvivalSection({required this.emoji, required this.title, required this.color,
    required this.items, required this.numbered, this.isFormula = false});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
      ]),
      const SizedBox(height: 12),
      ...items.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (numbered)
            Container(width: 24, height: 24, margin: const EdgeInsets.only(right: 10, top: 1),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))))
          else
            Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 10, top: 8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          Expanded(child: isFormula
            ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(e.value, style: TextStyle(color: color, fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 13)))
            : Text(e.value, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5))),
        ]),
      )),
    ]),
  );
}
