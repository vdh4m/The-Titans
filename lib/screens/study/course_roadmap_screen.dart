import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class CourseRoadmapScreen extends StatefulWidget {
  const CourseRoadmapScreen({super.key});
  @override
  State<CourseRoadmapScreen> createState() => _CourseRoadmapScreenState();
}

class _CourseRoadmapScreenState extends State<CourseRoadmapScreen> {

  void _addRoadmap() async {
    final isAr = context.read<AppProvider>().isArabic;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final subjectCtrl = TextEditingController();
    final unitsCtrl   = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'خارطة طريق جديدة' : 'New Roadmap'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: subjectCtrl,
            decoration: InputDecoration(
              labelText: isAr ? 'اسم المادة' : 'Subject name',
              prefixIcon: const Icon(Icons.book_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: unitsCtrl,
            decoration: InputDecoration(
              labelText: isAr ? 'الوحدات (كل وحدة في سطر)' : 'Units (one per line)',
              hintText: isAr ? 'الوحدة الأولى\nالوحدة الثانية' : 'Chapter 1\nChapter 2',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            keyboardType: TextInputType.multiline,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              final subject = subjectCtrl.text.trim();
              if (subject.isEmpty) return;
              final units = unitsCtrl.text
                  .split('\n').map((u) => u.trim()).where((u) => u.isNotEmpty).toList();
              if (units.isEmpty) return;

              final unitsList = units.asMap().entries
                  .map((e) => {'index': e.key, 'title': e.value, 'done': false})
                  .toList();

              // No orderBy → no composite index needed; sort in Dart instead
              await FirebaseFirestore.instance.collection('roadmaps').add({
                'userId': user.uid,
                'subject': subject,
                'units': unitsList,
                'createdAt': DateTime.now().millisecondsSinceEpoch, // int for easy sort
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isAr ? 'إنشاء' : 'Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user  = context.watch<AuthProvider>().currentUser;
    final isAr  = context.watch<AppProvider>().isArabic;
    final theme = Theme.of(context);
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'خارطة الطريق' : 'Course Roadmap'),
        actions: [
          TextButton.icon(
            onPressed: _addRoadmap,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(isAr ? 'إضافة' : 'Add'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ❌ No orderBy to avoid composite-index exception; sort in Dart
        stream: FirebaseFirestore.instance
            .collection('roadmaps')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final docs = (snap.data?.docs ?? [])
            ..sort((a, b) {
              final aT = (a.data() as Map)['createdAt'] as int? ?? 0;
              final bT = (b.data() as Map)['createdAt'] as int? ?? 0;
              return bT.compareTo(aT); // newest first
            });

          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🗺', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text(isAr ? 'لا توجد خرائط طريق بعد' : 'No roadmaps yet',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  isAr ? 'اضغط "إضافة" لإنشاء خارطة لمادة' : 'Tap "Add" to create a subject roadmap',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _addRoadmap,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(isAr ? 'إضافة خارطة طريق' : 'Add Roadmap'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
                ),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) => _RoadmapCard(
              docId: docs[i].id,
              data: docs[i].data() as Map<String, dynamic>,
              isAr: isAr,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _RoadmapCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isAr;
  const _RoadmapCard({required this.docId, required this.data, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final units = List<Map<String, dynamic>>.from(data['units'] ?? []);
    final done  = units.where((u) => u['done'] as bool? ?? false).length;
    final total = units.length;
    final pct   = total > 0 ? done / total : 0.0;
    final isComplete  = pct == 1.0;
    final accentColor = isComplete ? const Color(0xFF06D6A0) : AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? const Color(0xFF06D6A0).withOpacity(0.45)
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08)),
          width: 1.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['subject'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 3),
              Text(
                '$done / $total ${isAr ? "وحدة" : "Unit"}${isComplete ? (isAr ? "  ✅ مكتمل!" : "  ✅ Complete!") : ""}',
                style: TextStyle(
                  color: isComplete ? const Color(0xFF06D6A0) : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: isComplete ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ])),
            // Progress ring
            SizedBox(width: 50, height: 50, child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: pct, strokeWidth: 4,
                backgroundColor: Colors.grey.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(accentColor),
              ),
              Text('${(pct * 100).round()}%',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: accentColor)),
            ])),
          ]),
        ),
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 5,
              backgroundColor: Colors.grey.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(accentColor),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // ── Units list ────────────────────────────────────────────────
        ...units.asMap().entries.map((e) {
          final unit   = e.value;
          final isDone = unit['done'] as bool? ?? false;
          final isLocked = !isDone && e.key > 0 && !(units[e.key - 1]['done'] as bool? ?? false);

          return InkWell(
            onTap: () async {
              if (isLocked) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isAr ? 'أكمل الوحدة السابقة أولاً' : 'Complete the previous unit first'),
                  duration: const Duration(seconds: 1),
                ));
                return;
              }
              final newUnits = List<Map<String, dynamic>>.from(units);
              newUnits[e.key] = {...unit, 'done': !isDone};
              await FirebaseFirestore.instance.collection('roadmaps').doc(docId).update({'units': newUnits});
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
              child: Row(children: [
                // Timeline
                Column(children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? const Color(0xFF06D6A0)
                          : isLocked
                              ? Colors.grey.withOpacity(0.15)
                              : AppTheme.primaryColor.withOpacity(0.1),
                      border: Border.all(
                        color: isDone
                            ? const Color(0xFF06D6A0)
                            : isLocked
                                ? Colors.grey.withOpacity(0.3)
                                : AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                          : isLocked
                              ? Icon(Icons.lock_rounded, color: Colors.grey[400], size: 11)
                              : Text('${e.key + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: AppTheme.primaryColor)),
                    ),
                  ),
                  if (e.key < units.length - 1)
                    Container(width: 2, height: 16,
                        color: isDone ? const Color(0xFF06D6A0).withOpacity(0.35) : Colors.grey.withOpacity(0.2)),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(unit['title'] as String? ?? '',
                    style: TextStyle(
                      fontWeight: isDone ? FontWeight.w400 : FontWeight.w600,
                      fontSize: 13,
                      color: isLocked
                          ? Colors.grey[400]
                          : isDone
                              ? Colors.grey
                              : theme.textTheme.bodyMedium?.color,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.grey,
                    )),
                )),
              ]),
            ),
          );
        }),
        // Delete
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: GestureDetector(
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(isAr ? 'حذف الخارطة؟' : 'Delete Roadmap?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(80, 40)),
                      child: Text(isAr ? 'حذف' : 'Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) await FirebaseFirestore.instance.collection('roadmaps').doc(docId).delete();
            },
            child: const Text('🗑', style: TextStyle(fontSize: 18)),
          ),
        ),
      ]),
    );
  }
}

