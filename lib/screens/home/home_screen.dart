import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studyhub/generated/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';
import '../../models/course_model.dart';
import '../../widgets/course_card.dart';
import 'notification_center_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final auth  = context.watch<AuthProvider>();
    final ap    = context.watch<AppProvider>();
    final user  = auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isAr  = ap.isArabic;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 9),
          Text(l10n.appName,
              style: const TextStyle(
                  color: AppTheme.primaryColor, fontWeight: FontWeight.w900)),
        ]),
        actions: [
          _NotifBell(uid: user.uid),
          IconButton(
            icon: Icon(ap.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: AppTheme.primaryColor),
            onPressed: ap.toggleTheme,
          ),
          IconButton(
            icon: Text(isAr ? 'EN' : 'ع',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontSize: 13)),
            onPressed: () =>
                ap.setLocale(isAr ? const Locale('en') : const Locale('ar')),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: R.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GreetingCard(user: user, isAr: isAr),
                const SizedBox(height: 24),

                Text(isAr ? '📚 المواد الرئيسية' : '📚 Main Courses',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _CourseList(user: user, isAr: isAr, l10n: l10n, isMain: true),
                const SizedBox(height: 24),

                Text(isAr ? '🧩 المواد الجانبية' : '🧩 Side Courses',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _CourseList(user: user, isAr: isAr, l10n: l10n, isMain: false),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Notification Bell ─────────────────────────────────────────────────────────
class _NotifBell extends StatelessWidget {
  final String uid;
  const _NotifBell({required this.uid});
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('notifications')
        .where('recipients', arrayContains: uid)
        .where('read', isEqualTo: false)
        .limit(99)
        .snapshots(),
    builder: (_, snap) {
      final count = snap.data?.docs.length ?? 0;
      return Stack(children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: AppTheme.primaryColor,
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NotificationCenterScreen())),
        ),
        if (count > 0)
          Positioned(right: 8, top: 8, child: Container(
            width: 16, height: 16,
            decoration: const BoxDecoration(
                color: Colors.red, shape: BoxShape.circle),
            child: Center(child: Text(count > 9 ? '9+' : '$count',
                style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))),
          )),
      ]);
    },
  );
}

// ── Greeting card ─────────────────────────────────────────────────────────────
class _GreetingCard extends StatelessWidget {
  final dynamic user;
  final bool isAr;
  const _GreetingCard({required this.user, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final name = user.isDoctor
        ? (user.fullName ?? (isAr ? 'دكتور' : 'Doctor'))
        : (user.fullName ?? (isAr ? 'طالب' : 'Student'));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.isWide(context) ? 28 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.28),
            blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment:
            isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (user.isDoctor && user.isVerified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.verified_rounded,
                      color: AppTheme.verifiedColor, size: 16),
                  const SizedBox(width: 4),
                  Text(isAr ? 'موثق' : 'Verified',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              )
            else
              const SizedBox(),
            const Icon(Icons.school_rounded, color: Colors.white30, size: 38),
          ]),
          const SizedBox(height: 10),
          Text(isAr ? 'أهلاً، $name 👋' : 'Hello, $name 👋',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: R.isWide(context) ? 24 : 21,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
            isAr
                ? '${user.facultyAr} · ${user.universityAr}'
                : '${user.facultyEn} · ${user.universityEn}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (user.isStudent && user.year != null) ...[
            const SizedBox(height: 4),
            Text(isAr ? 'السنة ${user.year}' : 'Year ${user.year}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          if (user.isStudent) ...[
            const SizedBox(height: 12),
            Row(children: [
              _StatChip(emoji: '⚡', value: '${user.totalXP} XP'),
              const SizedBox(width: 8),
              _StatChip(
                  emoji: '🔥',
                  value: '${user.streakDays} ${isAr ? "يوم" : "days"}'),
            ]),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji, value;
  const _StatChip({required this.emoji, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 5),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    ]),
  );
}

// ── Course list — responsive grid ─────────────────────────────────────────────
class _CourseList extends StatelessWidget {
  final dynamic user;
  final bool isAr, isMain;
  final AppLocalizations l10n;
  const _CourseList(
      {required this.user,
      required this.isAr,
      required this.l10n,
      required this.isMain});

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance.collection('courses');
    if (isMain) {
      if (user.isStudent) {
        q = q
            .where('universityAr', isEqualTo: user.universityAr)
            .where('facultyAr', isEqualTo: user.facultyAr)
            .where('year', isEqualTo: user.year)
            .where('type', isEqualTo: 'main');
      } else {
        q = q
            .where('doctorId', isEqualTo: user.uid)
            .where('type', isEqualTo: 'main');
      }
    } else {
      q = q.where('type', isEqualTo: 'side').limit(30);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.noCoursesYet,
                  style: TextStyle(color: Colors.grey[600])),
            ),
          );
        }

        final courses = snap.data!.docs
            .map((d) => CourseModel.fromMap(d.data() as Map<String, dynamic>))
            .toList();

        final cols = R.gridCols(context, mobile: 1, tablet: 2, desktop: 3);

        if (cols == 1) {
          // Mobile: simple list
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                CourseCard(course: courses[i], isAr: isAr, isSide: !isMain),
          );
        }

        // Tablet / Desktop: responsive grid
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.8,
          ),
          itemCount: courses.length,
          itemBuilder: (_, i) =>
              CourseCard(course: courses[i], isAr: isAr, isSide: !isMain),
        );
      },
    );
  }
}