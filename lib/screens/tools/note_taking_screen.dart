import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class NoteTakingScreen extends StatelessWidget {
  const NoteTakingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAr = context.watch<AppProvider>().isArabic;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'ملاحظاتي' : 'My Notes')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notes')
          .where('userId', isEqualTo: user.uid).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final notes = snap.data!.docs.map((d) => {...(d.data() as Map<String, dynamic>), 'docId': d.id}).toList()
            ..sort((a, b) => (b['updatedAt'] as String? ?? '').compareTo(a['updatedAt'] as String? ?? ''));

          if (notes.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.note_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(isAr ? 'لا توجد ملاحظات' : 'No notes yet', style: TextStyle(color: Colors.grey[500])),
          ]));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
            itemCount: notes.length,
            itemBuilder: (_, i) => _NoteCard(note: notes[i], isAr: isAr,
              onTap: () => _editNote(context, notes[i], isAr)),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editNote(context, null, isAr, userId: context.read<AuthProvider>().currentUser?.uid),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  static const _colors = [
    Color(0xFFFFF9C4), Color(0xFFB3E5FC), Color(0xFFC8E6C9),
    Color(0xFFFFCCBC), Color(0xFFE1BEE7), Color(0xFFFFE0B2),
  ];

  void _editNote(BuildContext context, Map<String, dynamic>? existing, bool isAr, {String? userId}) {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final contentCtrl = TextEditingController(text: existing?['content'] ?? '');
    final subjectCtrl = TextEditingController(text: existing?['subject'] ?? '');
    int colorIndex = existing?['colorIndex'] ?? 0;

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Scaffold(
        backgroundColor: _colors[colorIndex],
        appBar: AppBar(
          backgroundColor: _colors[colorIndex],
          elevation: 0,
          title: Text(existing == null ? (isAr ? 'ملاحظة جديدة' : 'New Note') : (isAr ? 'تعديل' : 'Edit')),
          actions: [
            // Color picker
            ...List.generate(_colors.length, (i) => GestureDetector(
              onTap: () => setS(() => colorIndex = i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: _colors[i], shape: BoxShape.circle,
                  border: Border.all(color: colorIndex == i ? Colors.black54 : Colors.transparent, width: 2),
                ),
              ),
            )),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.check_rounded),
              onPressed: () async {
                if (contentCtrl.text.trim().isEmpty) { Navigator.pop(ctx); return; }
                final uid = userId ?? context.read<AuthProvider>().currentUser?.uid;
                final data = {
                  'userId': uid, 'title': titleCtrl.text.trim(),
                  'content': contentCtrl.text.trim(), 'subject': subjectCtrl.text.trim(),
                  'colorIndex': colorIndex, 'updatedAt': DateTime.now().toIso8601String(),
                };
                if (existing == null) {
                  await FirebaseFirestore.instance.collection('notes').add({...data, 'createdAt': DateTime.now().toIso8601String()});
                } else {
                  await FirebaseFirestore.instance.collection('notes').doc(existing['docId']).update(data);
                }
                Navigator.pop(ctx);
              }),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(controller: titleCtrl,
              decoration: InputDecoration(hintText: isAr ? 'العنوان' : 'Title', border: InputBorder.none, hintStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20), maxLines: 1),
            TextField(controller: subjectCtrl,
              decoration: InputDecoration(hintText: isAr ? 'المادة' : 'Subject', border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13)),
              style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 1),
            const Divider(),
            Expanded(child: TextField(controller: contentCtrl,
              decoration: InputDecoration(hintText: isAr ? 'اكتب ملاحظتك هنا...' : 'Write your note here...', border: InputBorder.none),
              style: const TextStyle(fontSize: 15, height: 1.6), maxLines: null, expands: true)),
          ]),
        ),
      )),
    ));
  }
}

class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> note; final bool isAr; final VoidCallback onTap;
  static const _colors = [
    Color(0xFFFFF9C4), Color(0xFFB3E5FC), Color(0xFFC8E6C9),
    Color(0xFFFFCCBC), Color(0xFFE1BEE7), Color(0xFFFFE0B2),
  ];
  const _NoteCard({required this.note, required this.isAr, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final colorIndex = (note['colorIndex'] as int? ?? 0).clamp(0, _colors.length - 1);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _colors[colorIndex], borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((note['subject'] ?? '').isNotEmpty)
            Text(note['subject'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
          if ((note['title'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note['title'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 6),
          Expanded(child: Text(note['content'] ?? '', style: const TextStyle(fontSize: 12, height: 1.5), maxLines: 8, overflow: TextOverflow.fade)),
        ]),
      ),
    );
  }
}
