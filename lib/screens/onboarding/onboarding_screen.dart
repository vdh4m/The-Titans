import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../auth/welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _current    = 0;
  String _selectedStyle = '';
  final List<String> _selectedGoals = [];

  static const _totalPages = 5;

  static const _studyStyles = [
    {'id': 'visual',   'emoji': '👁',  'labelAr': 'بصري',   'labelEn': 'Visual',    'descAr': 'أفضل مع الرسوم والمخططات', 'descEn': 'Learn best with diagrams & visuals'},
    {'id': 'reading',  'emoji': '📖', 'labelAr': 'قراءة',   'labelEn': 'Reading',   'descAr': 'أحب القراءة والملاحظات',   'descEn': 'Prefer reading and taking notes'},
    {'id': 'practice', 'emoji': '✏',  'labelAr': 'تطبيق',  'labelEn': 'Practice',  'descAr': 'أفضل تعلم بالتمارين',     'descEn': 'Learn by solving exercises'},
    {'id': 'audio',    'emoji': '🎧', 'labelAr': 'استماع',  'labelEn': 'Listening', 'descAr': 'أفضل الاستماع للشروح',    'descEn': 'Prefer listening to explanations'},
  ];

  static const _goals = [
    {'id': 'grades',  'emoji': '🎯', 'labelAr': 'تحسين درجاتي',        'labelEn': 'Improve my grades'},
    {'id': 'habit',   'emoji': '🔥', 'labelAr': 'بناء عادة مذاكرة',    'labelEn': 'Build a study habit'},
    {'id': 'exam',    'emoji': '📝', 'labelAr': 'الاستعداد للامتحانات', 'labelEn': 'Prepare for exams'},
    {'id': 'org',     'emoji': '📅', 'labelAr': 'تنظيم وقتي',          'labelEn': 'Organize my time'},
    {'id': 'compete', 'emoji': '🏆', 'labelAr': 'التنافس مع زملائي',   'labelEn': 'Compete with classmates'},
    {'id': 'career',  'emoji': '💼', 'labelAr': 'بناء مستقبلي المهني', 'labelEn': 'Build my career'},
  ];

  void _next() {
    if (_current < _totalPages - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ap   = context.watch<AppProvider>();
    final isAr = ap.isArabic;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              // Progress dots
              ...List.generate(_totalPages, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 5),
                width: _current == i ? 26 : 8, height: 8,
                decoration: BoxDecoration(
                  color: _current >= i ? AppTheme.primaryColor : Colors.grey.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
              const Spacer(),
              // ── Language toggle ──────────────────────────────────────
              GestureDetector(
                onTap: () => ap.setLocale(isAr ? const Locale('en') : const Locale('ar')),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🌐', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      isAr ? 'English' : 'العربية',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                          fontSize: 12),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              // Skip
              if (_current < _totalPages - 1)
                TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text(isAr ? 'تخطي' : 'Skip',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ),
            ]),
          ),

          // ── Pages ────────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _current = i),
              children: [
                _WelcomePage(isAr: isAr),
                _StylePage(
                  isAr: isAr, selected: _selectedStyle,
                  onSelect: (s) => setState(() => _selectedStyle = s),
                  styles: List<Map<String, String>>.from(
                      _studyStyles.map((m) => m.map((k, v) => MapEntry(k, v.toString())))),
                ),
                _GoalsPage(
                  isAr: isAr, selected: _selectedGoals,
                  onToggle: (g) => setState(() =>
                      _selectedGoals.contains(g) ? _selectedGoals.remove(g) : _selectedGoals.add(g)),
                  goals: List<Map<String, String>>.from(
                      _goals.map((m) => m.map((k, v) => MapEntry(k, v.toString())))),
                ),
                _FeaturesPage(isAr: isAr),
                _ReadyPage(isAr: isAr),
              ],
            ),
          ),

          // ── Bottom button ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: AppTheme.primaryColor, elevation: 0,
              ),
              child: Text(
                _current == _totalPages - 1
                    ? (isAr ? 'ابدأ الرحلة!' : "Let's Go!")
                    : (isAr ? 'التالي' : 'Next'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Page 1: Welcome ───────────────────────────────────────────────────────────
class _WelcomePage extends StatelessWidget {
  final bool isAr;
  const _WelcomePage({required this.isAr});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 130, height: 130,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, Color(0xFF7209B7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.35),
              blurRadius: 30, offset: const Offset(0, 12))],
        ),
        child: const Center(child: Text('🎓', style: TextStyle(fontSize: 62))),
      ),
      const SizedBox(height: 36),
      Text(isAr ? 'أهلاً بك في ستادي هاب' : 'Welcome to StudyHub',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 27),
          textAlign: TextAlign.center),
      const SizedBox(height: 14),
      Text(
        isAr
            ? 'المنصة الأولى للمذاكرة الذكية\nمخصصة للطلاب المصريين 🇪🇬'
            : 'The #1 smart study platform\nbuilt for Egyptian students 🇪🇬',
        style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.7),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 36),
      Wrap(spacing: 10, children: [
        _Pill(emoji: '🤖', label: isAr ? 'ذكاء اصطناعي' : 'AI Powered'),
        _Pill(emoji: '🏆', label: isAr ? 'تنافسي' : 'Competitive'),
        _Pill(emoji: '🇪🇬', label: isAr ? 'مصري' : 'Egyptian'),
      ]),
    ]),
  );
}

