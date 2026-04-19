import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:studyhub/utils/app_theme.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/xp_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId, groupName; final bool isAr;
  const GroupChatScreen({super.key, required this.groupId, required this.groupName, required this.isAr});
  @override State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  void _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    _ctrl.clear();
    final msgId = const Uuid().v4();
    await FirebaseFirestore.instance
      .collection('study_groups').doc(widget.groupId)
      .collection('messages').doc(msgId).set({
        'id': msgId, 'text': text, 'senderId': user.uid,
        'senderEmail': user.email, 'senderName': user.fullName ?? user.email, 'isDoctor': user.isDoctor,
        'createdAt': DateTime.now().toIso8601String(),
      });
    await FirebaseFirestore.instance.collection('study_groups').doc(widget.groupId)
      .update({'lastMessage': text, 'lastMessageTime': DateTime.now().toIso8601String()});

    // XP for messaging — capped at 20 per day
    final prefs  = await SharedPreferences.getInstance();
    final today  = DateTime.now().toIso8601String().substring(0, 10);
    final key    = 'msg_xp_$today';
    final count  = prefs.getInt(key) ?? 0;
    if (count < 20) {
      await XpService.award(user.uid, XpEvent.sendMessage);
      await prefs.setInt(key, count + 1);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
            .collection('study_groups').doc(widget.groupId)
            .collection('messages').orderBy('createdAt').snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final msgs = snap.data!.docs;
            return ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i].data() as Map<String, dynamic>;
                final isMe = m['senderId'] == uid;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isMe) ...[
                        CircleAvatar(radius: 14, backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                          child: Text((m['senderEmail'] as String? ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 8),
                      ],
                      Flexible(child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primaryColor : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
                            bottomLeft: isMe ? const Radius.circular(14) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(14),
                          ),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (!isMe) Text(m['senderEmail'] ?? '',
                            style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w700)),
                          Text(m['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : null, height: 1.4)),
                        ]),
                      )),
                    ],
                  ),
                );
              },
            );
          },
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3))],
          ),
          child: Row(children: [
            Expanded(child: TextField(controller: _ctrl, decoration: InputDecoration(
              hintText: widget.isAr ? 'اكتب رسالة...' : 'Type a message...',
            ), maxLines: null, onSubmitted: (_) => _send())),
            const SizedBox(width: 8),
            GestureDetector(onTap: _send,
              child: Container(padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
          ]),
        ),
      ]),
    );
  }
}