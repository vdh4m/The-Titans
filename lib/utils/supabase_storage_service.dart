import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
    final ext  = filename.split('.').last.toLowerCase();
    final path = '$courseId/${const Uuid().v4()}.$ext';

    await Supabase.instance.client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: false),
    );

    final publicUrl = Supabase.instance.client.storage
        .from(_bucket)
        .getPublicUrl(path);

    return publicUrl;
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
