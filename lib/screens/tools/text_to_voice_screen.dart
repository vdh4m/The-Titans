import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

class TextToVoiceScreen extends StatefulWidget {
  const TextToVoiceScreen({super.key});
  @override
  State<TextToVoiceScreen> createState() => _TextToVoiceScreenState();
}

class _TextToVoiceScreenState extends State<TextToVoiceScreen> {
  final FlutterTts _tts = FlutterTts();
  final _textCtrl = TextEditingController();
  bool _isSpeaking = false;
  bool _isPaused = false;
  double _speed = 0.5;
  double _pitch = 1.0;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setSpeechRate(_speed);
    await _tts.setPitch(_pitch);
    _tts.setStartHandler(() => setState(() { _isSpeaking = true; _isPaused = false; }));
    _tts.setCompletionHandler(() => setState(() { _isSpeaking = false; _isPaused = false; }));
    _tts.setCancelHandler(() => setState(() { _isSpeaking = false; _isPaused = false; }));
    _tts.setPauseHandler(() => setState(() { _isPaused = true; }));
    _tts.setContinueHandler(() => setState(() { _isPaused = false; }));
  }

  Future<void> _speak() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final isAr = context.read<AppProvider>().isArabic;
    await _tts.setLanguage(isAr ? 'ar-SA' : 'en-US');
    await _tts.setSpeechRate(_speed);
    await _tts.setPitch(_pitch);
    await _tts.speak(text);
  }

  Future<void> _pause() async => await _tts.pause();
  Future<void> _stop() async => await _tts.stop();

  @override
  void dispose() {
    _tts.stop();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    // ignore: unused_local_variable
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔊', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(isAr ? 'النص إلى صوت' : 'Text to Voice'),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7209B7), AppTheme.primaryColor],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isSpeaking ? 72 : 60,
                height: _isSpeaking ? 72 : 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('🔊', style: TextStyle(fontSize: 32))),
              ),
              const SizedBox(height: 12),
              Text(isAr ? 'محوّل النص إلى كلام' : 'Text to Speech',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              Text(isAr ? 'اكتب أي نص واستمع إليه' : 'Type any text and listen to it',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (_isSpeaking) ...[
                const SizedBox(height: 8),
                Text(_isPaused ? (isAr ? '⏸ متوقف مؤقتاً' : '⏸ Paused') : (isAr ? '▶ جاري التشغيل...' : '▶ Playing...'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(height: 24),

          // Text input
          TextField(
            controller: _textCtrl,
            maxLines: 7,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            decoration: InputDecoration(
              hintText: isAr ? 'اكتب أو الصق النص هنا...' : 'Type or paste your text here...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 20),

          // Speed
          Row(children: [
            const Icon(Icons.speed_rounded, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text(isAr ? 'السرعة: ${(_speed * 2).toStringAsFixed(1)}x' : 'Speed: ${(_speed * 2).toStringAsFixed(1)}x',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Expanded(child: Slider(
              value: _speed,
              min: 0.1, max: 1.0,
              activeColor: AppTheme.primaryColor,
              onChanged: (v) => setState(() => _speed = v),
            )),
          ]),

          // Pitch
          Row(children: [
            const Icon(Icons.graphic_eq_rounded, size: 18, color: Color(0xFF7209B7)),
            const SizedBox(width: 6),
            Text(isAr ? 'النبرة: ${_pitch.toStringAsFixed(1)}' : 'Pitch: ${_pitch.toStringAsFixed(1)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Expanded(child: Slider(
              value: _pitch,
              min: 0.5, max: 2.0,
              activeColor: const Color(0xFF7209B7),
              onChanged: (v) => setState(() => _pitch = v),
            )),
          ]),
          const SizedBox(height: 20),

          // Controls
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Stop
            if (_isSpeaking)
              IconButton.filled(
                onPressed: _stop,
                icon: const Icon(Icons.stop_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.red, iconSize: 24),
              ),
            const SizedBox(width: 12),
            // Play / Pause
            GestureDetector(
              onTap: _isSpeaking && !_isPaused ? _pause : _speak,
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF7209B7)]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Icon(
                  _isSpeaking && !_isPaused ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 32),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // Clear button
          if (_textCtrl.text.isNotEmpty)
            TextButton.icon(
              onPressed: () { _stop(); _textCtrl.clear(); setState(() {}); },
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: Text(isAr ? 'مسح النص' : 'Clear text'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),

          const SizedBox(height: 40),
          // Tips
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.lightbulb_rounded, color: AppTheme.primaryColor, size: 16),
                const SizedBox(width: 6),
                Text(isAr ? 'نصائح' : 'Tips',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryColor, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              Text(isAr
                ? '• الكتابة بالعربية تشغّل صوت عربي تلقائياً\n• خفّض السرعة لفهم أفضل\n• يمكنك الصق ملخصات الـ AI مباشرة هنا'
                : '• App language controls the voice language\n• Lower speed for better comprehension\n• Paste AI summaries directly here',
                style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.6)),
            ]),
          ),
        ]),
      ),
    );
  }
}
