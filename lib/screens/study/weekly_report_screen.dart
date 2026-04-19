import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../payment/paywall_gate.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});
  @override State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  Map<String, dynamic>? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadReport();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final snap = await FirebaseFirestore.instance
        .collection('study_progress')
        .where('userId', isEqualTo: user.uid)
        .get();

    final weekSessions = snap.docs
        .map((d) => d.data())
        .where((d) {
          final s = d['startTime'] as String?;
          if (s == null) return false;
          final dt = DateTime.tryParse(s);
          return dt != null && dt.isAfter(weekAgo);
        })
        .toList();

    final totalSeconds = weekSessions.fold<int>(
        0, (sum, s) => sum + (s['duration'] as int? ?? 0));
    final totalMinutes = totalSeconds ~/ 60;

    // Per-subject
    final Map<String, int> subjectMinutes = {};
    for (final s in weekSessions) {
      final isAr = context.read<AppProvider>().isArabic;
      final sub =
          s['courseName'] as String? ?? (isAr ? 'عام' : 'General');
      subjectMinutes[sub] =
          (subjectMinutes[sub] ?? 0) + ((s['duration'] as int? ?? 0) ~/ 60);
    }

    // Best day
    final Map<String, int> dayMinutes = {};
    for (final s in weekSessions) {
      final dateStr = s['startTime'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      final day = '${date.year}-${date.month}-${date.day}';
      dayMinutes[day] =
          (dayMinutes[day] ?? 0) + ((s['duration'] as int? ?? 0) ~/ 60);
    }
    String? bestDay;
    int bestDayMinutes = 0;
    dayMinutes.forEach((d, m) {
      if (m > bestDayMinutes) {
        bestDayMinutes = m;
        bestDay = d;
      }
    });

    setState(() {
      _report = {
        'totalHours': totalMinutes ~/ 60,
        'totalMins': totalMinutes % 60,
        'totalMinutesRaw': totalMinutes,
        'sessions': weekSessions.length,
        'subjectBreakdown': subjectMinutes,
        'bestDay': bestDay,
        'bestDayMinutes': bestDayMinutes,
        'daysStudied': dayMinutes.keys.length,
        'xpThisWeek': user.weeklyXP,
        'streak': user.streakDays,
      };
      _loading = false;
    });
    _animCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    final user = context.watch<AuthProvider>().currentUser;

    // ── Paywall: advancedReports requires Pro ──────────────────────────────
    if (user != null && !PaywallGate.canAccess(user, PremiumFeature.advancedReports)) {
      return Scaffold(
        appBar: AppBar(title: Text(isAr ? 'تقرير الأسبوع' : 'Weekly Report')),
        body: Center(
          child: PaywallGate(
            feature: PremiumFeature.advancedReports,
            child: const SizedBox(height: 300, width: double.infinity),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'تقرير الأسبوع' : 'Weekly Report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [

                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, Color(0xFF7209B7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(children: [
                      const Text('📊', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text(
                        isAr ? 'تقرير أسبوعك' : 'Your Weekly Recap',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatPill(
                            label: isAr ? 'ساعات' : 'Hours',
                            value:
                                '${_report!["totalHours"]}h ${_report!["totalMins"]}m',
                            emoji: '⏱',
                          ),
                          _StatPill(
                            label: isAr ? 'جلسات' : 'Sessions',
                            value: '${_report!["sessions"]}',
                            emoji: '🎯',
                          ),
                          _StatPill(
                            label: isAr ? 'أيام' : 'Days',
                            value: '${_report!["daysStudied"]}/7',
                            emoji: '📅',
                          ),
                        ],
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // XP & Streak
                  Row(children: [
                    Expanded(
                      child: _InfoCard(
                        emoji: '⚡',
                        title: isAr ? 'XP هذا الأسبوع' : 'XP This Week',
                        value: '+${_report!["xpThisWeek"]}',
                        color: const Color(0xFFFF9F1C),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        emoji: '🔥',
                        title: isAr ? 'أطول سلسلة' : 'Current Streak',
                        value:
                            '${_report!["streak"]} ${isAr ? "يوم" : "days"}',
                        color: Colors.red,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Subject breakdown
                  if ((_report!['subjectBreakdown'] as Map).isNotEmpty) ...[
                    _SectionCard(
                      title: isAr
                          ? 'توزيع المذاكرة على المواد'
                          : 'Study Breakdown by Subject',
                      child: _SubjectBreakdown(
                        breakdown: Map<String, int>.from(
                            _report!['subjectBreakdown'] as Map),
                        isAr: isAr,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Best day
                  if (_report!['bestDay'] != null)
                    _SectionCard(
                      title: isAr ? 'أفضل يوم' : 'Best Day',
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9F1C).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('🏆',
                              style: TextStyle(fontSize: 28)),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDay(
                                  _report!['bestDay'] as String, isAr),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            Text(
                              '${_report!["bestDayMinutes"]} ${isAr ? "دقيقة مذاكرة" : "minutes of studying"}',
                              style: const TextStyle(
                                  color: Color(0xFFFF9F1C),
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ]),
                    ),
                  const SizedBox(height: 16),

                  // Motivational message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06D6A0).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF06D6A0).withOpacity(0.3)),
                    ),
                    child: Text(
                      _motivation(
                          _report!['totalMinutesRaw'] as int, isAr),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
    );
  }

  String _formatDay(String iso, bool isAr) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const ar = ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    const en = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return isAr ? ar[d.weekday - 1] : en[d.weekday - 1];
  }

  String _motivation(int minutes, bool isAr) {
    if (minutes == 0) {
      return isAr
          ? 'الأسبوع ده مكنتش هنا! الأسبوع الجاي هيبقى أحسن 💪'
          : "You didn't study this week! Next week will be better 💪";
    }
    if (minutes < 60) {
      return isAr
          ? 'بداية كويسة! زيّد شوية الأسبوع الجاي'
          : 'Good start! Try to add more next week';
    }
    if (minutes < 300) {
      return isAr
          ? 'شغل كويس! استمر وهتوصل لأهدافك'
          : 'Good work! Keep it up and you will reach your goals';
    }
    if (minutes < 600) {
      return isAr
          ? 'أسبوع ممتاز! أنت على الطريق الصح 🔥'
          : 'Excellent week! You are on the right track 🔥';
    }
    return isAr
        ? 'أسبوع خرافي! أنت من أكتر الطلاب جدية في كليتك 👑'
        : 'Incredible week! You are among the most dedicated students 👑';
  }
}

// ── Subject Breakdown Widget ───────────────────────────────────────────────────
class _SubjectBreakdown extends StatelessWidget {
  final Map<String, int> breakdown;
  final bool isAr;
  const _SubjectBreakdown({required this.breakdown, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.isEmpty ? 1 : sorted.first.value;

    return Column(
      children: sorted.map((entry) {
        final pct = maxVal > 0 ? entry.value / maxVal : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.value} ${isAr ? "دقيقة" : "min"}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: Colors.grey.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(
                      AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label, value, emoji;
  const _StatPill(
      {required this.label, required this.value, required this.emoji});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ]);
}

class _InfoCard extends StatelessWidget {
  final String emoji, title, value;
  final Color color;
  const _InfoCard(
      {required this.emoji,
      required this.title,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: color.withOpacity(0.25), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: color)),
          Text(title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ]),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.black.withOpacity(0.07), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 14),
          child,
        ]),
      );
}