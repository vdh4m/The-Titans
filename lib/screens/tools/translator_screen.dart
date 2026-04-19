import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../utils/app_theme.dart';

class TranslatorScreen extends StatefulWidget {
  final String? initialText;
  const TranslatorScreen({super.key, this.initialText});
  @override State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final _inCtrl  = TextEditingController();
  final _outCtrl = TextEditingController();
  Timer?  _debounce;
  bool    _loading = false;
  String  _error   = '';
  String  _src = 'en';
  String  _tgt = 'ar';

  static const _langs = [
    ('ar','🇸🇦 Arabic'),       ('en','🇺🇸 English'),
    ('fr','🇫🇷 French'),        ('de','🇩🇪 German'),
    ('es','🇪🇸 Spanish'),       ('it','🇮🇹 Italian'),
    ('pt','🇧🇷 Portuguese'),    ('ru','🇷🇺 Russian'),
    ('zh','🇨🇳 Chinese'),       ('ja','🇯🇵 Japanese'),
    ('ko','🇰🇷 Korean'),        ('tr','🇹🇷 Turkish'),
    ('nl','🇳🇱 Dutch'),         ('pl','🇵🇱 Polish'),
    ('sv','🇸🇪 Swedish'),       ('uk','🇺🇦 Ukrainian'),
    ('he','🇮🇱 Hebrew'),        ('fa','🇮🇷 Persian'),
    ('hi','🇮🇳 Hindi'),         ('ur','🇵🇰 Urdu'),
    ('bn','🇧🇩 Bengali'),       ('id','🇮🇩 Indonesian'),
    ('ms','🇲🇾 Malay'),         ('th','🇹🇭 Thai'),
    ('vi','🇻🇳 Vietnamese'),    ('tl','🇵🇭 Filipino'),
    ('sw','🇰🇪 Swahili'),       ('ro','🇷🇴 Romanian'),
    ('cs','🇨🇿 Czech'),         ('hu','🇭🇺 Hungarian'),
    ('el','🇬🇷 Greek'),         ('da','🇩🇰 Danish'),
    ('fi','🇫🇮 Finnish'),       ('no','🇳🇴 Norwegian'),
    ('sk','🇸🇰 Slovak'),        ('bg','🇧🇬 Bulgarian'),
    ('hr','🇭🇷 Croatian'),      ('lt','🇱🇹 Lithuanian'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _inCtrl.text = widget.initialText!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _translate());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _inCtrl.dispose(); _outCtrl.dispose();
    super.dispose();
  }

  void _onInput(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() { _outCtrl.text = ''; _error = ''; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 800), _translate);
  }

  Future<void> _translate() async {
    final text = _inCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get'
        '?q=${Uri.encodeComponent(text)}'
        '&langpair=$_src|$_tgt',
      );
      final res = await http.get(uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final body = res.body;
      // Parse JSON manually — no json_decode needed for this simple case
      final match = RegExp(r'"translatedText"\s*:\s*"((?:[^"\\]|\\.)*)"')
          .firstMatch(body);
      String translated = match?.group(1) ?? '';

      // Unescape common sequences
      translated = translated
          .replaceAll(r'\u0027', "'")
          .replaceAll(r'\u0022', '"')
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n');

      if (mounted) setState(() { _outCtrl.text = translated; _loading = false; });
    } on TimeoutException {
      if (mounted) setState(() { _loading = false; _error = 'Connection timed out'; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Translation failed: $e'; });
    }
  }

  void _swap() {
    setState(() {
      final t = _src; _src = _tgt; _tgt = t;
      final tv = _inCtrl.text; _inCtrl.text = _outCtrl.text; _outCtrl.text = tv;
    });
    if (_inCtrl.text.isNotEmpty) _translate();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌐 Translator',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        // ── Language bar ─────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1730) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
                blurRadius: 10, offset: const Offset(0,3))],
          ),
          child: Row(children: [
            Expanded(child: _LangDrop(value: _src, langs: _langs,
                onChanged: (v) { setState(() => _src = v!); _translate(); })),
            GestureDetector(
              onTap: _swap,
              child: Container(
                width: 38, height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.swap_horiz_rounded,
                    color: AppTheme.primaryColor, size: 22),
              ),
            ),
            Expanded(child: _LangDrop(value: _tgt, langs: _langs,
                onChanged: (v) { setState(() => _tgt = v!); _translate(); })),
          ]),
        ),

        // ── Panels ───────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // Input
              _Panel(
                ctrl: _inCtrl,
                readOnly: false,
                isDark: isDark,
                onChanged: _onInput,
                hint: 'Enter text...',
                trailing: [
                  IconButton(icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () { _inCtrl.clear(); _outCtrl.clear(); }),
                  IconButton(
                    icon: const Icon(Icons.translate_rounded, size: 18,
                        color: AppTheme.primaryColor),
                    onPressed: _translate,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Output
              if (_loading)
                Container(height: 100,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator())
              else if (_error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error,
                        style: const TextStyle(color: Colors.red, fontSize: 13))),
                    TextButton(onPressed: _translate,
                        child: const Text('Retry')),
                  ]),
                )
              else
                _Panel(
                  ctrl: _outCtrl,
                  readOnly: true,
                  isDark: isDark,
                  onChanged: (_) {},
                  hint: 'Translation...',
                  trailing: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _outCtrl.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied!'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating));
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _LangDrop extends StatelessWidget {
  final String value;
  final List<(String,String)> langs;
  final ValueChanged<String?> onChanged;
  const _LangDrop({required this.value, required this.langs, required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonHideUnderline(
    child: DropdownButton<String>(
      value: langs.any((l)=>l.$1==value) ? value : langs.first.$1,
      isExpanded: true,
      icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      items: langs.map((l) => DropdownMenuItem(value: l.$1,
          child: Text(l.$2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: onChanged,
    ),
  );
}

class _Panel extends StatelessWidget {
  final TextEditingController ctrl;
  final bool readOnly, isDark;
  final ValueChanged<String> onChanged;
  final String hint;
  final List<Widget> trailing;
  const _Panel({required this.ctrl, required this.readOnly,
      required this.isDark, required this.onChanged,
      required this.hint, required this.trailing});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1730) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: AppTheme.primaryColor.withOpacity(readOnly ? 0.15 : 0.35),
          width: readOnly ? 1 : 1.5),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
          blurRadius: 8, offset: const Offset(0,2))],
    ),
    child: Column(children: [
      TextField(
        controller: ctrl, readOnly: readOnly,
        onChanged: onChanged, maxLines: 6, minLines: 4,
        style: TextStyle(fontSize: 15, height: 1.5,
            color: readOnly ? (isDark ? Colors.white : Colors.black87) : null),
        decoration: InputDecoration(
          hintText: hint, border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
      Divider(height: 1,
          color: isDark ? Colors.white12 : Colors.grey.shade100),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: trailing),
    ]),
  );
}