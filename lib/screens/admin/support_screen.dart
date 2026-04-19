import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SupportScreen — In-app live chat support
//
//  Student/Doctor side: Opens a chat thread with support
//  Admin side:          Sees all open tickets, can reply
//
//  Firestore:
//   support_tickets/{ticketId}
//     { uid, userEmail, userName, userRole, status, createdAt, lastMessage, lastMessageAt }
//   support_tickets/{ticketId}/messages/{msgId}
//     { senderId, senderName, isAdmin, text, createdAt }
// ─────────────────────────────────────────────────────────────────────────────
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Admin sees all tickets; others see their own chat
    final isAdmin = (user as dynamic).isAdmin == true;
    if (isAdmin) return const _AdminTicketListScreen();
    return _UserSupportChatScreen(uid: user.uid, userName: user.fullName ?? user.email, userRole: user.role, userEmail: user.email);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  USER SIDE — Chat with support
// ─────────────────────────────────────────────────────────────────────────────
class _UserSupportChatScreen extends StatefulWidget {
  final String uid, userName, userRole, userEmail;
  const _UserSupportChatScreen({required this.uid, required this.userName, required this.userRole, required this.userEmail});
  @override State<_UserSupportChatScreen> createState() => _UserSupportChatScreenState();
}

class _UserSupportChatScreenState extends State<_UserSupportChatScreen> {
  final _ctrl     = TextEditingController();
  final _scroll   = ScrollController();
  String? _ticketId;
  bool    _loading = true;

  @override
  void initState() { super.initState(); _initTicket(); }
  @override void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  // ignore: unused_element
  bool get _isAr => context.read<AppProvider>().isArabic;

  Future<void> _initTicket() async {
    // Check if user already has an open ticket
    final snap = await FirebaseFirestore.instance
        .collection('support_tickets')
        .where('uid', isEqualTo: widget.uid)
        .where('status', isEqualTo: 'open')
        .limit(1).get();

    if (snap.docs.isNotEmpty) {
      setState(() { _ticketId = snap.docs.first.id; _loading = false; });
    } else {
      // Create new ticket
      final id = const Uuid().v4();
      await FirebaseFirestore.instance.collection('support_tickets').doc(id).set({
        'uid':           widget.uid,
        'userEmail':     widget.userEmail,
        'userName':      widget.userName,
        'userRole':      widget.userRole,
        'status':        'open',
        'createdAt':     DateTime.now().toIso8601String(),
        'lastMessage':   '',
        'lastMessageAt': DateTime.now().toIso8601String(),
      });
      setState(() { _ticketId = id; _loading = false; });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _ticketId == null) return;
    _ctrl.clear();

    final msgId = const Uuid().v4();
    final now   = DateTime.now().toIso8601String();
    final batch = FirebaseFirestore.instance.batch();

    // Add message
    batch.set(
      FirebaseFirestore.instance
          .collection('support_tickets').doc(_ticketId)
          .collection('messages').doc(msgId),
      {
        'id':         msgId,
        'senderId':   widget.uid,
        'senderName': widget.userName,
        'isAdmin':    false,
        'text':       text,
        'createdAt':  now,
      },
    );
    // Update ticket last message
    batch.update(
      FirebaseFirestore.instance.collection('support_tickets').doc(_ticketId),
      {'lastMessage': text, 'lastMessageAt': now, 'status': 'open'},
    );
    await batch.commit();

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr   = context.watch<AppProvider>().isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Center(child: Text('🎧', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isAr ? 'الدعم الفني' : 'Support',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(isAr ? 'عادةً يرد خلال ساعات' : 'Usually replies within hours',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Welcome banner
              if (MediaQuery.of(context).viewInsets.bottom < 50)
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Text('👋', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      isAr
                          ? 'مرحباً! اكتب مشكلتك وسيرد عليك فريق الدعم في أقرب وقت.'
                          : 'Hi! Describe your issue and our support team will reply shortly.',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    )),
                  ]),
                ),

              // Messages
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('support_tickets').doc(_ticketId)
                      .collection('messages')
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (_, snap) {
                    if (snap.hasError) return Center(child: Text('Error loading messages: ${snap.error}', style: const TextStyle(color: Colors.red)));
                    if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final msgs = snap.data!.docs;
                    if (msgs.isEmpty) {
                      return Center(
                      child: Text(
                        isAr ? 'ابدأ المحادثة...' : 'Start the conversation...',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scroll.hasClients) {
                        _scroll.jumpTo(_scroll.position.maxScrollExtent);
                      }
                    });
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m      = msgs[i].data() as Map<String, dynamic>;
                        final isMe   = !(m['isAdmin'] as bool? ?? false);
                        return _Bubble(
                            text: m['text'] ?? '',
                            isMe: isMe,
                            senderName: m['senderName'] ?? '',
                            time: m['createdAt'] as String? ?? '',
                            isDark: isDark);
                      },
                    );
                  },
                ),
              ),

              // Input
              _ChatInput(ctrl: _ctrl, isAr: isAr, isDark: isDark, onSend: _send),
            ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ADMIN SIDE — See all tickets and reply
// ─────────────────────────────────────────────────────────────────────────────
class _AdminTicketListScreen extends StatefulWidget {
  const _AdminTicketListScreen();
  @override State<_AdminTicketListScreen> createState() => _AdminTicketListScreenState();
}

