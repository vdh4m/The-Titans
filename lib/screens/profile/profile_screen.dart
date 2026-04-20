import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:studyhub/generated/l10n/app_localizations.dart';
import 'package:studyhub/screens/payment/premium_screen.dart';
import 'package:studyhub/screens/payment/subscription_screen.dart';
import 'package:studyhub/utils/responsive.dart';
import 'package:studyhub/utils/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../admin/support_screen.dart';
import '../admin/doctor_approval_screen.dart';
import '../auth/welcome_screen.dart';
import 'gpa_tracker_screen.dart';
import 'student_portfolio_screen.dart';
import 'cv_builder_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final auth  = context.watch<AuthProvider>();
    final ap    = context.watch<AppProvider>();
    final user  = auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isAr  = ap.isArabic;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // XP level
    final level = user.totalXP < 100  ? (isAr ? 'مبتدئ'   : 'Beginner')
                : user.totalXP < 500  ? (isAr ? 'متعلم'   : 'Learner')
                : user.totalXP < 1500 ? (isAr ? 'متقدم'   : 'Advanced')
                : user.totalXP < 5000 ? (isAr ? 'خبير'    : 'Expert')
                :                       (isAr ? 'أسطورة'  : 'Legend');

    // Year arabic labels
    final yearLabels = isAr
        ? ['', 'الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة']
        : ['', 'First',  'Second',  'Third',    'Fourth',   'Fifth',    'Sixth'];
    final yearStr = user.year != null && user.year! <= 6
        ? (isAr ? 'السنة ${yearLabels[user.year!]}' : '${yearLabels[user.year!]} Year')
        : (isAr ? 'السنة ${user.year}' : 'Year ${user.year}');

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(l10n.profile)),
      body: ResponsiveBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(children: [

          // ── Hero gradient card ───────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF7209B7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(children: [
              // Avatar
              Stack(alignment: Alignment.bottomRight, children: [
                Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: Center(child: Text(
                    (user.fullName ?? user.email)[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                  )),
                ),
                if (user.isDoctor && user.isVerified)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.verified_rounded, color: AppTheme.verifiedColor, size: 18),
                  ),
              ]),
              const SizedBox(height: 12),
              Text(user.fullName ?? user.email.split('@').first,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 4),
              if (user.isStudent)
                Text(
                  isAr ? '${user.facultyAr} · ${user.universityAr}'
                       : '${user.facultyEn} · ${user.universityEn}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 10),
              // Role + Year + Level chips
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
                _WhiteChip(label: user.isDoctor ? (isAr ? '👨‍🏫 دكتور' : '👨‍🏫 Doctor') : (isAr ? '🎓 طالب' : '🎓 Student')),
                if (user.isStudent && user.year != null) _WhiteChip(label: yearStr),
                if (user.isStudent) _WhiteChip(label: '⚡ $level'),
                if (user.isStudent) _WhiteChip(label: '🔥 ${user.streakDays}'),
              ]),
              const SizedBox(height: 16),
              // Stats row — students only
              if (user.isStudent)
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _HeroStat(value: '${user.totalXP}',  label: 'XP'),
                  Container(width: 1, height: 30, color: Colors.white24),
                  _HeroStat(value: user.gpa > 0 ? user.gpa.toStringAsFixed(1) : '--', label: 'GPA'),
                  Container(width: 1, height: 30, color: Colors.white24),
                  _HeroStat(value: '${user.streakDays}', label: isAr ? 'يوم' : 'Days'),
                  Container(width: 1, height: 30, color: Colors.white24),
                  _HeroStat(value: isAr ? yearStr.replaceAll('السنة ', '').replaceAll(' Year', '')
                                         : user.year?.toString() ?? '--',
                            label: isAr ? 'السنة' : 'Year'),
                ]),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Student quick actions ────────────────────────────────────
          if (user.isStudent) ...[
            _Label(isAr ? 'ملفي الشخصي' : 'My Profile', isDark),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _ActionCard(
                icon: Icons.person_rounded, emoji: '🏅',
                label: isAr ? 'بورتفوليو' : 'Portfolio',
                sub: isAr ? 'عرض ملفك العام' : 'View your public profile',
                color: AppTheme.primaryColor, isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentPortfolioScreen())),
              )),
              const SizedBox(width: 12),
              Expanded(child: _ActionCard(
                icon: Icons.description_rounded, emoji: '📄',
                label: isAr ? 'سيرة ذاتية' : 'CV Builder',
                sub: isAr ? 'بناء الـ CV' : 'Build your CV',
                color: const Color(0xFF7209B7), isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CvBuilderScreen())),
              )),
            ]),
            const SizedBox(height: 12),
            _ActionCardWide(
              icon: Icons.grade_rounded, emoji: '📊',
              label: isAr ? 'متابعة الدرجات' : 'GPA Tracker',
              sub: isAr ? 'تتبع معدلك التراكمي' : 'Track your cumulative GPA',
              color: const Color(0xFF06D6A0), isDark: isDark,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GpaTrackerScreen())),
            ),
            const SizedBox(height: 12),
            _ActionCardWide(
              icon: Icons.workspace_premium_rounded, emoji: '👑',
              label: isAr ? 'الاشتراك المميز' : 'Premium',
              sub: isAr ? 'إدارة اشتراكك أو الترقية' : 'Manage or upgrade your subscription',
              color: const Color(0xFFFFB300), isDark: isDark,
              onTap: () {
                if (user.isPremium) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                }
              },
            ),
            const SizedBox(height: 20),
          ],

          // ── Year promotion card ──────────────────────────────────────
          if (user.isStudent) ...[
            _Label(isAr ? 'السنة الدراسية' : 'Academic Year', isDark),
            const SizedBox(height: 10),
            _YearCard(isAr: isAr, auth: auth, isDark: isDark, yearLabels: yearLabels),
            const SizedBox(height: 20),
          ],

          // ── Account info ─────────────────────────────────────────────
          _Label(isAr ? 'معلومات الحساب' : 'Account Info', isDark),
          const SizedBox(height: 10),
          _InfoBlock(isDark: isDark, children: [
            if (user.isStudent) ...[
              _InfoRow(icon: Icons.account_balance_outlined,
                  label: l10n.universityName, value: isAr ? user.universityAr : user.universityEn, isDark: isDark),
              _InfoRow(icon: Icons.school_outlined,
                  label: l10n.facultyName, value: isAr ? user.facultyAr : user.facultyEn, isDark: isDark),
              if (user.year != null)
                _InfoRow(icon: Icons.stairs_rounded,
                    label: l10n.year, value: yearStr, isDark: isDark),
            ],
            if (user.isDoctor) ...[
              // Show teachingAt list if populated
              for (var i = 0; i < user.teachingAt.length; i++)
                _InfoRow(
                  icon: Icons.account_balance_outlined,
                  label: isAr ? 'جامعة ${i + 1}' : 'University ${i + 1}',
                  value: () {
                    final t = user.teachingAt[i];
                    // Support both key formats: universityAr (registration) and uniAr (edit dialog)
                    final uni = isAr
                        ? (t['universityAr'] ?? t['uniAr'] ?? t['universityEn'] ?? t['uniEn'] ?? '')
                        : (t['universityEn'] ?? t['uniEn'] ?? t['universityAr'] ?? t['uniAr'] ?? '');
                    final fac = isAr
                        ? (t['facultyAr'] ?? t['facAr'] ?? t['facultyEn'] ?? t['facEn'] ?? '')
                        : (t['facultyEn'] ?? t['facEn'] ?? t['facultyAr'] ?? t['facAr'] ?? '');
                    return '$uni · $fac';
                  }(),
                  isDark: isDark,
                ),
              // Fallback: show legacy universityAr/facultyAr if teachingAt is empty
              if (user.teachingAt.isEmpty && (user.universityAr.isNotEmpty || user.universityEn.isNotEmpty)) ...[
                _InfoRow(
                  icon: Icons.account_balance_outlined,
                  label: isAr ? 'جامعة 1' : 'University 1',
                  value: '${isAr ? user.universityAr : user.universityEn} · ${isAr ? user.facultyAr : user.facultyEn}',
                  isDark: isDark,
                ),
              ],
              if (user.teachingAt.isEmpty && user.universityAr.isEmpty && user.universityEn.isEmpty)
                _InfoRow(
                  icon: Icons.info_outline_rounded,
                  label: isAr ? 'مواضع التدريس' : 'Teaching Positions',
                  value: isAr ? 'لم تُحدد بعد — اضغط تعديل' : 'Not set yet — tap Edit below',
                  isDark: isDark,
                ),
            ],
            _InfoRow(icon: Icons.email_outlined,
                label: l10n.email, value: user.email, isDark: isDark),
          ]),
          if (user.isDoctor) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showEditTeachingDialog(context, user, isAr, auth),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: Text(isAr ? 'تعديل جامعات التدريس' : 'Edit Teaching Positions'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                foregroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // ── Settings ─────────────────────────────────────────────────
          _Label(isAr ? 'الإعدادات' : 'Settings', isDark),
          const SizedBox(height: 10),
          _InfoBlock(isDark: isDark, children: [
            ListTile(
              leading: Icon(Icons.dark_mode_outlined, color: AppTheme.primaryColor),
              title: Text(ap.isDarkMode ? l10n.lightMode : l10n.darkMode),
              trailing: Switch(value: ap.isDarkMode, onChanged: (_) => ap.toggleTheme(), activeThumbColor: AppTheme.primaryColor),
            ),
            Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.07)),
            ListTile(
              leading: const Icon(Icons.language_outlined, color: AppTheme.primaryColor),
              title: Text(l10n.language),
              trailing: TextButton(
                onPressed: () => ap.setLocale(isAr ? const Locale('en') : const Locale('ar')),
                child: Text(isAr ? 'English' : 'العربية',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // ── Support & Admin ──────────────────────────────────────────
          _ActionCardWide(
            icon: Icons.headset_mic_rounded, emoji: '🎧',
            label: isAr ? 'الدعم الفني' : 'Support',
            sub: isAr ? 'تواصل مع فريق الدعم' : 'Chat with support team',
            color: AppTheme.primaryColor, isDark: isDark,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SupportScreen())),
          ),
          const SizedBox(height: 8),
          if (user.isAdmin) ...[
            _ActionCardWide(
              icon: Icons.admin_panel_settings_rounded, emoji: '🔐',
              label: 'Doctor Requests',
              sub: 'Approve / reject doctor accounts',
              color: Colors.red, isDark: isDark,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DoctorApprovalScreen())),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),

          // ── Logout ───────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (_) => false);
              }
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            label: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
            const SizedBox(height: 80),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Widgets ─────────────────────────────────────

