import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class TaskManagerScreen extends StatelessWidget {
  const TaskManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAr = context.watch<AppProvider>().isArabic;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isAr ? 'المهام' : 'Tasks'),
          bottom: TabBar(tabs: [
            Tab(text: isAr ? 'قيد التنفيذ' : 'Pending'),
            Tab(text: isAr ? 'مكتملة' : 'Done'),
          ]),
          actions: [IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _addTask(context, user, isAr))],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('tasks')
            .where('userId', isEqualTo: user.uid).snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final all = snap.data!.docs.map((d) => {...(d.data() as Map<String, dynamic>), 'docId': d.id}).toList()
              ..sort((a, b) => (a['deadline'] as String? ?? '').compareTo(b['deadline'] as String? ?? ''));
            final pending = all.where((t) => !(t['done'] as bool? ?? false)).toList();
            final done = all.where((t) => t['done'] as bool? ?? false).toList();
            return TabBarView(children: [
              _TaskList(tasks: pending, isAr: isAr, onAdd: () => _addTask(context, user, isAr)),
              _TaskList(tasks: done, isAr: isAr, isDone: true, onAdd: () {}),
            ]);
          },
        ),
      ),
    );
  }

  void _addTask(BuildContext context, user, bool isAr) {
    final titleCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    DateTime? deadline;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (c2, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'مهمة جديدة' : 'New Task'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: InputDecoration(
            labelText: isAr ? 'المهمة' : 'Task', prefixIcon: const Icon(Icons.task_alt_rounded))),
          const SizedBox(height: 12),
          TextField(controller: subjectCtrl, decoration: InputDecoration(
            labelText: isAr ? 'المادة' : 'Subject', prefixIcon: const Icon(Icons.book_outlined))),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final p = await showDatePicker(context: c2, initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (p != null) setS(() => deadline = p);
            },
            child: Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.07), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 10),
                Text(deadline == null ? (isAr ? 'اختر الموعد النهائي' : 'Pick deadline') :
                  '${deadline!.day}/${deadline!.month}/${deadline!.year}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              ])),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(onPressed: () async {
            if (titleCtrl.text.trim().isEmpty) return;
            await FirebaseFirestore.instance.collection('tasks').add({
              'id': const Uuid().v4(), 'userId': user.uid,
              'title': titleCtrl.text.trim(), 'subject': subjectCtrl.text.trim(),
              'deadline': deadline?.toIso8601String() ?? '',
              'done': false, 'createdAt': DateTime.now().toIso8601String(),
            });
            Navigator.pop(ctx);
          }, child: Text(isAr ? 'إضافة' : 'Add')),
        ],
      ),
    ));
  }
}

class _TaskList extends StatelessWidget {
  final List<Map<String, dynamic>> tasks; final bool isAr; final bool isDone; final VoidCallback onAdd;
  const _TaskList({required this.tasks, required this.isAr, this.isDone = false, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(isDone ? Icons.check_circle_outline_rounded : Icons.task_alt_rounded, size: 56, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text(isDone ? (isAr ? 'لا توجد مهام مكتملة' : 'No completed tasks') : (isAr ? 'لا توجد مهام' : 'No tasks'),
        style: TextStyle(color: Colors.grey[500])),
      if (!isDone) ...[const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(isAr ? 'أضف مهمة' : 'Add Task'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(160, 44)))],
    ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        final t = tasks[i];
        final deadline = t['deadline'] != null && (t['deadline'] as String).isNotEmpty
          ? DateTime.tryParse(t['deadline']) : null;
        final isOverdue = deadline != null && deadline.isBefore(DateTime.now()) && !isDone;
        final daysLeft = deadline?.difference(DateTime.now()).inDays;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Checkbox(
              value: t['done'] as bool? ?? false,
              onChanged: (_) => FirebaseFirestore.instance.collection('tasks').doc(t['docId'])
                .update({'done': !(t['done'] as bool? ?? false)}),
              activeColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            title: Text(t['title'] ?? '', style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? Colors.grey : null,
            )),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((t['subject'] ?? '').isNotEmpty)
                Text(t['subject'], style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              if (deadline != null) Text(
                daysLeft == 0 ? (isAr ? 'اليوم!' : 'Today!')
                  : daysLeft! < 0 ? (isAr ? 'متأخر ${-daysLeft} يوم' : '${-daysLeft} days overdue')
                  : (isAr ? 'باقي $daysLeft يوم' : '$daysLeft days left'),
                style: TextStyle(color: isOverdue ? Colors.red : Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ]),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
              onPressed: () => FirebaseFirestore.instance.collection('tasks').doc(t['docId']).delete(),
            ),
          ),
        );
      },
    );
  }
}
