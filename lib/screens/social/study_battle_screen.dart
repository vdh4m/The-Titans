import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
// ignore: unused_import
import '../../utils/xp_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  XP Awards in Study Battle:
//   +5  XP  per correct answer (instant, live)
//   +10 XP  for finishing the battle (participation — even if you lose)
//   +30 XP  for winning
//   +50 XP  for a perfect score (all 10 correct)
//   +15 XP  for a draw
// ─────────────────────────────────────────────────────────────────────────────
class StudyBattleScreen extends StatefulWidget {
  const StudyBattleScreen({super.key});
  @override State<StudyBattleScreen> createState() => _StudyBattleScreenState();
}

class _StudyBattleScreenState extends State<StudyBattleScreen> {
  static const _apiKey = 'AIzaSyBFYmfZC_D-4vwigPrOM0MiPYYEZb4UdBM';

  String? _battleId;
  String _phase = 'lobby'; // lobby | waiting | countdown | battle | result
  List<Map<String, dynamic>> _questions = [];
  int _currentQ       = 0;
  int _myScore        = 0;
  int _opponentScore  = 0;
  int _timeLeft       = 600; // 10 min
  Timer? _timer;
  int? _selectedAnswer;
  bool _answered      = false;
  String? _opponentEmail;
  StreamSubscription? _battleSub;

  // XP tracking
  int _xpEarnedThisBattle = 0;
  bool _xpAwarded         = false;

  @override
  void dispose() {
    _timer?.cancel();
    _battleSub?.cancel();
    if (_battleId != null && _phase != 'result') _leaveBattle();
    super.dispose();
  }

  Future<void> _leaveBattle() async {
    if (_battleId == null) return;
    await FirebaseFirestore.instance
        .collection('battles').doc(_battleId)
        .update({'status': 'abandoned'}).catchError((_) {});
  }

  String get _uid   => context.read<AuthProvider>().currentUser?.uid   ?? '';
  // ignore: unused_element
  String get _email => context.read<AuthProvider>().currentUser?.email ?? '';

  // ── Find / create battle ──────────────────────────────────────────────────
  Future<void> _findOpponent() async {
    final user = context.read<AuthProvider>().currentUser;
    final isAr = context.read<AppProvider>().isArabic;
    if (user == null) return;
    setState(() => _phase = 'waiting');

    final open = await FirebaseFirestore.instance.collection('battles')
        .where('status', isEqualTo: 'waiting')
        .where('facultyAr', isEqualTo: user.facultyAr)
        .get();

    if (open.docs.isNotEmpty) {
      final doc = open.docs.first;
      _battleId = doc.id;
      final hostEmail = doc.data()['hostEmail'] as String? ?? '';
      await doc.reference.update({
        'player2':      user.uid,
        'player2Email': user.email,
        'status':       'countdown',
      });
      setState(() => _opponentEmail = hostEmail);
      _listenBattle(isAr);
    } else {
      _battleId = const Uuid().v4();
      await FirebaseFirestore.instance.collection('battles').doc(_battleId).set({
        'id':          _battleId,
        'hostId':      user.uid,
        'hostEmail':   user.email,
        'player2':     null,
        'player2Email': null,
        'facultyAr':   user.facultyAr,
        'universityAr': user.universityAr,
        'status':      'waiting',
        'questions':   [],
        'scores':      {user.uid: 0},
        'createdAt':   DateTime.now().toIso8601String(),
      });
      _listenBattle(isAr);
    }
  }

  // ── Listen to battle ──────────────────────────────────────────────────────
  void _listenBattle(bool isAr) {
    _battleSub = FirebaseFirestore.instance
        .collection('battles').doc(_battleId)
        .snapshots().listen((snap) async {
      if (!snap.exists || !mounted) return;
      final data   = snap.data()!;
      final status = data['status'] as String?;
      final user   = context.read<AuthProvider>().currentUser;

      if (status == 'countdown' && _phase == 'waiting') {
        setState(() {
          _opponentEmail = data[user?.uid == data['hostId']
              ? 'player2Email' : 'hostEmail'] as String?;
        });
        if (user?.uid == data['hostId'] &&
            (data['questions'] as List?)?.isEmpty != false) {
          final qs = await _generateQuestions(
              isAr, user?.facultyEn ?? 'Science');
          await FirebaseFirestore.instance
              .collection('battles').doc(_battleId)
              .update({'questions': qs, 'status': 'battle'});
        }
        setState(() => _phase = 'countdown');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _phase = 'battle');
        });
      }