class _Label extends StatelessWidget {
  final String text; final bool isDark;
  const _Label(this.text, this.isDark);
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: TextStyle(
        fontWeight: FontWeight.w800, fontSize: 12,
        color: isDark ? Colors.white54 : Colors.black54,
        letterSpacing: 0.4)),
  );
}

class _WhiteChip extends StatelessWidget {
  final String label;
  const _WhiteChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
  );
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  const _HeroStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]);
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final String emoji, label, sub; final Color color;
  final bool isDark; final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.emoji, required this.label,
      required this.sub, required this.color, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
      ]),
    ),
  );
}

class _ActionCardWide extends StatelessWidget {
  final IconData icon; final String emoji, label, sub; final Color color;
  final bool isDark; final VoidCallback onTap;
  const _ActionCardWide({required this.icon, required this.emoji, required this.label,
      required this.sub, required this.color, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
          Text(sub, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
      ]),
    ),
  );
}

class _InfoBlock extends StatelessWidget {
  final List<Widget> children; final bool isDark;
  const _InfoBlock({required this.children, required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
          width: 1.5),
    ),
    child: Column(children: children),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value; final bool isDark;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final divColor = isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.07);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 10),
          // Fixed-width label so value always aligns to the right consistently
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54, fontSize: 13)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87),
              textAlign: TextAlign.end,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ),
      Divider(height: 1, color: divColor),
    ]);
  }
}

