import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/tools/translator_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TranslatableText — drop-in replacement for Text / SelectableText
//  Long-press any word → shows a popup with translation + "Open Translator"
// ─────────────────────────────────────────────────────────────────────────────
class TranslatableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final String targetLang;   // e.g. 'ar' or 'en'

  const TranslatableText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.targetLang = 'ar',
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      contextMenuBuilder: (ctx, editableTextState) {
        final selection = editableTextState.textEditingValue.selection;
        final selectedText = selection.isValid && !selection.isCollapsed
            ? text.substring(selection.start, selection.end)
            : '';
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: [
            // Default items
            ...editableTextState.contextMenuButtonItems,
            // Translate selected
            if (selectedText.isNotEmpty)
              ContextMenuButtonItem(
                label: '🌐 Translate',
                onPressed: () {
                  ContextMenuController.removeAny();
                  _showTranslatePopup(ctx, selectedText);
                },
              ),
          ],
        );
      },
    );
  }

  void _showTranslatePopup(BuildContext ctx, String word) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TranslateSheet(word: word, targetLang: targetLang),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Quick translate bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _TranslateSheet extends StatefulWidget {
  final String word, targetLang;
  const _TranslateSheet({required this.word, required this.targetLang});
  @override State<_TranslateSheet> createState() => _TranslateSheetState();
}

class _TranslateSheetState extends State<_TranslateSheet> {
  String _result  = '';
  bool   _loading = true;
  String _tgt     = '';

  @override
  void initState() {
    super.initState();
    _tgt = widget.targetLang;
    _translate();
  }

  Future<void> _translate() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get'
        '?q=${Uri.encodeComponent(widget.word)}&langpair=en|$_tgt',
      );
      final client = HttpClient();
      final req    = await client.getUrl(uri);
      final res    = await req.close();
      final buf    = StringBuffer();
      await res.transform(utf8.decoder).forEach(buf.write);
      client.close();
      final match  = RegExp(r'"translatedText"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(buf.toString());
      final result = match?.group(1) ?? widget.word;
      setState(() { _result = result; _loading = false; });
    } catch (_) {
      setState(() { _result = 'Translation unavailable'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1730) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),
        // Original word
        Row(children: [
          const Icon(Icons.translate_rounded, color: Color(0xFF06D6A0), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('"${widget.word}"',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _result));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Copied!'), duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ));
            },
          ),
        ]),
        const Divider(),
        // Result
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF06D6A0).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF06D6A0).withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_tgt == 'ar' ? '🇸🇦 Arabic' : '🌐 Translation',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF06D6A0),
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(_result,
                  style: const TextStyle(fontSize: 20,
                      fontWeight: FontWeight.w800, height: 1.3)),
            ]),
          ),
        const SizedBox(height: 14),
        // Open full translator
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => TranslatorScreen(initialText: widget.word)));
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open Full Translator'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF06D6A0),
              side: const BorderSide(color: Color(0xFF06D6A0)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }
}