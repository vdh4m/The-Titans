import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:studyhub/generated/l10n/app_localizations.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../payment/paywall_gate.dart';

class _Msg {
  final String text;
  final bool isUser;
  final DateTime time;
  _Msg({required this.text, required this.isUser, required this.time});
}

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});
  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _msgs = [];
  final List<Map<String, dynamic>> _history = [];
  bool _loading = false;

  // ← ضع الـ API Key هنا
  static const _apiKey = 'AIzaSyBFYmfZC_D-4vwigPrOM0MiPYYEZb4UdBM';

  static const _systemPrompt =
      'أنت مساعد تعليمي ذكي للطلاب والأساتذة في الجامعات المصرية. '
      'ساعد في شرح المواد الدراسية والإجابة على الأسئلة الأكاديمية. '
      'أجب باللغة التي يستخدمها المستخدم (عربي أو إنجليزي). '
      'كن موجزاً ومفيداً وودوداً.';

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    // ── Paywall check ─────────────────────────────────────────────────────
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && !PaywallGate.canAccess(user, PremiumFeature.unlimitedAi)) {
      PaywallGate.showUpgradeSheet(context, feature: PremiumFeature.unlimitedAi);
      return;
    }

    setState(() {
      _msgs.add(_Msg(text: text, isUser: true, time: DateTime.now()));
      _loading = true;
    });
    _msgCtrl.clear();
    _scrollDown();

    // build history for context
    _history.add({'role': 'user', 'parts': [{'text': text}]});

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey',
      );

      final body = jsonEncode({
        'system_instruction': {
          'parts': [{'text': _systemPrompt}]
        },
        'contents': _history,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1024,
        },
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        _history.add({'role': 'model', 'parts': [{'text': reply}]});
        setState(() {
          _msgs.add(_Msg(text: reply, isUser: false, time: DateTime.now()));
          _loading = false;
        });
      } else {
        final err = jsonDecode(response.body);
        final errMsg = err['error']?['message'] ?? 'Status ${response.statusCode}';
        _addError(errMsg);
      }
    } catch (e) {
      _addError(e.toString());
    }

    _scrollDown();
  }

  void _addError(String msg) {
    if (_history.isNotEmpty && _history.last['role'] == 'user') {
      _history.removeLast();
    }
    setState(() {
      _msgs.add(_Msg(text: '⚠️ $msg', isUser: false, time: DateTime.now()));
      _loading = false;
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = context.watch<AppProvider>().isArabic;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Text(l10n.aiAssistant),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() { _msgs.clear(); _history.clear(); }),
            color: Colors.grey,
          ),
        ],
      ),
      body: Column(children: [
        if (_msgs.isEmpty)
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 50),
            ),
            const SizedBox(height: 20),
            Text(
              isAr ? 'مرحباً! كيف يمكنني مساعدتك؟' : 'Hi! How can I help you?',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isAr ? 'اسألني أي شيء عن دراستك' : 'Ask me anything about your studies',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Chip(label: isAr ? 'اشرح قانون نيوتن' : 'Explain Newton\'s law',
                onTap: () { _msgCtrl.text = isAr ? 'اشرح قانون نيوتن' : 'Explain Newton\'s law'; _send(); }),
              _Chip(label: isAr ? 'كيف أذاكر بكفاءة؟' : 'Study tips?',
                onTap: () { _msgCtrl.text = isAr ? 'كيف أذاكر بكفاءة؟' : 'Give me study tips'; _send(); }),
              _Chip(label: isAr ? 'لخص الخلية الحية' : 'Summarize the cell',
                onTap: () { _msgCtrl.text = isAr ? 'لخص الخلية الحية' : 'Summarize the living cell'; _send(); }),
            ]),
          ])))
        else
          Expanded(child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _msgs.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _msgs.length) return const _Typing();
              return _Bubble(msg: _msgs[i]);
            },
          )),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3))],
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                decoration: InputDecoration(hintText: l10n.askAI),
                maxLines: null,
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _loading ? null : _send,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: _loading ? null : const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
                  color: _loading ? Colors.grey[300] : null,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send_rounded, color: _loading ? Colors.grey : Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _Chip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Text(label, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
    ),
  );
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  const _Bubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: msg.isUser ? AppTheme.primaryColor : theme.cardTheme.color,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: msg.isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight: msg.isUser ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Text(msg.text, style: TextStyle(color: msg.isUser ? Colors.white : null, height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16),
          ),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          _Dot(0), SizedBox(width: 4), _Dot(200), SizedBox(width: 4), _Dot(400),
        ]),
      ),
    ]),
  );
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot(this.delay);
  @override State<_Dot> createState() => _DotState();
}
class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _c.forward(); });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(
      width: 8, height: 8 + _a.value * 6,
      decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
    ),
  );
}