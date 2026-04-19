import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/course_model.dart';
import '../../models/meeting_model.dart';
import '../home/notification_center_screen.dart';
import 'in_app_meeting_screen.dart';

// ── MEETINGS TAB (StatefulWidget — stream cached in initState) ────────────────
class MeetingsTab extends StatefulWidget {
  final CourseModel course;
  final bool isAr;
  final dynamic user;
  final bool canManage;

  const MeetingsTab({
    super.key,
    required this.course,
    required this.isAr,
    required this.user,
    required this.canManage,
  });

  @override
  State<MeetingsTab> createState() => _MeetingsTabState();
}

class _MeetingsTabState extends State<MeetingsTab> {
  late final Stream<QuerySnapshot> _stream;
  List<MeetingModel> _meetings = [];
  bool _loading = true;
  StreamSubscription<QuerySnapshot>? _sub;

  CollectionReference get _col => FirebaseFirestore.instance
      .collection('courses')
      .doc(widget.course.id)
      .collection('meetings');

  @override
  void initState() {
    super.initState();
    _stream = _col.snapshots();
    _sub = _stream.listen(
      (snap) {
        if (!mounted) return;
        final list = snap.docs
            .map((d) => MeetingModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        setState(() { _meetings = list; _loading = false; });
      },
      onError: (e) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  String _generateRoomName() {
    final rand  = Random().nextInt(99999).toString().padLeft(5, '0');
    final short = widget.course.id.length >= 8
        ? widget.course.id.substring(0, 8)
        : widget.course.id;
    return 'studyhub-$short-$rand';
  }

  Future<void> _startMeeting() async {
    final ctx = context;
    final titleArCtrl = TextEditingController(
        text: widget.isAr ? widget.course.titleAr : widget.course.titleEn);
    final titleEnCtrl = TextEditingController(text: widget.course.titleEn);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('📹  ', style: TextStyle(fontSize: 20)),
          Text('ابدأ اجتماع'),
        ]),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.videocam_rounded, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  widget.isAr
                      ? 'الاجتماع سيعمل داخل التطبيق مباشرة'
                      : 'Meeting runs inside the app',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                )),
              ]),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: titleArCtrl,
              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
              decoration: const InputDecoration(
                  labelText: 'العنوان (عربي)',
                  prefixIcon: Icon(Icons.title_rounded)),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: titleEnCtrl,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              decoration: const InputDecoration(
                  labelText: 'Title (English)',
                  prefixIcon: Icon(Icons.title_rounded)),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.isAr ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.videocam_rounded, color: Colors.white),
            label: Text(widget.isAr ? 'ابدأ الآن' : 'Start Now',
                style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final roomName = _generateRoomName();
    final titleAr  = titleArCtrl.text.trim();
    final titleEn  = titleEnCtrl.text.trim();

    try {
      await _col.add({
        'courseId':  widget.course.id,
        'doctorId':  widget.user.uid,
        'titleAr':   titleAr,
        'titleEn':   titleEn,
        'roomName':  roomName,
        'link':      '',
        'startedAt': DateTime.now().toIso8601String(),
        'isActive':  true,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطأ: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      }
      return;
    }

    // Notify students (best-effort)
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('universityAr', isEqualTo: widget.course.universityAr)
          .where('facultyAr',    isEqualTo: widget.course.facultyAr)
          .where('year',         isEqualTo: widget.course.year)
          .get();
      final uids = snap.docs.map((d) => d.id)
          .where((id) => id != widget.user.uid)
          .toList();
      await NotificationHelper.sendToMany(
        uids:    uids,
        type:    'meeting',
        titleAr: 'اجتماع مباشر — $titleAr',
        titleEn: 'Live Meeting — $titleEn',
        bodyAr:  'الدكتور بدأ اجتماعاً الآن في ${widget.course.titleAr}. انضم الآن!',
        bodyEn:  'Doctor started a live meeting in ${widget.course.titleEn}. Join now!',
        extra:   {'courseId': widget.course.id},
      );
    } catch (_) {}

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => InAppMeetingScreen(
        roomName: roomName,
        title:    widget.isAr ? titleAr : titleEn,
        isAr:     widget.isAr,
      ),
    ));
  }

  Future<void> _endMeeting(String id) async {
    try { await _col.doc(id).update({'isActive': false}); } catch (_) {}
  }

  Future<void> _deleteMeeting(String id) async {
    try { await _col.doc(id).delete(); } catch (_) {}
  }

  void _joinMeeting(MeetingModel m) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => InAppMeetingScreen(
        roomName: m.roomName.isNotEmpty ? m.roomName : m.link,
        title:    widget.isAr ? m.titleAr : m.titleEn,
        isAr:     widget.isAr,
      ),
    ));
  }

  // ─── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_meetings.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('📹', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(widget.isAr ? 'لا توجد اجتماعات بعد' : 'No meetings yet',
              style: theme.textTheme.titleMedium),
          if (widget.canManage) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _startMeeting,
              icon: const Icon(Icons.videocam_rounded, color: Colors.white),
              label: Text(widget.isAr ? 'ابدأ اجتماع الآن' : 'Start Meeting Now',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
          ],
        ]),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: _meetings.length,
          itemBuilder: (_, i) {
            final m = _meetings[i];
            return _MeetCard(
              meeting:   m,
              isAr:      widget.isAr,
              canManage: widget.canManage,
              onJoin:    () => _joinMeeting(m),
              onEnd:     () => _endMeeting(m.id),
              onDelete:  () => _deleteMeeting(m.id),
            );
          },
        ),
        if (widget.canManage)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              heroTag: 'meet_fab_${widget.course.id}',
              onPressed: _startMeeting,
              backgroundColor: const Color(0xFF16A34A),
              icon: const Icon(Icons.videocam_rounded, color: Colors.white),
              label: Text(widget.isAr ? 'ابدأ اجتماع' : 'Start Meeting',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

// ── Meeting Card ──────────────────────────────────────────────────────────────
class _MeetCard extends StatelessWidget {
  final MeetingModel meeting;
  final bool isAr, canManage;
  final VoidCallback onJoin, onEnd, onDelete;

  const _MeetCard({
    required this.meeting,
    required this.isAr,
    required this.canManage,
    required this.onJoin,
    required this.onEnd,
    required this.onDelete,
  });

  String _timeLabel(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return isAr ? 'الآن' : 'Just now';
    if (diff.inMinutes < 60) return isAr ? 'منذ ${diff.inMinutes}د' : '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return isAr ? 'منذ ${diff.inHours}س'   : '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final live  = meeting.isActive;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: live
            ? const LinearGradient(
                colors: [Color(0xFF14532D), Color(0xFF166534)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: live ? null : (isDark ? const Color(0xFF1A1730) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: live ? const Color(0xFF16A34A) : Colors.grey.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [BoxShadow(
          color: live
              ? const Color(0xFF16A34A).withOpacity(0.3)
              : Colors.black.withOpacity(0.05),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (live)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.circle, color: Colors.white, size: 8),
                  const SizedBox(width: 4),
                  Text(isAr ? 'مباشر' : 'LIVE',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                ]),
              ),
            Expanded(
              child: Text(
                isAr ? meeting.titleAr : meeting.titleEn,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15,
                    color: live ? Colors.white : null),
              ),
            ),
            if (canManage && !live)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                tooltip: isAr ? 'حذف' : 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.videocam_rounded,
                size: 14, color: live ? Colors.white54 : Colors.grey[400]),
            const SizedBox(width: 4),
            Text(isAr ? 'داخل التطبيق' : 'In-App',
                style: TextStyle(fontSize: 11,
                    color: live ? Colors.white54 : Colors.grey[500])),
            const SizedBox(width: 8),
            Text(_timeLabel(meeting.startedAt),
                style: TextStyle(fontSize: 11,
                    color: live ? Colors.white70 : Colors.grey[500])),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
                label: Text(isAr ? 'انضم' : 'Join',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: live ? Colors.white24 : const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
            if (canManage && live) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onEnd,
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(isAr ? 'إنهاء' : 'End',
                    style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}
