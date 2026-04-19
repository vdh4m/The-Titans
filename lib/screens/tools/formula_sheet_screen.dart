import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class FormulaSheetScreen extends StatelessWidget {
  const FormulaSheetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAr = context.watch<AppProvider>().isArabic;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'ورقة المعادلات' : 'Formula Sheet'),
        actions: [IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _addFormula(context, user, isAr))],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('formulas')
          .where('userId', isEqualTo: user.uid).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs.map((d) => {...(d.data() as Map<String, dynamic>), 'docId': d.id}).toList();

          // Group by subject
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final f in docs) {
            final sub = f['subject'] as String? ?? (isAr ? 'عام' : 'General');
            grouped.putIfAbsent(sub, () => []).add(f);
          }

          if (docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.functions_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(isAr ? 'لا توجد معادلات' : 'No formulas yet', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: () => _addFormula(context, user, isAr),
              icon: const Icon(Icons.add), label: Text(isAr ? 'إضافة معادلة' : 'Add Formula'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48))),
          ]));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((e) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Container(width: 4, height: 18, decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryColor)),
                ]),
              ),
              ...e.value.map((f) => _FormulaCard(formula: f, isAr: isAr)),
            ])).toList(),
          );
        },
      ),
    );
  }

  void _addFormula(BuildContext context, user, bool isAr) {
    final nameCtrl = TextEditingController();
    final formulaCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isAr ? 'إضافة معادلة' : 'Add Formula'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: subjectCtrl, decoration: InputDecoration(
          labelText: isAr ? 'المادة' : 'Subject', prefixIcon: const Icon(Icons.book_outlined))),
        const SizedBox(height: 10),
        TextField(controller: nameCtrl, decoration: InputDecoration(
          labelText: isAr ? 'اسم المعادلة' : 'Formula name', prefixIcon: const Icon(Icons.label_outline_rounded))),
        const SizedBox(height: 10),
        TextField(controller: formulaCtrl, decoration: InputDecoration(
          labelText: isAr ? 'المعادلة' : 'Formula', prefixIcon: const Icon(Icons.functions_rounded)),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
        const SizedBox(height: 10),
        TextField(controller: descCtrl, decoration: InputDecoration(
          labelText: isAr ? 'شرح (اختياري)' : 'Description (optional)'), maxLines: 2),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Cancel')),
        ElevatedButton(onPressed: () async {
          if (formulaCtrl.text.trim().isEmpty) return;
          await FirebaseFirestore.instance.collection('formulas').add({
            'id': const Uuid().v4(), 'userId': user.uid,
            'name': nameCtrl.text.trim(), 'formula': formulaCtrl.text.trim(),
            'description': descCtrl.text.trim(), 'subject': subjectCtrl.text.trim(),
            'createdAt': DateTime.now().toIso8601String(),
          });
          Navigator.pop(ctx);
        }, child: Text(isAr ? 'حفظ' : 'Save')),
      ],
    ));
  }
}

class _FormulaCard extends StatelessWidget {
  final Map<String, dynamic> formula; final bool isAr;
  const _FormulaCard({required this.formula, required this.isAr});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          if ((formula['name'] ?? '').isNotEmpty)
            Text(formula['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: formula['formula'] ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isAr ? 'تم النسخ' : 'Copied'),
                  duration: const Duration(seconds: 1), backgroundColor: AppTheme.primaryColor));
              },
              child: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => FirebaseFirestore.instance.collection('formulas').doc(formula['docId']).delete(),
              child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
            ),
          ]),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
          ),
          child: Text(formula['formula'] ?? '',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
            textAlign: TextAlign.center),
        ),
        if ((formula['description'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(formula['description'], style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4)),
        ],
      ]),
    ),
  );
}
