import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studyhub/generated/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import '../../utils/xp_service.dart';
import '../../models/course_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
// ignore: unused_import
import '../../widgets/course_card.dart';
import 'course_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CoursesScreen
//  Doctors  : Main courses (theirs) + Side courses (theirs) — Tab view
//  Students : Main courses (uni/faculty/year) + Side courses (theirs only)
// ─────────────────────────────────────────────────────────────────────────────
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});
  @override State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context)!;
    final auth   = context.watch<AuthProvider>();
    final isAr   = context.watch<AppProvider>().isArabic;
    final user   = auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.courses, style: const TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(icon: const Icon(Icons.menu_book_rounded, size: 18),
                text: isAr ? 'المواد الرئيسية' : 'Main Courses'),
            Tab(icon: const Icon(Icons.extension_rounded, size: 18),
                text: isAr ? 'المواد الجانبية' : 'Side Courses'),
          ],
        ),
      ),
      // FAB — context-aware per tab
      floatingActionButton: _buildFab(context, user, isAr, l10n),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _q = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: isAr ? 'ابحث عن مادة...' : 'Search courses...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () { _searchCtrl.clear(); setState(() => _q = ''); })
                  : null,
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _CourseList(user: user, isAr: isAr, l10n: l10n, q: _q, isMain: true),
              _CourseList(user: user, isAr: isAr, l10n: l10n, q: _q, isMain: false),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildFab(BuildContext ctx, dynamic user, bool isAr, AppLocalizations l10n) {
    final onMain = _tabs.index == 0;
    // Doctors can add main courses on tab 0, side courses on tab 1
    // Students can only add side courses (tab 1)
    if (user.isDoctor && onMain) {
      return FloatingActionButton.extended(
        heroTag: 'fab_main',
        onPressed: () => _showAddMainDialog(ctx, isAr, user),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(isAr ? 'إضافة مادة رئيسية' : 'Add Main Course',
            style: const TextStyle(color: Colors.white)),
      );
    }
    // Tab 1 (side) — both doctors and students
    if (!onMain || !user.isDoctor) {
      return FloatingActionButton.extended(
        heroTag: 'fab_side',
        onPressed: () => _showAddSideDialog(ctx, isAr, user),
        backgroundColor: AppTheme.accentColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(isAr ? 'إضافة مادة جانبية' : 'Add Side Course',
            style: const TextStyle(color: Colors.white)),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Course list
// ─────────────────────────────────────────────────────────────────────────────
class _CourseList extends StatelessWidget {
  final dynamic user;
  final bool isAr, isMain;
  final AppLocalizations l10n;
  final String q;
  const _CourseList({required this.user, required this.isAr, required this.isMain,
      required this.l10n, required this.q});

  Query<Map<String, dynamic>> get _query {
    final db = FirebaseFirestore.instance.collection('courses');
    if (isMain) {
      // Main courses
      if (user.isDoctor) {
        return db.where('doctorId', isEqualTo: user.uid).where('type', isEqualTo: 'main');
      } else {
        // Student: main courses for their uni/faculty/year
        return db
            .where('universityAr', isEqualTo: user.universityAr)
            .where('facultyAr',    isEqualTo: user.facultyAr)
            .where('year',         isEqualTo: user.year)
            .where('type',         isEqualTo: 'main');
      }
    } else {
      // Side courses — ALL side courses from every user (global discovery)
      // Anyone can view; only the creator (doctorId == uid) can manage
      return db.where('type', isEqualTo: 'side').limit(50);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<QuerySnapshot>(
      stream: _query.snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _EmptyState(isAr: isAr, isMain: isMain);
        }
        var courses = snap.data!.docs
            .map((d) => CourseModel.fromMap(d.data() as Map<String, dynamic>))
            .toList();
        if (q.isNotEmpty) {
          courses = courses.where((c) =>
              c.titleAr.toLowerCase().contains(q) ||
              c.titleEn.toLowerCase().contains(q)).toList();
        }
        if (courses.isEmpty) {
          return Center(child: Text(
            isAr ? 'لا نتائج للبحث' : 'No results',
            style: TextStyle(color: Colors.grey[500])));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: courses.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CourseCard(
                course: courses[i], isAr: isAr, isDark: isDark,
                isOwner: user.uid == courses[i].doctorId),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Unified course card
//  • isOwner + isMain → shows Edit / Delete action buttons at the bottom
//  • isOwner + isSide → edit/delete handled inside CourseDetailScreen AppBar
// ─────────────────────────────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final bool isAr, isDark, isOwner;
  const _CourseCard({required this.course, required this.isAr,
      required this.isDark, required this.isOwner});

  bool get _isMain => course.type == 'main';
  Color get _color => _isMain ? AppTheme.primaryColor : const Color(0xFF06D6A0);

  void _open(BuildContext ctx) => Navigator.push(ctx,
      MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course, isAr: isAr)));

  Future<void> _delete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'حذف المادة؟' : 'Delete Course?'),
        content: Text(isAr
            ? 'سيتم حذف "${course.titleAr}" وكل محتوياتها نهائياً'
            : 'This will permanently delete "${course.titleEn}" and all its content.'),
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
    if (ok != true || !ctx.mounted) return;
    final db = FirebaseFirestore.instance;
    // Delete materials
    final mats = await db.collection('materials')
        .where('courseId', isEqualTo: course.id).get();
    for (final d in mats.docs) {
      await d.reference.delete();
    }
    // Delete announcements
    final anns = await db.collection('announcements')
        .where('courseId', isEqualTo: course.id).get();
    for (final d in anns.docs) {
      await d.reference.delete();
    }
    // Delete course
    await db.collection('courses').doc(course.id).delete();
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(isAr ? '✅ تم حذف المادة' : '✅ Course deleted'),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show action row only when: owner of a main course
    final showActions = isOwner && _isMain;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1730) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _color.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(
            color: _color.withOpacity(0.07),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Main info row ──────────────────────────────────────────────
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          onTap: () => _open(context),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, showActions ? 10 : 14),
            child: Row(children: [
              // Icon
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isMain
                        ? [AppTheme.primaryColor, const Color(0xFF7209B7)]
                        : [const Color(0xFF06D6A0), const Color(0xFF0094C6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                    _isMain ? Icons.menu_book_rounded : Icons.extension_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isAr ? course.titleAr : course.titleEn,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(isAr ? course.facultyAr : course.facultyEn,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (_isMain) ...[
                    const SizedBox(height: 2),
                    Text(isAr ? course.universityAr : course.universityEn,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 5),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: _color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        _isMain ? (isAr ? 'رئيسية' : 'Main')
                                : (isAr ? 'جانبية' : 'Side'),
                        style: TextStyle(
                            color: _color, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (_isMain && course.year > 0) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.stairs_rounded, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text(isAr ? 'السنة ${course.year}' : 'Year ${course.year}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                    if (isOwner) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(isAr ? 'منشئ' : 'Owner',
                            style: const TextStyle(
                                color: Colors.amber, fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                ],
              )),
              Icon(Icons.chevron_right_rounded, color: _color, size: 22),
            ]),
          ),
        ),

        // ── Action buttons — doctor/owner of main course only ──────────
        if (showActions) ...[
          Divider(height: 1,
              color: isDark ? Colors.white.withOpacity(0.07) : Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(children: [
              // Open
              Expanded(child: TextButton.icon(
                icon: Icon(Icons.open_in_new_rounded, size: 15, color: _color),
                label: Text(isAr ? 'فتح' : 'Open',
                    style: TextStyle(color: _color, fontSize: 12,
                        fontWeight: FontWeight.w700)),
                onPressed: () => _open(context),
              )),
              Container(width: 1, height: 24,
                  color: isDark ? Colors.white12 : Colors.grey.shade200),
              // Edit
              Expanded(child: TextButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 15, color: Colors.blue),
                label: Text(isAr ? 'تعديل' : 'Edit',
                    style: const TextStyle(color: Colors.blue, fontSize: 12,
                        fontWeight: FontWeight.w700)),
                onPressed: () => _showEditMainDialog(context, isAr, course),
              )),
              Container(width: 1, height: 24,
                  color: isDark ? Colors.white12 : Colors.grey.shade200),
              // Delete
              Expanded(child: TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 15, color: Colors.red),
                label: Text(isAr ? 'حذف' : 'Delete',
                    style: const TextStyle(color: Colors.red, fontSize: 12,
                        fontWeight: FontWeight.w700)),
                onPressed: () => _delete(context),
              )),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isAr, isMain;
  const _EmptyState({required this.isAr, required this.isMain});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(40), child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(isMain ? '📚' : '🧩', style: const TextStyle(fontSize: 60)),
        const SizedBox(height: 16),
        Text(
          isMain
              ? (isAr ? 'لا توجد مواد رئيسية بعد' : 'No main courses yet')
              : (isAr ? 'لا توجد مواد جانبية بعد' : 'No side courses yet'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isMain
              ? (isAr ? 'ستظهر هنا المواد الرئيسية لجامعتك' : 'Main courses for your faculty will appear here')
              : (isAr ? 'اضغط + لإضافة مادة جانبية' : 'Tap + to add a side course'),
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    )),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Add MAIN course (doctor only)
// ─────────────────────────────────────────────────────────────────────────────
void _showAddMainDialog(BuildContext ctx, bool isAr, dynamic user) {
  final arCtrl = TextEditingController();
  final enCtrl = TextEditingController();
  final fKey   = GlobalKey<FormState>();
  bool loading = false;

  final firstTeaching = (user.teachingAt is List && (user.teachingAt as List).isNotEmpty)
      ? Map<String, dynamic>.from((user.teachingAt as List).first as Map)
      : <String, dynamic>{};
  final defaultUniAr = (firstTeaching['universityAr'] ?? user.universityAr ?? '').toString();
  final defaultFacAr = (firstTeaching['facultyAr'] ?? user.facultyAr ?? '').toString();

  Map<String, dynamic>? selUni = AppConstants.egyptianUniversities.firstWhere(
    (u) => u['nameAr'] == defaultUniAr,
    orElse: () => AppConstants.egyptianUniversities.first,
  );
  Map<String, dynamic>? selFac;
  int selYear = 1;

  showModalBottomSheet(
    context: ctx, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(
      builder: (ctx2, setS) {
        final facs = selUni != null
            ? List<Map<String, dynamic>>.from(selUni!['faculties'])
            : <Map<String, dynamic>>[];
        if (selFac == null && facs.isNotEmpty) {
          selFac = facs.firstWhere(
            (f) => f['nameAr'] == defaultFacAr,
            orElse: () => facs.first,
          );
        }
        final maxY = selFac != null ? (selFac!['years'] as int? ?? 4) : 4;
        final isDark = Theme.of(ctx2).brightness == Brightness.dark;
        return _SheetWrapper(
          title: isAr ? '➕ إضافة مادة رئيسية' : '➕ Add Main Course',
          color: AppTheme.primaryColor,
          isDark: isDark,
          child: Form(key: fKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
            _SheetField(ctrl: arCtrl,
                label: isAr ? 'اسم المادة بالعربي' : 'Arabic Name',
                icon: Icons.translate_rounded),
            const SizedBox(height: 12),
            _SheetField(ctrl: enCtrl,
                label: isAr ? 'اسم المادة بالإنجليزي' : 'English Name',
                icon: Icons.abc_rounded),
            const SizedBox(height: 12),
            _SheetDrop<Map<String, dynamic>>(
              label: isAr ? 'الجامعة' : 'University',
              icon: Icons.account_balance_outlined,
              value: selUni,
              items: AppConstants.egyptianUniversities,
              getLabel: (u) => isAr ? u['nameAr'] : u['nameEn'],
              onChanged: (u) => setS(() { selUni = u; selFac = null; selYear = 1; }),
            ),
            const SizedBox(height: 12),
            _SheetDrop<Map<String, dynamic>>(
              label: isAr ? 'الكلية' : 'Faculty',
              icon: Icons.school_outlined,
              value: selFac,
              items: facs,
              getLabel: (f) => isAr ? f['nameAr'] : f['nameEn'],
              onChanged: (f) => setS(() { selFac = f; selYear = 1; }),
              enabled: selUni != null,
            ),
            const SizedBox(height: 12),
            _SheetDrop<int>(
              label: isAr ? 'السنة الدراسية' : 'Academic Year',
              icon: Icons.stairs_rounded,
              value: selYear,
              items: List.generate(maxY, (i) => i + 1),
              getLabel: (y) => isAr ? 'السنة $y' : 'Year $y',
              onChanged: (y) => setS(() => selYear = y!),
            ),
            const SizedBox(height: 20),
            _SheetButton(
              label: isAr ? 'إضافة المادة' : 'Add Course',
              color: AppTheme.primaryColor,
              loading: loading,
              onTap: () async {
                if (!fKey.currentState!.validate()) return;
                if (selUni == null || selFac == null) {
                  ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(
                    content: Text(isAr ? 'اختر الجامعة والكلية' : 'Select university & faculty'),
                    backgroundColor: Colors.orange,
                  ));
                  return;
                }
                setS(() => loading = true);
                final course = CourseModel(
                  id: const Uuid().v4(),
                  titleAr: arCtrl.text.trim(), titleEn: enCtrl.text.trim(),
                  doctorId: user.uid, doctorName: user.fullName ?? user.email,
                  universityAr: selUni!['nameAr'], universityEn: selUni!['nameEn'],
                  facultyAr: selFac!['nameAr'],    facultyEn: selFac!['nameEn'],
                  year: selYear, type: 'main', createdAt: DateTime.now(),
                );
                await FirebaseFirestore.instance
                    .collection('courses').doc(course.id).set(course.toMap());
                if (ctx2.mounted) {
                  Navigator.pop(ctx2);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(isAr ? '✅ تمت إضافة المادة الرئيسية' : '✅ Main course added'),
                    backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
                  ));
                }
              },
            ),
          ])),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Add SIDE course (doctor OR student)
// ─────────────────────────────────────────────────────────────────────────────
void _showAddSideDialog(BuildContext ctx, bool isAr, dynamic user) {
  final arCtrl = TextEditingController();
  final enCtrl = TextEditingController();
  final fKey   = GlobalKey<FormState>();
  bool loading = false;

  showModalBottomSheet(
    context: ctx, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(
      builder: (ctx2, setS) {
        final isDark = Theme.of(ctx2).brightness == Brightness.dark;
        return _SheetWrapper(
          title: isAr ? '🧩 إضافة مادة جانبية' : '🧩 Add Side Course',
          color: AppTheme.accentColor,
          isDark: isDark,
          child: Form(key: fKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Info chip
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 15,
                    color: AppTheme.accentColor),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  isAr
                      ? 'المادة الجانبية خاصة بيك — تقدر تضيف مواد ورفع ملفات'
                      : 'Side course is personal — you can add materials & files',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                )),
              ]),
            ),
            const SizedBox(height: 14),
            _SheetField(ctrl: arCtrl,
                label: isAr ? 'اسم المادة بالعربي' : 'Arabic Name',
                icon: Icons.translate_rounded),
            const SizedBox(height: 12),
            _SheetField(ctrl: enCtrl,
                label: isAr ? 'اسم المادة بالإنجليزي' : 'English Name',
                icon: Icons.abc_rounded),
            const SizedBox(height: 20),
            _SheetButton(
              label: isAr ? 'إضافة المادة' : 'Add Course',
              color: AppTheme.accentColor,
              loading: loading,
              onTap: () async {
                if (!fKey.currentState!.validate()) return;
                setS(() => loading = true);
                // For side courses: doctorId = creator uid (works for both roles)
                final course = CourseModel(
                  id: const Uuid().v4(),
                  titleAr: arCtrl.text.trim(), titleEn: enCtrl.text.trim(),
                  doctorId: user.uid,  // creator = owner regardless of role
                  doctorName: user.fullName ?? user.email,
                  universityAr: user.universityAr, universityEn: user.universityEn,
                  facultyAr: user.facultyAr,       facultyEn: user.facultyEn,
                  year: 0, type: 'side', createdAt: DateTime.now(),
                );
                await FirebaseFirestore.instance
                    .collection('courses').doc(course.id).set(course.toMap());
                await XpService.award(user.uid, XpEvent.createSideCourse);
                if (ctx2.mounted) {
                  Navigator.pop(ctx2);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(isAr ? '✅ تمت إضافة المادة الجانبية (+20 XP)' : '✅ Side course added (+20 XP)'),
                    backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
                  ));
                }
              },
            ),
          ])),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Edit MAIN course dialog (doctor/owner only)
