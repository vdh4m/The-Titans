import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../payment/paywall_gate.dart';

class ExplainImageScreen extends StatefulWidget {
  const ExplainImageScreen({super.key});
  @override State<ExplainImageScreen> createState() => _ExplainImageScreenState();
}

class _ExplainImageScreenState extends State<ExplainImageScreen> {
  static const _apiKey = 'AIzaSyBFYmfZC_D-4vwigPrOM0MiPYYEZb4UdBM';
  String? _imagePath;
  String? _base64Image;
  String? _explanation;
  bool _loading = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imagePath = picked.path;
      _base64Image = base64Encode(bytes);
      _explanation = null;
    });
  }

  Future<void> _explain() async {
    if (_base64Image == null) return;
    final isAr = context.read<AppProvider>().isArabic;

    // ── Paywall check ─────────────────────────────────────────────────────
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && !PaywallGate.canAccess(user, PremiumFeature.unlimitedAi)) {
      PaywallGate.showUpgradeSheet(context, feature: PremiumFeature.unlimitedAi);
      return;
    }

    setState(() => _loading = true);

    final prompt = isAr
      ? 'اشرح هذه الصورة الأكاديمية بالتفصيل. لو فيها معادلات أو رسوم بيانية أو مفاهيم علمية، اشرحها بطريقة واضحة وسهلة للطالب. استخدم اللغة العربية.'
      : 'Explain this academic image in detail. If it contains equations, diagrams, or scientific concepts, explain them clearly and simply for a student.';

    try {
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [
          {'inline_data': {'mime_type': 'image/jpeg', 'data': _base64Image}},
          {'text': prompt},
        ]}], 'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 1024}}),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() { _explanation = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? ''; _loading = false; });
      } else {
        final err = jsonDecode(res.body);
        setState(() { _explanation = '⚠️ ${err['error']?['message'] ?? 'Error'}'; _loading = false; });
      }
    } catch (e) { setState(() { _explanation = '⚠️ $e'; _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'اشرح هذه الصورة' : 'Explain This Image')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Header
          Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7209B7), Color(0xFF4361EE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const Text('🔬', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(isAr ? 'صوّر معادلة أو رسم أو صفحة' : 'Photograph an equation, diagram or page',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15), textAlign: TextAlign.center),
              Text(isAr ? 'والذكاء الاصطناعي يشرحها لك فوراً' : 'and AI will explain it instantly',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          const SizedBox(height: 24),

          // Pick source buttons
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(isAr ? 'كاميرا' : 'Camera'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48),
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.image_rounded),
              label: Text(isAr ? 'معرض الصور' : 'Gallery'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48),
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
          ]),
          const SizedBox(height: 16),

          // Image preview
          if (_imagePath != null) ...[
            ClipRRect(borderRadius: BorderRadius.circular(16),
              child: Image.network(_imagePath!, fit: BoxFit.contain, height: 250, width: double.infinity,
                errorBuilder: (_, __, ___) => Container(height: 150, color: Colors.grey[100],
                  child: const Icon(Icons.image_rounded, size: 48, color: Colors.grey)))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _explain,
              icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded),
              label: Text(_loading ? (isAr ? 'جاري الشرح...' : 'Explaining...') : (isAr ? 'اشرح الصورة' : 'Explain Image')),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ],

          // Explanation
          if (_explanation != null) ...[
            const SizedBox(height: 20),
            Container(width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.07), width: 1.5)),
              child: SelectableText(_explanation!, style: const TextStyle(fontSize: 14, height: 1.7))),
          ],
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}
