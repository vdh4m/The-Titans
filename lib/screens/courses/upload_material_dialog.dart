import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../models/course_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/xp_service.dart';
import '../home/notification_center_screen.dart';

const _cloudName    = 'dupiy6t8r';
const _uploadPreset = 'StudyHub';

/// Opens the improved upload dialog for a course material.
/// Shows: file name chip, Arabic/English title fields, live progress bar.
/// On success: saves to Firestore + notifies enrolled students.
Future<void> showUploadMaterialDialog({
  required BuildContext ctx,
  required CourseModel course,
  required dynamic user,
  required bool isAr,
}) async {
  final res = await FilePicker.platform.pickFiles(withData: true);
  if (res == null) return;
  final file = res.files.single;
  if (file.bytes == null) return;
  if (!ctx.mounted) return;

  final ext    = (file.extension ?? 'file').toLowerCase();
  final tArC   = TextEditingController(text: file.name);
  final tEnC   = TextEditingController(text: file.name);

  double uploadProgress = 0;
  bool uploading  = false;
  String? errorMsg;

  await showDialog(
    context: ctx,
    barrierDismissible: false,
    builder: (dCtx) => StatefulBuilder(
      builder: (_, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(_extIcon(ext), color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(child: Text(isAr ? 'رفع ملف' : 'Upload File',
              overflow: TextOverflow.ellipsis)),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // File info chip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(_extIcon(ext), size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Text(file.name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
                Text('${(file.size / 1024).round()} KB',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tArC,
              enabled: !uploading,
              decoration: InputDecoration(
                  labelText: isAr ? 'الاسم (عربي)' : 'Title (Arabic)',
                  prefixIcon: const Icon(Icons.title_rounded)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tEnC,
              enabled: !uploading,
              decoration: InputDecoration(
                  labelText: isAr ? 'الاسم (إنجليزي)' : 'Title (English)',
                  prefixIcon: const Icon(Icons.title_rounded)),
            ),

            // Progress bar
            if (uploading) ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: uploadProgress > 0 ? uploadProgress : null,
                  minHeight: 8,
                  backgroundColor: Colors.grey.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                uploadProgress > 0
                    ? '${(uploadProgress * 100).round()}%'
                    : (isAr ? 'جاري الرفع...' : 'Uploading...'),
                style: TextStyle(fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor, fontSize: 13),
              ),
            ],

            // Error
            if (errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ]),
        ),
        actions: [
          if (!uploading)
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text(isAr ? 'إلغاء' : 'Cancel'),
            ),
          if (!uploading)
            ElevatedButton.icon(
              onPressed: () async {
                setD(() { uploading = true; errorMsg = null; uploadProgress = 0.05; });
                try {
                  final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
                  final resourceType = isVideo ? 'video' : 'raw';
                  final uri = Uri.parse(
                      'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');

                  final request = http.MultipartRequest('POST', uri)
                    ..fields['upload_preset'] = _uploadPreset
                    ..fields['folder'] = 'studyhub/materials/${course.id}'
                    ..files.add(http.MultipartFile.fromBytes(
                        'file', file.bytes!, filename: file.name));

                  setD(() => uploadProgress = 0.2);
                  final response = await request.send();
                  setD(() => uploadProgress = 0.8);
                  final body = jsonDecode(await response.stream.bytesToString());
                  setD(() => uploadProgress = 0.95);

                  if (response.statusCode != 200) {
                    throw Exception(body['error']?['message'] ?? 'Upload failed');
                  }

                  final url     = body['secure_url'] as String;
                  final id      = const Uuid().v4();
                  final titleAr = tArC.text.trim().isEmpty ? file.name : tArC.text.trim();
                  final titleEn = tEnC.text.trim().isEmpty ? file.name : tEnC.text.trim();

                  await XpService.award(user.uid, XpEvent.uploadMaterial);
                  await FirebaseFirestore.instance.collection('materials').doc(id).set({
                    'id':         id,
                    'courseId':   course.id,
                    'titleAr':    titleAr,
                    'titleEn':    titleEn,
                    'fileUrl':    url,
                    'fileType':   ext,
                    'uploadedBy': user.uid,
                    'uploadedAt': DateTime.now().millisecondsSinceEpoch,
                  });

                  // Notify enrolled students
                  try {
                    final usersSnap = await FirebaseFirestore.instance
                        .collection('users')
                        .where('universityAr', isEqualTo: course.universityAr)
                        .where('facultyAr',    isEqualTo: course.facultyAr)
                        .where('year',         isEqualTo: course.year)
                        .get();
                    final uids = usersSnap.docs
                        .map((d) => d.id)
                        .where((uid) => uid != user.uid)
                        .toList();
                    await NotificationHelper.sendToMany(
                      uids:    uids,
                      type:    'material',
                      titleAr: 'ماتريال جديد — ${course.titleAr}',
                      titleEn: 'New Material — ${course.titleEn}',
                      bodyAr:  'تم رفع "$titleAr" في ${course.titleAr}',
                      bodyEn:  '"$titleEn" was uploaded to ${course.titleEn}',
                      extra:   {'courseId': course.id},
                    );
                  } catch (_) {}

                  setD(() { uploading = false; uploadProgress = 1.0; });
                  if (dCtx.mounted) Navigator.pop(dCtx);

                  // Success snackbar
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(isAr
                          ? 'تم رفع "$titleAr" بنجاح ✅'
                          : '"$titleEn" uploaded successfully ✅'),
                      backgroundColor: const Color(0xFF06D6A0),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } catch (e) {
                  setD(() {
                    uploading    = false;
                    uploadProgress = 0;
                    errorMsg     = e.toString();
                  });
                }
              },
              icon: const Icon(Icons.upload_rounded, color: Colors.white),
              label: Text(isAr ? 'رفع' : 'Upload',
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    ),
  );
}

IconData _extIcon(String ext) {
  switch (ext) {
    case 'pdf':           return Icons.picture_as_pdf_rounded;
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':           return Icons.videocam_rounded;
    case 'jpg':
    case 'jpeg':
    case 'png':           return Icons.image_rounded;
    case 'doc':
    case 'docx':          return Icons.description_rounded;
    case 'ppt':
    case 'pptx':          return Icons.slideshow_rounded;
    case 'xls':
    case 'xlsx':          return Icons.table_chart_rounded;
    default:              return Icons.insert_drive_file_rounded;
  }
}
