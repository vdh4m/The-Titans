import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class ExamCountdownScreen extends StatelessWidget {
  const ExamCountdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAr = context.watch<AppProvider>().isArabic;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'مواعيد الامتحانات' : 'Exam Countdown'),
        actions: [
          if (user.isDoctor)
            IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _addExam(context, user, isAr)),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: user.isDoctor
          ? FirebaseFirestore.instance.collection('exams').where('userId', isEqualTo: user.uid).snapshots()
          : FirebaseFirestore.instance.collection('exams')
              .where('facultyAr', isEqualTo: user.facultyAr)
              .where('universityAr', isEqualTo: user.universityAr)
              .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final exams = snap.data!.docs
            .map((d) => {...(d.data() as Map<String, dynamic>), 'docId': d.id})
            .toList()
            ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

          if (exams.isEmpty) return _Empty(isAr: isAr, isDoctor: user.isDoctor, onAdd: () => _addExam(context, user, isAr));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exams.length,
            itemBuilder: (_, i) => _ExamCard(exam: exams[i], isAr: isAr),
          );
        },
      ),
    );
  }

  void _addExam(BuildContext context, user, bool isAr) {
    final subjectCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (c2, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'إضافة امتحان' : 'Add Exam'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: subjectCtrl, decoration: InputDecoration(
            labelText: isAr ? 'اسم المادة' : 'Subject name',
            prefixIcon: const Icon(Icons.book_outlined),
          )),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(context: c2,
                initialDate: selectedDate, firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)));
              if (picked != null) setS(() => selectedDate = picked);
            },
            child: Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 10),
                Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(onPressed: () async {
            if (subjectCtrl.text.trim().isEmpty) return;
            await FirebaseFirestore.instance.collection('exams').add({
              'id': const Uuid().v4(), 'userId': user.uid,
              'subject': subjectCtrl.text.trim(),
              'date': selectedDate.toIso8601String(),
              'facultyAr': user.facultyAr, 'universityAr': user.universityAr,
              'year': user.year,
              'createdAt': DateTime.now().toIso8601String(),
            });
            Navigator.pop(ctx);
          }, child: Text(isAr ? 'إضافة' : 'Add')),
        ],
      ),
    ));
  }
}

class _ExamCard extends StatelessWidget {
  final Map<String, dynamic> exam; final bool isAr;
  const _ExamCard({required this.exam, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(exam['date'] ?? '') ?? DateTime.now();
    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    final isPast = diff < 0;
    final isToday = diff == 0;
    final isTomorrow = diff == 1;

    Color cardColor = AppTheme.primaryColor;
    if (isPast) {
      cardColor = Colors.grey;
    } else if (isToday) cardColor = Colors.red;
    else if (diff <= 3) cardColor = Colors.orange;
    else if (diff <= 7) cardColor = const Color(0xFFFF9F1C);

    String countdownText;
    if (isPast) {
      countdownText = isAr ? 'انتهى' : 'Past';
    } else if (isToday) countdownText = isAr ? 'اليوم!' : 'Today!';
    else if (isTomorrow) countdownText = isAr ? 'غداً!' : 'Tomorrow!';
    else countdownText = isAr ? '$diff يوم' : '$diff days';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${date.day}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: cardColor)),
              Text(_monthName(date.month, isAr), style: TextStyle(fontSize: 10, color: cardColor, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exam['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: cardColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(countdownText, style: TextStyle(color: cardColor, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ])),
          // Only doctor who created can delete
          if ((exam['userId'] ?? '') == context.read<AuthProvider>().currentUser?.uid)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
              onPressed: () => FirebaseFirestore.instance.collection('exams').doc(exam['docId']).delete(),
            ),
        ]),
      ),
    );
  }

  String _monthName(int m, bool isAr) {
    const ar = ['','يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    const en = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return isAr ? ar[m] : en[m];
  }
}

class _Empty extends StatelessWidget {
  final bool isAr, isDoctor; final VoidCallback onAdd;
  const _Empty({required this.isAr, required this.isDoctor, required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.event_rounded, size: 64, color: Colors.grey[300]),
    const SizedBox(height: 16),
    Text(isAr ? 'لا توجد امتحانات' : 'No exams yet', style: TextStyle(color: Colors.grey[500])),
    if (isDoctor) ...[
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add),
        label: Text(isAr ? 'إضافة امتحان' : 'Add Exam'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48))),
    ] else ...[
      const SizedBox(height: 8),
      Text(isAr ? 'سيظهر هنا امتحانات كليتك' : 'Your faculty exams will appear here',
        style: TextStyle(color: Colors.grey[400], fontSize: 12)),
    ],
  ]));
}