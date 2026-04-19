import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class SummarizeNotesScreen extends StatefulWidget {
  const SummarizeNotesScreen({super.key});
  @override State<SummarizeNotesScreen> createState() => _SummarizeNotesScreenState();
}

class _SummarizeNotesScreenState extends State<SummarizeNotesScreen> {
  static const _apiKey = 'AIzaSyBFYmfZC_D-4vwigPrOM0MiPYYEZb4UdBM';
  final _notesCtrl = TextEditingController();
  String? _summary;
  bool _loading = false;
  String _mode = 'summary'; // summary | bullets | exam

  Future<void> _summarize() async {
    if (_notesCtrl.text.trim().isEmpty) return;
    final isAr = context.read<AppProvider>().isArabic;
    setState(() { _loading = true; _summary = null; });

    final modePrompts = {
      'summary': isAr ? 'لخص هذه الملاحظات في فقرات واضحة ومنظمة بالعربية:' : 'Summarize these notes in clear organized paragraphs:',
      'bullets': isAr ? 'لخص هذه الملاحظات كنقاط مختصرة بالعربية (كل نقطة سطر واحد):' : 'Summarize as concise bullet points (one line each):',
      'exam': isAr ? 'استخرج من هذه الملاحظات: أهم المفاهيم، تعريفات مهمة، وأسئلة امتحان محتملة. اكتب بالعربية:' : 'Extract: key concepts, important definitions, and likely exam questions from these notes:',
    };

    try {
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [{'text': '${modePrompts[_mode]}\n\n${_notesCtrl.text}'}]}],
          'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 2000}}),
      ).timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() { _summary = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? ''; _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'لخص ملاحظاتك' : 'Summarize My Notes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Mode selector
          Row(children: [
            _ModeBtn(label: isAr ? 'ملخص' : 'Summary', icon: Icons.article_outlined, selected: _mode == 'summary', onTap: () => setState(() => _mode = 'summary')),
            const SizedBox(width: 8),
            _ModeBtn(label: isAr ? 'نقاط' : 'Bullets', icon: Icons.format_list_bulleted_rounded, selected: _mode == 'bullets', onTap: () => setState(() => _mode = 'bullets')),
            const SizedBox(width: 8),
            _ModeBtn(label: isAr ? 'امتحان' : 'Exam Prep', icon: Icons.school_rounded, selected: _mode == 'exam', onTap: () => setState(() => _mode = 'exam')),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              hintText: isAr ? 'الصق ملاحظاتك هنا...' : 'Paste your notes here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            maxLines: 8,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _summarize,
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded),
            label: Text(_loading ? (isAr ? 'جاري التلخيص...' : 'Summarizing...') : (isAr ? 'لخص الآن' : 'Summarize Now')),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
          if (_summary != null) ...[
            const SizedBox(height: 16),
            Container(width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.07), width: 1.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(isAr ? 'الملخص' : 'Summary', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.primaryColor)),
                  GestureDetector(onTap: () { Clipboard.setData(ClipboardData(text: _summary!)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تم النسخ' : 'Copied'), duration: const Duration(seconds: 1))); },
                    child: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primaryColor)),
                ]),
                const SizedBox(height: 12),
                SelectableText(_summary!, style: const TextStyle(fontSize: 14, height: 1.7)),
              ])),
          ],
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label; final IconData icon; final bool selected; final VoidCallback onTap;
  const _ModeBtn({required this.label, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, size: 18, color: selected ? Colors.white : AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppTheme.primaryColor)),
      ])),
  ));
}