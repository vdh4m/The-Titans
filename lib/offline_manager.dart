import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Manages offline downloads — stores metadata in Hive, files on disk.
/// Usage:
///   await OfflineManager.init();              // call once in main()
///   await OfflineManager.download(mat);       // download a material
///   OfflineManager.isDownloaded(id)           // check if available
///   OfflineManager.localPath(id)              // get file path
///   await OfflineManager.delete(id)           // remove
///   OfflineManager.all()                      // list all downloaded items
class OfflineManager {
  static const _boxName = 'offline_materials';
  static late Box<Map> _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(_boxName);
  }

  // ── Download ─────────────────────────────────────────────────────────────
  static Future<void> download(
    Map<String, dynamic> material, {
    ValueChanged<double>? onProgress,
  }) async {
    final id  = material['id'] as String;
    final url = material['fileUrl'] as String;
    final ext = (material['fileType'] ?? 'file') as String;

    final dir  = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/offline/$id.$ext';
    await Directory('${dir.path}/offline').create(recursive: true);

    // Try URL candidates (handles Cloudinary image/raw mismatch)
    final candidates = _urlCandidates(url, ext);
    Object? lastErr;

    for (final candidate in candidates) {
      try {
        await Dio().download(
          candidate, path,
          options: Options(
            headers: {'Accept': '*/*'},
            receiveTimeout: const Duration(minutes: 15),
            validateStatus: (s) => s != null && s < 400,
          ),
          onReceiveProgress: (r, t) {
            if (t > 0) onProgress?.call(r / t);
          },
        );
        // Success — save metadata
        await _box.put(id, {
          ...material,
          'localPath': path,
          'downloadedAt': DateTime.now().toIso8601String(),
          'fileSize': File(path).lengthSync(),
        });
        return;
      } catch (e) {
        lastErr = e;
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      }
    }
    throw lastErr ?? Exception('Download failed for all URL candidates');
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  static Future<void> delete(String id) async {
    final meta = _box.get(id);
    if (meta != null) {
      final path = meta['localPath'] as String?;
      if (path != null) {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      }
      await _box.delete(id);
    }
  }

  // ── Query ─────────────────────────────────────────────────────────────────
  static bool isDownloaded(String id) => _box.containsKey(id);

  static String? localPath(String id) => _box.get(id)?['localPath'] as String?;

  static Map<String, dynamic>? getMeta(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  static List<Map<String, dynamic>> all() => _box.values
      .map((v) => Map<String, dynamic>.from(v))
      .toList()
      ..sort((a, b) {
        final aT = a['downloadedAt'] as String? ?? '';
        final bT = b['downloadedAt'] as String? ?? '';
        return bT.compareTo(aT);
      });

  static List<Map<String, dynamic>> forCourse(String courseId) =>
      all().where((m) => m['courseId'] == courseId).toList();

  // ── Helpers ───────────────────────────────────────────────────────────────
  static List<String> _urlCandidates(String url, String ext) {
    if (!url.contains('cloudinary.com')) return [url];
    final isMedia = ['mp4','mov','avi','mkv','webm','jpg','jpeg','png','gif','webp']
        .contains(ext.toLowerCase());
    if (isMedia) return [url];
    final toRaw  = url.replaceFirstMapped(RegExp(r'/(image|video|auto)/upload/'), (_) => '/raw/upload/');
    final toAuto = url.replaceFirstMapped(RegExp(r'/(image|video|raw)/upload/'),  (_) => '/auto/upload/');
    return {url, toRaw, toAuto}.toList();
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}