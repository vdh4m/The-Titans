import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  IconData _icon(String type) {
    switch (type) {
      case 'exam':         return Icons.event_rounded;
      case 'xp':           return Icons.electric_bolt_rounded;
      case 'streak':       return Icons.local_fire_department_rounded;
      case 'badge':        return Icons.emoji_events_rounded;
      case 'announcement': return Icons.campaign_rounded;
      case 'battle':       return Icons.sports_kabaddi_rounded;
      case 'meeting':      return Icons.videocam_rounded;
      case 'material':     return Icons.upload_file_rounded;
      case 'quiz':         return Icons.quiz_rounded;
      default:             return Icons.notifications_rounded;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'exam':         return Colors.red;
      case 'xp':           return const Color(0xFFFF9F1C);
      case 'streak':       return Colors.deepOrange;
      case 'badge':        return const Color(0xFFFF9F1C);
      case 'announcement': return AppTheme.primaryColor;
      case 'battle':       return Colors.purple;
      case 'meeting':      return const Color(0xFF16A34A);
      case 'material':     return const Color(0xFF0284C7);
      case 'quiz':         return const Color(0xFF7C3AED);
      default:             return Colors.grey;
    }
  }

  String _timeAgo(String isoDate, bool isAr) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1)  return isAr ? 'الآن'                           : 'Just now';
    if (diff.inMinutes < 60) return isAr ? 'منذ ${diff.inMinutes}د'         : '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return isAr ? 'منذ ${diff.inHours}س'           : '${diff.inHours}h ago';
    if (diff.inDays < 7)     return isAr ? 'منذ ${diff.inDays} يوم'         : '${diff.inDays}d ago';
    return isAr ? '${date.day}/${date.month}' : '${date.month}/${date.day}';
  }

  Future<void> _markRead(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .update({'read': true});
    } catch (_) {}
  }

  // ❌ Removed compound query (.where recipients + .where read==false) 
  // → causes composite-index exception. Fetch all → filter in Dart.
  Future<void> _markAllRead(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipients', arrayContains: uid)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['read'] != true) {
          batch.update(doc.reference, {'read': true});
        }
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user  = context.watch<AuthProvider>().currentUser;
    final isAr  = context.watch<AppProvider>().isArabic;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'الإشعارات' : 'Notifications'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(user.uid),
            child: Text(isAr ? 'قراءة الكل' : 'Mark all read',
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
          ),
        ],
      ),
      // Single query: only arrayContains — no compound filter → no index needed
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipients', arrayContains: user.uid)
            .limit(50)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            // Graceful fallback for permission errors
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🔔', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(isAr ? 'لا توجد إشعارات بعد' : 'No notifications yet',
                  style: theme.textTheme.titleMedium),
            ]));
          }

          // Sort: unread first, then by date
          final docs = snap.data?.docs ?? [];
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aRead = aData['read'] as bool? ?? false;
            final bRead = bData['read'] as bool? ?? false;
            if (aRead != bRead) return aRead ? 1 : -1; // unread first
            final aDate = aData['createdAt'] as String? ?? '';
            final bDate = bData['createdAt'] as String? ?? '';
            return bDate.compareTo(aDate); // newest first
          });

          if (docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🔔', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(isAr ? 'لا توجد إشعارات بعد' : 'No notifications yet',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                isAr ? 'ستظهر هنا إشعارات الامتحانات والـ XP والشارات'
                     : 'Exam alerts, XP gains and badge updates appear here',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ]));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.06)),
            itemBuilder: (_, i) {
              final data  = docs[i].data() as Map<String, dynamic>;
              final docId = docs[i].id;
              final type  = data['type'] as String? ?? 'general';
              final isRead = data['read'] as bool? ?? false;
              final createdAt = data['createdAt'] as String? ?? '';
              final color = _color(type);

              return InkWell(
                onTap: () => _markRead(docId),
                child: Container(
                  color: isRead
                      ? Colors.transparent
                      : color.withOpacity(isDark ? 0.06 : 0.04),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Icon circle
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(_icon(type), color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(
                          isAr
                              ? (data['titleAr'] as String? ?? '')
                              : (data['titleEn'] as String? ?? ''),
                          style: TextStyle(
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w800,
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87),
                        )),
                        if (!isRead)
                          Container(width: 8, height: 8,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        isAr
                            ? (data['bodyAr'] as String? ?? '')
                            : (data['bodyEn'] as String? ?? ''),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(_timeAgo(createdAt, isAr),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ])),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Helper to send notifications from anywhere ────────────────────────────────
class NotificationHelper {
  /// Send to a single user
  static Future<void> send({
    required String uid,
    required String type,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipients': [uid],
        'type':       type,
        'titleAr':    titleAr,
        'titleEn':    titleEn,
        'bodyAr':     bodyAr,
        'bodyEn':     bodyEn,
        'read':       false,
        'createdAt':  DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Broadcast to many users (e.g. all students enrolled in a course)
  static Future<void> sendToMany({
    required List<String> uids,
    required String type,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    Map<String, dynamic> extra = const {},
  }) async {
    if (uids.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final col   = FirebaseFirestore.instance.collection('notifications');
      final now   = DateTime.now().toIso8601String();
      // Firestore arrayContains works chunk by 10 — store all UIDs in one doc
      batch.set(col.doc(), {
        'recipients': uids,
        'type':       type,
        'titleAr':    titleAr,
        'titleEn':    titleEn,
        'bodyAr':     bodyAr,
        'bodyEn':     bodyEn,
        'read':       false,
        'createdAt':  now,
        ...extra,
      });
      await batch.commit();
    } catch (_) {}
  }
}