// ─────────────────── Year Promotion Card ─────────────────────────────────────
class _YearCard extends StatelessWidget {
  final bool isAr, isDark;
  final AuthProvider auth;
  final List<String> yearLabels;
  const _YearCard({required this.isAr, required this.isDark, required this.auth, required this.yearLabels});

  void _confirm(BuildContext context) async {
    final user       = auth.currentUser!;
    final current    = user.year ?? 1;
    final max        = auth.getMaxYearForUser();
    final nextYear   = current + 1;
    if (current >= max) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAr ? 'أنت في السنة النهائية بالفعل!' : 'Already in final year!'),
          backgroundColor: Colors.orange));
      return;
    }

    final next = nextYear <= 6 ? (isAr ? 'السنة ${yearLabels[nextYear]}' : '${yearLabels[nextYear]} Year')
                               : (isAr ? 'السنة $nextYear' : 'Year $nextYear');
    final curr = current <= 6 ? (isAr ? 'السنة ${yearLabels[current]}' : '${yearLabels[current]} Year')
                              : (isAr ? 'السنة $current' : 'Year $current');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'الانتقال للسنة التالية' : 'Move to Next Year'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Visual year transition
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFFF9F1C).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF9F1C).withOpacity(0.25))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _YearBubble(label: curr, color: Colors.grey),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.arrow_forward_rounded, color: Color(0xFFFF9F1C))),
              _YearBubble(label: next, color: Color(0xFFFF9F1C)),
            ]),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text(
                isAr ? 'مواد سنتك الحالية ستُخفى وستظهر مواد السنة التالية. لا يمكن التراجع.'
                     : 'Current year courses will hide and next year courses will appear. Cannot undo.',
                style: const TextStyle(fontSize: 12, color: Colors.red, height: 1.5),
              )),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9F1C), foregroundColor: Colors.black87,
                minimumSize: const Size(80, 40)),
            child: Text(isAr ? 'تأكيد' : 'Confirm'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final newYear = await auth.promoteToNextYear();
      if (context.mounted && newYear != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isAr ? 'تم الانتقال بنجاح 🎉' : 'Year updated successfully 🎉'),
            backgroundColor: const Color(0xFF06D6A0)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user    = auth.currentUser!;
    final current = user.year ?? 1;
    final max     = auth.getMaxYearForUser();
    final isMax   = current >= max;
    final gold    = const Color(0xFFFF9F1C);

    final currLabel = current <= 6
        ? (isAr ? 'السنة ${yearLabels[current]}' : '${yearLabels[current]} Year')
        : (isAr ? 'السنة $current' : 'Year $current');
    final nextLabel = (current + 1) <= 6
        ? (isAr ? 'السنة ${yearLabels[current + 1]}' : '${yearLabels[current + 1]} Year')
        : (isAr ? 'السنة ${current + 1}' : 'Year ${current + 1}');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMax
            ? (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03))
            : gold.withOpacity(isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isMax
                ? (isDark ? Colors.white12 : Colors.black12)
                : gold.withOpacity(0.45),
            width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Current year display
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: isMax ? Colors.grey.withOpacity(0.12) : gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                isMax ? Icons.school_rounded : Icons.stairs_rounded,
                color: isMax ? Colors.grey : gold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isAr ? 'السنة الحالية' : 'Current Year',
                style: TextStyle(fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(currLabel, style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 16,
                color: isMax ? (isDark ? Colors.white54 : Colors.black54) : gold)),
          ])),
          if (isMax)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFF06D6A0).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF06D6A0).withOpacity(0.3))),
              child: Text(isAr ? 'السنة النهائية 🎓' : 'Final Year 🎓',
                  style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
        if (!isMax) ...[
          const SizedBox(height: 14),
          Divider(height: 1, color: gold.withOpacity(0.2)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAr ? 'السنة التالية' : 'Next Year',
                  style: TextStyle(fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
              Text(nextLabel, style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54)),
            ])),
            ElevatedButton.icon(
              onPressed: () => _confirm(context),
              icon: const Icon(Icons.upgrade_rounded, size: 16),
              label: Text(isAr ? 'انتقال' : 'Promote'),
              style: ElevatedButton.styleFrom(
                backgroundColor: gold, foregroundColor: Colors.black87,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _YearBubble extends StatelessWidget {
  final String label; final Color color;
  const _YearBubble({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.4), width: 1.5)),
      child: Icon(Icons.school_rounded, color: color, size: 20),
    ),
    const SizedBox(height: 5),
    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  ]);
}

