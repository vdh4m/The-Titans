import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:studyhub/generated/l10n/app_localizations.dart';
import '../../providers/study_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../models/course_model.dart';
import '../../utils/app_theme.dart';
// ignore: unused_import
import '../../services/focus_mode_service.dart';
import '../../widgets/focus_banner.dart';
import 'flashcard_screen.dart';
import '../tools/calculator_screen.dart';
import '../tools/translator_screen.dart';
import '../tools/scanner_screen.dart';
import '../tools/speech_to_text_screen.dart';
import 'pdf_summarizer_screen.dart';
import 'quiz_generator_screen.dart';
import 'leaderboard_screen.dart';
import 'course_roadmap_screen.dart';
import 'smart_revision_screen.dart';
import 'exam_survival_screen.dart';
import 'mood_selector_screen.dart';
import 'weekly_report_screen.dart';
import '../ai/mock_exam_screen.dart';
import '../ai/summarize_notes_screen.dart';
import '../tools/text_to_voice_screen.dart';

class StudyModeScreen extends StatelessWidget {
  const StudyModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final study = context.watch<StudyProvider>();
    final auth = context.watch<AuthProvider>();
    final isAr = context.watch<AppProvider>().isArabic;
    final user = auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(l10n.studyMode)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Focus Mode Banner ──────────────────────────────────────────────
          FocusBanner(isAr: isAr),
          const SizedBox(height: 16),

          // Streak & XP bar
          if (user.isStudent) _StreakXPBar(user: user, isAr: isAr),
          if (user.isStudent) const SizedBox(height: 16),

          // Mode toggle
          if (!study.isRunning) _ModeToggle(study: study, isAr: isAr),
          if (!study.isRunning) const SizedBox(height: 16),

          _TimerCard(study: study, isAr: isAr, l10n: l10n),
          const SizedBox(height: 24),

          // Study Tools
          _StudyTools(isAr: isAr, user: user),
          const SizedBox(height: 24),

          if (!study.isRunning) ...[
            Text(l10n.selectSubject, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _CoursePicker(user: user, isAr: isAr, study: study),
          ],
          const SizedBox(height: 24),
          Text(l10n.progress, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _ProgressSection(user: user, isAr: isAr, study: study),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

// ── STREAK & XP BAR ──────────────────────────────────────────────────────────
class _StreakXPBar extends StatelessWidget {
  final user; final bool isAr;
  const _StreakXPBar({required this.user, required this.isAr});

  String _xpLevel(int xp) {
    if (xp < 100) return isAr ? 'مبتدئ' : 'Beginner';
    if (xp < 500) return isAr ? 'متعلم' : 'Learner';
    if (xp < 1500) return isAr ? 'متقدم' : 'Advanced';
    if (xp < 5000) return isAr ? 'خبير' : 'Expert';
    return isAr ? 'أسطورة' : 'Legend';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black.withOpacity(0.07), width: 1.5),
    ),
    child: Row(children: [
      // Streak
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔥', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 4),
          Text('${user.streakDays}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.orange)),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_xpLevel(user.totalXP), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text('${user.totalXP} XP', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (user.totalXP % 500) / 500,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isAr ? 'سلسلة ${user.streakDays} يوم' : '${user.streakDays} day streak',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ])),
    ]),
  );
}

// ── MODE TOGGLE ───────────────────────────────────────────────────────────────
class _ModeToggle extends StatelessWidget {
  final StudyProvider study; final bool isAr;
  const _ModeToggle({required this.study, required this.isAr});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(children: [
      _ModeBtn(
        label: isAr ? '⏱ عادي' : '⏱ Normal',
        selected: study.studyMode == StudyMode.normal,
        onTap: () => study.setStudyMode(StudyMode.normal),
      ),
      _ModeBtn(
        label: isAr ? '🍅 بومودورو' : '🍅 Pomodoro',
        selected: study.studyMode == StudyMode.pomodoro,
        onTap: () => study.setStudyMode(StudyMode.pomodoro),
      ),
    ]),
  );
}

class _ModeBtn extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _ModeBtn({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, textAlign: TextAlign.center,
        style: TextStyle(color: selected ? Colors.white : Colors.grey, fontWeight: FontWeight.w700)),
    ),
  ));
}

