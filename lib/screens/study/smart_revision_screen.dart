import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class SmartRevisionScreen extends StatefulWidget {
  const SmartRevisionScreen({super.key});
  @override
  State<SmartRevisionScreen> createState() => _SmartRevisionScreenState();
}

class _SmartRevisionScreenState extends State<SmartRevisionScreen> {
  final List<Map<String, dynamic>> _exams    = [];
  final List<Map<String, dynamic>> _schedule = [];
  bool _generated = false;

  // ─── Add exam ─────────────────────────────────────────────────────────────
  void _showAddDialog() {
    final isAr   = context.read<AppProvider>().isArabic;
    final subCtrl = TextEditingController();
    DateTime picked = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isAr ? 'إضافة امتحان' : 'Add Exam'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: subCtrl,
              decoration: InputDecoration(
                labelText: isAr ? 'اسم المادة' : 'Subject name',
                prefixIcon: const Icon(Icons.book_outlined),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx2,
                  initialDate: picked,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 180)),
                );
                if (d != null) setSt(() => picked = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 10),
                  Text('${picked.day}/${picked.month}/${picked.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Cancel')),
            ElevatedButton(
              onPressed: () {
                final sub = subCtrl.text.trim();
                if (sub.isEmpty) return;
                setState(() { _exams.add({'subject': sub, 'date': picked}); _generated = false; });
                Navigator.pop(ctx);
              },
              child: Text(isAr ? 'إضافة' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Generate schedule ────────────────────────────────────────────────────
  void _generate() {
    if (_exams.isEmpty) return;
    final today    = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final result   = <Map<String, dynamic>>[];

    final sorted = List<Map<String, dynamic>>.from(_exams)
      ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    for (final exam in sorted) {
      final examDate = exam['date'] as DateTime;
      final daysLeft = examDate.difference(today).inDays;
      if (daysLeft <= 0) continue;

      for (int i = daysLeft.clamp(1, 7); i >= 1; i--) {
        final sessionDate = examDate.subtract(Duration(days: i));
        if (sessionDate.isBefore(today)) continue;

        result.add({
          'date':       sessionDate,
          'subject':    exam['subject'],
          'activityAr': i == 1 ? 'مراجعة سريعة كاملة'
                      : i == 2 ? 'حل تمارين وأسئلة قديمة'
                      : i <= 4 ? 'مراجعة المفاهيم الأساسية'
                               : 'قراءة وفهم الوحدات',
          'activityEn': i == 1 ? 'Full quick review'
                      : i == 2 ? 'Practice problems & past questions'
                      : i <= 4 ? 'Review core concepts'
                               : 'Read & understand units',
          'intensity':  i <= 2 ? 'high' : i <= 4 ? 'medium' : 'low',
          'done':       false,
        });
      }
    }

    result.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    setState(() { _schedule..clear()..addAll(result); _generated = true; });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isAr  = context.watch<AppProvider>().isArabic;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'جدول المراجعة الذكي' : 'Smart Revision Planner')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Banner ────────────────────────────────────────────────────
          Container(
            width: double.infinity, padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF06D6A0), AppTheme.primaryColor],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(children: [
              const Text('📅', style: TextStyle(fontSize: 38)),
              const SizedBox(height: 6),
              Text(isAr ? 'جدول المراجعة الذكي' : 'Smart Revision Planner',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 4),
              Text(isAr ? 'أضف امتحاناتك وهنعمل لك جدول تلقائي' : 'Add your exams and get an auto schedule',
                  style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Exams header ───────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(isAr ? 'الامتحانات' : 'Exams',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(isAr ? 'إضافة' : 'Add'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // ── Exams list ─────────────────────────────────────────────────
          if (_exams.isEmpty)
            _EmptyBox(isAr: isAr, theme: theme,
                emoji: '📝',
                text: isAr ? 'لم تضف أي امتحانات بعد' : 'No exams added yet')
          else
            ...(_exams.asMap().entries.map((e) => _ExamTile(
              exam: e.value, isAr: isAr, theme: theme,
              onDelete: () => setState(() { _exams.removeAt(e.key); _generated = false; }),
            ))),

          if (_exams.isNotEmpty) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(isAr ? 'اعمل جدول المراجعة' : 'Generate Schedule'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: const Color(0xFF06D6A0), foregroundColor: Colors.white,
              ),
            ),
          ],

          // ── Schedule ──────────────────────────────────────────────────
          if (_generated && _schedule.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(isAr ? 'جدول المراجعة' : 'Revision Schedule',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            _ScheduleList(schedule: _schedule, isAr: isAr, theme: theme,
                onToggle: (idx) => setState(() => _schedule[idx]['done'] = !(_schedule[idx]['done'] as bool))),
          ],

          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _EmptyBox extends StatelessWidget {
  final bool isAr; final ThemeData theme; final String emoji, text;
  const _EmptyBox({required this.isAr, required this.theme, required this.emoji, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5))),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 34)),
      const SizedBox(height: 8),
      Text(text, style: TextStyle(color: Colors.grey[600])),
    ]),
  );
}

