import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
// ignore: unused_import
import '../../utils/app_theme.dart';
import '../../widgets/course_material_picker.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});
  @override State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  static const _apiKey = 'AIzaSyBFYmfZC_D-4vwigPrOM0MiPYYEZb4UdBM';
  Map<String, dynamic>? _challenge;
  bool _loading = false;
  int? _selected;
  bool _answered = false;
  bool _alreadyDoneToday = false;
  int _xpEarned = 0;
  bool _showPicker = false; // show material picker first time

  @override
  void initState() { super.initState(); _loadChallenge(); }

  Future<void> _loadChallenge() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('challenge_date');
    if (lastDate == today) {
      setState(() { _alreadyDoneToday = true; _xpEarned = prefs.getInt('challenge_xp') ?? 0; });
      return;
    }
    // Show picker
    setState(() => _showPicker = true);
  }

  Future<void> _generateFromMaterial(Uint8List pdfBytes, String courseTitle, String matTitle) async {
    final isAr = context.read<AppProvider>().isArabic;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    setState(() { _loading = true; _showPicker = false; });

    final base64Pdf = base64Encode(pdfBytes);
    final prompt = isAr
      ? 'من هذا المستند، اعمل سؤال اختيار متعدد واحد مناسب. استخدم اللغة العربية. أجب بـ JSON فقط: {"question":"...","options":["أ","ب","ج","د"],"correct":0,"explanation":"..."}'
      : 'From this document, create one multiple choice question. Use English. Return ONLY JSON: {"question":"...","options":["A","B","C","D"],"correct":0,"explanation":"..."}';

    try {
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [
          {'inline_data': {'mime_type': 'application/pdf', 'data': base64Pdf}},
          {'text': prompt},
        ]}], 'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 512}}),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        var text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '{}';
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();
        setState(() { _challenge = jsonDecode(text); _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (e) { setState(() => _loading = false); }
  }

  void _answer(int idx) async {
    if (_answered) return;
    final correct = _challenge?['correct'] as int? ?? 0;
    final isCorrect = idx == correct;
    final xp = isCorrect ? 50 : 10;
    setState(() { _selected = idx; _answered = true; _xpEarned = xp; });

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('challenge_date', today);
    await prefs.setInt('challenge_xp', xp);

    if (!mounted) return;
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'totalXP': FieldValue.increment(xp),
        'weeklyXP': FieldValue.increment(xp),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'تحدي اليوم' : 'Daily Challenge')),
      body: _loading
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const CircularProgressIndicator(color: Color(0xFFFF9F1C)),
            const SizedBox(height: 16),
            Text(isAr ? 'جاري تحضير السؤال...' : 'Preparing question...'),
          ]))
        : _alreadyDoneToday
          ? _DoneToday(isAr: isAr, xp: _xpEarned)
          : _showPicker
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Container(width: double.infinity, padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF9F1C), Color(0xFFFF6B35)]),
                      borderRadius: BorderRadius.circular(20)),
                    child: Column(children: [
                      const Text('⚡', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 8),
                      Text(isAr ? 'تحدي اليوم' : 'Daily Challenge',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                      Text(isAr ? 'اختار مادة وأجيب بشكل صحيح واكسب 50 XP' : 'Pick a course and answer correctly to earn 50 XP',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ])),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(16)),
                    child: CourseMaterialPicker(onPdfSelected: _generateFromMaterial),
                  ),
                ]),
              )
            : _challenge == null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(isAr ? 'تعذر تحميل السؤال' : 'Failed to load question'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => setState(() => _showPicker = true),
                    child: Text(isAr ? 'إعادة المحاولة' : 'Retry')),
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Container(width: double.infinity, padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF9F1C), Color(0xFFFF6B35)]),
                        borderRadius: BorderRadius.circular(20)),
                      child: Column(children: [
                        const Text('⚡', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(isAr ? 'تحدي اليوم' : 'Daily Challenge',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                        Text(isAr ? 'أجب بشكل صحيح واكسب 50 XP' : 'Answer correctly to earn 50 XP',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ])),
                    const SizedBox(height: 24),
                    Container(width: double.infinity, padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(16)),
                      child: Text(_challenge!['question'] ?? '',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5))),
                    const SizedBox(height: 16),
                    ...(_challenge!['options'] as List? ?? []).asMap().entries.map((e) {
                      final i = e.key; final opt = e.value as String;
                      final correct = _challenge!['correct'] as int? ?? 0;
                      Color? bg; Color? border;
                      if (_answered) {
                        if (i == correct) { bg = const Color(0xFF06D6A0).withOpacity(0.1); border = const Color(0xFF06D6A0); }
                        else if (i == _selected && i != correct) { bg = Colors.red.withOpacity(0.08); border = Colors.red; }
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
                            if (_answered && i == correct) const Icon(Icons.check_circle_rounded, color: Color(0xFF06D6A0)),
                            if (_answered && i == _selected && i != correct) const Icon(Icons.cancel_rounded, color: Colors.red),
                          ]),
                        ),
                      );
                    }),
                    if (_answered && (_challenge!['explanation'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF06D6A0).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF06D6A0).withOpacity(0.3))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.lightbulb_rounded, color: Color(0xFF06D6A0), size: 18),
                            const SizedBox(width: 6),
                            Text(isAr ? 'الشرح' : 'Explanation', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF06D6A0))),
                          ]),
                          const SizedBox(height: 8),
                          Text(_challenge!['explanation'], style: const TextStyle(fontSize: 13, height: 1.5)),
                        ])),
                    ],
                    if (_answered) ...[
                      const SizedBox(height: 20),
                      Container(padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFFFF9F1C).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('⚡', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Text('+$_xpEarned XP', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFFFF9F1C))),
                          const SizedBox(width: 8),
                          Text(isAr ? 'مكتسبة!' : 'earned!', style: TextStyle(color: Colors.grey[600])),
                        ])),
                    ],
                  ]),
                ),
    );
  }
}

class _DoneToday extends StatelessWidget {
  final bool isAr; final int xp;
  const _DoneToday({required this.isAr, required this.xp});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('🎉', style: TextStyle(fontSize: 64)),
    const SizedBox(height: 16),
    Text(isAr ? 'أنهيت تحدي اليوم!' : 'Daily challenge complete!',
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
    const SizedBox(height: 8),
    Text('+$xp XP ${isAr ? 'مكتسبة' : 'earned'}',
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFFFF9F1C))),
    const SizedBox(height: 8),
    Text(isAr ? 'عود غداً للتحدي القادم' : 'Come back tomorrow for the next challenge',
      style: TextStyle(color: Colors.grey[600])),
  ]));
}