// ── TIMER CARD ────────────────────────────────────────────────────────────────
class _TimerCard extends StatelessWidget {
  final StudyProvider study; final bool isAr; final AppLocalizations l10n;
  const _TimerCard({required this.study, required this.isAr, required this.l10n});

  Color get _phaseColor {
    switch (study.pomodoroPhase) {
      case PomodoroPhase.work: return AppTheme.primaryColor;
      case PomodoroPhase.shortBreak: return const Color(0xFF06D6A0);
      case PomodoroPhase.longBreak: return const Color(0xFF7209B7);
    }
  }

  String _phaseLabel(bool isAr) {
    switch (study.pomodoroPhase) {
      case PomodoroPhase.work: return isAr ? '🍅 وقت التركيز' : '🍅 Focus Time';
      case PomodoroPhase.shortBreak: return isAr ? '☕ راحة قصيرة' : '☕ Short Break';
      case PomodoroPhase.longBreak: return isAr ? '🛋 راحة طويلة' : '🛋 Long Break';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = study.currentCourse != null ? (isAr ? study.currentCourse!.titleAr : study.currentCourse!.titleEn) : '';
    final isPomodoro = study.isPomodoro;

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPomodoro ? [_phaseColor, _phaseColor.withOpacity(0.7)] : [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: (isPomodoro ? _phaseColor : AppTheme.primaryColor).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        if (isPomodoro && study.isRunning) ...[
          Text(_phaseLabel(isAr), style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          // Pomodoro round dots
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < (study.pomodoroRound % 4) ? Colors.white : Colors.white30,
            ),
          ))),
          const SizedBox(height: 8),
        ] else if (study.currentCourse != null)
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),

        const SizedBox(height: 8),

        // Timer display
        isPomodoro && study.isRunning
          ? _PomodoroRing(progress: study.pomodoroProgress, time: study.formattedTime, color: Colors.white)
          : Text(study.formattedTime, style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold)),

        const SizedBox(height: 20),
        if (study.isRunning)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Btn(label: l10n.pause, icon: Icons.pause_rounded, onTap: study.pauseStudy, outlined: true),
            const SizedBox(width: 14),
            _Btn(label: l10n.stopStudy, icon: Icons.stop_rounded, color: Colors.red, onTap: () => study.stopStudy()),
          ])
        else if (study.currentCourse != null)
          _Btn(label: l10n.resume, icon: Icons.play_arrow_rounded, onTap: study.resumeStudy)
        else
          Text(isAr ? 'اختر مادة للبدء' : 'Select a subject to start', style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }
}

