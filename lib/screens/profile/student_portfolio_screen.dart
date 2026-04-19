import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:studyhub/screens/tools/badges_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class StudentPortfolioScreen extends StatelessWidget {
  const StudentPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAr = context.watch<AppProvider>().isArabic;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final earned = List<String>.from(user.earnedBadges);
    final badges = BadgesScreen.getBadges(user, earned);
    final unlockedBadges = badges.where((b) => b['unlocked'] as bool).toList();
    final xpLevel = user.totalXP < 100 ? (isAr ? 'مبتدئ' : 'Beginner')
        : user.totalXP < 500 ? (isAr ? 'متعلم' : 'Learner')
        : user.totalXP < 1500 ? (isAr ? 'متقدم' : 'Advanced')
        : user.totalXP < 5000 ? (isAr ? 'خبير' : 'Expert')
        : (isAr ? 'أسطورة' : 'Legend');

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'ملفي الشخصي' : 'My Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              final text = isAr
                  ? 'ملفي على StudyHub:\n'
                    '${user.fullName ?? user.email}\n'
                    '${user.facultyAr} - ${user.universityAr}\n'
                    'XP: ${user.totalXP} | GPA: ${user.gpa.toStringAsFixed(1)} | '
                    'Streak: ${user.streakDays} يوم'
                  : 'My StudyHub Profile:\n'
                    '${user.fullName ?? user.email}\n'
                    '${user.facultyEn} - ${user.universityEn}\n'
                    'XP: ${user.totalXP} | GPA: ${user.gpa.toStringAsFixed(1)} | '
                    'Streak: ${user.streakDays} days';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isAr ? 'تم نسخ الملف الشخصي' : 'Profile copied to clipboard'),
                backgroundColor: AppTheme.primaryColor,
              ));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [

          // ── Hero Banner ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, Color(0xFF7209B7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(children: [
              // Avatar
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Center(
                  child: Text(
                    (user.fullName ?? user.email)[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.fullName ?? user.email.split('@').first,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                isAr ? '${user.facultyAr} - ${user.universityAr}' : '${user.facultyEn} - ${user.universityEn}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (user.isStudent && user.year != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAr ? 'السنة ${user.year}' : 'Year ${user.year}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // Level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F1C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('⚡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(xpLevel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                ]),
              ),
            ]),
          ),

          // ── Stats Row ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(value: '${user.totalXP}', label: 'XP', icon: '⚡'),
                _Divider(),
                _StatItem(value: user.gpa > 0 ? user.gpa.toStringAsFixed(1) : '--', label: 'GPA', icon: '📚'),
                _Divider(),
                _StatItem(value: '${user.streakDays}', label: isAr ? 'يوم' : 'Days', icon: '🔥'),
                _Divider(),
                _StatItem(value: '${unlockedBadges.length}', label: isAr ? 'شارة' : 'Badges', icon: '🏅'),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── About Section ──────────────────────────────────────
              _SectionHeader(title: isAr ? 'عن الطالب' : 'About', icon: Icons.person_outline_rounded),
              const SizedBox(height: 12),
              _InfoCard(children: [
                _InfoRow(icon: Icons.school_rounded, label: isAr ? 'الجامعة' : 'University',
                    value: isAr ? user.universityAr : user.universityEn),
                _InfoRow(icon: Icons.account_balance_rounded, label: isAr ? 'الكلية' : 'Faculty',
                    value: isAr ? user.facultyAr : user.facultyEn),
                if (user.year != null)
                  _InfoRow(icon: Icons.calendar_today_rounded, label: isAr ? 'السنة' : 'Year',
                      value: isAr ? 'السنة ${user.year}' : 'Year ${user.year}'),
                _InfoRow(icon: Icons.email_outlined, label: isAr ? 'البريد' : 'Email',
                    value: user.email),
              ]),
              const SizedBox(height: 24),

              // ── Study Stats ────────────────────────────────────────
              _SectionHeader(title: isAr ? 'إحصائيات المذاكرة' : 'Study Stats', icon: Icons.bar_chart_rounded),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatCard(emoji: '⚡', value: '${user.totalXP}', label: 'Total XP', color: const Color(0xFFFF9F1C))),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(emoji: '🔥', value: '${user.streakDays}', label: isAr ? 'أيام السلسلة' : 'Streak Days', color: Colors.red)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatCard(
                  emoji: '📊',
                  value: user.totalXP < 100 ? 'Beginner'
                      : user.totalXP < 500 ? 'Learner'
                      : user.totalXP < 1500 ? 'Advanced'
                      : user.totalXP < 5000 ? 'Expert' : 'Legend',
                  label: isAr ? 'المستوى' : 'Level',
                  color: AppTheme.primaryColor,
                )),
                const SizedBox(width: 12),
                if (user.gpa > 0)
                  Expanded(child: _StatCard(emoji: '🎯', value: user.gpa.toStringAsFixed(1), label: 'GPA', color: const Color(0xFF06D6A0)))
                else
                  Expanded(child: _StatCard(emoji: '🎯', value: '--', label: 'GPA', color: const Color(0xFF06D6A0))),
              ]),
              const SizedBox(height: 24),

              // ── Badges ─────────────────────────────────────────────
              if (unlockedBadges.isNotEmpty) ...[
                _SectionHeader(title: isAr ? 'الشارات المكتسبة' : 'Earned Badges', icon: Icons.emoji_events_rounded),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: unlockedBadges.map((b) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9F1C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF9F1C).withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(b['emoji'] as String, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(isAr ? b['titleAr'] as String : b['titleEn'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFFF9F1C))),
                    ]),
                  )).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // ── GPA breakdown ──────────────────────────────────────
              if (user.grades.isNotEmpty) ...[
                _SectionHeader(title: isAr ? 'الدرجات' : 'Grades', icon: Icons.grade_rounded),
                const SizedBox(height: 12),
                _InfoCard(children: user.grades.take(5).map((g) =>
                  _InfoRow(
                    icon: Icons.book_outlined,
                    label: g['subject'] as String? ?? '',
                    value: '${g['grade']}%',
                  ),
                ).toList()),
              ],

              const SizedBox(height: 80),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label, icon;
  const _StatItem({required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(icon, style: const TextStyle(fontSize: 20)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
    Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
  ]);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.2));
}

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: AppTheme.primaryColor)),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
  ]);
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black.withOpacity(0.07), width: 1.5)),
    child: Column(children: children.asMap().entries.map((e) => Column(children: [
      e.value,
      if (e.key < children.length - 1) Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
    ])).toList()),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.grey[500]),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String emoji, value, label; final Color color;
  const _StatCard({required this.emoji, required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.2), width: 1.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]),
  );
}