class _Pill extends StatelessWidget {
  final String emoji, label;
  const _Pill({required this.emoji, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.primaryColor.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
    ]),
  );
}

// ── Page 2: Study Style ───────────────────────────────────────────────────────
class _StylePage extends StatelessWidget {
  final bool isAr;
  final String selected;
  final Function(String) onSelect;
  final List<Map<String, String>> styles;
  const _StylePage({required this.isAr, required this.selected, required this.onSelect, required this.styles});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isAr ? 'إزاي بتذاكر؟' : 'How do you learn best?',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
        const SizedBox(height: 6),
        Text(isAr ? 'هنخصص تجربتك بناءً على أسلوبك' : 'We\'ll personalize your experience',
            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 22),
        ...styles.map((s) {
          final isSel = selected == s['id'];
          return GestureDetector(
            onTap: () => onSelect(s['id']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSel ? AppTheme.primaryColor.withOpacity(0.07) : theme.cardTheme.color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isSel ? AppTheme.primaryColor : Colors.grey.withOpacity(0.18),
                    width: isSel ? 2 : 1),
                boxShadow: isSel ? [BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: Row(children: [
                Text(s['emoji']!, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isAr ? s['labelAr']! : s['labelEn']!,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                          color: isSel ? AppTheme.primaryColor : null)),
                  Text(isAr ? s['descAr']! : s['descEn']!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ])),
                if (isSel) const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 22),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ── Page 3: Goals ─────────────────────────────────────────────────────────────
class _GoalsPage extends StatelessWidget {
  final bool isAr;
  final List<String> selected;
  final Function(String) onToggle;
  final List<Map<String, String>> goals;
  const _GoalsPage({required this.isAr, required this.selected, required this.onToggle, required this.goals});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isAr ? 'إيه هدفك؟' : 'What are your goals?',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
      const SizedBox(height: 6),
      Text(isAr ? 'اختر كل الأهداف اللي بتوصفك' : 'Select all that apply',
          style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      const SizedBox(height: 22),
      Wrap(
        spacing: 10, runSpacing: 10,
        children: goals.map((g) {
          final isSel = selected.contains(g['id']);
          return GestureDetector(
            onTap: () => onToggle(g['id']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: isSel ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: isSel ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.25)),
                boxShadow: isSel ? [BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.25),
                    blurRadius: 8, offset: const Offset(0, 3))] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(g['emoji']!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 7),
                Text(isAr ? g['labelAr']! : g['labelEn']!,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSel ? Colors.white : AppTheme.primaryColor,
                        fontSize: 13)),
              ]),
            ),
          );
        }).toList(),
      ),
    ]),
  );
}