class _PomodoroRing extends StatelessWidget {
  final double progress; final String time; final Color color;
  const _PomodoroRing({required this.progress, required this.time, required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 140, height: 140,
    child: Stack(alignment: Alignment.center, children: [
      SizedBox(width: 140, height: 140,
        child: CircularProgressIndicator(
          value: progress, strokeWidth: 8,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation(color),
        )),
      Text(time, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _Btn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap; final Color? color; final bool outlined;
  const _Btn({required this.label, required this.icon, required this.onTap, this.color, this.outlined = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : (color ?? Colors.white),
        border: outlined ? Border.all(color: Colors.white, width: 2) : null,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: outlined ? Colors.white : (color != null ? Colors.white : AppTheme.primaryColor), size: 20),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: outlined ? Colors.white : (color != null ? Colors.white : AppTheme.primaryColor), fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      ]),
    ),
  );
}

// ── STUDY TOOLS ───────────────────────────────────────────────────────────────
class _StudyTools extends StatelessWidget {
  final bool isAr; final user;
  const _StudyTools({required this.isAr, required this.user});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isDesktop = screenW >= 900;
    final isTablet  = screenW >= 600 && screenW < 900;
    final cols = isDesktop ? 4 : isTablet ? 3 : 2;
    // On desktop, cards are compact horizontal tiles (more like a grid of chips)
    final cardAspect = isDesktop ? 2.6 : isTablet ? 2.0 : 1.45;

    final tools = [
      _Tool(Icons.style_rounded,          isAr ? 'فلاش كارد'        : 'Flashcards',      isAr ? 'بطاقات مراجعة'         : 'Review cards',          AppTheme.primaryColor,         () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashcardScreen()))),
      _Tool(Icons.auto_awesome_rounded,   isAr ? 'تلخيص PDF'        : 'PDF Summary',     isAr ? 'بالذكاء الاصطناعي'    : 'AI-powered',             const Color(0xFF7209B7),       () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfSummarizerScreen()))),
      if (!user.isDoctor)
      _Tool(Icons.quiz_rounded,           isAr ? 'توليد أسئلة'      : 'Quiz Gen',        isAr ? 'أسئلة من PDF'          : 'Questions from PDF',    const Color(0xFFFF9F1C),       () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizGeneratorScreen()))),
      _Tool(Icons.leaderboard_rounded,    isAr ? 'المتصدرون'        : 'Leaderboard',     isAr ? 'منافسة الكلية'         : 'Faculty ranking',        const Color(0xFF06D6A0),       () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderboardScreen(user: user)))),
      _Tool(Icons.warning_amber_rounded,  isAr ? 'وضع الطوارئ'      : 'Exam Survival',   isAr ? 'باقي 24 ساعة'          : '24h before exam',        Colors.red,                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamSurvivalScreen()))),
      _Tool(Icons.emoji_emotions_outlined,isAr ? 'مزاج المذاكرة'    : 'Study Mood',      isAr ? 'اختر طريقتك'           : 'Pick your style',        const Color(0xFFFF6B35),       () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodSelectorScreen()))),
      _Tool(Icons.psychology_rounded,     isAr ? 'امتحان تجريبي'    : 'Mock Exam',       isAr ? 'AI يمتحنك'             : 'AI-powered exam',        const Color(0xFF7209B7),       () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MockExamScreen()))),
      _Tool(Icons.summarize_rounded,      isAr ? 'لخص ملاحظاتي'    : 'Summarize Notes', isAr ? 'تلخيص ذكي'             : 'AI summary',             const Color(0xFF06D6A0),       () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SummarizeNotesScreen()))),
      _Tool(Icons.map_rounded,            isAr ? 'خارطة الطريق'     : 'Course Roadmap',  isAr ? 'تقدمك وحدة بوحدة'      : 'Progress unit by unit',  const Color(0xFF06D6A0),       () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CourseRoadmapScreen()))),
      _Tool(Icons.calendar_today_rounded, isAr ? 'جدول المراجعة'    : 'Revision Planner',isAr ? 'خطة ذكية قبل الامتحان' : 'Smart pre-exam schedule', const Color(0xFF4361EE),       () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartRevisionScreen()))),
      _Tool(Icons.calculate_rounded,      isAr ? 'آلة حاسبة علمية' : 'Calculator',      isAr ? 'Casio fx-991ES'        : 'Casio fx-991ES style',   const Color(0xFF1A3A4A),       () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculatorScreen()))),
      _Tool(Icons.translate_rounded,      isAr ? 'مترجم'            : 'Translator',      isAr ? '٣٨ لغة'               : '38 languages',           const Color(0xFF06D6A0),       () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TranslatorScreen()))),
      _Tool(Icons.document_scanner_rounded,isAr ? 'ماسح ضوئي'      : 'Scanner',         isAr ? 'صورة → نص / PDF'       : 'Image → Text / PDF',    Colors.orange,                 () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()))),
      _Tool(Icons.mic_rounded,            isAr ? 'صوت → نص'         : 'Voice to Text',   isAr ? 'تحويل صوتي فوري'       : 'Instant transcription',  Colors.red,                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeechToTextScreen()))),
      _Tool(Icons.record_voice_over_rounded,isAr ? 'نص → صوت'      : 'Text to Voice',   isAr ? 'استمع للنص'            : 'Listen to text',         const Color(0xFF7209B7),       () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TextToVoiceScreen()))),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isAr ? 'أدوات الدراسة' : 'Study Tools',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: cardAspect,
        ),
        itemCount: tools.length,
        itemBuilder: (_, i) => _ToolCard(tool: tools[i], isDesktop: isDesktop),
      ),
      const SizedBox(height: 16),
      // Weekly report button
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyReportScreen())),
        child: Container(width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF7209B7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Text('📊', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAr ? 'تقرير أسبوعك' : 'Your Weekly Report', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              Text(isAr ? 'شوف إحصائيات مذاكرتك هذا الأسبوع' : 'See your study stats this week', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ])),
      ),
    ]);
  }
}

