import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class CvBuilderScreen extends StatefulWidget {
  const CvBuilderScreen({super.key});
  @override State<CvBuilderScreen> createState() => _CvBuilderScreenState();
}

class _CvBuilderScreenState extends State<CvBuilderScreen> {
  final _summaryCtrl = TextEditingController();
  final List<Map<String, TextEditingController>> _skills = [];
  final List<Map<String, TextEditingController>> _activities = [];
  final List<Map<String, TextEditingController>> _experience = [];

  @override
  void initState() {
    super.initState();
    _skills.add({'name': TextEditingController()});
    _activities.add({
      'title': TextEditingController(),
      'org': TextEditingController(),
      'year': TextEditingController(),
    });
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    super.dispose();
  }

  String _buildCvText(user, bool isAr) {
    final sb = StringBuffer();
    sb.writeln('═══════════════════════════════════════');
    sb.writeln(user.fullName ?? user.email.split('@').first);
    sb.writeln('═══════════════════════════════════════');
    sb.writeln(user.email);
    sb.writeln(isAr ? '${user.facultyAr} | ${user.universityAr}' : '${user.facultyEn} | ${user.universityEn}');
    if (user.year != null) sb.writeln(isAr ? 'السنة ${user.year}' : 'Year ${user.year}');
    sb.writeln();

    if (_summaryCtrl.text.isNotEmpty) {
      sb.writeln(isAr ? '── الملخص الشخصي ──' : '── Summary ──');
      sb.writeln(_summaryCtrl.text);
      sb.writeln();
    }

    sb.writeln(isAr ? '── التعليم ──' : '── Education ──');
    sb.writeln(isAr ? user.facultyAr : user.facultyEn);
    sb.writeln(isAr ? user.universityAr : user.universityEn);
    if (user.gpa > 0) sb.writeln('GPA: ${user.gpa.toStringAsFixed(2)}');
    sb.writeln();

    final skillNames = _skills.map((s) => s['name']!.text.trim()).where((s) => s.isNotEmpty).toList();
    if (skillNames.isNotEmpty) {
      sb.writeln(isAr ? '── المهارات ──' : '── Skills ──');
      for (final s in skillNames) {
        sb.writeln('• $s');
      }
      sb.writeln();
    }

    final validActs = _activities.where((a) => a['title']!.text.isNotEmpty).toList();
    if (validActs.isNotEmpty) {
      sb.writeln(isAr ? '── الأنشطة والإنجازات ──' : '── Activities & Achievements ──');
      for (final a in validActs) {
        sb.write('• ${a["title"]!.text}');
        if (a['org']!.text.isNotEmpty) sb.write(' | ${a["org"]!.text}');
        if (a['year']!.text.isNotEmpty) sb.write(' (${a["year"]!.text})');
        sb.writeln();
      }
      sb.writeln();
    }

    final validExp = _experience.where((e) => e['title']!.text.isNotEmpty).toList();
    if (validExp.isNotEmpty) {
      sb.writeln(isAr ? '── الخبرات ──' : '── Experience ──');
      for (final e in validExp) {
        sb.write('• ${e["title"]!.text}');
        if (e['org']!.text.isNotEmpty) sb.write(' | ${e["org"]!.text}');
        if (e['period']!.text.isNotEmpty) sb.write(' (${e["period"]!.text})');
        sb.writeln();
      }
      sb.writeln();
    }

    sb.writeln(isAr ? '── StudyHub Stats ──' : '── StudyHub Stats ──');
    sb.writeln('XP: ${user.totalXP} | Streak: ${user.streakDays} ${isAr ? "يوم" : "days"}');
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAr = context.watch<AppProvider>().isArabic;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'بناء السيرة الذاتية' : 'CV Builder'),
        actions: [
          TextButton.icon(
            onPressed: () {
              final cv = _buildCvText(user, isAr);
              Clipboard.setData(ClipboardData(text: cv));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isAr ? 'تم نسخ السيرة الذاتية' : 'CV copied to clipboard'),
                backgroundColor: AppTheme.primaryColor,
              ));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(isAr ? 'نسخ' : 'Copy'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Auto-filled header
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF7209B7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAr ? 'البيانات الأساسية (تلقائي)' : 'Basic Info (auto-filled)',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(user.fullName ?? user.email.split('@').first,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              Text(isAr ? '${user.facultyAr} - ${user.universityAr}' : '${user.facultyEn} - ${user.universityEn}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (user.gpa > 0)
                Text('GPA: ${user.gpa.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 20),

          // Personal summary
          _BuildSection(title: isAr ? 'الملخص الشخصي' : 'Personal Summary', icon: Icons.notes_rounded),
          const SizedBox(height: 10),
          TextField(controller: _summaryCtrl,
            decoration: InputDecoration(hintText: isAr ? 'اكتب جملتين عن نفسك وأهدافك...' : 'Write 2 sentences about yourself and goals...'),
            maxLines: 3),
          const SizedBox(height: 20),

          // Skills
          _BuildSection(title: isAr ? 'المهارات' : 'Skills', icon: Icons.psychology_rounded,
            onAdd: () => setState(() => _skills.add({'name': TextEditingController()}))),
          const SizedBox(height: 10),
          ..._skills.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: TextField(controller: e.value['name'],
                decoration: InputDecoration(hintText: isAr ? 'مثال: Python, Excel, تحليل بيانات...' : 'e.g. Python, Excel, Data Analysis...',
                  prefixIcon: const Icon(Icons.circle, size: 8, color: AppTheme.primaryColor)))),
              if (_skills.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 20),
                onPressed: () => setState(() => _skills.removeAt(e.key))),
            ]),
          )),
          const SizedBox(height: 20),

          // Activities
          _BuildSection(title: isAr ? 'الأنشطة والإنجازات' : 'Activities & Achievements', icon: Icons.emoji_events_rounded,
            onAdd: () => setState(() => _activities.add({'title': TextEditingController(), 'org': TextEditingController(), 'year': TextEditingController()}))),
          const SizedBox(height: 10),
          ..._activities.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.15))),
            child: Column(children: [
              TextField(controller: e.value['title'], decoration: InputDecoration(hintText: isAr ? 'اسم النشاط أو الإنجاز' : 'Activity or achievement name', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: e.value['org'], decoration: InputDecoration(hintText: isAr ? 'الجهة' : 'Organization', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: TextField(controller: e.value['year'], decoration: const InputDecoration(hintText: '2024', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)), keyboardType: TextInputType.number)),
                if (_activities.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 18),
                  onPressed: () => setState(() => _activities.removeAt(e.key))),
              ]),
            ]),
          )),
          const SizedBox(height: 20),

          // Experience
          _BuildSection(title: isAr ? 'الخبرات' : 'Experience', icon: Icons.work_outline_rounded,
            onAdd: () => setState(() => _experience.add({'title': TextEditingController(), 'org': TextEditingController(), 'period': TextEditingController()}))),
          const SizedBox(height: 10),
          ..._experience.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.15))),
            child: Column(children: [
              TextField(controller: e.value['title'], decoration: InputDecoration(hintText: isAr ? 'المسمى الوظيفي' : 'Job title', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: e.value['org'], decoration: InputDecoration(hintText: isAr ? 'الشركة' : 'Company', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
                const SizedBox(width: 8),
                SizedBox(width: 100, child: TextField(controller: e.value['period'], decoration: InputDecoration(hintText: isAr ? '2023-2024' : '2023-2024', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
                if (_experience.isNotEmpty) IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 18),
                  onPressed: () => setState(() => _experience.removeAt(e.key))),
              ]),
            ]),
          )),

          // Preview button
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showPreview(context, user, isAr),
            icon: const Icon(Icons.preview_rounded),
            label: Text(isAr ? 'معاينة السيرة الذاتية' : 'Preview CV'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  void _showPreview(BuildContext context, user, bool isAr) {
    final cv = _buildCvText(user, isAr);
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
        builder: (_, ctrl) => Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Text(isAr ? 'معاينة' : 'Preview', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const Spacer(),
            ElevatedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: cv)); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تم النسخ' : 'Copied'), backgroundColor: AppTheme.primaryColor)); },
              icon: const Icon(Icons.copy_rounded, size: 16), label: Text(isAr ? 'نسخ' : 'Copy')),
          ])),
          Expanded(child: SingleChildScrollView(controller: ctrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            child: Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.2))),
              child: SelectableText(cv, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6))))),
        ])));
  }
}

class _BuildSection extends StatelessWidget {
  final String title; final IconData icon; final VoidCallback? onAdd;
  const _BuildSection({required this.title, required this.icon, this.onAdd});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: AppTheme.primaryColor)),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    const Spacer(),
    if (onAdd != null) GestureDetector(onTap: onAdd,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add_rounded, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text('Add', style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
        ]))),
  ]);
}
