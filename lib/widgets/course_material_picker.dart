import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';

/// A widget that lets users pick a course then one of its PDF materials.
/// Calls [onPdfSelected] with the raw bytes, course title, and material title.
class CourseMaterialPicker extends StatefulWidget {
  final void Function(Uint8List bytes, String courseTitle, String matTitle) onPdfSelected;
  final String? selectedCourseName;
  final String? selectedMatName;

  const CourseMaterialPicker({
    super.key,
    required this.onPdfSelected,
    this.selectedCourseName,
    this.selectedMatName,
  });

  @override
  State<CourseMaterialPicker> createState() => _CourseMaterialPickerState();
}

class _CourseMaterialPickerState extends State<CourseMaterialPicker> {
  Map<String, dynamic>? _selectedCourse;
  Map<String, dynamic>? _selectedMat;
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
      // Main courses (by uni/faculty/year for students, or owned by doctor)
      Query mainQ;
      if (user.isDoctor) {
        mainQ = db.collection('courses').where('doctorId', isEqualTo: user.uid).where('type', isEqualTo: 'main');
      } else {
        mainQ = db.collection('courses')
          .where('universityAr', isEqualTo: user.universityAr)
          .where('facultyAr', isEqualTo: user.facultyAr)
          .where('year', isEqualTo: user.year)
          .where('type', isEqualTo: 'main');
      }

      // Side courses: owned by this user
      final sideQ = db.collection('courses').where('doctorId', isEqualTo: user.uid).where('type', isEqualTo: 'side');

      final results = await Future.wait([mainQ.get(), sideQ.get()]);
      final allDocs = [...results[0].docs, ...results[1].docs];
      final courses = allDocs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();

      if (mounted) setState(() { _courses = courses; _loadingCourses = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingCourses = false; });
    }
  }

  Future<void> _loadMaterials(String courseId) async {
    setState(() { _loadingMats = true; _materials = []; _selectedMat = null; });
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

  Future<void> _downloadAndSelect(Map<String, dynamic> mat, String courseTitle) async {
    final url = mat['fileUrl'] as String? ?? '';
    if (url.isEmpty) return;
    setState(() => _downloading = true);
    try {
      final res = await Dio().get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      final bytes = Uint8List.fromList(res.data!);
      final isAr = context.read<AppProvider>().isArabic;
      final matTitle = isAr
        ? (mat['titleAr'] as String? ?? mat['titleEn'] as String? ?? 'Material')
        : (mat['titleEn'] as String? ?? mat['titleAr'] as String? ?? 'Material');
      widget.onPdfSelected(bytes, courseTitle, matTitle);
      if (mounted) setState(() { _selectedMat = mat; _downloading = false; });
    } catch (_) {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    final theme = Theme.of(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── COURSE PICKER ──────────────────────────────────────────────
      Text(isAr ? 'اختر المادة' : 'Select Course',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 6),
      _loadingCourses
        ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        : _courses.isEmpty
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(isAr ? 'لا توجد مواد متاحة' : 'No courses available', style: const TextStyle(color: Colors.orange, fontSize: 13)),
              ]))
          : Container(
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
                    hint: Text(isAr ? 'اختر مادة...' : 'Choose a course...', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    borderRadius: BorderRadius.circular(12),
                    items: _courses.map((c) {
                      final isArabic = isAr;
                      final title = isArabic ? (c['titleAr'] ?? c['titleEn'] ?? '') : (c['titleEn'] ?? c['titleAr'] ?? '');
                      final type = c['type'] == 'main' ? (isArabic ? 'رئيسية' : 'Main') : (isArabic ? 'جانبية' : 'Side');
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: c,
                        child: Row(children: [
                          Icon(c['type'] == 'main' ? Icons.menu_book_rounded : Icons.extension_rounded,
                            size: 16, color: c['type'] == 'main' ? AppTheme.primaryColor : const Color(0xFF06D6A0)),
                          const SizedBox(width: 8),
                          Expanded(child: Text('$title ($type)', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                        ]),
                      );
                    }).toList(),
                    onChanged: (c) {
                      setState(() { _selectedCourse = c; _materials = []; _selectedMat = null; });
                      if (c != null) _loadMaterials(c['id'] as String);
                    },
                  ),
                ),
              ),
            ),

      // ── MATERIAL PICKER ────────────────────────────────────────────
      if (_selectedCourse != null) ...[
        const SizedBox(height: 12),
        Text(isAr ? 'اختر الملف (PDF)' : 'Select File (PDF)',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        _loadingMats
          ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          : _materials.isEmpty
            ? Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: Text(isAr ? 'لا توجد ملفات PDF في هذه المادة' : 'No PDF files in this course',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)))
            : Column(
                children: _materials.map((mat) {
                  final isSelected = _selectedMat?['id'] == mat['id'];
                  return GestureDetector(
                    onTap: _downloading ? null : () {
                      final isArabic = isAr;
                      final courseTitle = isArabic
                        ? (_selectedCourse!['titleAr'] ?? _selectedCourse!['titleEn'] ?? '')
                        : (_selectedCourse!['titleEn'] ?? _selectedCourse!['titleAr'] ?? '');
                      _downloadAndSelect(mat, courseTitle as String);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.withOpacity(0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.picture_as_pdf_rounded,
                          color: isSelected ? AppTheme.primaryColor : Colors.red.shade400, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          isAr
                            ? (mat['titleAr'] as String? ?? mat['titleEn'] as String? ?? 'PDF')
                            : (mat['titleEn'] as String? ?? mat['titleAr'] as String? ?? 'PDF'),
                          style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500))),
                        if (_downloading && isSelected)
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        else if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20),
                      ]),
                    ),
                  );
                }).toList(),
              ),
      ],
    ]);
  }
}