      if (status == 'battle' && _phase == 'countdown') {
        final qs = List<Map<String, dynamic>>.from(data['questions'] ?? []);
        setState(() { _questions = qs; _phase = 'battle'; });
        _startTimer();
      }

      if (status == 'battle') {
        final scores = Map<String, dynamic>.from(data['scores'] ?? {});
        final oppId  = user?.uid == data['hostId']
            ? data['player2'] as String?
            : data['hostId'] as String?;
        if (oppId != null) {
          setState(() => _opponentScore = (scores[oppId] as int?) ?? 0);
        }
      }

      if (status == 'finished' && _phase == 'battle') {
        _timer?.cancel();
        setState(() => _phase = 'result');
        await _awardEndXP();
      }
    });
  }

  // ── Generate questions ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _generateQuestions(
      bool isAr, String faculty) async {
    final prompt = isAr
        ? 'اعمل 10 أسئلة اختيار متعدد سريعة لطالب كلية $faculty. أجب بـ JSON فقط: [{"q":"...","options":["أ","ب","ج","د"],"correct":0}, ...]'
        : 'Create 10 quick MCQ for a $faculty student. JSON only: [{"q":"...","options":["A","B","C","D"],"correct":0}, ...]';
    try {
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.6, 'maxOutputTokens': 1500},
        }),
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        var text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '[]';
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return List<Map<String, dynamic>>.from(jsonDecode(text));
      }
    } catch (_) {}
    return [];
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) { t.cancel(); return; }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0 || _currentQ >= _questions.length) {
        t.cancel();
        await FirebaseFirestore.instance
            .collection('battles').doc(_battleId)
            .update({'status': 'finished'});
        if (mounted) {
          setState(() => _phase = 'result');
          await _awardEndXP();
        }
      }
    });
  }

  // ── Answer a question — awards +5 XP per correct answer live ─────────────
  Future<void> _answer(int idx) async {
    if (_answered || _currentQ >= _questions.length) return;
    final correct   = _questions[_currentQ]['correct'] as int? ?? 0;
    final isCorrect = idx == correct;

    setState(() {
      _selectedAnswer = idx;
      _answered       = true;
      if (isCorrect) _myScore++;
    });

    // ── +5 XP per correct answer (awarded immediately) ──────────────────────
    if (isCorrect) {
      const xpPerCorrect = 5;
      _xpEarnedThisBattle += xpPerCorrect;
      await FirebaseFirestore.instance
          .collection('users').doc(_uid).update({
        'totalXP':  FieldValue.increment(xpPerCorrect),
        'weeklyXP': FieldValue.increment(xpPerCorrect),
      });
    }

    await FirebaseFirestore.instance
        .collection('battles').doc(_battleId)
        .update({'scores.$_uid': _myScore});

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _currentQ++;
      _selectedAnswer = null;
      _answered       = false;
    });

    if (_currentQ >= _questions.length) {
      _timer?.cancel();
      await FirebaseFirestore.instance
          .collection('battles').doc(_battleId)
          .update({'status': 'finished'});
      if (mounted) {
        setState(() => _phase = 'result');
        await _awardEndXP();
      }
    }
  }

  // ── End-of-battle XP ─────────────────────────────────────────────────────
  Future<void> _awardEndXP() async {
    if (_xpAwarded) return;
    _xpAwarded = true;

    final total    = _questions.length;
    final iWon     = _myScore > _opponentScore;
    final isDraw   = _myScore == _opponentScore;
    final isPerfect = _myScore == total && total > 0;

    int bonus = 0;

    // +10 XP participation (always)
    bonus += 10;

    if (isPerfect) {
      // +50 XP perfect score
      bonus += 50;
    } else if (iWon) {
      // +30 XP win
      bonus += 30;
    } else if (isDraw) {
      // +15 XP draw
      bonus += 15;
    }

    _xpEarnedThisBattle += bonus;

    if (bonus > 0 && _uid.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users').doc(_uid).update({
        'totalXP':  FieldValue.increment(bonus),
        'weeklyXP': FieldValue.increment(bonus),
      });
    }

    // Badge checks
    if (iWon) await _tryBadge('top_3');
    if (isPerfect) await _tryBadge('quiz_master');
    if (mounted) setState(() {}); // refresh result screen with XP earned
  }

  Future<void> _tryBadge(String id) async {
    if (_uid.isEmpty) return;
    await FirebaseFirestore.instance.collection('users').doc(_uid).update({
      'earnedBadges': FieldValue.arrayUnion([id]),
    }).catchError((_) {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'تحدي دراسي' : 'Study Battle'),
        backgroundColor: const Color(0xFF0A0A0F),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF0A0A0F),
      body: _buildBody(isAr),
    );
  }

  Widget _buildBody(bool isAr) {
    switch (_phase) {
      case 'lobby':
        return _LobbyView(isAr: isAr, onFind: _findOpponent);
      case 'waiting':
        return const _WaitingView(isAr: true);
      case 'countdown':
        return _CountdownView(isAr: isAr, opponent: _opponentEmail ?? '?');
      case 'battle':
        return _BattleView(
          isAr: isAr,
          questions: _questions,
          currentQ: _currentQ,
          myScore: _myScore,
          oppScore: _opponentScore,
          timeLeft: _timeLeft,
          selectedAnswer: _selectedAnswer,
          answered: _answered,
          onAnswer: _answer,
        );
      case 'result':
        return _ResultView(
          isAr: isAr,
          myScore: _myScore,
          oppScore: _opponentScore,
          total: _questions.length,
          opponent: _opponentEmail ?? '?',
          xpEarned: _xpEarnedThisBattle,
        );
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Lobby
// ─────────────────────────────────────────────────────────────────────────────
class _LobbyView extends StatelessWidget {
  final bool isAr; final VoidCallback onFind;
  const _LobbyView({required this.isAr, required this.onFind});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚔️', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 16),
        Text(isAr ? 'تحدي دراسي' : 'Study Battle',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w900, fontSize: 28)),
        const SizedBox(height: 8),
        Text(
          isAr
              ? '10 أسئلة • 10 دقائق\nمين أسرع وأصح؟\n\n'
                '+5 XP لكل إجابة صحيحة\n'
                '+30 XP للفوز • +50 XP للنتيجة الكاملة'
              : '10 questions • 10 minutes\nWho\'s faster & smarter?\n\n'
                '+5 XP per correct answer\n'
                '+30 XP for winning • +50 XP for perfect score',
          style: const TextStyle(color: Colors.white60, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: onFind,
          icon: const Icon(Icons.search_rounded),
          label: Text(isAr ? 'ابحث عن خصم' : 'Find Opponent'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(240, 56),
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Waiting
// ─────────────────────────────────────────────────────────────────────────────
class _WaitingView extends StatelessWidget {
  final bool isAr;
  const _WaitingView({required this.isAr});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const SizedBox(width: 60, height: 60,
        child: CircularProgressIndicator(
            strokeWidth: 3, color: AppTheme.primaryColor)),
    const SizedBox(height: 24),
    Text(isAr ? 'جاري البحث عن خصم...' : 'Searching for opponent...',
        style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w700, fontSize: 18)),
    const SizedBox(height: 8),
    Text(
      isAr
          ? 'سيبدأ التحدي تلقائياً عند وجود لاعب آخر'
          : 'Battle starts automatically when a player joins',
      style: const TextStyle(color: Colors.white60),
      textAlign: TextAlign.center,
    ),
  ]));
}

// ─────────────────────────────────────────────────────────────────────────────
//  Countdown
// ─────────────────────────────────────────────────────────────────────────────
class _CountdownView extends StatelessWidget {
  final bool isAr; final String opponent;
  const _CountdownView({required this.isAr, required this.opponent});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Text(isAr ? 'وجدنا خصم!' : 'Opponent found!',
        style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w900, fontSize: 24)),
    const SizedBox(height: 8),
    Text(opponent.split('@').first,
        style: const TextStyle(color: AppTheme.primaryColor,
            fontWeight: FontWeight.w700, fontSize: 18)),
    const SizedBox(height: 24),
    const Text('⚔️', style: TextStyle(fontSize: 64)),
    const SizedBox(height: 24),
    Text(isAr ? 'التحدي يبدأ الآن...' : 'Battle starting now...',
        style: const TextStyle(color: Colors.white60, fontSize: 16)),
    const SizedBox(height: 20),
    const CircularProgressIndicator(color: Colors.red),
  ]));
}

