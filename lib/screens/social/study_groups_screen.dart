import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/xp_service.dart';
import 'group_chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  StudyGroupsScreen
//  Doctor:  create groups, delete own groups, view member list
//  Student: join via code
// ─────────────────────────────────────────────────────────────────────────────
class StudyGroupsScreen extends StatelessWidget {
  const StudyGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAr = context.watch<AppProvider>().isArabic;
    final user = auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'مجموعات الدراسة' : 'Study Groups'),
        actions: [
          if (user.isDoctor)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _createGroup(context, user, isAr),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('study_groups')
            .where('members', arrayContains: user.uid)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data!.docs;
          if (groups.isEmpty) {
            return _EmptyGroups(
              isAr: isAr,
              isDoctor: user.isDoctor,
              onCreate: () => _createGroup(context, user, isAr),
              onJoin: () => _joinGroup(context, user, isAr),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i].data() as Map<String, dynamic>;
              final isOwner = (g['createdBy'] ?? '') == user.uid;
              return _GroupCard(
                group: g,
                groupId: groups[i].id,
                isAr: isAr,
                currentUid: user.uid,
                isOwner: isOwner,
                isDoctor: user.isDoctor,
              );
            },
          );
        },
      ),
      floatingActionButton: user.isDoctor
          ? FloatingActionButton.extended(
              onPressed: () => _createGroup(context, user, isAr),
              icon: const Icon(Icons.add_rounded),
              label: Text(isAr ? 'إنشاء مجموعة' : 'Create Group'),
              backgroundColor: AppTheme.primaryColor,
            )
          : FloatingActionButton.extended(
              onPressed: () => _joinGroup(context, user, isAr),
              icon: const Icon(Icons.group_add_rounded),
              label: Text(isAr ? 'انضم لمجموعة' : 'Join Group'),
              backgroundColor: AppTheme.primaryColor,
            ),
    );
  }

  // ── Create group ────────────────────────────────────────────────────────────
  void _createGroup(BuildContext context, user, bool isAr) {
    final nameCtrl    = TextEditingController();
    final subjectCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'إنشاء مجموعة' : 'Create Group'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: InputDecoration(
            labelText: isAr ? 'اسم المجموعة' : 'Group name',
            prefixIcon: const Icon(Icons.group_rounded),
          )),
          const SizedBox(height: 12),
          TextField(controller: subjectCtrl, decoration: InputDecoration(
            labelText: isAr ? 'المادة' : 'Subject',
            prefixIcon: const Icon(Icons.book_outlined),
          )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final code =
                  (const Uuid().v4()).substring(0, 6).toUpperCase();
              await FirebaseFirestore.instance
                  .collection('study_groups').add({
                'name':            nameCtrl.text.trim(),
                'subject':         subjectCtrl.text.trim(),
                'createdBy':       user.uid,
                'members':         [user.uid],
                'code':            code,
                'createdAt':       DateTime.now().toIso8601String(),
                'lastMessage':     '',
                'lastMessageTime': DateTime.now().toIso8601String(),
              });
              Navigator.pop(ctx);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text(isAr
                      ? 'تم الإنشاء! كود المجموعة: $code'
                      : 'Created! Group code: $code'),
                  duration: const Duration(seconds: 6),
                  backgroundColor: AppTheme.primaryColor,
                ));
              }
            },
            child: Text(isAr ? 'إنشاء' : 'Create'),
          ),
        ],
      ),
    );
  }

  // ── Join group ──────────────────────────────────────────────────────────────
  void _joinGroup(BuildContext context, user, bool isAr) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'انضم بكود' : 'Join with Code'),
        content: TextField(
          controller: codeCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: isAr ? 'كود المجموعة' : 'Group code',
            prefixIcon: const Icon(Icons.tag_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              final snap = await FirebaseFirestore.instance
                  .collection('study_groups')
                  .where('code', isEqualTo: codeCtrl.text.trim().toUpperCase())
                  .get();
              if (snap.docs.isEmpty) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(isAr ? 'كود غير صحيح' : 'Invalid code'),
                    backgroundColor: Colors.red,
                  ));
                }
                return;
              }
              await snap.docs.first.reference.update({
                'members': FieldValue.arrayUnion([user.uid]),
              });
              await XpService.award(user.uid, XpEvent.joinGroup);
              Navigator.pop(ctx);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                content: Text('✅ Joined! +10 XP'),
                backgroundColor: Color(0xFF06D6A0),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ));
              }
            },
            child: Text(isAr ? 'انضم' : 'Join'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Group card — doctor sees Delete + Members buttons
// ─────────────────────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final String groupId, currentUid;
  final bool isAr, isOwner, isDoctor;
  const _GroupCard({
    required this.group, required this.groupId,
    required this.isAr, required this.currentUid,
    required this.isOwner, required this.isDoctor,
  });

  Future<void> _deleteGroup(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isAr ? 'حذف المجموعة؟' : 'Delete Group?'),
        content: Text(isAr
            ? 'سيتم حذف "${group['name']}" ومحادثاتها نهائياً'
            : 'This will permanently delete "${group['name']}" and its chat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'حذف' : 'Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Delete messages subcollection
    final db  = FirebaseFirestore.instance;
    final msgs = await db.collection('chats').doc(groupId)
        .collection('messages').get();
    for (final m in msgs.docs) {
      await m.reference.delete();
    }
    await db.collection('study_groups').doc(groupId).delete();
  }

  void _showMembers(BuildContext ctx) {
    final members = List<String>.from(group['members'] ?? []);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _MembersSheet(
          memberIds: members, isAr: isAr, groupName: group['name'] ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberCount = (group['members'] as List?)?.length ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF7209B7)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(
              (group['name'] as String? ?? '?')[0].toUpperCase(),
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 20),
            )),
          ),
          title: Text(group['name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((group['subject'] ?? '').isNotEmpty)
              Text(group['subject'],
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            Row(children: [
              Icon(Icons.people_rounded, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 3),
              Text('$memberCount ${isAr ? 'أعضاء' : 'members'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: group['code'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isAr
                        ? 'تم نسخ الكود: ${group['code']}'
                        : 'Code copied: ${group['code']}'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppTheme.primaryColor,
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.tag_rounded, size: 10,
                        color: AppTheme.primaryColor),
                    const SizedBox(width: 2),
                    Text(group['code'] ?? '',
                        style: TextStyle(fontSize: 10,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 2),
                    Icon(Icons.copy_rounded, size: 10,
                        color: AppTheme.primaryColor),
                  ]),
                ),
              ),
            ]),
          ]),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => GroupChatScreen(
                groupId: groupId,
                groupName: group['name'] ?? '',
                isAr: isAr))),
        ),

        // ── Doctor action bar ────────────────────────────────────────────────
        if (isDoctor) ...[
          Divider(height: 1,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white12 : Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(children: [
              // View members (all doctors in group)
              Expanded(child: TextButton.icon(
                icon: Icon(Icons.people_outline_rounded, size: 15,
                    color: AppTheme.primaryColor),
                label: Text(isAr ? 'الأعضاء' : 'Members',
                    style: TextStyle(color: AppTheme.primaryColor,
                        fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () => _showMembers(context),
              )),
              if (isOwner) ...[
                Container(width: 1, height: 24, color: Colors.grey.shade200),
                // Delete (owner only)
                Expanded(child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 15, color: Colors.red),
                  label: Text(isAr ? 'حذف المجموعة' : 'Delete',
                      style: const TextStyle(color: Colors.red,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () => _deleteGroup(context),
                )),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Members bottom sheet — fetches user names from Firestore
// ─────────────────────────────────────────────────────────────────────────────
class _MembersSheet extends StatelessWidget {
  final List<String> memberIds;
  final bool isAr;
  final String groupName;
  const _MembersSheet({required this.memberIds, required this.isAr,
      required this.groupName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1730) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Container(width: 4, height: 24,
              decoration: BoxDecoration(color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 10),
          Expanded(child: Text(
            isAr
                ? 'أعضاء مجموعة "$groupName"'
                : 'Members of "$groupName"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Text('${memberIds.length}',
                style: const TextStyle(color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: memberIds.isEmpty
              ? Center(child: Text(isAr ? 'لا يوجد أعضاء' : 'No members',
                  style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: memberIds.length,
                  itemBuilder: (_, i) => _MemberTile(
                      uid: memberIds[i], isAr: isAr, index: i),
                ),
        ),
      ]),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String uid; final bool isAr; final int index;
  const _MemberTile({required this.uid, required this.isAr, required this.index});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (_, snap) {
        String name  = isAr ? 'جاري التحميل...' : 'Loading...';
        String role  = '';
        String email = '';
        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() as Map<String, dynamic>;
          name  = d['fullName'] ?? d['email'] ?? uid;
          role  = d['role'] ?? 'student';
          email = d['email'] ?? '';
        }
        final isDoctor = role == 'doctor';
        final colors   = [
          AppTheme.primaryColor, const Color(0xFF06D6A0),
          const Color(0xFFF72585), const Color(0xFFFF9F1C),
        ];
        final avatarColor = colors[index % colors.length];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 4, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: avatarColor.withOpacity(0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: avatarColor,
                  fontWeight: FontWeight.w800),
            ),
          ),
          title: Text(name, style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(email,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          trailing: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isDoctor
                  ? AppTheme.primaryColor : const Color(0xFF06D6A0))
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isDoctor
                  ? (isAr ? 'دكتور' : 'Doctor')
                  : (isAr ? 'طالب' : 'Student'),
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: isDoctor
                    ? AppTheme.primaryColor : const Color(0xFF06D6A0),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  final bool isAr, isDoctor;
  final VoidCallback onCreate, onJoin;
  const _EmptyGroups({required this.isAr, required this.isDoctor,
      required this.onCreate, required this.onJoin});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('👥', style: TextStyle(fontSize: 60)),
    const SizedBox(height: 16),
    Text(isAr ? 'لا توجد مجموعات بعد' : 'No groups yet',
        style: TextStyle(color: Colors.grey[500], fontSize: 16)),
    const SizedBox(height: 20),
    if (isDoctor)
      ElevatedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add),
          label: Text(isAr ? 'إنشاء مجموعة' : 'Create Group'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48)))
    else
      ElevatedButton.icon(onPressed: onJoin,
          icon: const Icon(Icons.group_add_rounded),
          label: Text(isAr ? 'انضم لمجموعة' : 'Join Group'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48))),
  ]));
}