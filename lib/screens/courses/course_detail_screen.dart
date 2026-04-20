// ignore_for_file: unused_import, duplicate_ignore

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: duplicate_ignore
// ignore: unused_import
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
// ignore: unused_import
import 'package:http/http.dart' as http;
import 'package:studyhub/generated/l10n/app_localizations.dart';
import 'package:studyhub/offline_manager.dart';
// ignore: unused_import
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../models/course_model.dart';
import 'meetings_tab.dart';
import 'upload_material_dialog.dart';
// ignore: unused_import
import '../../models/meeting_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import 'file_viewer_screen.dart';
// ignore: unused_import
import '../../utils/xp_service.dart';
import '../payment/paywall_gate.dart';
import '../home/notification_center_screen.dart';
import 'doctor_course_quiz_screen.dart';
import 'student_quiz_screen.dart';


class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;
  final bool isAr;
  const CourseDetailScreen({super.key, required this.course, required this.isAr});
  @override State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Side course: only Material + Chat tabs (NO announcements)
  bool get _isSide => widget.course.type == 'side';

  @override
  void initState() {
    super.initState();
    // Side courses: 2 tabs   Main courses: 4 tabs (Material, Meetings, Announcements, Chat)
    _tabs = TabController(length: _isSide ? 2 : 4, vsync: this);
  }

  @override void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Who can manage materials?
    // • Main course → doctor who owns it
    // • Side course → the user who created it (doctorId stores creator uid)
    final canManage = user.uid == widget.course.doctorId;

    final tabs = _isSide
        ? [
            Tab(text: widget.isAr ? 'المواد' : 'Material'),
            Tab(text: widget.isAr ? 'المحادثة' : 'Chat'),
          ]
        : [
            Tab(text: widget.isAr ? 'المواد' : 'Material'),
            Tab(text: widget.isAr ? 'الاجتماعات' : 'Meetings'),
            Tab(text: widget.isAr ? 'الإعلانات' : 'Announcements'),
            Tab(text: widget.isAr ? 'المحادثة' : 'Chat'),
          ];

    final tabViews = _isSide
        ? [
            _MatTab(course: widget.course, isAr: widget.isAr, user: user, l10n: l10n, canManage: canManage),
            _ChatTab(course: widget.course, isAr: widget.isAr, user: user, l10n: l10n),
          ]
        : [
            _MatTab(course: widget.course, isAr: widget.isAr, user: user, l10n: l10n, canManage: canManage),
            MeetingsTab(course: widget.course, isAr: widget.isAr, user: user, canManage: canManage),
            _AnnTab(course: widget.course, isAr: widget.isAr, user: user, l10n: l10n),
            _ChatTab(course: widget.course, isAr: widget.isAr, user: user, l10n: l10n),
          ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.isAr ? widget.course.titleAr : widget.course.titleEn,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (_isSide)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.isAr ? 'كورس جانبي' : 'Side Course',
                style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.w700),
              ),
            ),
        ]),
        actions: [
          // Edit/Delete side course — only by creator
          if (_isSide && canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: widget.isAr ? 'تعديل' : 'Edit',
              onPressed: () => _editCourse(context, user),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: widget.isAr ? 'حذف الكورس' : 'Delete course',
              onPressed: () => _deleteCourse(context),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: tabs,
        ),
      ),
      body: TabBarView(controller: _tabs, children: tabViews),
    );
  }

  // ── Edit side course ───────────────────────────────────────────────────────
  void _editCourse(BuildContext ctx, dynamic user) {
    final isAr = widget.isAr;
    final arCtrl = TextEditingController(text: widget.course.titleAr);
    final enCtrl = TextEditingController(text: widget.course.titleEn);
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isAr ? 'تعديل الكورس الجانبي' : 'Edit Side Course',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(controller: arCtrl,
              decoration: const InputDecoration(labelText: 'اسم المادة (عربي)')),
          const SizedBox(height: 10),
          TextField(controller: enCtrl,
              decoration: const InputDecoration(labelText: 'Course Name (English)')),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              if (arCtrl.text.trim().isEmpty || enCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('courses').doc(widget.course.id)
                  .update({'titleAr': arCtrl.text.trim(), 'titleEn': enCtrl.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isAr ? 'حفظ' : 'Save'),
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Delete side course ─────────────────────────────────────────────────────
  Future<void> _deleteCourse(BuildContext ctx) async {
    final isAr = widget.isAr;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'حذف الكورس؟' : 'Delete Course?'),
        content: Text(isAr
            ? 'سيتم حذف الكورس وكل موادة نهائياً'
            : 'This will permanently delete the course and all its materials.'),
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
    if (ok == true && ctx.mounted) {
      // Delete materials first
      final mats = await FirebaseFirestore.instance
          .collection('materials').where('courseId', isEqualTo: widget.course.id).get();
      for (final d in mats.docs) { await d.reference.delete(); }
      await FirebaseFirestore.instance.collection('courses').doc(widget.course.id).delete();
      if (ctx.mounted) Navigator.pop(ctx);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Materials Tab — canManage = creator (doctor for main, any user for side)
// ─────────────────────────────────────────────────────────────────────────────
class _MatTab extends StatelessWidget {
  final CourseModel course;
  final bool isAr;
  final dynamic user;
  final AppLocalizations l10n;
  final bool canManage;
  const _MatTab({required this.course, required this.isAr, required this.user,
      required this.l10n, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Upload button: visible to creator of the course (doctor for main, any creator for side)
      if (canManage)
        Padding(
          padding: const EdgeInsets.all(14),
          child: ElevatedButton.icon(
            onPressed: () => showUploadMaterialDialog(
              ctx: context, course: course, user: user, isAr: isAr),
            icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
            label: Text(l10n.uploadMaterial),
          ),
        ),
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('materials')
              .stream(primaryKey: ['id'])
              .eq('course_id', course.id),
          builder: (_, snap) {
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final mats = snap.data!;
            if (mats.isEmpty) return Center(child: Text(l10n.noCoursesYet));
            
            // Sort by uploaded_at descending
            mats.sort((a, b) {
              final aT = a['uploaded_at'] is int ? a['uploaded_at'] as int : 0;
              final bT = b['uploaded_at'] is int ? b['uploaded_at'] as int : 0;
              return bT.compareTo(aT);
            });

            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: mats.length,
              itemBuilder: (_, i) => _MatCard(
                data: mats[i],
                docId: mats[i]['id']?.toString() ?? '',
                isAr: isAr,
                canManage: canManage,
              ),
            );
          },
        ),
      ),
    ]);
  }

}