// ── Edit Teaching Positions dialog ────────────────────────────────────────────
void _showEditTeachingDialog(
    BuildContext context, dynamic user, bool isAr, AuthProvider auth) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditTeachingDialog(
      initial: List<Map<String, dynamic>>.from(user.teachingAt),
      isAr: isAr,
      uid: user.uid,
      auth: auth,
    ),
  );
}

class _EditTeachingDialog extends StatefulWidget {
  final List<Map<String, dynamic>> initial;
  final bool isAr;
  final String uid;
  final AuthProvider auth;
  const _EditTeachingDialog({
    required this.initial, required this.isAr,
    required this.uid, required this.auth,
  });
  @override
  State<_EditTeachingDialog> createState() => _EditTeachingDialogState();
}

class _EditTeachingDialogState extends State<_EditTeachingDialog> {
  // ignore: unnecessary_question_mark
  late List<Map<String, dynamic?>> _entries;
  bool _saving = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _entries = widget.initial.map((e) {
      final uniAr = (e['universityAr'] ?? e['uniAr'] ?? '') as String;
      final facAr = (e['facultyAr'] ?? e['facAr'] ?? '') as String;

      Map<String, dynamic>? selectedUni;
      Map<String, dynamic>? selectedFac;

      for (var uni in AppConstants.egyptianUniversities) {
        if (uni['nameAr'] == uniAr || uni['nameEn'] == (e['universityEn'] ?? '')) {
          selectedUni = uni;
          final facs = List<Map<String, dynamic>>.from(uni['faculties']);
          for (var fac in facs) {
            if (fac['nameAr'] == facAr || fac['nameEn'] == (e['facultyEn'] ?? '')) {
              selectedFac = fac;
              break;
            }
          }
          break;
        }
      }
      return {'id': UniqueKey(), 'uni': selectedUni, 'fac': selectedFac};
    }).toList();