// ─────────────────────────────────────────────────────────────────────────────
void _showEditMainDialog(BuildContext ctx, bool isAr, CourseModel course) {
  final arCtrl = TextEditingController(text: course.titleAr);
  final enCtrl = TextEditingController(text: course.titleEn);
  final fKey   = GlobalKey<FormState>();
  bool loading = false;

  Map<String, dynamic>? selUni = AppConstants.egyptianUniversities.firstWhere(
    (u) => u['nameAr'] == course.universityAr,
    orElse: () => AppConstants.egyptianUniversities.first,
  );
  // ignore: unnecessary_null_comparison
  final allFacs = selUni != null
      ? List<Map<String, dynamic>>.from(selUni['faculties'])
      : <Map<String, dynamic>>[];
  Map<String, dynamic>? selFac = allFacs.isNotEmpty
      ? allFacs.firstWhere((f) => f['nameAr'] == course.facultyAr,
          orElse: () => allFacs.first)
      : null;
  int selYear = course.year.clamp(1, 6);

  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(
      builder: (ctx2, setS) {
        final facs = selUni != null
            ? List<Map<String, dynamic>>.from(selUni!['faculties'])
            : <Map<String, dynamic>>[];
        final maxY = selFac != null ? (selFac!['years'] as int? ?? 6) : 6;
        final isDark = Theme.of(ctx2).brightness == Brightness.dark;

        return _SheetWrapper(
          title: isAr ? '✏️ تعديل المادة الرئيسية' : '✏️ Edit Main Course',
          color: Colors.blue,
          isDark: isDark,
          child: Form(key: fKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
            _SheetField(ctrl: arCtrl,
                label: isAr ? 'اسم المادة بالعربي' : 'Arabic Name',
                icon: Icons.translate_rounded),
            const SizedBox(height: 12),
            _SheetField(ctrl: enCtrl,
                label: isAr ? 'اسم المادة بالإنجليزي' : 'English Name',
                icon: Icons.abc_rounded),
            const SizedBox(height: 12),
            _SheetDrop<Map<String, dynamic>>(
              label: isAr ? 'الجامعة' : 'University',
              icon: Icons.account_balance_outlined,
              value: selUni,
              items: AppConstants.egyptianUniversities,
              getLabel: (u) => isAr ? u['nameAr'] : u['nameEn'],
              onChanged: (u) => setS(() { selUni = u; selFac = null; selYear = 1; }),
            ),
            const SizedBox(height: 12),
            _SheetDrop<Map<String, dynamic>>(
              label: isAr ? 'الكلية' : 'Faculty',
              icon: Icons.school_outlined,
              value: selFac,
              items: facs,
              getLabel: (f) => isAr ? f['nameAr'] : f['nameEn'],
              onChanged: (f) => setS(() { selFac = f; selYear = 1; }),
              enabled: selUni != null,
            ),
            const SizedBox(height: 12),
            _SheetDrop<int>(
              label: isAr ? 'السنة الدراسية' : 'Academic Year',
              icon: Icons.stairs_rounded,
              value: selYear.clamp(1, maxY),
              items: List.generate(maxY, (i) => i + 1),
              getLabel: (y) => isAr ? 'السنة $y' : 'Year $y',
              onChanged: (y) => setS(() => selYear = y!),
            ),
            const SizedBox(height: 20),
            _SheetButton(
              label: isAr ? 'حفظ التعديلات' : 'Save Changes',
              color: Colors.blue,
              loading: loading,
              onTap: () async {
                if (!fKey.currentState!.validate()) return;
                setS(() => loading = true);
                final updates = <String, dynamic>{
                  'titleAr':     arCtrl.text.trim(),
                  'titleEn':     enCtrl.text.trim(),
                  if (selUni != null) 'universityAr': selUni!['nameAr'],
                  if (selUni != null) 'universityEn': selUni!['nameEn'],
                  if (selFac != null) 'facultyAr':    selFac!['nameAr'],
                  if (selFac != null) 'facultyEn':    selFac!['nameEn'],
                  'year': selYear,
                };
                await FirebaseFirestore.instance
                    .collection('courses').doc(course.id).update(updates);
                if (ctx2.mounted) {
                  Navigator.pop(ctx2);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(isAr ? '✅ تم تعديل المادة' : '✅ Course updated'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
            ),
          ])),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared bottom sheet widgets
// ─────────────────────────────────────────────────────────────────────────────
class _SheetWrapper extends StatelessWidget {
  final String title; final Color color; final bool isDark; final Widget child;
  const _SheetWrapper({required this.title, required this.color,
      required this.isDark, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1730) : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    ),
    padding: EdgeInsets.only(
      left: 20, right: 20, top: 20,
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Container(width: 4, height: 24,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 20),
        child,
      ],
    )),
  );
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl; final String label; final IconData icon;
  const _SheetField({required this.ctrl, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب / Required' : null,
  );
}

class _SheetDrop<T> extends StatelessWidget {
  final String label; final IconData icon; final T? value;
  final List<T> items; final String Function(T) getLabel;
  final ValueChanged<T?> onChanged; final bool enabled;
  const _SheetDrop({required this.label, required this.icon, required this.value,
      required this.items, required this.getLabel, required this.onChanged,
      this.enabled = true});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value, isExpanded: true,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon),
        enabled: enabled),
    items: items.map((e) => DropdownMenuItem<T>(
        value: e, child: Text(getLabel(e), overflow: TextOverflow.ellipsis))).toList(),
    onChanged: enabled ? onChanged : null,
  );
}

class _SheetButton extends StatelessWidget {
  final String label; final Color color; final bool loading; final VoidCallback onTap;
  const _SheetButton({required this.label, required this.color,
      required this.loading, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: loading ? null : onTap,
      child: loading
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
    ),
  );
}