// ─────────────────────────────────────────────────────────────────────────────
//  Material card — with download button (for students, both main & side)
// ─────────────────────────────────────────────────────────────────────────────
class _MatCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isAr, canManage;
  const _MatCard({required this.data, required this.docId,
      required this.isAr, required this.canManage});
  @override State<_MatCard> createState() => _MatCardState();
}

class _MatCardState extends State<_MatCard> {
  bool _downloading = false;
  double _progress  = 0;

  String get _id    => (widget.data['id'] ?? widget.docId).toString();
  String get _ext   => (widget.data['file_type'] ?? widget.data['fileType'] ?? 'file') as String;
  String get _title => widget.isAr
      ? (widget.data['title_ar'] ?? widget.data['titleAr'] ?? '') as String
      : (widget.data['title_en'] ?? widget.data['titleEn'] ?? '') as String;
  String get _url   => (widget.data['file_url'] ?? widget.data['fileUrl'] ?? '') as String;

  bool get _isDownloaded => OfflineManager.isDownloaded(_id);

  void _open() {
    // If downloaded locally, open local copy; otherwise open remote URL
    final localPath = OfflineManager.localPath(_id);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FileViewerScreen(
        fileUrl: (localPath != null) ? 'file://$localPath' : _url,
        title: _title,
        fileType: _ext,
      ),
    ));
  }

  Future<void> _download() async {
    // ── Paywall check ─────────────────────────────────────────────────────
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && !PaywallGate.canAccess(user, PremiumFeature.extraOffline)) {
      PaywallGate.showUpgradeSheet(
        context,
        feature: PremiumFeature.extraOffline,
        titleAr: 'وصلت للحد الأقصى من الملفات بدون إنترنت (${user.maxOffline})',
        titleEn: 'You reached your offline file limit (${user.maxOffline})',
      );
      return;
    }
    setState(() { _downloading = true; _progress = 0; });
    try {
      await OfflineManager.download(
        {...widget.data, 'id': _id},
        onProgress: (p) { if (mounted) setState(() => _progress = p); },
      );
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isAr
              ? '✅ تم حفظ "$_title" للاستخدام بدون إنترنت'
              : '✅ "$_title" saved for offline use'),
          backgroundColor: const Color(0xFF06D6A0),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isAr ? '❌ فشل التحميل' : '❌ Download failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _removeOffline() async {
    await OfflineManager.delete(_id);
    if (mounted) setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isAr ? 'تم حذف النسخة المحفوظة' : 'Offline copy removed'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(widget.isAr ? 'حذف الملف' : 'Delete File'),
        content: Text(widget.isAr
            ? 'هل تريد حذف هذا الملف نهائياً؟'
            : 'Are you sure you want to delete this file?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(widget.isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.isAr ? 'حذف' : 'Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await OfflineManager.delete(_id); // also remove local copy if any
      await FirebaseFirestore.instance
          .collection('materials').doc(widget.docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color c; IconData ic;
    switch (_ext.toLowerCase()) {
      case 'pdf':               c = Colors.red;    ic = Icons.picture_as_pdf_rounded;   break;
      case 'doc': case 'docx':  c = Colors.blue;   ic = Icons.description_rounded;      break;
      case 'ppt': case 'pptx':  c = Colors.orange; ic = Icons.slideshow_rounded;        break;
      case 'xls': case 'xlsx':  c = Colors.green;  ic = Icons.table_chart_rounded;      break;
      case 'mp4': case 'mov':
      case 'avi': case 'mkv':   c = Colors.purple; ic = Icons.play_circle_fill_rounded; break;
      case 'jpg': case 'jpeg':
      case 'png': case 'gif':
      case 'webp':              c = Colors.teal;   ic = Icons.image_rounded;            break;
      default:                  c = Colors.grey;   ic = Icons.insert_drive_file_rounded;
    }

    final downloaded = _isDownloaded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1730) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: downloaded
              ? const Color(0xFF06D6A0).withOpacity(0.4)
              : c.withOpacity(0.2),
          width: downloaded ? 2 : 1.5,
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          onTap: _open,
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          leading: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: c.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(ic, color: c, size: 22),
            ),
            // Offline badge
            if (downloaded)
              Positioned(
                bottom: -2, right: -2,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                      color: Color(0xFF06D6A0), shape: BoxShape.circle),
                  child: const Icon(Icons.offline_bolt_rounded,
                      color: Colors.white, size: 10),
                ),
              ),
          ]),
          title: Text(_title,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: c.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(_ext.toUpperCase(),
                  style: TextStyle(fontSize: 10, color: c,
                      fontWeight: FontWeight.w800)),
            ),
            if (downloaded) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFF06D6A0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                  widget.isAr ? '⚡ محفوظ' : '⚡ Saved',
                  style: const TextStyle(fontSize: 10,
                      color: Color(0xFF06D6A0), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ]),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            // Open button
            IconButton(
              icon: Icon(Icons.open_in_new_rounded, color: c, size: 20),
              onPressed: _open,
              tooltip: widget.isAr ? 'فتح' : 'Open',
            ),
            // Download / Remove offline button
            if (_downloading)
              SizedBox(
                width: 32, height: 32,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, value: _progress > 0 ? _progress : null,
                      color: const Color(0xFF06D6A0)),
                ),
              )
            else if (downloaded)
              IconButton(
                icon: const Icon(Icons.offline_bolt_rounded,
                    color: Color(0xFF06D6A0), size: 22),
                onPressed: _removeOffline,
                tooltip: widget.isAr ? 'حذف النسخة المحفوظة' : 'Remove offline copy',
              )
            else
              IconButton(
                icon: const Icon(Icons.download_rounded,
                    color: Color(0xFF06D6A0), size: 22),
                onPressed: _download,
                tooltip: widget.isAr ? 'تحميل للاستخدام بدون إنترنت' : 'Download for offline',
              ),
            // Delete from course (manager only)
            if (widget.canManage)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 20),
                onPressed: () => _confirmDelete(context),
                tooltip: widget.isAr ? 'حذف الملف' : 'Delete file',
              ),
          ]),
        ),
        // Download progress bar
        if (_downloading && _progress > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF06D6A0)),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isAr
                    ? 'جاري التحميل... ${(_progress * 100).toInt()}٪'
                    : 'Downloading... ${(_progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 11,
                    color: Color(0xFF06D6A0), fontWeight: FontWeight.w600),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Announcements Tab — doctor can post unlimited announcements with full details
