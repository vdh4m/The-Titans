// ignore_for_file: unused_import

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/course_material_picker.dart';

class MockExamScreen extends StatefulWidget {
  const MockExamScreen({super.key});
  @override State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  static const _apiKey = 'AIzaSyAZZa9NXGiAV4JCnlFT96juU37cMWPj9ko';
  List<Map<String, dynamic>> _questions = [];
  bool _loading = false, _examStarted = false, _examFinished = false;
  int _current = 0, _score = 0;
  List<int?> _answers = [];
  int _numQuestions = 10;
  bool _useCourse = true;
  // ignore: unused_field
  String? _sourceName;

  Future<void> _generateFromMaterial(Uint8List pdfBytes, String courseTitle, String matTitle) async {
    final isAr = context.read<AppProvider>().isArabic;
    setState(() { _loading = true; _questions = []; _sourceName = '$courseTitle — $matTitle'; });

    final base64Pdf = base64Encode(pdfBytes);
    final prompt = isAr
      ? '''من هذا المستند، اعمل امتحان تجريبي بـ $_numQuestions سؤال اختيار متعدد بصعوبة متدرجة من سهل لصعب. استخدم اللغة العربية.
أجب بـ JSON فقط بدون backticks:
[{"q":"السؤال","options":["أ","ب","ج","د"],"correct":0,"explanation":"شرح الإجابة","difficulty":"easy|medium|hard"}]'''
      : '''From this document, create a mock exam with $_numQuestions multiple choice questions of gradually increasing difficulty. Use English.
Return ONLY JSON no backticks:
[{"q":"question","options":["A","B","C","D"],"correct":0,"explanation":"answer explanation","difficulty":"easy|medium|hard"}]''';

    try {
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [
          {'inline_data': {'mime_type': 'application/pdf', 'data': base64Pdf}},
          {'text': prompt},
        ]}], 'generationConfig': {'temperature': 0.5, 'maxOutputTokens': 4000}}),
      ).timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        var text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '[]';
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();
        final qs = List<Map<String, dynamic>>.from(jsonDecode(text));
        setState(() { _questions = qs; _answers = List.filled(qs.length, null); _loading = false; _examStarted = true; });
      } else { setState(() => _loading = false); }
    } catch (e) { setState(() => _loading = false); }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    await _generateFromMaterial(result.files.single.bytes!, result.files.single.name, '');
  }

  void _submitExam() {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i]['correct']) score++;
    }
    setState(() { _score = score; _examFinished = true; });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    if (_examFinished) return _ResultScreen(isAr: isAr, score: _score, total: _questions.length, questions: _questions, answers: _answers, onRetry: () => setState(() { _examFinished = false; _examStarted = false; _questions = []; _answers = []; _current = 0; }));
    if (_examStarted && _questions.isNotEmpty) return _ExamView(isAr: isAr, questions: _questions, answers: _answers, current: _current, onAnswer: (i) => setState(() { _answers[_current] = i; if (_current < _questions.length - 1) _current++; }), onNext: () { if (_current < _questions.length - 1) setState(() => _current++); }, onPrev: () { if (_current > 0) setState(() => _current--); }, onSubmit: _submitExam);

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'امتحان تجريبي AI' : 'AI Mock Exam')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7209B7), AppTheme.primaryColor],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.psychology, color: Colors.white, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAr ? 'امتحان تجريبي ذكي' : 'Smart Mock Exam',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                Text(isAr ? 'الـ AI يعمل امتحان من مادتك الفعلية' : 'AI generates an exam from your actual course material',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ])),
          const SizedBox(height: 24),

          // Number of questions
          Row(children: [
            Text(isAr ? 'عدد الأسئلة:' : 'Questions:', style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            ...([5, 10, 15, 20]).map((n) => GestureDetector(
              onTap: () => setState(() => _numQuestions = n),
              child: Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: _numQuestions == n ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('$n', style: TextStyle(fontWeight: FontWeight.w700, color: _numQuestions == n ? Colors.white : AppTheme.primaryColor))),
            )),
          ]),
          const SizedBox(height: 20),

          // Source toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(14)),
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
            CourseMaterialPicker(
              onPdfSelected: _generateFromMaterial,
              actionLabel: 'Start Exam',
              actionLabelAr: 'ابدأ الامتحان',
              actionIcon: Icons.play_circle_filled_rounded,
            )
          else
            GestureDetector(
              onTap: _loading ? null : _pickFile,
              child: Container(width: double.infinity, padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3))),
                child: Column(children: [
                  const Icon(Icons.upload_file_rounded, color: AppTheme.primaryColor, size: 36),
                  const SizedBox(height: 8),
                  Text(isAr ? 'اضغط لاختيار ملف PDF' : 'Tap to select a PDF', textAlign: TextAlign.center),
                ])),
            ),

          if (_loading) ...[  
            const SizedBox(height: 24),
            const Center(child: Column(children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 12),
              Text('Preparing exam...'),
            ])),
          ],
        ]),
      ),
    );
  }
}