class _ExamTile extends StatelessWidget {
  final Map<String, dynamic> exam; final bool isAr;
  final ThemeData theme; final VoidCallback onDelete;
  const _ExamTile({required this.exam, required this.isAr, required this.theme, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final date     = exam['date'] as DateTime;
    final today    = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final daysLeft = date.difference(today).inDays;
    final dotColor = daysLeft <= 3 ? Colors.red : daysLeft <= 7 ? const Color(0xFFFF9F1C) : const Color(0xFF06D6A0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.5))),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(exam['subject'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(
            daysLeft <= 0  ? (isAr ? 'الامتحان اليوم!' : 'Exam today!')
            : daysLeft == 1? (isAr ? 'غداً!' : 'Tomorrow!')
                           : (isAr ? 'بعد $daysLeft يوم' : 'In $daysLeft days'),
            style: TextStyle(fontSize: 12,
                color: daysLeft <= 3 ? Colors.red : Colors.grey[600],
                fontWeight: daysLeft <= 3 ? FontWeight.w700 : FontWeight.normal),
          ),
        ])),
        Text('${date.day}/${date.month}/${date.year}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(width: 8),
        GestureDetector(onTap: onDelete,
            child: const Icon(Icons.close_rounded, size: 18, color: Colors.red)),
      ]),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  final List<Map<String, dynamic>> schedule;
  final bool isAr; final ThemeData theme;
  final Function(int) onToggle;
  const _ScheduleList({required this.schedule, required this.isAr, required this.theme, required this.onToggle});

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  String _monthEn(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];

  @override
  Widget build(BuildContext context) {
    final today    = DateTime.now();
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    // Group by date
    final Map<String, List<int>> groups = {};
    for (int i = 0; i < schedule.length; i++) {
      final d = schedule[i]['date'] as DateTime;
      final k = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      groups.putIfAbsent(k, () => []).add(i);
    }

    return Column(children: groups.entries.map((entry) {
      final date    = DateTime.parse(entry.key);
      final isToday = _sameDay(date, today);
      final isTomow = _sameDay(date, tomorrow);
      final label   = isToday ? (isAr ? 'اليوم' : 'Today')
                    : isTomow ? (isAr ? 'غداً'  : 'Tomorrow')
                    : isAr    ? '${date.day}/${date.month}'
                              : '${_monthEn(date.month)} ${date.day}';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isToday ? AppTheme.primaryColor.withOpacity(0.5) : theme.dividerColor.withOpacity(0.4),
            width: isToday ? 2 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Day header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isToday ? AppTheme.primaryColor.withOpacity(0.08) : Colors.transparent,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Text(isToday ? '⭐' : '📅', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
                  color: isToday ? AppTheme.primaryColor : theme.textTheme.bodyMedium?.color)),
            ]),
          ),
          // Sessions
          ...entry.value.map((idx) {
            final item      = schedule[idx];
            final intensity = item['intensity'] as String;
            final isDone    = item['done'] as bool;
            final iColor    = intensity == 'high' ? Colors.red
                            : intensity == 'medium' ? const Color(0xFFFF9F1C)
                            : const Color(0xFF06D6A0);
            return InkWell(
              onTap: () => onToggle(idx),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                child: Row(children: [
                  // Checkbox circle
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? const Color(0xFF06D6A0) : Colors.transparent,
                      border: Border.all(
                          color: isDone ? const Color(0xFF06D6A0) : Colors.grey.withOpacity(0.4), width: 2),
                    ),
                    child: isDone ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['subject'] as String,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                            color: isDone ? Colors.grey : theme.textTheme.bodyMedium?.color,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            decorationColor: Colors.grey)),
                    Text(isAr ? item['activityAr'] as String : item['activityEn'] as String,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: iColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      intensity == 'high' ? (isAr ? 'مكثف' : 'High')
                          : intensity == 'medium' ? (isAr ? 'متوسط' : 'Med')
                          : (isAr ? 'خفيف' : 'Light'),
                      style: TextStyle(fontSize: 10, color: iColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ]),
      );
    }).toList());
  }
}