// ─────────────────────────────────────────────────────────────────────────────
class _AnnTab extends StatelessWidget {
  final CourseModel course;
  final bool isAr;
  final dynamic user;
  final AppLocalizations l10n;
  const _AnnTab({required this.course, required this.isAr,
      required this.user, required this.l10n});

  bool get _canPost => user.isDoctor && user.uid == course.doctorId;

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(children: [
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .where('courseId', isEqualTo: course.id)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.data!.docs.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📢', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(isAr ? 'لا توجد إعلانات بعد' : 'No announcements yet',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15)),
              if (_canPost) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showDialog(context),
                  icon: const Icon(Icons.campaign_rounded, color: Colors.white),
                  label: Text(isAr ? 'إضافة أول إعلان' : 'Post First Announcement',
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            ]));
          }
          final anns = snap.data!.docs
              .map((d) => AnnouncementModel.fromMap(d.data() as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(14, 14, 14, _canPost ? 130 : 14),
            itemCount: anns.length,
            itemBuilder: (_, i) => _AnnCard(
                ann: anns[i], isAr: isAr,
                canDelete: _canPost,
                isStudent: user.isStudent,
                courseId: course.id,
                onDelete: () => _deleteAnn(context, anns[i].id)),
          );
        },
      ),

      // FABs for doctor
      if (_canPost)
        Positioned(
          bottom: 16, right: 16,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Quiz FAB
            FloatingActionButton.extended(
              heroTag: 'quiz_fab',
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => DoctorCourseQuizScreen(course: course))),
              backgroundColor: const Color(0xFFFF9F1C),
              icon: const Icon(Icons.quiz_rounded, color: Colors.white),
              label: Text(isAr ? 'كويز جديد' : 'New Quiz',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            // Announcement FAB
            FloatingActionButton.extended(
              heroTag: 'ann_fab',
              onPressed: () => _showDialog(context),
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.campaign_rounded, color: Colors.white),
              label: Text(isAr ? 'إعلان جديد' : 'New Announcement',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
    ]);
  }

  Future<void> _deleteAnn(BuildContext ctx, String annId) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isAr ? 'حذف الإعلان؟' : 'Delete Announcement?'),
        content: Text(isAr ? 'لن تتمكن من استرجاعه' : 'This cannot be undone.'),
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
    await FirebaseFirestore.instance
        .collection('announcements').doc(annId).delete();
  }

  void _showDialog(BuildContext ctx) {
    final tArC = TextEditingController();
    final tEnC = TextEditingController();
    final bArC = TextEditingController();
    final bEnC = TextEditingController();
    bool isExam   = false;
    bool loading  = false;
    final fKey = GlobalKey<FormState>();
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (c2, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c2).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1730) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: SingleChildScrollView(child: Form(key: fKey, child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),

                // Title row
                Row(children: [
                  Container(width: 4, height: 24,
                      decoration: BoxDecoration(color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 10),
                  Text(isAr ? '📢 إعلان جديد' : '📢 New Announcement',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor)),
                ]),
                const SizedBox(height: 18),

                // Exam toggle chip
                GestureDetector(
                  onTap: () => setS(() => isExam = !isExam),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isExam
                          ? Colors.red.withOpacity(0.12)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isExam ? Colors.red : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(children: [
                      Icon(isExam ? Icons.quiz_rounded : Icons.campaign_rounded,
                          color: isExam ? Colors.red : Colors.grey, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? (isExam ? '🔴 إعلان امتحان' : 'نوع الإعلان')
                                 : (isExam ? '🔴 Exam Announcement' : 'Announcement Type'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13,
                              color: isExam ? Colors.red : null,
                            ),
                          ),
                          Text(
                            isAr ? 'اضغط للتغيير' : 'Tap to toggle',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      )),
                      Icon(isExam ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isExam ? Colors.red : Colors.grey, size: 20),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Arabic title
                TextFormField(
                  controller: tArC,
                  decoration: const InputDecoration(
                    labelText: 'العنوان بالعربي *',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'مطلوب' : null,
                ),
                const SizedBox(height: 10),

                // English title
                TextFormField(
                  controller: tEnC,
                  decoration: const InputDecoration(
                    labelText: 'Title in English *',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required' : null,
                ),
                const SizedBox(height: 10),

                // Arabic body
                TextFormField(
                  controller: bArC, maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'التفاصيل بالعربي',
                    prefixIcon: Icon(Icons.notes_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),

                // English body
                TextFormField(
                  controller: bEnC, maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Details in English',
                    prefixIcon: Icon(Icons.notes_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExam ? Colors.red : AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: loading ? null : () async {
                      if (!fKey.currentState!.validate()) return;
                      setS(() => loading = true);
                      final ann = AnnouncementModel(
                        id: const Uuid().v4(),
                        courseId: course.id,
                        titleAr: tArC.text.trim(),
                        titleEn: tEnC.text.trim(),
                        bodyAr:  bArC.text.trim(),
                        bodyEn:  bEnC.text.trim(),
                        isExam:  isExam,
                        createdAt: DateTime.now(),
                      );
                      await FirebaseFirestore.instance
                          .collection('announcements')
                          .doc(ann.id).set(ann.toMap());

                      // ── Notify students ──────────────────────────────────
                      try {
                        final snap = await FirebaseFirestore.instance
                            .collection('users')
                            .where('universityAr', isEqualTo: course.universityAr)
                            .where('facultyAr',    isEqualTo: course.facultyAr)
                            .where('year',         isEqualTo: course.year)
                            .where('role',         isEqualTo: 'student')
                            .get();
                        final uids = snap.docs
                            .map((d) => d.id)
                            .where((id) => id != user.uid)
                            .toList();
                        if (uids.isNotEmpty) {
                          await NotificationHelper.sendToMany(
                            uids:    uids,
                            type:    isExam ? 'exam' : 'announcement',
                            titleAr: isExam
                                ? '🔴 امتحان — ${ann.titleAr}'
                                : '📢 إعلان جديد — ${ann.titleAr}',
                            titleEn: isExam
                                ? '🔴 Exam — ${ann.titleEn}'
                                : '📢 New Announcement — ${ann.titleEn}',
                            bodyAr:  bArC.text.trim().isNotEmpty
                                ? bArC.text.trim()
                                : (isExam ? 'تحقق من تفاصيل الامتحان' : 'تحقق من الإعلان الجديد'),
                            bodyEn:  bEnC.text.trim().isNotEmpty
                                ? bEnC.text.trim()
                                : (isExam ? 'Check exam details' : 'Check the new announcement'),
                            extra: {'courseId': course.id},
                          );
                        }
                      } catch (_) {}

                      if (c2.mounted) Navigator.pop(c2);
                    },
                    icon: loading
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Icon(isExam
                            ? Icons.quiz_rounded : Icons.send_rounded,
                            color: Colors.white),
                    label: Text(
                      isAr ? 'نشر الإعلان' : 'Post Announcement',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ))),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Announcement Card — expandable body, delete button for doctor
// ─────────────────────────────────────────────────────────────────────────────
class _AnnCard extends StatefulWidget {
  final AnnouncementModel ann;
  final bool isAr, canDelete, isStudent;
  final String courseId;
  final VoidCallback onDelete;
  const _AnnCard({required this.ann, required this.isAr,
      required this.canDelete, required this.isStudent,
      required this.courseId, required this.onDelete});
  @override State<_AnnCard> createState() => _AnnCardState();
}

class _AnnCardState extends State<_AnnCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ann    = widget.ann;
    final isAr   = widget.isAr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final body   = isAr ? ann.bodyAr : ann.bodyEn;
    final hasBody = body.isNotEmpty;

    final accentColor = ann.isExam ? Colors.red : AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1730) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(
            color: accentColor.withOpacity(0.07),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                ann.isExam ? Icons.quiz_rounded : Icons.campaign_rounded,
                color: accentColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (ann.isExam)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(isAr ? '🔴 امتحان' : '🔴 Exam',
                        style: const TextStyle(color: Colors.red,
                            fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
              ]),
              Text(isAr ? ann.titleAr : ann.titleEn,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                _formatDate(ann.createdAt, isAr),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ])),

            // Actions
            Column(children: [
              if (widget.canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red, size: 20),
                  onPressed: widget.onDelete,
                  tooltip: isAr ? 'حذف الإعلان' : 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                ),
              if (hasBody)
                IconButton(
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey, size: 22),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                ),
            ]),
          ]),
        ),

        // Body (expandable)
        if (hasBody && _expanded) ...[
          Divider(height: 1,
              color: accentColor.withOpacity(0.15),
              indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Text(body,
                style: TextStyle(
                    fontSize: 14, height: 1.6,
                    color: isDark ? Colors.white70 : Colors.grey[700])),
          ),
        ],

        // "Tap to read more" hint
        if (hasBody && !_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: GestureDetector(
              onTap: () => setState(() => _expanded = true),
              child: Text(
                isAr ? 'اضغط لقراءة التفاصيل ▾' : 'Tap to read more ▾',
                style: TextStyle(
                    fontSize: 12, color: accentColor,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        // Quiz Start Button — for students on quiz-type announcements
        if (widget.isStudent && (ann.isQuiz || ann.isExam) && ann.questions.isNotEmpty) ...[
          Divider(height: 1, color: accentColor.withOpacity(0.15), indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => StudentQuizScreen(
                  announcementId: ann.id,
                  titleAr: ann.titleAr,
                  titleEn: ann.titleEn,
                  questions: ann.questions,
                  courseId: widget.courseId,
                ),
              )),
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: Text(
                isAr ? 'ابدأ الكويز ☝' : 'Start Quiz ☝',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ann.isExam ? Colors.red : AppTheme.primaryColor,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  String _formatDate(DateTime dt, bool isAr) {
    final months = isAr
        ? ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
           'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر']
        : ['Jan','Feb','Mar','Apr','May','Jun',
           'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Tab
// ─────────────────────────────────────────────────────────────────────────────
class _ChatTab extends StatefulWidget {
  final CourseModel course;
  final bool isAr;
  final dynamic user;
  final AppLocalizations l10n;
  const _ChatTab({required this.course, required this.isAr,
      required this.user, required this.l10n});
  @override State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _ctrl = TextEditingController();
  String _type = 'question';
  MessageModel? _replyTo;
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final user = widget.user;
    final msg = MessageModel(
      id: const Uuid().v4(), courseId: widget.course.id, senderId: user.uid,
      senderName: user.fullName ?? user.email,
      senderRole: user.role, text: text,
      messageType: user.isDoctor ? 'normal' : _type,
      replyToId: _replyTo?.id, replyToText: _replyTo?.text,
      replyToSenderName: _replyTo?.senderName, createdAt: DateTime.now(),
    );
    await FirebaseFirestore.instance
        .collection('chats').doc(widget.course.id)
        .collection('messages').doc(msg.id).set(msg.toMap());
    _ctrl.clear();
    setState(() => _replyTo = null);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final isDoc = widget.user.isDoctor;
    final theme = Theme.of(context);
    return Column(children: [
      if (!isDoc)
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            _Chip('Q', isAr ? 'سؤال' : 'Q', 'question', _type, (t) => setState(() => _type = t)),
            _Chip('A', isAr ? 'إجابة' : 'A', 'answer',   _type, (t) => setState(() => _type = t)),
            _Chip('N', isAr ? 'ملاحظة' : 'N', 'note',    _type, (t) => setState(() => _type = t)),
          ]),
        ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats').doc(widget.course.id)
              .collection('messages').orderBy('createdAt').snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final msgs = snap.data!.docs
                .map((d) => MessageModel.fromMap(d.data() as Map<String, dynamic>))
                .toList();
            if (msgs.isEmpty) {
              return Center(child: Text(
                isAr ? 'لا توجد رسائل' : 'No messages yet',
                style: TextStyle(color: Colors.grey[600])));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12), itemCount: msgs.length,
              itemBuilder: (_, i) => _Bubble(
                msg: msgs[i], isMe: msgs[i].senderId == widget.user.uid,
                isAr: isAr, isDoc: isDoc,
                onReply: (m) => setState(() => _replyTo = m),
              ),
            );
          },
        ),
      ),
      if (_replyTo != null)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: const Border(left: BorderSide(color: AppTheme.primaryColor, width: 3)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_replyTo!.senderName,
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor, fontSize: 12)),
              Text(_replyTo!.text,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            ])),
            IconButton(icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _replyTo = null)),
          ]),
        ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 10,
              offset: const Offset(0, -3))],
        ),
        child: Row(children: [
          Expanded(child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(hintText: widget.l10n.typeMessage),
              maxLines: null)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String key2, label, type, selected;
  final ValueChanged<String> onTap;
  const _Chip(this.key2, this.label, this.type, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) {
    final sel = type == selected;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: sel ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12)),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(
                color: sel ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold)),
      ),
    ));
  }
}