class _Tool {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _Tool(this.icon, this.label, this.subtitle, this.color, this.onTap);
}

class _ToolCard extends StatefulWidget {
  final _Tool tool;
  final bool isDesktop;
  const _ToolCard({required this.tool, required this.isDesktop});
  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tool;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: t.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isDesktop ? 14 : 12,
            vertical: widget.isDesktop ? 12 : 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [t.color, t.color.withOpacity(0.75)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: t.color.withOpacity(_hovered ? 0.45 : 0.22),
                blurRadius: _hovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // Desktop: icon LEFT + text RIGHT (horizontal)
          // Mobile:  icon TOP + text BOTTOM (vertical)
          child: widget.isDesktop
            ? Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(t.icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(t.subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: Icon(t.icon, color: Colors.white, size: 18),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  Text(t.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ]),
              ]),
        ),
      ),
    );
  }
}

// ── COURSE PICKER ─────────────────────────────────────────────────────────────
class _CoursePicker extends StatelessWidget {
  final user; final bool isAr; final StudyProvider study;
  const _CoursePicker({required this.user, required this.isAr, required this.study});
  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance.collection('courses');
    if (user.isStudent) {
      q = q.where('universityAr', isEqualTo: user.universityAr).where('facultyAr', isEqualTo: user.facultyAr).where('year', isEqualTo: user.year);
    } else {
      q = q.where('doctorId', isEqualTo: user.uid);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final courses = snap.data!.docs.map((d) => CourseModel.fromMap(d.data() as Map<String, dynamic>)).toList();
        return Column(children: courses.map((c) => _PickItem(course: c, isAr: isAr, progress: study.getProgressForCourse(c.id), onStart: () => study.startStudy(c))).toList());
      },
    );
  }
}

class _PickItem extends StatelessWidget {
  final CourseModel course; final bool isAr; final double progress; final VoidCallback onStart;
  const _PickItem({required this.course, required this.isAr, required this.progress, required this.onStart});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircularPercentIndicator(radius: 24, lineWidth: 4, percent: progress,
        center: Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
        progressColor: AppTheme.primaryColor, backgroundColor: Colors.grey.withOpacity(0.2)),
      title: Text(isAr ? course.titleAr : course.titleEn, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: ElevatedButton(onPressed: onStart, style: ElevatedButton.styleFrom(minimumSize: const Size(60, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white)),
    ),
  );
}

// ── PROGRESS SECTION ──────────────────────────────────────────────────────────
class _ProgressSection extends StatelessWidget {
  final user; final bool isAr; final StudyProvider study;
  const _ProgressSection({required this.user, required this.isAr, required this.study});
  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance.collection('courses');
    if (user.isStudent) {
      q = q.where('universityAr', isEqualTo: user.universityAr).where('facultyAr', isEqualTo: user.facultyAr).where('year', isEqualTo: user.year);
    } else {
      q = q.where('doctorId', isEqualTo: user.uid);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox();
        final courses = snap.data!.docs.map((d) => CourseModel.fromMap(d.data() as Map<String, dynamic>)).toList();
        return Column(children: courses.map((c) {
          final prog = study.getProgressForCourse(c.id);
          final secs = study.courseProgress[c.id] ?? 0;
          final h = secs ~/ 3600; final m = (secs % 3600) ~/ 60;
          return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(isAr ? c.titleAr : c.titleEn, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${(prog * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: prog, backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                borderRadius: BorderRadius.circular(4), minHeight: 6),
              const SizedBox(height: 4),
              Text(isAr ? 'وقت الدراسة: ${h > 0 ? '${h}h ' : ''}${m}m' : 'Study time: ${h > 0 ? '${h}h ' : ''}${m}m',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ]),
          ));
        }).toList());
      },
    );
  }
}
