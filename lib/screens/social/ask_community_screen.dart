import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../utils/xp_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class AskCommunityScreen extends StatelessWidget {
  const AskCommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAr = context.watch<AppProvider>().isArabic;
    final user = auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'اسأل المجتمع' : 'Ask Community')),
      body: Column(children: [
        // Ask button
        Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () => _askQuestion(context, user, isAr),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1.5),
              ),
              child: Row(children: [
                const Icon(Icons.help_outline_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(isAr ? 'اكتب سؤالك هنا...' : 'Write your question here...',
                  style: TextStyle(color: Colors.grey[500])),
              ]),
            ),
          ),
        ),
        // Questions feed
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('community_questions')
            .where('facultyAr', isEqualTo: user.facultyAr)
            .where('universityAr', isEqualTo: user.universityAr)
            .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final questions = snap.data!.docs
              .map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id})
              .toList()
              ..sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
            if (questions.isEmpty) {
              return Center(child: Text(isAr ? 'لا توجد أسئلة بعد' : 'No questions yet',
              style: TextStyle(color: Colors.grey[500])));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: questions.length,
              itemBuilder: (_, i) => _QuestionCard(q: questions[i], isAr: isAr, currentUid: user.uid),
            );
          },
        )),
      ]),
    );
  }

  void _askQuestion(BuildContext context, user, bool isAr) {
    final ctrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isAr ? 'اطرح سؤالاً' : 'Ask a Question'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: subjectCtrl, decoration: InputDecoration(
            labelText: isAr ? 'المادة (اختياري)' : 'Subject (optional)',
            prefixIcon: const Icon(Icons.book_outlined),
          )),
          const SizedBox(height: 12),
          TextField(controller: ctrl, decoration: InputDecoration(
            labelText: isAr ? 'سؤالك' : 'Your question',
            prefixIcon: const Icon(Icons.help_outline_rounded),
          ), maxLines: 4),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Cancel')),
        ElevatedButton(onPressed: () async {
          if (ctrl.text.trim().isEmpty) return;
          await FirebaseFirestore.instance.collection('community_questions').add({
            'id': const Uuid().v4(), 'question': ctrl.text.trim(),
            'subject': subjectCtrl.text.trim(),
            'askedBy': user.uid, 'askerEmail': user.email,
            'facultyAr': user.facultyAr, 'universityAr': user.universityAr,
            'year': user.year, 'answers': [],
            'upvotes': 0, 'upvotedBy': [],
            'createdAt': DateTime.now().toIso8601String(),
          });
          await XpService.award(user.uid, XpEvent.postCommunity); // +5 XP
          Navigator.pop(ctx);
        }, child: Text(isAr ? 'نشر' : 'Post')),
      ],
    ));
  }
}

class _QuestionCard extends StatelessWidget {
  final Map<String, dynamic> q; final bool isAr; final String currentUid;
  const _QuestionCard({required this.q, required this.isAr, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final answers = List.from(q['answers'] ?? []);
    final upvotes = q['upvotes'] ?? 0;
    final upvotedBy = List.from(q['upvotedBy'] ?? []);
    final hasUpvoted = upvotedBy.contains(currentUid);

    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ((q['subject'] ?? '').isNotEmpty)
          Container(margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(q['subject'], style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w600))),
        Text(q['question'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.4)),
        const SizedBox(height: 10),
        Row(children: [
          GestureDetector(
            onTap: () async {
              final ref = FirebaseFirestore.instance.collection('community_questions').doc(q['id']);
              if (hasUpvoted) {
                await ref.update({'upvotes': FieldValue.increment(-1), 'upvotedBy': FieldValue.arrayRemove([currentUid])});
              } else {
                await ref.update({'upvotes': FieldValue.increment(1), 'upvotedBy': FieldValue.arrayUnion([currentUid])});
                // Award XP to post author
                final postAuthor = q['askedBy'] as String?;
                if (postAuthor != null && postAuthor != currentUid) {
                  await XpService.award(postAuthor, XpEvent.receiveUpvote);
                }
              }
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(hasUpvoted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                size: 16, color: hasUpvoted ? AppTheme.primaryColor : Colors.grey),
              const SizedBox(width: 4),
              Text('$upvotes', style: TextStyle(color: hasUpvoted ? AppTheme.primaryColor : Colors.grey, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 16),
          Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Text('${answers.length} ${isAr ? 'إجابة' : 'answers'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const Spacer(),
          Text(q['askerEmail']?.split('@').first ?? '', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        ]),
        if (answers.isNotEmpty) ...[
          const Divider(height: 16),
          ...answers.take(2).map((a) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6, right: 8, left: 8),
                decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle)),
              Expanded(child: Text(a['text'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4))),
            ]),
          )),
        ],
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _answerDialog(context, q['id'], isAr),
          child: Text(isAr ? '+ أضف إجابة' : '+ Add answer',
            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ]),
    ));
  }

  void _answerDialog(BuildContext context, String qId, bool isAr) {
    final ctrl = TextEditingController();
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    final email = context.read<AuthProvider>().currentUser?.email ?? '';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isAr ? 'إجابتك' : 'Your Answer'),
      content: SingleChildScrollView(
        child: TextField(controller: ctrl, decoration: InputDecoration(
          hintText: isAr ? 'اكتب إجابتك...' : 'Write your answer...',
        ), maxLines: 4),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Cancel')),
        ElevatedButton(onPressed: () async {
          if (ctrl.text.trim().isEmpty) return;
          await FirebaseFirestore.instance.collection('community_questions').doc(qId).update({
            'answers': FieldValue.arrayUnion([{'text': ctrl.text.trim(), 'by': email, 'uid': uid, 'at': DateTime.now().toIso8601String()}])
          });
          Navigator.pop(ctx);
        }, child: Text(isAr ? 'نشر' : 'Post')),
      ],
    ));
  }
}