class _Bubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe, isAr, isDoc;
  final ValueChanged<MessageModel> onReply;
  const _Bubble({required this.msg, required this.isMe, required this.isAr,
      required this.isDoc, required this.onReply});

  Color get _typeColor {
    switch (msg.messageType) {
      case 'question': return Colors.blue;
      case 'answer':   return Colors.green;
      case 'note':     return Colors.orange;
      default:         return AppTheme.primaryColor;
    }
  }

  String _typeLabel(bool ar) {
    switch (msg.messageType) {
      case 'question': return ar ? 'سؤال' : 'Q';
      case 'answer':   return ar ? 'إجابة' : 'A';
      case 'note':     return ar ? 'ملاحظة' : 'N';
      default:         return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPress: () => showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.reply_rounded, color: AppTheme.primaryColor),
            title: Text(isAr ? 'رد' : 'Reply'),
            onTap: () { Navigator.pop(context); onReply(msg); },
          ),
          const SizedBox(height: 16),
        ]),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!isMe) ...[
                  Text(msg.senderName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor)),
                  if (msg.senderRole == 'doctor') ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        color: AppTheme.verifiedColor, size: 14),
                  ],
                  const SizedBox(width: 6),
                ],
                if (msg.messageType != 'normal')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_typeLabel(isAr),
                        style: TextStyle(color: _typeColor,
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
            const SizedBox(height: 2),
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryColor : theme.cardTheme.color,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (msg.replyToText != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                          left: BorderSide(color: Colors.white54, width: 2)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(msg.replyToSenderName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 11, color: Colors.white70)),
                      Text(msg.replyToText!,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12,
                              color: isMe ? Colors.white70 : Colors.grey[700])),
                    ]),
                  ),
                Text(msg.text, style: TextStyle(color: isMe ? Colors.white : null)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}