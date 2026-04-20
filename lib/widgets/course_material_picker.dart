import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';

/// A widget that lets users pick a course then one of its PDF materials.
/// Calls [onPdfSelected] with the raw bytes, course title, and material title.
///
/// [actionLabel] / [actionLabelAr] set the button text.
/// [actionIcon] sets the button icon.
class CourseMaterialPicker extends StatefulWidget {
  final void Function(Uint8List bytes, String courseTitle, String matTitle) onPdfSelected;
  final String? selectedCourseName;
  final String? selectedMatName;
  final String? actionLabel;
  final String? actionLabelAr;
  final IconData? actionIcon;

  const CourseMaterialPicker({
    super.key,
    required this.onPdfSelected,
    this.selectedCourseName,
    this.selectedMatName,
    this.actionLabel,
    this.actionLabelAr,
    this.actionIcon,
  });

  @override
  State<CourseMaterialPicker> createState() => _CourseMaterialPickerState();
}

class _CourseMaterialPickerState extends State<CourseMaterialPicker> {
  Map<String, dynamic>? _selectedCourse;
  Map<String, dynamic>? _pendingMat;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _materials = [];
  bool _loadingCourses = true;
  bool _loadingMats = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _loadingCourses = true);
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) { setState(() => _loadingCourses = false); return; }
    final db = FirebaseFirestore.instance;

    try {
      Query mainQ;
      if (user.isDoctor) {
        mainQ = db.collection('courses')
            .where('doctorId', isEqualTo: user.uid)
            .where('type', isEqualTo: 'main');
      } else {
        mainQ = db.collection('courses')
          .where('universityAr', isEqualTo: user.universityAr)
          .where('facultyAr', isEqualTo: user.facultyAr)
          .where('year', isEqualTo: user.year)
          .where('type', isEqualTo: 'main');
      }
      final sideQ = db.collection('courses')
          .where('doctorId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'side');

      final results = await Future.wait([mainQ.get(), sideQ.get()]);
      final allDocs = [...results[0].docs, ...results[1].docs];
      final courses = allDocs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();

      if (mounted) setState(() { _courses = courses; _loadingCourses = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingCourses = false; });
    }
  }

  Future<void> _loadMaterials(String courseId) async {
    setState(() { _loadingMats = true; _materials = []; _pendingMat = null; });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('materials')
          .where('courseId', isEqualTo: courseId)
          .where('fileType', isEqualTo: 'pdf')
          .get();
      final mats = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mounted) setState(() { _materials = mats; _loadingMats = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingMats = false; });
    }
  }

  Future<void> _confirmAndProcess() async {
    if (_pendingMat == null || _selectedCourse == null) return;
    final mat = _pendingMat!;
    final url = mat['fileUrl'] as String? ?? '';
    if (url.isEmpty) return;

    final isAr = context.read<AppProvider>().isArabic;
    final courseTitle = isAr
        ? (_selectedCourse!['titleAr'] ?? _selectedCourse!['titleEn'] ?? '')
        : (_selectedCourse!['titleEn'] ?? _selectedCourse!['titleAr'] ?? '');
    final matTitle = isAr
        ? (mat['titleAr'] as String? ?? mat['titleEn'] as String? ?? 'Material')
        : (mat['titleEn'] as String? ?? mat['titleAr'] as String? ?? 'Material');

    setState(() => _downloading = true);
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        widget.onPdfSelected(res.bodyBytes, courseTitle as String, matTitle);
      } else {
        throw Exception('Download failed with status ${res.statusCode} for url: $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading file: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    final theme = Theme.of(context);

    final btnLabel = isAr
        ? (widget.actionLabelAr ?? 'ابدأ')
        : (widget.actionLabel ?? 'Use This File');
    final btnIcon = widget.actionIcon ?? Icons.play_arrow_rounded;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── COURSE DROPDOWN ─────────────────────────────────────────────
      Text(
        isAr ? 'اختر المادة' : 'Select Course',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      const SizedBox(height: 6),

      if (_loadingCourses)
        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
      else if (_courses.isEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Text(
              isAr ? 'لا توجد مواد متاحة' : 'No courses available',
              style: const TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ]),
        )
      else
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedCourse,
                isExpanded: true,
                hint: Text(
                  isAr ? 'اختر مادة...' : 'Choose a course...',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                borderRadius: BorderRadius.circular(12),
                items: _courses.map((c) {
                  final title = isAr
                      ? (c['titleAr'] ?? c['titleEn'] ?? '')
                      : (c['titleEn'] ?? c['titleAr'] ?? '');
                  final type = c['type'] == 'main'
                      ? (isAr ? 'رئيسية' : 'Main')
                      : (isAr ? 'جانبية' : 'Side');
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: c,
                    child: Row(children: [
                      Icon(
                        c['type'] == 'main'
                            ? Icons.menu_book_rounded
                            : Icons.extension_rounded,
                        size: 16,
                        color: c['type'] == 'main'
                            ? AppTheme.primaryColor
                            : const Color(0xFF06D6A0),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$title ($type)',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ]),
                  );
                }).toList(),
                onChanged: (c) {
                  setState(() {
                    _selectedCourse = c;
                    _materials = [];
                    _pendingMat = null;
                  });
                  if (c != null) _loadMaterials(c['id'] as String);
                },
              ),
            ),
          ),
        ),

      // ── FILE LIST ────────────────────────────────────────────────────
      if (_selectedCourse != null) ...[
        const SizedBox(height: 12),
        Text(
          isAr ? 'اختر الملف (PDF)' : 'Select File (PDF)',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),

        if (_loadingMats)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else if (_materials.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isAr ? 'لا توجد ملفات PDF في هذه المادة' : 'No PDF files in this course',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          )
        else
          Column(
            children: _materials.map((mat) {
              final isPending = _pendingMat != null && _pendingMat!['id'] == mat['id'];
              final matName = isAr
                  ? (mat['titleAr'] as String? ?? mat['titleEn'] as String? ?? 'PDF')
                  : (mat['titleEn'] as String? ?? mat['titleAr'] as String? ?? 'PDF');

              return InkWell(
                onTap: _downloading
                    ? null
                    : () {
                        setState(() => _pendingMat = mat);
                      },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isPending
                        ? AppTheme.primaryColor.withOpacity(0.12)
                        : theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPending
                          ? AppTheme.primaryColor
                          : Colors.grey.withOpacity(0.2),
                      width: isPending ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: isPending ? AppTheme.primaryColor : Colors.red.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        matName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isPending ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isPending)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.primaryColor, size: 20),
                  ]),
                ),
              );
            }).toList(),
          ),

        // ── ACTION BUTTON ─────────────────────────────────────────────
        if (_pendingMat != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _downloading ? null : _confirmAndProcess,
              icon: _downloading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(btnIcon, color: Colors.white),
              label: Text(
                _downloading
                    ? (isAr ? 'جاري التحميل...' : 'Loading...')
                    : btnLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    ]);
  }
}
