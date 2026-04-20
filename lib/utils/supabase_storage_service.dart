import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Supabase Storage helper.
/// Bucket `materials` must be created in the Supabase dashboard as **Public**.
class SupabaseStorageService {
  static const String _bucket = 'materials';

  /// Uploads [bytes] with [filename] into path `courseId/uuid.ext`.
  /// Returns the public URL string on success, or throws.
  static Future<String> uploadFile({
    required String courseId,
    required String filename,
    required Uint8List bytes,
  }) async {
    final ext = filename.split('.').last.toLowerCase();
    // Use the original filename (sanitized) so the PDF viewer shows a readable name.
    // A timestamp prefix ensures uniqueness even for identical filenames.
    final nameWithoutExt = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;
    // Remove characters that are unsafe in URLs/filenames, keep letters/digits/spaces/dashes/underscores
    final sanitized = nameWithoutExt
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final safeName = sanitized.isEmpty ? 'file' : sanitized;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$courseId/${timestamp}_$safeName.$ext';

    await Supabase.instance.client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: false,
        contentType: _getMimeType(ext),
      ),
    );

    final publicUrl = Supabase.instance.client.storage
        .from(_bucket)
        .getPublicUrl(path);

    return publicUrl.trim();
  }

  static String _getMimeType(String ext) {
    switch (ext) {
      case 'pdf':  return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      case 'mp4':  return 'video/mp4';
      case 'webm': return 'video/webm';
      case 'txt':  return 'text/plain';
      default:     return 'application/octet-stream';
    }
  }

  /// Deletes the file at the given public URL (for cleanup).
  static Future<void> deleteFile(String publicUrl) async {
    // Extract the path after /object/public/materials/
    final marker = '/object/public/$_bucket/';
    final idx = publicUrl.indexOf(marker);
    if (idx == -1) return;
    final path = publicUrl.substring(idx + marker.length);
    await Supabase.instance.client.storage.from(_bucket).remove([path]);
  }
}
