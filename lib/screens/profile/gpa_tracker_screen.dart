import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
// ignore: unused_import
import '../../utils/xp_service.dart';

class GpaTrackerScreen extends StatefulWidget {
  const GpaTrackerScreen({super.key});
  @override State<GpaTrackerScreen> createState() => _GpaTrackerScreenState();
}

class _GpaTrackerScreenState extends State<GpaTrackerScreen> {
  List<Map<String, dynamic>> _grades = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _grades = List<Map<String, dynamic>>.from(user?.grades ?? []);
  }

  // ── GPA computation — works for any max grade (out of 50, 60, 100…) ──────
  double get _gpaPercent {
    if (_grades.isEmpty) return 0.0;
    double sum = 0; int count = 0;
    for (final g in _grades) {
      final score = (g['grade'] as num?)?.toDouble() ?? 0;
      final max   = (g['maxGrade'] as num?)?.toDouble() ?? 100;
      if (max > 0) { sum += (score / max) * 100; count++; }
    }
    return count > 0 ? sum / count : 0;
  }

  String _letterGrade(double pct) {
    if (pct >= 90) return 'A+'; if (pct >= 85) return 'A'; if (pct >= 80) return 'A-';
    if (pct >= 75) return 'B+'; if (pct >= 70) return 'B'; if (pct >= 65) return 'B-';
    if (pct >= 60) return 'C+'; if (pct >= 55) return 'C'; if (pct >= 50) return 'C-';
    return 'F';
  }

  Color _gradeColor(double pct) {
    if (pct >= 80) return const Color(0xFF06D6A0);
    if (pct >= 60) return const Color(0xFFFF9F1C);
    return Colors.red;
  }

  // ── Add grade dialog ──────────────────────────────────────────────────────
  void _addGrade() {
    final isAr      = context.read<AppProvider>().isArabic;
    final subjCtrl  = TextEditingController();
    final gradeCtrl = TextEditingController();
    final maxCtrl   = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'إضافة مادة' : 'Add Subject'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: subjCtrl,
            decoration: InputDecoration(
              labelText: isAr ? 'اسم المادة' : 'Subject name',
              prefixIcon: const Icon(Icons.book_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: gradeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isAr ? 'درجتك' : 'Your grade',
                  prefixIcon: const Icon(Icons.grade_outlined),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(isAr ? 'من' : 'out of',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ),
            Expanded(
              child: TextField(
                controller: maxCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isAr ? 'الكلي' : 'Total',
                ),
              ),
            ),
          ]),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final score = double.tryParse(gradeCtrl.text.trim());
              final max   = double.tryParse(maxCtrl.text.trim()) ?? 100;
              if (subjCtrl.text.trim().isEmpty || score == null) return;
              if (max <= 0) return;
              Navigator.pop(ctx);
              setState(() => _grades.add({
                'subject':  subjCtrl.text.trim(),
                'grade':    score.clamp(0, max),
                'maxGrade': max,
              }));
              await _saveGrades();
            },
            child: Text(isAr ? 'إضافة' : 'Add'),
          ),
        ],
      ),
    );
  }

  // ── Edit grade ─────────────────────────────────────────────────────────────
  void _editGrade(int index) {
    final isAr   = context.read<AppProvider>().isArabic;
    final g      = _grades[index];
    final subjCtrl  = TextEditingController(text: g['subject'] ?? '');
    final gradeCtrl = TextEditingController(text: '${g['grade'] ?? ''}');
    final maxCtrl   = TextEditingController(text: '${g['maxGrade'] ?? 100}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'تعديل المادة' : 'Edit Subject'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: subjCtrl,
              decoration: InputDecoration(
                  labelText: isAr ? 'اسم المادة' : 'Subject name',
                  prefixIcon: const Icon(Icons.book_outlined))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(flex: 2, child: TextField(
              controller: gradeCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: isAr ? 'درجتك' : 'Your grade'),
            )),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(isAr ? 'من' : 'of',
                  style: TextStyle(color: Colors.grey[500])),
            ),
            Expanded(child: TextField(
              controller: maxCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: isAr ? 'الكلي' : 'Total'),
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              final score = double.tryParse(gradeCtrl.text.trim());
              final max   = double.tryParse(maxCtrl.text.trim()) ?? 100;
              if (subjCtrl.text.trim().isEmpty || score == null || max <= 0) return;
              Navigator.pop(ctx);
              setState(() => _grades[index] = {
                'subject':  subjCtrl.text.trim(),
                'grade':    score.clamp(0, max),
                'maxGrade': max,
              });
              await _saveGrades();
            },
            child: Text(isAr ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGrades() async {
    setState(() => _loading = true);
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .update({'grades': _grades, 'gpa': _gpaPercent});
    }
    setState(() => _loading = false);
  }

  void _removeGrade(int index) async {
    setState(() => _grades.removeAt(index));
    await _saveGrades();
  }

  @override
  Widget build(BuildContext context) {
    final isAr  = context.watch<AppProvider>().isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gpa   = _gpaPercent;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'متابعة الدرجات' : 'GPA Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: isAr ? 'إضافة مادة' : 'Add subject',
            onPressed: _addGrade,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // ── GPA Card ────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_gradeColor(gpa), _gradeColor(gpa).withOpacity(0.7)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(
                        color: _gradeColor(gpa).withOpacity(0.35),
                        blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(children: [
                    Text(isAr ? 'معدلك التراكمي' : 'Your GPA',
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(gpa.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 64,
                            fontWeight: FontWeight.w900)),
                    Text(_letterGrade(gpa),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 28,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: gpa / 100,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${_grades.length} ${isAr ? "مادة مسجلة" : "subjects recorded"}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 24),

                if (_grades.isEmpty)
                  Center(child: Column(children: [
                    const SizedBox(height: 40),
                    Icon(Icons.grade_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      isAr ? 'أضف درجاتك لحساب معدلك' : 'Add your grades to calculate GPA',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAr
                          ? 'يمكنك إضافة درجة من أي مجموع (من 50، 60، 100…)'
                          : 'You can add grades from any total (out of 50, 60, 100…)',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _addGrade,
                      icon: const Icon(Icons.add),
                      label: Text(isAr ? 'إضافة مادة' : 'Add Subject'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48)),
                    ),
                  ]))
                else
                  ...(_grades.asMap().entries.map((e) {
                    final i     = e.key;
                    final g     = e.value;
                    final score = (g['grade'] as num).toDouble();
                    final max   = ((g['maxGrade'] as num?)?.toDouble()) ?? 100;
                    final pct   = max > 0 ? (score / max * 100) : 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1730) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _gradeColor(pct).withOpacity(0.2), width: 1.5),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                            blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                              color: _gradeColor(pct).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text(
                            _letterGrade(pct),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _gradeColor(pct), fontSize: 14),
                          )),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g['subject'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation(_gradeColor(pct)),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 5,
                            ),
                            const SizedBox(height: 4),
                            // Show actual score e.g. "45 / 60  (75%)"
                            Text(
                              '${score % 1 == 0 ? score.toInt() : score} / ${max % 1 == 0 ? max.toInt() : max}  (${pct.toStringAsFixed(1)}%)',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        )),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              color: AppTheme.primaryColor, size: 18),
                          onPressed: () => _editGrade(i),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.red, size: 18),
                          onPressed: () => _removeGrade(i),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ]),
                    );
                  })),

                const SizedBox(height: 100),
              ]),
            ),
    );
  }
}