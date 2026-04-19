import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:studyhub/offline_manager.dart';
import 'package:studyhub/screens/courses/file_viewer_screen.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

/// Shows all downloaded materials — works 100% without internet.
class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});
  @override State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  List<Map<String, dynamic>> _items = [];
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _reload(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _reload() => setState(() => _items = OfflineManager.all());

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items.where((m) =>
      (m['titleAr'] ?? '').toString().toLowerCase().contains(q) ||
      (m['titleEn'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAr  = context.watch<AppProvider>().isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.offline_bolt_rounded,
                color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Text(isAr ? 'المحتوى المحفوظ' : 'Offline Library',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: isAr ? 'ابحث في الملفات المحفوظة...' : 'Search downloads...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                  : null,
            ),
          ),
        ),

        // Stats bar
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _StatPill(
                icon: Icons.download_done_rounded,
                label: '${_items.length} ${isAr ? "ملف" : "files"}',
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.storage_rounded,
                label: OfflineManager.formatSize(_items.fold(0, (s, m) =>
                    s + ((m['fileSize'] as int?) ?? 0))),
                color: const Color(0xFF06D6A0),
              ),
            ]),
          ),

        // List
        Expanded(child: _filtered.isEmpty
          ? _EmptyState(isAr: isAr, hasItems: _items.isNotEmpty)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _OfflineCard(
                meta: _filtered[i],
                isAr: isAr,
                isDark: isDark,
                onDeleted: _reload,
              ),
            ),
        ),
      ]),
    );
  }
}

// ── Offline file card ─────────────────────────────────────────────────────────
class _OfflineCard extends StatelessWidget {
  final Map<String, dynamic> meta;
  final bool isAr, isDark;
  final VoidCallback onDeleted;
  const _OfflineCard({required this.meta, required this.isAr,
      required this.isDark, required this.onDeleted});

  String get _ext => (meta['fileType'] ?? 'file') as String;
  String get _title => isAr
      ? (meta['titleAr'] ?? meta['titleEn'] ?? '') as String
      : (meta['titleEn'] ?? meta['titleAr'] ?? '') as String;

  Color get _color {
    switch (_ext.toLowerCase()) {
      case 'pdf':               return Colors.red;
      case 'doc': case 'docx': return Colors.blue;
      case 'ppt': case 'pptx': return Colors.orange;
      case 'xls': case 'xlsx': return Colors.green;
      case 'mp4': case 'mov': case 'avi': case 'mkv': return Colors.purple;
      case 'jpg': case 'jpeg': case 'png': case 'gif': return Colors.teal;
      default: return Colors.grey;
    }
  }

  IconData get _icon {
    switch (_ext.toLowerCase()) {
      case 'pdf':               return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx': return Icons.description_rounded;
      case 'ppt': case 'pptx': return Icons.slideshow_rounded;
      case 'xls': case 'xlsx': return Icons.table_chart_rounded;
      case 'mp4': case 'mov': case 'avi': case 'mkv': return Icons.play_circle_fill_rounded;
      case 'jpg': case 'jpeg': case 'png': case 'gif': return Icons.image_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  void _open(BuildContext ctx) {
    final path = meta['localPath'] as String?;
    if (path == null || !File(path).existsSync()) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(isAr ? 'الملف غير موجود — أعد التحميل' : 'File missing — re-download'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => FileViewerScreen(
      fileUrl: 'file://$path',   // local file URI
      title: _title,
      fileType: _ext,
    )));
  }

  void _delete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isAr ? 'حذف الملف؟' : 'Delete file?'),
        content: Text(isAr
            ? 'سيتم حذف "$_title" من التخزين المحلي'
            : '"$_title" will be removed from local storage'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isAr ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await OfflineManager.delete(meta['id'] as String);
      onDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = (meta['fileSize'] as int?) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B3A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _color.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: () => _open(context),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(_icon, color: _color, size: 24),
        ),
        title: Text(_title,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(_ext.toUpperCase(),
                  style: TextStyle(color: _color,
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            if (size > 0) Text(OfflineManager.formatSize(size),
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(Icons.play_arrow_rounded, color: _color, size: 28),
            onPressed: () => _open(context),
            tooltip: isAr ? 'فتح' : 'Open',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 22),
            onPressed: () => _delete(context),
            tooltip: isAr ? 'حذف' : 'Delete',
          ),
        ]),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isAr, hasItems;
  const _EmptyState({required this.isAr, required this.hasItems});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('📥', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 20),
      Text(
        hasItems
            ? (isAr ? 'لا نتائج للبحث' : 'No results found')
            : (isAr ? 'لا توجد ملفات محفوظة' : 'No offline files yet'),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 10),
      Text(
        hasItems
            ? (isAr ? 'جرب كلمة بحث أخرى' : 'Try a different search term')
            : (isAr
                ? 'اضغط على زر التحميل في أي ملف لحفظه للاستخدام بدون إنترنت'
                : 'Tap the download button on any file to save it for offline use'),
        style: TextStyle(color: Colors.grey[500], fontSize: 14),
        textAlign: TextAlign.center,
      ),
    ]),
  ));
}

// ── Stat pill ─────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color,
          fontWeight: FontWeight.w700, fontSize: 12)),
    ]),
  );
}