class _AdminTicketListScreenState extends State<_AdminTicketListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎧 Support Tickets', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: '🔵 Open'), Tab(text: '✅ Closed')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TicketList(status: 'open', isDark: isDark),
          _TicketList(status: 'closed', isDark: isDark),
        ],
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  final String status; final bool isDark;
  const _TicketList({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .where('status', isEqualTo: status)
          .orderBy('lastMessageAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: SelectableText('Database setup required. Please copy this link and open in browser to create the index:\n\n${snap.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))));
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
          child: Text(status == 'open' ? 'No open tickets 🎉' : 'No closed tickets',
              style: TextStyle(color: Colors.grey[500])),
        );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d  = docs[i].data() as Map<String, dynamic>;
            final dt = d['lastMessageAt'] != null
                ? DateTime.tryParse(d['lastMessageAt']) : null;
            return ListTile(
              contentPadding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: isDark ? const Color(0xFF1A1730) : Colors.white,
              leading: CircleAvatar(
                backgroundColor: d['userRole'] == 'doctor'
                    ? AppTheme.primaryColor.withOpacity(0.12)
                    : const Color(0xFF06D6A0).withOpacity(0.12),
                child: Text(
                  (d['userName'] as String? ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: d['userRole'] == 'doctor'
                          ? AppTheme.primaryColor : const Color(0xFF06D6A0)),
                ),
              ),
              title: Row(children: [
                Expanded(child: Text(d['userName'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: d['userRole'] == 'doctor'
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : const Color(0xFF06D6A0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    d['userRole'] == 'doctor' ? 'Doctor' : 'Student',
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: d['userRole'] == 'doctor'
                          ? AppTheme.primaryColor : const Color(0xFF06D6A0),
                    ),
                  ),
                ),
              ]),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['userEmail'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text(d['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ]),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (dt != null)
                  Text('${dt.day}/${dt.month}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                if (status == 'open')
                  const Icon(Icons.circle, color: Color(0xFF06D6A0), size: 8),
              ]),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => _AdminChatScreen(
                  ticketId:  docs[i].id,
                  userName:  d['userName'] ?? 'User',
                  userEmail: d['userEmail'] ?? '',
                  userRole:  d['userRole'] ?? 'student',
                  isDark:    isDark,
                ),
              )),
            );
          },
        );
      },
    );
  }
}

class _AdminChatScreen extends StatefulWidget {
  final String ticketId, userName, userEmail, userRole; final bool isDark;
  const _AdminChatScreen({required this.ticketId, required this.userName,
      required this.userEmail, required this.userRole, required this.isDark});
  @override State<_AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<_AdminChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  @override void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _send() async {
    final text = _ctrl.text.trim(); if (text.isEmpty) return; _ctrl.clear();
    final msgId = const Uuid().v4(); final now = DateTime.now().toIso8601String();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      FirebaseFirestore.instance.collection('support_tickets').doc(widget.ticketId).collection('messages').doc(msgId),
      {'id': msgId, 'senderId': 'admin', 'senderName': 'Support Team 🎧', 'isAdmin': true, 'text': text, 'createdAt': now},
    );
    batch.update(
      FirebaseFirestore.instance.collection('support_tickets').doc(widget.ticketId),
      {'lastMessage': text, 'lastMessageAt': now},
    );
    await batch.commit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _closeTicket() async {
    await FirebaseFirestore.instance.collection('support_tickets').doc(widget.ticketId).update({'status': 'closed'});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          Text(widget.userEmail, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
        actions: [
          TextButton.icon(
            onPressed: _closeTicket,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('support_tickets').doc(widget.ticketId)
              .collection('messages').orderBy('createdAt').snapshots(),
          builder: (_, snap) {
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)));
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final msgs = snap.data!.docs;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
            });
            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m    = msgs[i].data() as Map<String, dynamic>;
                final isMe = m['isAdmin'] as bool? ?? false;
                return _Bubble(text: m['text'] ?? '', isMe: isMe, senderName: m['senderName'] ?? '', time: m['createdAt'] ?? '', isDark: isDark);
              },
            );
          },
        )),
        _ChatInput(ctrl: _ctrl, isAr: false, isDark: isDark, onSend: _send),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final String text, senderName, time; final bool isMe, isDark;
  const _Bubble({required this.text, required this.isMe, required this.senderName, required this.time, required this.isDark});

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso); if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2,'0');
    final m = dt.minute.toString().padLeft(2,'0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          CircleAvatar(radius: 14, backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: const Text('🎧', style: TextStyle(fontSize: 12))),
          const SizedBox(width: 6),
        ],
        Flexible(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primaryColor : (isDark ? const Color(0xFF1A1730) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(18),
              topRight:    const Radius.circular(18),
              bottomLeft:  Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!isMe)
              Text(senderName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
            Text(text, style: TextStyle(fontSize: 14, color: isMe ? Colors.white : null, height: 1.4)),
            const SizedBox(height: 3),
            Text(_fmt(time), style: TextStyle(fontSize: 10, color: isMe ? Colors.white54 : Colors.grey[400])),
          ]),
        )),
        if (isMe) const SizedBox(width: 6),
      ],
    ),
  );
}

class _ChatInput extends StatelessWidget {
  final TextEditingController ctrl; final bool isAr, isDark; final VoidCallback onSend;
  const _ChatInput({required this.ctrl, required this.isAr, required this.isDark, required this.onSend});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 16),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF0E0C1E) : Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -3))],
    ),
    child: Row(children: [
      Expanded(child: TextField(
        controller: ctrl,
        maxLines: 4, minLines: 1,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          hintText: isAr ? 'اكتب رسالتك...' : 'Type a message...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          filled: true, fillColor: isDark ? const Color(0xFF1A1730) : Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      )),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onSend,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    ]),
  );
}