class _ExamView extends StatelessWidget {
  final bool isAr; final List<Map<String, dynamic>> questions; final List<int?> answers;
  final int current; final Function(int) onAnswer; final VoidCallback onNext, onPrev, onSubmit;
  const _ExamView({required this.isAr, required this.questions, required this.answers, required this.current, required this.onAnswer, required this.onNext, required this.onPrev, required this.onSubmit});
  @override
  Widget build(BuildContext context) {
    final q = questions[current];
    final answered = answers[current];
    final diffColor = q['difficulty'] == 'easy' ? const Color(0xFF06D6A0) : q['difficulty'] == 'medium' ? const Color(0xFFFF9F1C) : Colors.red;

    return Scaffold(
      appBar: AppBar(title: Text('${current + 1} / ${questions.length}'), actions: [
        TextButton(onPressed: onSubmit, child: Text(isAr ? 'تسليم' : 'Submit', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800))),
      ]),
      body: Column(children: [
        // Progress
        LinearProgressIndicator(value: (current + 1) / questions.length, backgroundColor: Colors.grey.withOpacity(0.1), valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor), minHeight: 4),
        // Answered count
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Theme.of(context).cardTheme.color,
          child: Row(children: [
            ...questions.asMap().entries.map((e) => Expanded(child: Container(
              height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2),
                color: e.key == current ? AppTheme.primaryColor : answers[e.key] != null ? const Color(0xFF06D6A0) : Colors.grey.withOpacity(0.2))))),
          ])),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: diffColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(q['difficulty'] as String? ?? '', style: TextStyle(color: diffColor, fontSize: 11, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(14)),
              child: Text(q['q'] as String? ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.5))),
            const SizedBox(height: 16),
            ...((q['options'] as List?) ?? []).asMap().entries.map((e) {
              final isSelected = answered == e.key;
              return GestureDetector(
                onTap: () => onAnswer(e.key),
                child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.withOpacity(0.2), width: isSelected ? 2 : 1)),
                  child: Row(children: [
                    Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.08)),
                      child: Center(child: Text(String.fromCharCode(65 + e.key),
                        style: TextStyle(fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppTheme.primaryColor, fontSize: 12)))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(e.value as String, style: const TextStyle(fontWeight: FontWeight.w500))),
                  ])),
              );
            }),
          ]),
        )),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (current > 0) OutlinedButton.icon(onPressed: onPrev, icon: const Icon(Icons.arrow_back_ios_rounded, size: 14), label: Text(isAr ? 'السابق' : 'Prev'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(100, 44))),
            const Spacer(),
            if (current < questions.length - 1)
              ElevatedButton.icon(onPressed: onNext, icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14), label: Text(isAr ? 'التالي' : 'Next'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)))
            else
              ElevatedButton.icon(onPressed: onSubmit, icon: const Icon(Icons.check_rounded), label: Text(isAr ? 'تسليم الامتحان' : 'Submit Exam'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(160, 44), backgroundColor: const Color(0xFF06D6A0))),
          ]),
        ),
      ]),
    );
  }
}

class _ResultScreen extends StatelessWidget {
  final bool isAr; final int score, total; final List<Map<String, dynamic>> questions;
  final List<int?> answers; final VoidCallback onRetry;
  const _ResultScreen({required this.isAr, required this.score, required this.total, required this.questions, required this.answers, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (score / total * 100).round() : 0;
    final grade = pct >= 90 ? 'A' : pct >= 80 ? 'B' : pct >= 70 ? 'C' : pct >= 60 ? 'D' : 'F';
    final gradeColor = pct >= 80 ? const Color(0xFF06D6A0) : pct >= 60 ? const Color(0xFFFF9F1C) : Colors.red;
    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'نتيجة الامتحان' : 'Exam Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [gradeColor, gradeColor.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24)),
            child: Column(children: [
              Text(grade, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 64)),
              Text('$score / $total  ($pct%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
              Text(pct >= 80 ? (isAr ? 'ممتاز! 🎉' : 'Excellent! 🎉') : pct >= 60 ? (isAr ? 'جيد، استمر 💪' : 'Good, keep going 💪') : (isAr ? 'تحتاج مراجعة أكتر 📚' : 'Needs more review 📚'),
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ])),
          const SizedBox(height: 20),
          // Questions review
          ...questions.asMap().entries.map((e) {
            final q = e.value; final userAns = answers[e.key]; final correct = q['correct'] as int? ?? 0;
            final isCorrect = userAns == correct;
            return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: isCorrect ? const Color(0xFF06D6A0).withOpacity(0.06) : Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14), border: Border.all(color: isCorrect ? const Color(0xFF06D6A0).withOpacity(0.3) : Colors.red.withOpacity(0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isCorrect ? const Color(0xFF06D6A0) : Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text('${isAr ? 'سؤال' : 'Q'} ${e.key + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
                const SizedBox(height: 6),
                Text(q['q'] as String? ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 8),
                Text('${isAr ? 'الإجابة الصحيحة:' : 'Correct:'} ${(q['options'] as List?)?[correct] ?? ''}',
                  style: const TextStyle(color: Color(0xFF06D6A0), fontWeight: FontWeight.w600, fontSize: 12)),
                if ((q['explanation'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(q['explanation'] as String, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontStyle: FontStyle.italic)),
                ],
              ]));
          }),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.replay_rounded), label: Text(isAr ? 'امتحان جديد' : 'New Exam'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 60),
        ]),
      ),
    );
  }
}
