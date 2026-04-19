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

class QuizGeneratorScreen extends StatefulWidget {
  const QuizGeneratorScreen({super.key});
  @override State<QuizGeneratorScreen> createState() => _QuizGeneratorScreenState();
}

class _QuizGeneratorScreenState extends State<QuizGeneratorScreen> {
  static const _apiKey = 'AIzaSyBFYmfZC_D-4vwigPrOM0MiPYYEZb4UdBM';

  List<Map<String, dynamic>> _questions = [];
  int _currentQ = 0;
  int? _selectedAnswer;
  int _score = 0;
  bool _showResult = false;
  bool _loading = false;
  String? _sourceName;
  bool _useCourse = true;

  Future<void> _generate(Uint8List pdfBytes, String sourceName) async {
    final isAr = context.read<AppProvider>().isArabic;
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && !PaywallGate.canAccess(user, PremiumFeature.unlimitedAi)) {
      PaywallGate.showUpgradeSheet(context, feature: PremiumFeature.unlimitedAi);
      return;
    }
    setState(() { _loading = true; _questions = []; _sourceName = sourceName; });

    final base64Pdf = base64Encode(pdfBytes);
    final prompt = isAr
      ? 'من هذا المستند، اعمل 10 أسئلة اختيار من متعدد (MCQ) بـ 4 خيارات لكل سؤال. استخدم اللغة العربية. أجب بـ JSON فقط بدون أي نص آخر: [{"question":"...","options":["أ","ب","ج","د"],"correct":0}]'
      : 'From this document, generate 10 multiple choice questions with 4 options each. Use English. Return ONLY a JSON array, no extra text: [{"question":"...","options":["A","B","C","D"],"correct":0}]';

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [
          {'inline_data': {'mime_type': 'application/pdf', 'data': base64Pdf}},
          {'text': prompt},
        ]}], 'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 2048}}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        var text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '[]';
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();
        final questions = List<Map<String, dynamic>>.from(jsonDecode(text));
        setState(() { _questions = questions; _loading = false; _currentQ = 0; _score = 0; _showResult = false; _selectedAnswer = null; });
      } else { setState(() => _loading = false); }
    } catch (e) { setState(() => _loading = false); }
  }

  Future<void> _pickFile() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && !PaywallGate.canAccess(user, PremiumFeature.unlimitedAi)) {
      PaywallGate.showUpgradeSheet(context, feature: PremiumFeature.unlimitedAi);
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    await _generate(result.files.single.bytes!, result.files.single.name);
  }

  void _answer(int i) {
    if (_selectedAnswer != null) return;
    final correct = _questions[_currentQ]['correct'] as int? ?? 0;
    setState(() {
      _selectedAnswer = i;
      if (i == correct) _score++;
    });
  }

  void _next() {
    if (_currentQ < _questions.length - 1) {
      setState(() { _currentQ++; _selectedAnswer = null; });
    } else {
      setState(() => _showResult = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    final theme = Theme.of(context);

    if (_showResult) {
      final pct = (_score / _questions.length * 100).round();
      final color = pct >= 80 ? const Color(0xFF06D6A0) : pct >= 60 ? const Color(0xFFFF9F1C) : Colors.red;
      return Scaffold(
        appBar: AppBar(title: Text(isAr ? 'نتيجتك' : 'Your Score')),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 120, height: 120, decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]), shape: BoxShape.circle),
            child: Center(child: Text('$pct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)))),
          const SizedBox(height: 16),
          Text('$_score / ${_questions.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 8),
          Text(pct >= 80 ? (isAr ? '🎉 ممتاز!' : '🎉 Excellent!') : pct >= 60 ? (isAr ? '💪 جيد، استمر' : '💪 Good, keep going') : (isAr ? '📚 راجع أكتر' : '📚 Study more'),
            style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() { _questions = []; _showResult = false; _score = 0; _currentQ = 0; }),
            icon: const Icon(Icons.replay_rounded),
            label: Text(isAr ? 'كويز جديد' : 'New Quiz'),
          ),
        ])),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'مولّد الكويز' : 'Quiz Generator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Header
          Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7209B7), AppTheme.primaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const Text('🎯', style: TextStyle(fontSize: 40)),
              Text(isAr ? 'مولّد الكويز بالـ AI' : 'AI Quiz Generator',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              Text(isAr ? 'اعمل كويز من مواد كورساتك' : 'Generate quiz from your course materials',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          const SizedBox(height: 20),

          if (_questions.isEmpty) ...[
            // Source toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _useCourse = true),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: _useCourse ? AppTheme.primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                    child: Text(isAr ? '📚 من الكورسات' : '📚 From Courses',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _useCourse ? Colors.white : Colors.grey, fontWeight: FontWeight.w700, fontSize: 12))),
                )),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _useCourse = false),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: !_useCourse ? AppTheme.primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                    child: Text(isAr ? '📁 رفع ملف' : '📁 Upload File',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: !_useCourse ? Colors.white : Colors.grey, fontWeight: FontWeight.w700, fontSize: 12))),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            if (_useCourse)
              CourseMaterialPicker(onPdfSelected: (bytes, course, mat) => _generate(bytes, '$course — $mat'))
            else
              GestureDetector(
                onTap: _loading ? null : _pickFile,
                child: Container(width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), style: BorderStyle.solid)),
                  child: const Column(children: [
                    Icon(Icons.upload_file_rounded, color: AppTheme.primaryColor, size: 36),
                    SizedBox(height: 8),
                    Text('Tap to select a PDF', textAlign: TextAlign.center),
                  ])),
              ),

            if (_loading) ...[
              const SizedBox(height: 24),
              const Center(child: Column(children: [
                CircularProgressIndicator(color: AppTheme.primaryColor),
                SizedBox(height: 12),
                Text('Generating quiz...'),
              ])),
            ],
          ] else ...[
            // Quiz in progress
            if (_sourceName != null)
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_sourceName!, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  Text('${_currentQ + 1}/${_questions.length}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.primaryColor)),
                ])),
            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentQ + 1) / _questions.length,
                backgroundColor: Colors.grey.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor), minHeight: 6)),
            const SizedBox(height: 20),

            // Question
            Container(width: double.infinity, padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2))),
              child: Text(_questions[_currentQ]['question'] ?? '',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.5))),
            const SizedBox(height: 16),

            // Options
            ...(_questions[_currentQ]['options'] as List? ?? []).asMap().entries.map((e) {
              final i = e.key; final opt = e.value as String;
              final correct = _questions[_currentQ]['correct'] as int? ?? 0;
              Color? bg; Color? border;
              if (_selectedAnswer != null) {
                if (i == correct) { bg = const Color(0xFF06D6A0).withOpacity(0.1); border = const Color(0xFF06D6A0); }
                else if (i == _selectedAnswer && i != correct) { bg = Colors.red.withOpacity(0.08); border = Colors.red; }
              }
              return GestureDetector(
                onTap: () => _answer(i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: bg ?? theme.cardTheme.color, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border ?? Colors.grey.withOpacity(0.2), width: border != null ? 2 : 1)),
                  child: Row(children: [
                    Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle,
                      color: (border ?? Colors.grey).withOpacity(0.1)),
                      child: Center(child: Text(String.fromCharCode(65 + i),
                        style: TextStyle(fontWeight: FontWeight.w800, color: border ?? Colors.grey)))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(opt, style: const TextStyle(fontWeight: FontWeight.w500))),
                    if (_selectedAnswer != null && i == correct) const Icon(Icons.check_circle_rounded, color: Color(0xFF06D6A0)),
                    if (_selectedAnswer != null && i == _selectedAnswer && i != correct) const Icon(Icons.cancel_rounded, color: Colors.red),
                  ]),
                ),
              );
            }),

            if (_selectedAnswer != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _next,
                icon: Icon(_currentQ < _questions.length - 1 ? Icons.arrow_forward_rounded : Icons.check_rounded),
                label: Text(_currentQ < _questions.length - 1 ? (isAr ? 'التالي' : 'Next') : (isAr ? 'إنهاء' : 'Finish')),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ],
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}
