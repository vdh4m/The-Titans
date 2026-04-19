import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class LeaderboardScreen extends StatelessWidget {
  final dynamic user;
  const LeaderboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'المتصدرون' : 'Leaderboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: user.isDoctor
          // Doctor sees all students in their faculty
          ? FirebaseFirestore.instance.collection('users')
              .where('role', isEqualTo: 'student')
              .where('facultyAr', isEqualTo: user.facultyAr)
              .where('universityAr', isEqualTo: user.universityAr)
              .snapshots()
          // Student sees only their year
          : FirebaseFirestore.instance.collection('users')
              .where('role', isEqualTo: 'student')
              .where('facultyAr', isEqualTo: user.facultyAr)
              .where('universityAr', isEqualTo: user.universityAr)
              .where('year', isEqualTo: user.year)
              .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final students = snap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList()
            ..sort((a, b) => (b['totalXP'] as int? ?? 0).compareTo(a['totalXP'] as int? ?? 0));

          if (students.isEmpty) return Center(child: Text(isAr ? 'لا يوجد طلاب بعد' : 'No students yet'));

          return CustomScrollView(slivers: [
            // Header
            SliverToBoxAdapter(child: _Header(isAr: isAr, students: students, currentUid: user.uid)),
            // List
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) {
                  if (i < 3) return const SizedBox(); // top 3 shown in header
                  final s = students[i];
                  final isMe = s['uid'] == user.uid;
                  return _ListItem(student: s, rank: i + 1, isMe: isMe, isAr: isAr);
                },
                childCount: students.length,
              )),
            ),
          ]);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isAr; final List<Map<String, dynamic>> students; final String currentUid;
  const _Header({required this.isAr, required this.students, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final top3 = students.take(3).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF7209B7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(children: [
        Text(isAr ? '🏆 متصدرو الكلية' : '🏆 Faculty Top Students',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 4),
        Text(isAr ? 'مرتبون حسب نقاط XP' : 'Ranked by XP points',
          style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (top3.length > 1) _PodiumCard(student: top3[1], rank: 2, isMe: top3[1]['uid'] == currentUid, height: 90, isAr: isAr),
          const SizedBox(width: 12),
          if (top3.isNotEmpty) _PodiumCard(student: top3[0], rank: 1, isMe: top3[0]['uid'] == currentUid, height: 120, isAr: isAr),
          const SizedBox(width: 12),
          if (top3.length > 2) _PodiumCard(student: top3[2], rank: 3, isMe: top3[2]['uid'] == currentUid, height: 70, isAr: isAr),
        ]),
      ]),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final Map<String, dynamic> student; final int rank; final bool isMe; final double height; final bool isAr;
  const _PodiumCard({required this.student, required this.rank, required this.isMe, required this.height, required this.isAr});

  String get _medal => rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    if (rank == 1) const Text('👑', style: TextStyle(fontSize: 20)),
    Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMe ? const Color(0xFFFF9F1C) : Colors.white24,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(child: Text(
        ((student['fullName'] ?? student['email']) as String? ?? '?')[0].toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
      )),
    ),
    const SizedBox(height: 6),
    Text(_medal, style: const TextStyle(fontSize: 18)),
    Text('${student['totalXP'] ?? 0} XP',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
    Container(
      width: 80, height: height,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(rank == 1 ? 0.25 : 0.15),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Center(child: Text('#$rank', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 18))),
    ),
  ]);
}

class _ListItem extends StatelessWidget {
  final Map<String, dynamic> student; final int rank; final bool isMe, isAr;
  const _ListItem({required this.student, required this.rank, required this.isMe, required this.isAr});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isMe ? AppTheme.primaryColor.withOpacity(0.08) : Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: isMe ? AppTheme.primaryColor.withOpacity(0.3) : Colors.transparent, width: 1.5),
    ),
    child: Row(children: [
      SizedBox(width: 28, child: Text('#$rank', style: TextStyle(fontWeight: FontWeight.w800, color: isMe ? AppTheme.primaryColor : Colors.grey))),
      const SizedBox(width: 10),
      CircleAvatar(radius: 18, backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
        child: Text(((student['fullName'] ?? student['email']) as String? ?? '?')[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(student['fullName'] ?? student['email'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        Row(children: [
          const Text('🔥', style: TextStyle(fontSize: 11)),
          Text(' ${student['streakDays'] ?? 0} ${isAr ? 'يوم' : 'days'}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ]),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${student['totalXP'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryColor)),
        const Text('XP', style: TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
      if (isMe) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(10)),
        child: Text(isAr ? 'أنت' : 'You', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))],
    ]),
  );
}