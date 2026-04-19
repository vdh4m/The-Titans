import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../models/course_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/course_material_picker.dart';
import '../home/notification_center_screen.dart';

/// Doctor screen to generate a quiz (AI or PDF) and post it to a course's announcements.
class DoctorCourseQuizScreen extends StatefulWidget {
  /// If passed, skips course selection and uses this course directly.
  final CourseModel? course;
  const DoctorCourseQuizScreen({super.key, this.course});
  @override
  State<DoctorCourseQuizScreen> createState() => _DoctorCourseQuizScreenState();
}

class _DoctorCourseQuizScreenState extends State<DoctorCourseQuizScreen> {
  static const _apiKey = 'AIzaSyBFYmfZC_D-4vwigPrOM0MiPYYEZb4UdBM';

  // Quiz settings
  int _numQuestions = 10;
  bool _useAI = true; // AI from course material vs upload PDF
  bool _loading = false;
  bool _posting = false;
  String? _quizTitle;
  List<Map<String, dynamic>> _questions = [];
  String? _sourceName;

  // Course selection for standalone (when course not passed)
  List<Map<String, dynamic>> _myCourses = [];
  Map<String, dynamic>? _selectedCourse;
  bool _loadingCourses = true;

  @override
  void initState() {
    super.initState();
    if (widget.course == null) _loadMyCourses();
  }

