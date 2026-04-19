import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

/// Quiz-taking screen for students.
/// Auto-submits if student presses back, switches tabs, or leaves the app.
class StudentQuizScreen extends StatefulWidget {
  final String announcementId;
  final String titleAr;
  final String titleEn;
  final List<Map<String, dynamic>> questions;
  final String courseId;

  const StudentQuizScreen({
    super.key,
    required this.announcementId,
    required this.titleAr,
    required this.titleEn,
    required this.questions,
    required this.courseId,
  });

  @override
  State<StudentQuizScreen> createState() => _StudentQuizScreenState();
}

class _StudentQuizScreenState extends State<StudentQuizScreen>
    with WidgetsBindingObserver {
  final Map<int, int> _answers = {}; // questionIndex → chosenOptionIndex
  bool _submitted = false;
  bool _submitting = false;
  int? _score;
  bool _hasAutoSubmitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Auto-submit if not already done when widget is disposed (tab switch / screen pop)
    if (!_submitted && !_hasAutoSubmitted) {
      _autoSubmit();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App goes to background / loses focus — auto-submit
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) &&
        !_submitted &&
        !_hasAutoSubmitted) {
      _autoSubmit();
    }
  }

  Future<void> _autoSubmit() async {
    _hasAutoSubmitted = true;
    await _doSubmit();
  }

  Future<void> _doSubmit() async {
    if (_submitted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    int correct = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      // Support both key formats: 'correct' (from DoctorCourseQuizScreen) or 'correctIndex'
      final correctIdx = (q['correct'] ?? q['correctIndex'] ?? 0) as int;
      if (_answers[i] == correctIdx) correct++;
    }
    final score = correct;
    final total = widget.questions.length;

    try {
      // Save result to Firestore
      await FirebaseFirestore.instance
          .collection('quiz_results')
          .doc('${widget.announcementId}_${user.uid}')
          .set({
        'announcementId': widget.announcementId,
        'courseId': widget.courseId,
        'studentId': user.uid,
        'studentName': user.fullName ?? user.email,
        'score': score,
        'total': total,
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'submittedAt': DateTime.now().toIso8601String(),
        'autoSubmitted': _hasAutoSubmitted && !_submitted,
      });
    } catch (_) {}

    if (mounted) {
      setState(() {
        _submitted = true;
        _submitting = false;
        _score = score;
      });
    }
  }

  Future<void> _submitManually() async {
    if (_submitting || _submitted) return;
    setState(() => _submitting = true);
    await _doSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isAr ? widget.titleAr : widget.titleEn;

    return PopScope(
      // intercept back navigation — auto-submit before leaving
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (!_submitted && !_hasAutoSubmitted) {
          await _autoSubmit();
        }
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (!_submitted && !_hasAutoSubmitted) await _autoSubmit();
              if (context.mounted) Navigator.pop(context);
            },
          ),
          actions: [
            if (!_submitted)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _submitManually,
                  child: Text(
                    isAr ? 'تسليم' : 'Submit',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
        body: _submitted ? _ResultView(
          score: _score ?? 0,
          total: widget.questions.length,
          isAr: isAr,
          onClose: () => Navigator.pop(context),
        ) : _QuizView(
          questions: widget.questions,
          answers: _answers,
          isAr: isAr,
          isDark: isDark,
          onAnswerChanged: (qi, ai) => setState(() => _answers[qi] = ai),
          onSubmit: _submitManually,
          submitting: _submitting,
        ),
      ),
    );
  }
}

// ── Quiz question view ─────────────────────────────────────────────────────────
class _QuizView extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final Map<int, int> answers;
  final bool isAr, isDark, submitting;
  final void Function(int qi, int ai) onAnswerChanged;
  final VoidCallback onSubmit;

  const _QuizView({
    required this.questions,
    required this.answers,
    required this.isAr,
    required this.isDark,
    required this.onAnswerChanged,
    required this.onSubmit,
    required this.submitting,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Progress bar
      LinearProgressIndicator(
        value: answers.length / questions.length,
        backgroundColor: Colors.grey.shade200,
        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        minHeight: 4,
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: questions.length,
          itemBuilder: (_, i) {
            final q = questions[i];
            final qText = q['q'] ?? (isAr ? q['questionAr'] : q['questionEn']) ?? q['question'] ?? '';
            final options = (q['options'] as List?)?.cast<String>() ?? [];
            final chosen = answers[i];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1730) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: chosen != null ? AppTheme.primaryColor.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
                ),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text('${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w800,
                            fontSize: 12, color: AppTheme.primaryColor))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(qText,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                ]),
                const SizedBox(height: 12),
                ...options.asMap().entries.map((e) {
                  final idx = e.key;
                  final opt = e.value;
                  final isSelected = chosen == idx;
                  return GestureDetector(
                    onTap: () => onAnswerChanged(i, idx),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withOpacity(0.12)
                            : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? AppTheme.primaryColor : Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(opt, style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? AppTheme.primaryColor : null,
                        ))),
                      ]),
                    ),
                  );
                }),
              ]),
            );
          },
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton.icon(
            onPressed: submitting ? null : onSubmit,
            icon: submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, color: Colors.white),
            label: Text(
              isAr ? 'تسليم الإجابات' : 'Submit Answers',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Result view ────────────────────────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  final int score, total;
  final bool isAr;
  final VoidCallback onClose;
  const _ResultView({required this.score, required this.total,
      required this.isAr, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (score / total * 100).round() : 0;
    final passed = pct >= 50;
    final color = pct >= 80 ? const Color(0xFF16A34A) : pct >= 50 ? const Color(0xFFFF9F1C) : Colors.red;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(passed ? '🎉' : '😔', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text(
            isAr ? 'نتيجتك' : 'Your Score',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            '$score / $total',
            style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$pct%', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(height: 20),
          Text(
            pct >= 80 ? (isAr ? '🌟 ممتاز! نتيجة رائعة' : '🌟 Excellent result!')
                : pct >= 50 ? (isAr ? '👍 تجاوزت الحد الأدنى' : '👍 You passed!')
                : (isAr ? '💪 حاول مرة أخرى في المرة القادمة' : '💪 Try harder next time'),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(isAr ? 'إغلاق' : 'Close',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}
