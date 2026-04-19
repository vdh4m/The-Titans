import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Voice to Text
//  • Uses Android native MediaRecorder via MethodChannel — NO external packages
// ─────────────────────────────────────────────────────────────────────────────
class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({super.key});
  @override State<SpeechToTextScreen> createState() => _S2TState();
}

class _S2TState extends State<SpeechToTextScreen>
    with SingleTickerProviderStateMixin {

  static const _apiKey     = 'AIzaSyBFYmfZC_D-4vwigPrOM0MiPYYEZb4UdBM';
  static const _recChannel = MethodChannel('com.studyhub/recorder');

  final TextEditingController _ctrl = TextEditingController();

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  bool   _recording    = false;
  bool   _transcribing = false;
  String _status       = '';
  String _recPath      = '';
  int    _seconds      = 0;
  Timer? _timer;

  String _lang = 'Arabic';
  static const _langs = [
    'Arabic', 'English', 'French', 'German', 'Spanish',
    'Italian', 'Portuguese', 'Russian', 'Chinese',
    'Japanese', 'Korean', 'Turkish', 'Hindi', 'Urdu',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _ctrl.dispose();
    // Make sure recording stops if screen is closed
    _recChannel.invokeMethod('stopRecording').catchError((_) {});
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final dir  = await getTemporaryDirectory();
      _recPath   = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recChannel.invokeMethod('startRecording', {'path': _recPath});

      _seconds = 0;
      _timer   = Timer.periodic(const Duration(seconds: 1),
          (_) { if (mounted) setState(() => _seconds++); });

      setState(() {
        _recording = true;
        _status    = '';
        _pulseCtrl.repeat(reverse: true);
      });
    } on PlatformException catch (e) {
      setState(() => _status = '❌ ${e.message ?? e.code}');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _pulseCtrl.stop();
    try {
      await _recChannel.invokeMethod('stopRecording');
    } catch (_) {}
    setState(() { _recording = false; _transcribing = true;
        _status = 'Transcribing with Gemini AI...'; });
    await _transcribe();
  }

  Future<void> _transcribe() async {
    try {
      final file = File(_recPath);
      if (!file.existsSync() || file.lengthSync() == 0) {
        throw Exception('Recording file is empty or missing');
      }

      final bytes  = await file.readAsBytes();
      final b64    = base64Encode(bytes);

      final prompt =
          'Transcribe this audio recording accurately. '
          'The speaker is talking in $_lang. '
          'Return ONLY the transcribed text with no extra commentary.';

      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/'
            'models/gemini-2.5-flash-lite:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [
              {'text': prompt},
              {'inline_data': {'mime_type': 'audio/m4a', 'data': b64}},
            ],
          }],
          'generationConfig': {'temperature': 0, 'maxOutputTokens': 2048},
        }),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
            as String? ?? '';
        if (mounted) {
          setState(() {
          _ctrl.text = _ctrl.text.isEmpty ? text : '${_ctrl.text}\n$text';
          _transcribing = false;
          _status = '✅ Transcribed (${_seconds}s)';
        });
        }
      } else {
        throw Exception('Gemini API error ${res.statusCode}');
      }
      try { file.deleteSync(); } catch (_) {}
    } catch (e) {
      if (mounted) setState(() { _transcribing = false; _status = '❌ $e'; });
    }
  }

  String get _recTime {
    final m = _seconds ~/ 60, s = _seconds % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎙 Voice to Text',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_ctrl.text.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _ctrl.text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✅ Copied'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: () => setState(() { _ctrl.clear(); _status = ''; }),
            ),
          ],
        ],
      ),
      body: Column(children: [

        // Language selector
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1730) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _lang, isExpanded: true,
              icon: const Icon(Icons.language_rounded, color: AppTheme.primaryColor),
              items: _langs.map((l) => DropdownMenuItem(value: l,
                  child: Text(l, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _lang = v!),
            ),
          ),
        ),

        // Status bar
        if (_status.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _status.startsWith('❌')
                  ? Colors.red.withOpacity(0.08)
                  : AppTheme.primaryColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_status, style: TextStyle(fontSize: 12,
                color: _status.startsWith('❌') ? Colors.red : AppTheme.primaryColor,
                fontWeight: FontWeight.w600)),
          ),

        // Text area
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1730) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _recording
                    ? Colors.red
                    : AppTheme.primaryColor.withOpacity(0.2),
                width: _recording ? 2 : 1.5,
              ),
            ),
            child: Stack(children: [
              TextField(
                controller: _ctrl,
                maxLines: null, expands: true,
                style: const TextStyle(fontSize: 16, height: 1.7),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  hintText: _transcribing
                      ? 'Gemini is transcribing...'
                      : _recording
                          ? 'Recording $_recTime — speak now'
                          : 'Press the mic button and speak.\nAI will transcribe your voice.',
                  hintStyle: TextStyle(
                    color: _recording ? Colors.red : Colors.grey[400],
                    fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ),
              // REC badge
              if (_recording)
                Positioned(top: 10, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 7, height: 7,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(_recTime, style: const TextStyle(
                          color: Colors.red, fontSize: 10,
                          fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              // Transcribing spinner
              if (_transcribing)
                Container(
                  color: (isDark ? const Color(0xFF1A1730) : Colors.white)
                      .withOpacity(0.85),
                  child: const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('Gemini AI Transcribing...',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  )),
                ),
            ]),
          ),
        ),

        // Mic button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _recording ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: GestureDetector(
              onTap: _transcribing ? null
                  : (_recording ? _stopRecording : _startRecording),
              child: Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _recording
                        ? [Colors.red, const Color(0xFFFF6B6B)]
                        : _transcribing
                            ? [Colors.grey, Colors.grey.shade600]
                            : [AppTheme.primaryColor, const Color(0xFF7209B7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(
                    color: (_recording ? Colors.red : AppTheme.primaryColor)
                        .withOpacity(0.45),
                    blurRadius: _recording ? 30 : 16,
                    offset: const Offset(0, 6),
                  )],
                ),
                child: Icon(
                  _transcribing ? Icons.hourglass_top_rounded
                      : _recording ? Icons.stop_rounded
                      : Icons.mic_rounded,
                  color: Colors.white, size: 44,
                ),
              ),
            ),
          ),
        ),

        Text(
          _transcribing ? 'Transcribing, please wait...'
              : _recording ? 'Tap ■ to stop'
              : 'Tap 🎙 to start recording',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}