// ── Page 4: Features ──────────────────────────────────────────────────────────
class _FeaturesPage extends StatelessWidget {
  final bool isAr;
  const _FeaturesPage({required this.isAr});

  static const _features = [
    {'emoji': '🚨', 'titleAr': 'وضع الطوارئ',  'titleEn': 'Exam Survival',  'descAr': 'أهم 10 نقاط قبل الامتحان بـ 24 ساعة', 'descEn': 'Top 10 must-know points 24h before exam'},
    {'emoji': '⚔️', 'titleAr': 'تحدي دراسي',   'titleEn': 'Study Battle',   'descAr': 'تنافس مع زملاءك في أسئلة سريعة',     'descEn': 'Compete with classmates in quick quizzes'},
    {'emoji': '📊', 'titleAr': 'تقرير أسبوعي', 'titleEn': 'Weekly Report',  'descAr': 'إحصائيات مذاكرتك كل أسبوع',           'descEn': 'Your full study stats every week'},
    {'emoji': '🗺',  'titleAr': 'خارطة الطريق', 'titleEn': 'Course Roadmap', 'descAr': 'تابع تقدمك وحدة بوحدة',              'descEn': 'Track your progress unit by unit'},
    {'emoji': '🤖', 'titleAr': 'امتحان تجريبي','titleEn': 'AI Mock Exam',   'descAr': 'الذكاء الاصطناعي يولد امتحان مخصص',   'descEn': 'AI generates a personalized practice exam'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = [Colors.red, AppTheme.primaryColor, const Color(0xFF7209B7), const Color(0xFF06D6A0), const Color(0xFFFF9F1C)];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isAr ? 'هتلاقي في ستادي هاب' : 'Inside StudyHub',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
        const SizedBox(height: 6),
        Text(isAr ? 'كل اللي محتاجه لتذاكر أحسن' : 'Everything you need to study smarter',
            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 22),
        ..._features.asMap().entries.map((e) {
          final f = e.value;
          final c = colors[e.key % colors.length];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withOpacity(0.25), width: 1.5),
            ),
            child: Row(children: [
              Container(width: 46, height: 46,
                  decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(f['emoji']!, style: const TextStyle(fontSize: 22)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAr ? f['titleAr']! : f['titleEn']!,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: c)),
                Text(isAr ? f['descAr']! : f['descEn']!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4)),
              ])),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Page 5: Ready ─────────────────────────────────────────────────────────────
class _ReadyPage extends StatelessWidget {
  final bool isAr;
  const _ReadyPage({required this.isAr});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🚀', style: TextStyle(fontSize: 80)),
      const SizedBox(height: 24),
      Text(isAr ? 'أنت جاهز لتبدأ!' : 'You are all set!',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 30),
          textAlign: TextAlign.center),
      const SizedBox(height: 14),
      Text(
        isAr
            ? 'رحلتك في المذاكرة الذكية بدأت\nاكسب XP وارتق في الترتيب 💪'
            : 'Your smart study journey starts now\nEarn XP and climb the leaderboard 💪',
        style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.7),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isAr ? '💡 نصائح للبداية:' : '💡 Getting started:',
              style: const TextStyle(fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor, fontSize: 13)),
          const SizedBox(height: 10),
          ...[
            isAr ? 'ذاكر كل يوم عشان تحافظ على السلسلة 🔥' : 'Study daily to keep your streak 🔥',
            isAr ? 'استخدم وضع الطوارئ قبل كل امتحان 🚨'   : 'Use Exam Survival before each exam 🚨',
            isAr ? 'تحدى أصدقاءك في منافسة دراسية ⚔️'    : 'Challenge friends in Study Battle ⚔️',
          ].map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 5, height: 5,
                  margin: const EdgeInsets.only(top: 6, right: 8, left: 2),
                  decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle)),
              Expanded(child: Text(tip, style: const TextStyle(fontSize: 13, height: 1.4))),
            ]),
          )),
        ]),
      ),
    ]),
  );
}