    if (_entries.isEmpty) {
      _entries.add({'id': UniqueKey(), 'uni': null, 'fac': null});
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _addEntry() {
    setState(() => _entries.add({'id': UniqueKey(), 'uni': null, 'fac': null}));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void _removeEntry(int i) => setState(() => _entries.removeAt(i));

  Future<void> _save() async {
    setState(() => _saving = true);
    
    final validPairs = _entries.where((e) => e['uni'] != null && e['fac'] != null).toList();
    final list = validPairs.map((e) => {
      'universityAr': ((e['uni'] as Map)['nameAr'] as String),
      'universityEn': ((e['uni'] as Map)['nameEn'] as String),
      'facultyAr':    ((e['fac'] as Map)['nameAr'] as String),
      'facultyEn':    ((e['fac'] as Map)['nameEn'] as String),
    }).toList();

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'teachingAt': list});
      widget.auth.reloadCurrentUser();
    } catch (_) {}
    if (mounted) { setState(() => _saving = false); Navigator.pop(context); }
  }

  Widget _dropdown<T>(String label, IconData icon, T? value, List<T> items,
      String Function(T) getLabel, ValueChanged<T?> onChange, [bool enabled = true]) {
    return DropdownButtonFormField<T>(
      initialValue: value, isExpanded: true,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, size: 18), enabled: enabled,
        isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(getLabel(e), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: enabled ? onChange : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr  = widget.isAr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1730) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              const Icon(Icons.school_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Expanded(child: Text(
                isAr ? 'تعديل جامعات التدريس' : 'Edit Teaching Positions',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              )),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl, // Use our own controller instead of DraggableScrollableSheet ctrl to allow animation
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: _entries.length,
              itemBuilder: (_, i) {
                final e = _entries[i];
                final selUni = e['uni'] as Map<String, dynamic>?;
                final selFac = e['fac'] as Map<String, dynamic>?;
                final facs = selUni != null ? List<Map<String, dynamic>>.from(selUni['faculties']) : <Map<String, dynamic>>[];

                return Container(
                  key: e['id'] as Key,
                  margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(isAr ? 'موقع ${i + 1}' : 'Position ${i + 1}',
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                      const Spacer(),
                      if (_entries.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                          onPressed: () => _removeEntry(i),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    _dropdown(
                      isAr ? 'اختر الجامعة' : 'Select University', Icons.account_balance_outlined, selUni, AppConstants.egyptianUniversities,
                      (u) => isAr ? u['nameAr'] : u['nameEn'],
                      (u) => setState(() { _entries[i]['uni'] = u; _entries[i]['fac'] = null; }),
                    ),
                    const SizedBox(height: 8),
                    _dropdown(
                      isAr ? 'اختر الكلية' : 'Select Faculty', Icons.school_outlined, selFac, facs,
                      (f) => isAr ? f['nameAr'] : f['nameEn'],
                      (f) => setState(() => _entries[i]['fac'] = f),
                      selUni != null,
                    ),
                  ]),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(children: [
                OutlinedButton.icon(
                  onPressed: _addEntry,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(isAr ? 'إضافة جامعة أخرى' : 'Add Another University'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    side: const BorderSide(color: AppTheme.primaryColor),
                    foregroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded, color: Colors.white),
                  label: Text(
                    _saving ? (isAr ? 'جاري الحفظ...' : 'Saving…') : (isAr ? 'حفظ التعديلات' : 'Save Changes'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor, minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}