// ─────────────────────────────────────────────────────────────────────────────
//  Battle view
// ─────────────────────────────────────────────────────────────────────────────
class _BattleView extends StatelessWidget {
  final bool isAr, answered;
  final List<Map<String, dynamic>> questions;
  final int currentQ, myScore, oppScore, timeLeft;
  final int? selectedAnswer;
  final Future<void> Function(int) onAnswer;
  const _BattleView({
    required this.isAr, required this.questions, required this.currentQ,
    required this.myScore, required this.oppScore, required this.timeLeft,
    required this.selectedAnswer, required this.answered,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    if (currentQ >= questions.length) {
      return Center(child: Text(
          isAr ? 'انتهت الأسئلة...' : 'Loading...',
          style: const TextStyle(color: Colors.white)));
    }
    final q    = questions[currentQ];
    final mins = timeLeft ~/ 60;
    final secs = timeLeft % 60;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── Scoreboard ────────────────────────────────────────────
        Row(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(isAr ? 'أنت' : 'You',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
              Text('$myScore', style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w900, fontSize: 28)),
            ]),
          )),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: timeLeft < 60
                  ? Colors.red.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$mins:${secs.toString().padLeft(2, '0')}',
              style: TextStyle(
                  color: timeLeft < 60 ? Colors.red : Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
          Expanded(child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(isAr ? 'خصمك' : 'Opponent',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
              Text('$oppScore', style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w900, fontSize: 28)),
            ]),
          )),
        ]),
        const SizedBox(height: 12),

        // ── Progress ──────────────────────────────────────────────
        LinearProgressIndicator(
          value: questions.isEmpty ? 0 : currentQ / questions.length,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
          minHeight: 4,
        ),
        Text('${currentQ + 1}/${questions.length}',
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 16),

        // ── Question ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16)),
          child: Text(q['q'] as String? ?? '',
              style: const TextStyle(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w600, height: 1.5)),
        ),
        const SizedBox(height: 14),

        // ── Options ───────────────────────────────────────────────
        ...((q['options'] as List?) ?? []).asMap().entries.map((e) {
          final i       = e.key;
          final opt     = e.value as String;
          final correct = q['correct'] as int? ?? 0;

          Color bg = const Color(0xFF1A1A2E);
          Color border = Colors.white12;
          if (answered) {
            if (i == correct) {
              bg = const Color(0xFF06D6A0).withOpacity(0.2);
              border = const Color(0xFF06D6A0);
            } else if (i == selectedAnswer) {
              bg = Colors.red.withOpacity(0.2);
              border = Colors.red;
            }
          }
          return GestureDetector(
            onTap: () => onAnswer(i),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border)),
              child: Row(children: [
                Container(
                  width: 26, height: 26,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.white12),
                  child: Center(child: Text(
                    String.fromCharCode(65 + i),
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 12),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(opt,
                    style: const TextStyle(color: Colors.white, fontSize: 13))),
                // XP hint on correct answer reveal
                if (answered && i == correct)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Text('+5 XP',
                        style: TextStyle(color: Color(0xFFFF9F1C),
                            fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Result view — shows XP breakdown
// ─────────────────────────────────────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  final bool isAr;
  final int myScore, oppScore, total, xpEarned;
  final String opponent;
  const _ResultView({
    required this.isAr, required this.myScore, required this.oppScore,
    required this.total, required this.opponent, required this.xpEarned,
  });

  @override
  Widget build(BuildContext context) {
    final iWon      = myScore > oppScore;
    final isDraw    = myScore == oppScore;
    final isPerfect = myScore == total && total > 0;

    // XP breakdown
    final correctXP = myScore * 5;
    final int bonusXP;
    final String bonusLabel;
    if (isPerfect) {
      bonusXP   = 50 + 10;
      bonusLabel = isAr ? '🎯 نتيجة كاملة!' : '🎯 Perfect Score!';
    } else if (iWon) {
      bonusXP   = 30 + 10;
      bonusLabel = isAr ? '🏆 فزت!' : '🏆 Winner!';
    } else if (isDraw) {
      bonusXP   = 15 + 10;
      bonusLabel = isAr ? '🤝 تعادل' : '🤝 Draw';
    } else {
      bonusXP   = 10;
      bonusLabel = isAr ? '💪 شاركت' : '💪 Participated';
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 20),
          Text(
            isPerfect ? '🏆' : isDraw ? '🤝' : iWon ? '🥇' : '😅',
            style: const TextStyle(fontSize: 72),
          ),
          const SizedBox(height: 12),
          Text(
            isPerfect
                ? (isAr ? 'نتيجة مثالية! 🎯' : 'Perfect Score! 🎯')
                : isDraw
                    ? (isAr ? 'تعادل!' : 'Draw!')
                    : iWon
                        ? (isAr ? 'فزت! 🎉' : 'You Won! 🎉')
                        : (isAr ? 'خسرت هذه المرة' : 'You Lost This Time'),
            style: TextStyle(
              color: isPerfect
                  ? const Color(0xFFFF9F1C)
                  : isDraw
                      ? Colors.white
                      : iWon
                          ? const Color(0xFFFF9F1C)
                          : Colors.red,
              fontWeight: FontWeight.w900, fontSize: 26,
            ),
          ),
          const SizedBox(height: 24),

          // ── Score comparison ────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Column(children: [
              Text('$myScore/$total',
                  style: const TextStyle(color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w900, fontSize: 36)),
              Text(isAr ? 'نتيجتك' : 'Your Score',
                  style: const TextStyle(color: Colors.white60)),
            ]),
            const Text('vs',
                style: TextStyle(color: Colors.white38, fontSize: 20)),
            Column(children: [
              Text('$oppScore/$total',
                  style: const TextStyle(color: Colors.red,
                      fontWeight: FontWeight.w900, fontSize: 36)),
              Text(opponent.split('@').first,
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 28),

          // ── XP breakdown card ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0xFFFF9F1C).withOpacity(0.4)),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('⚡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(isAr ? 'XP المكتسبة' : 'XP Earned',
                    style: const TextStyle(color: Color(0xFFFF9F1C),
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              const SizedBox(height: 12),
              // Correct answers row
              _xpRow(
                isAr ? '$myScore إجابة × 5 XP' : '$myScore correct × 5 XP',
                '+$correctXP XP',
              ),
              const SizedBox(height: 6),
              // Bonus row
              _xpRow(bonusLabel, '+$bonusXP XP'),
              const Divider(color: Colors.white12, height: 20),
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isAr ? 'المجموع' : 'Total',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('+${correctXP + bonusXP} XP',
                      style: const TextStyle(
                          color: Color(0xFFFF9F1C),
                          fontWeight: FontWeight.w900, fontSize: 20)),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 28),

          // ── Play again ─────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.replay_rounded),
            label: Text(isAr ? 'تحدي جديد' : 'New Battle'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 50),
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _xpRow(String label, String xp) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
      Text(xp, style: const TextStyle(color: Color(0xFFFF9F1C),
          fontWeight: FontWeight.w700, fontSize: 13)),
    ],
  );
}