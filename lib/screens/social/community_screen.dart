import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import 'study_groups_screen.dart';
import 'ask_community_screen.dart';
import 'study_battle_screen.dart';
import '../planner/exam_countdown_screen.dart';
import '../planner/task_manager_screen.dart';
import '../tools/formula_sheet_screen.dart';
import '../tools/note_taking_screen.dart';
import '../tools/daily_challenge_screen.dart';
import '../tools/badges_screen.dart';
import '../tools/explain_image_screen.dart';
import '../study/leaderboard_screen.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(isAr ? 'المجتمع والأدوات' : 'Community & Tools'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Daily Challenge Banner — students only
            if (user != null && user.isStudent) GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DailyChallengeScreen())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9F1C), Color(0xFFFF6B35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  const Text('\u26A1', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      isAr ? 'تحدي اليوم جاهز!' : "Today's challenge is ready!",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      isAr ? 'أجب وأكسب 50 XP' : 'Answer and earn 50 XP',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ])),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Social Section
            _SectionTitle(title: isAr ? 'التواصل' : 'Social'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _MenuCard(
                emoji: '\uD83D\uDC65',
                label: isAr ? 'مجموعات الدراسة' : 'Study Groups',
                color: AppTheme.primaryColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupsScreen())),
              )),
              const SizedBox(width: 12),
              Expanded(child: _MenuCard(
                emoji: '\u2753',
                label: isAr ? 'اسأل المجتمع' : 'Ask Community',
                color: const Color(0xFF7209B7),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskCommunityScreen())),
              )),
            ]),
            const SizedBox(height: 12),

            // Study Battle - students only
            if (user != null && user.isStudent) _MenuCardWide(
              emoji: '\u2694\uFE0F',
              label: isAr ? 'تحدي دراسي مع صديق' : 'Study Battle',
              subtitle: isAr
                  ? '10 أسئلة - مين أسرع؟ العب الآن!'
                  : '10 questions - Who is faster? Play now!',
              color: Colors.red,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyBattleScreen())),
            ),
            const SizedBox(height: 20),

            // Leaderboard - everyone
            if (user != null) ...[
              _SectionTitle(title: isAr ? 'المتصدرون' : 'Leaderboard'),
              const SizedBox(height: 10),
              _MenuCardWide(
                emoji: '\uD83C\uDFC6',
                label: isAr ? 'ترتيب الطلاب' : 'Student Rankings',
                subtitle: isAr
                    ? (user.isDoctor ? 'أفضل طلاب كليتك' : 'مقارنة مع زملائك في نفس السنة')
                    : (user.isDoctor ? 'Top students in your faculty' : 'See how you rank vs your classmates'),
                color: const Color(0xFF06D6A0),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderboardScreen(user: user))),
              ),
              const SizedBox(height: 20),
            ],

            // Planner
            _SectionTitle(title: isAr ? 'التخطيط' : 'Planner'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _MenuCard(
                emoji: '\uD83D\uDCC6',
                label: isAr ? 'مواعيد الامتحانات' : 'Exam Countdown',
                color: Colors.red,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamCountdownScreen())),
              )),
              const SizedBox(width: 12),
              Expanded(child: _MenuCard(
                emoji: '\u2705',
                label: isAr ? 'المهام' : 'Tasks',
                color: const Color(0xFF06D6A0),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskManagerScreen())),
              )),
            ]),
            const SizedBox(height: 20),

            // Academic Tools
            _SectionTitle(title: isAr ? 'الأدوات الأكاديمية' : 'Academic Tools'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _MenuCard(
                emoji: '\uD83D\uDCDD',
                label: isAr ? 'ملاحظاتي' : 'My Notes',
                color: const Color(0xFFFF9F1C),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteTakingScreen())),
              )),
              const SizedBox(width: 12),
              Expanded(child: _MenuCard(
                emoji: '\uD83D\uDD22',
                label: isAr ? 'ورقة المعادلات' : 'Formula Sheet',
                color: Colors.indigo,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FormulaSheetScreen())),
              )),
            ]),
            const SizedBox(height: 12),
            _MenuCardWide(
              emoji: '\uD83D\uDD2C',
              label: isAr ? 'اشرح هذه الصورة (AI)' : 'Explain This Image (AI)',
              subtitle: isAr
                  ? 'صوّر معادلة أو رسم وأحصل على شرح فوري'
                  : 'Photograph any equation or diagram for instant explanation',
              color: const Color(0xFF7209B7),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExplainImageScreen())),
            ),
            const SizedBox(height: 20),

            // Achievements — students only
            if (user != null && user.isStudent) _SectionTitle(title: isAr ? 'الإنجازات' : 'Achievements'),
            if (user != null && user.isStudent) const SizedBox(height: 10),
            if (user != null && user.isStudent) _MenuCardWide(
              emoji: '\uD83C\uDFC5',
              label: isAr ? 'الشارات والإنجازات' : 'Badges & Achievements',
              subtitle: isAr
                  ? '${user.totalXP} XP  -  ${user.streakDays} يوم سلسلة'
                  : '${user.totalXP} XP  -  ${user.streakDays} day streak',
              color: const Color(0xFFFF9F1C),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _MenuCard extends StatelessWidget {
  final String emoji, label;
  final Color color;
  final VoidCallback onTap;
  const _MenuCard({required this.emoji, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 90,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

class _MenuCardWide extends StatelessWidget {
  final String emoji, label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuCardWide({required this.emoji, required this.label, required this.subtitle, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
      ]),
    ),
  );
}