  Future<void> _loadMyCourses() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) { setState(() => _loadingCourses = false); return; }
    final snap = await FirebaseFirestore.instance
        .collection('courses')
        .where('doctorId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'main')
        .get();
    final courses = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    if (mounted) setState(() { _myCourses = courses; _loadingCourses = false; });
  }

  String get _activeCourseId => widget.course?.id ?? (_selectedCourse?['id'] as String? ?? '');
  String _activeCourseTitle(bool isAr) {
    if (widget.course != null) return isAr ? widget.course!.titleAr : widget.course!.titleEn;
    final c = _selectedCourse;
    if (c == null) return '';
    return isAr ? (c['titleAr'] ?? '') : (c['titleEn'] ?? '');
  }

  Future<void> _generateFromPdf(Uint8List pdfBytes, String courseTitle, String matTitle) async {
    final isAr = context.read<AppProvider>().isArabic;
    setState(() { _loading = true; _questions = []; _sourceName = '$courseTitle — $matTitle'; });

    final base64Pdf = base64Encode(pdfBytes);
    final prompt = isAr
      ? '''من هذا المستند، اعمل $_numQuestions سؤال اختيار متعدد (MCQ) بمستويات صعوبة متدرجة. استخدم اللغة العربية.
أجب بـ JSON فقط بدون backticks:
[{"q":"السؤال","options":["أ","ب","ج","د"],"correct":0,"explanation":"شرح"}]'''
      : '''From this document, generate $_numQuestions multiple choice questions (MCQ) with gradually increasing difficulty. Use English.
Return ONLY JSON no backticks:
[{"q":"question","options":["A","B","C","D"],"correct":0,"explanation":"explanation"}]''';

    try {
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [
          {'inline_data': {'mime_type': 'application/pdf', 'data': base64Pdf}},
          {'text': prompt},
        ]}], 'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 4000}}),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        var text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '[]';
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();
        setState(() { _questions = List<Map<String, dynamic>>.from(jsonDecode(text)); _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (e) { setState(() => _loading = false); }
  }

  Future<void> _pickAndGenerate() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final f = result.files.single;
    await _generateFromPdf(f.bytes!, f.name, '');
  }

  Future<void> _postToAnnouncements() async {
    if (_questions.isEmpty || _activeCourseId.isEmpty) return;
    final isAr = context.read<AppProvider>().isArabic;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final title = _quizTitle?.trim().isEmpty == false
      ? _quizTitle!.trim()
      : (isAr ? 'كويز: ${_activeCourseTitle(isAr)}' : 'Quiz: ${_activeCourseTitle(isAr)}');

    setState(() => _posting = true);
    try {
      final annId = const Uuid().v4();
      final courseDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(_activeCourseId)
          .get();
      final courseMap = courseDoc.data() ?? const <String, dynamic>{};
      final targetUni = (courseMap['universityAr'] ?? '').toString();
      final targetFac = (courseMap['facultyAr'] ?? '').toString();
      final targetYear = (courseMap['year'] is int) ? courseMap['year'] as int : null;

      await FirebaseFirestore.instance.collection('announcements').doc(annId).set({
        'id': annId,
        'courseId': _activeCourseId,
        'doctorId': user.uid,
        'doctorName': user.fullName ?? user.email,
        'titleAr': title,
        'titleEn': title,
        'bodyAr': isAr
          ? '📝 كويز من $_numQuestions سؤال — مصدر: ${_sourceName ?? 'AI'}\nاجمع طلابك وجاوبوا الأسئلة!'
          : '📝 Quiz with $_numQuestions questions — Source: ${_sourceName ?? 'AI'}\nGather your students and answer!',
        'bodyEn': isAr
          ? '📝 كويز من $_numQuestions سؤال — مصدر: ${_sourceName ?? 'AI'}\nاجمع طلابك وجاوبوا الأسئلة!'
          : '📝 Quiz with $_numQuestions questions — Source: ${_sourceName ?? 'AI'}\nGather your students and answer!',
        'isExam': false,
        'isQuiz': true,
        'questions': _questions,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notify course students about newly posted quiz announcement.
      if (targetUni.isNotEmpty && targetFac.isNotEmpty && targetYear != null) {
        try {
          final usersSnap = await FirebaseFirestore.instance
              .collection('users')
              .where('universityAr', isEqualTo: targetUni)
              .where('facultyAr', isEqualTo: targetFac)
              .where('year', isEqualTo: targetYear)
              .get();
          final uids = usersSnap.docs
              .map((d) => d.id)
              .where((uid) => uid != user.uid)
              .toList();
          await NotificationHelper.sendToMany(
            uids: uids,
            type: 'quiz',
            titleAr: 'كويز جديد — ${_activeCourseTitle(true)}',
            titleEn: 'New Quiz — ${_activeCourseTitle(false)}',
            bodyAr: 'الدكتور نشر كويز جديد في ${_activeCourseTitle(true)}. ابدأ الآن!',
            bodyEn: 'Doctor posted a new quiz in ${_activeCourseTitle(false)}. Start now!',
            extra: {'courseId': _activeCourseId, 'announcementId': annId},
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAr ? '✅ تم نشر الكويز في الإعلانات!' : '✅ Quiz posted to announcements!'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'إنشاء كويز للطلاب' : 'Create Student Quiz'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ──────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7209B7), AppTheme.primaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const Text('🎯', style: TextStyle(fontSize: 40)),
              Text(isAr ? 'اعمل كويز وانشره للطلاب' : 'Create & Publish a Quiz',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              Text(isAr ? 'من المادة الدراسية أو PDF وانشره في الإعلانات' : 'From course material or PDF — posted in Announcements',
                style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
            ])),
          const SizedBox(height: 20),

          // ── Course selection (if no course pre-selected) ─────────────────
          if (widget.course == null) ...[
            Text(isAr ? 'اختر المادة' : 'Select Course',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            _loadingCourses
              ? const Center(child: CircularProgressIndicator())
              : _myCourses.isEmpty
                ? Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                    child: Text(isAr ? 'لا توجد مواد رئيسية بعد' : 'No main courses yet',
                      style: const TextStyle(color: Colors.orange)))
                : Container(
                    decoration: BoxDecoration(border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: ButtonTheme(
                        alignedDropdown: true,
                        child: DropdownButton<Map<String, dynamic>>(
                          value: _selectedCourse,
                          isExpanded: true,
                          hint: Text(isAr ? 'اختر المادة...' : 'Choose a course...', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                          borderRadius: BorderRadius.circular(12),
                          items: _myCourses.map((c) {
                            final t = isAr ? (c['titleAr'] ?? '') : (c['titleEn'] ?? '');
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: c,
                              child: Text(t.toString(), overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (c) => setState(() => _selectedCourse = c),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
          ],

          // ── Number of questions ──────────────────────────────────────────
          Text(isAr ? 'عدد الأسئلة' : 'Number of Questions',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [5, 10, 15, 20, 30].map((n) => GestureDetector(
            onTap: () => setState(() => _numQuestions = n),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _numQuestions == n ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text('$n', style: TextStyle(fontWeight: FontWeight.w700, color: _numQuestions == n ? Colors.white : AppTheme.primaryColor)),
            ),
          )).toList()),
          const SizedBox(height: 20),

          // ── Quiz title (optional) ────────────────────────────────────────
          TextField(
            onChanged: (v) => _quizTitle = v,
            decoration: InputDecoration(
              labelText: isAr ? 'عنوان الكويز (اختياري)' : 'Quiz title (optional)',
              prefixIcon: const Icon(Icons.title_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Source toggle ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _useAI = true),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: _useAI ? AppTheme.primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                  child: Text(isAr ? '🤖 من مواد الكورس' : '🤖 From Course Material',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _useAI ? Colors.white : Colors.grey, fontWeight: FontWeight.w700, fontSize: 12))),
              )),
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _useAI = false),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: !_useAI ? AppTheme.primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                  child: Text(isAr ? '📁 رفع PDF' : '📁 Upload PDF',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: !_useAI ? Colors.white : Colors.grey, fontWeight: FontWeight.w700, fontSize: 12))),
              )),
            ]),
          ),
          const SizedBox(height: 16),

          if (_useAI)
            CourseMaterialPicker(onPdfSelected: _generateFromPdf)
          else ...[
            GestureDetector(
              onTap: _loading ? null : _pickAndGenerate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3))),
                child: Column(children: [
                  const Icon(Icons.upload_file_rounded, color: AppTheme.primaryColor, size: 36),
                  const SizedBox(height: 8),
                  Text(isAr ? 'ارفع PDF لتوليد الكويز' : 'Upload PDF to generate quiz', textAlign: TextAlign.center),
                ])),
            ),
          ],

          if (_loading) ...[
            const SizedBox(height: 24),
            const Center(child: Column(children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 12),
              Text('🤖 AI is generating your quiz...', textAlign: TextAlign.center),
            ])),
          ],

          // ── Preview generated questions ──────────────────────────────────
          if (_questions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(isAr ? 'تم توليد ${_questions.length} سؤال' : '${_questions.length} questions generated',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                ]),
                const SizedBox(height: 8),
                ..._questions.take(3).toList().asMap().entries.map((e) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${e.key + 1}. ${e.value['q'] ?? ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  )),
                if (_questions.length > 3)
                  Text(isAr ? '...و${_questions.length - 3} أسئلة أخرى' : '...and ${_questions.length - 3} more',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ])),
            const SizedBox(height: 16),

            // Publish button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_posting || _activeCourseId.isEmpty) ? null : _postToAnnouncements,
                icon: _posting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.campaign_rounded),
                label: Text(_posting
                  ? (isAr ? 'جاري النشر...' : 'Publishing...')
                  : (isAr ? '📢 انشر الكويز في الإعلانات' : '📢 Publish Quiz to Announcements')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
            if (_activeCourseId.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(isAr ? '⚠️ اختر مادة أولاً' : '⚠️ Please select a course first',
                  style: const TextStyle(color: Colors.orange, fontSize: 12))),
          ],
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}
