import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/course_model.dart';

enum StudyMode { normal, pomodoro }
enum PomodoroPhase { work, shortBreak, longBreak }

class StudyProvider extends ChangeNotifier {
  Timer? _timer;
  Timer? _xpTimer;          // fires every 60 s to award 1 XP
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  CourseModel? _currentCourse;
  final Map<String, int> _courseProgress = {};
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;

  // Pomodoro
  StudyMode _studyMode = StudyMode.normal;
  PomodoroPhase _pomodoroPhase = PomodoroPhase.work;
  int _pomodoroRound = 0;
  int _pomodoroSecondsLeft = 25 * 60;
  static const _workDuration = 25 * 60;
  static const _shortBreak = 5 * 60;
  static const _longBreak = 15 * 60;

  bool get isRunning => _isRunning;
  int get elapsedSeconds => _elapsedSeconds;
  CourseModel? get currentCourse => _currentCourse;
  Map<String, int> get courseProgress => _courseProgress;
  StudyMode get studyMode => _studyMode;
  PomodoroPhase get pomodoroPhase => _pomodoroPhase;
  int get pomodoroRound => _pomodoroRound;
  int get pomodoroSecondsLeft => _pomodoroSecondsLeft;
  bool get isPomodoro => _studyMode == StudyMode.pomodoro;

  String get formattedTime {
    if (isPomodoro) {
      final m = _pomodoroSecondsLeft ~/ 60;
      final s = _pomodoroSecondsLeft % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get pomodoroProgress {
    final total = _pomodoroPhase == PomodoroPhase.work ? _workDuration
        : _pomodoroPhase == PomodoroPhase.shortBreak ? _shortBreak : _longBreak;
    return 1 - (_pomodoroSecondsLeft / total);
  }

  double getProgressForCourse(String courseId) {
    final seconds = _courseProgress[courseId] ?? 0;
    return ((seconds / 1800) * 0.05).clamp(0.0, 1.0);
  }

  void setUserId(String uid) { _userId = uid; _loadProgress(); }

  Future<void> _loadProgress() async {
    if (_userId == null) return;
    try {
      final snap = await _db.collection('study_progress').where('userId', isEqualTo: _userId).get();
      for (final doc in snap.docs) {
        final d = doc.data();
        _courseProgress[d['courseId']] = (_courseProgress[d['courseId']] ?? 0) + (d['durationSeconds'] as int? ?? 0);
      }
      notifyListeners();
    } catch (_) {}
  }

  void setStudyMode(StudyMode mode) {
    _studyMode = mode;
    if (mode == StudyMode.pomodoro) {
      _pomodoroPhase = PomodoroPhase.work;
      _pomodoroSecondsLeft = _workDuration;
      _pomodoroRound = 0;
    }
    notifyListeners();
  }

  void startStudy(CourseModel course) {
    _currentCourse = course;
    _isRunning = true;
    _elapsedSeconds = 0;

    if (isPomodoro) {
      _pomodoroPhase = PomodoroPhase.work;
      _pomodoroSecondsLeft = _workDuration;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tickPomodoro());
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsedSeconds++;
        notifyListeners();
      });
    }

    // ── 1 XP every minute while studying ─────────────────────────────────────
    _xpTimer = Timer.periodic(const Duration(minutes: 1), (_) => _awardMinuteXP());

    notifyListeners();
  }

  /// Awards 1 XP per minute of active study to Firestore immediately
  Future<void> _awardMinuteXP() async {
    if (_userId == null || _currentCourse == null) return;
    try {
      await _db.collection('users').doc(_userId).update({
        'totalXP':  FieldValue.increment(1),
        'weeklyXP': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('XP per minute error: $e');
    }
  }

  void _tickPomodoro() {
    _elapsedSeconds++;
    _pomodoroSecondsLeft--;
    if (_pomodoroSecondsLeft <= 0) {
      if (_pomodoroPhase == PomodoroPhase.work) {
        _pomodoroRound++;
        // +5 XP for each completed pomodoro work session
        if (_userId != null) {
          _db.collection('users').doc(_userId).update({
            'totalXP':       FieldValue.increment(5),
            'weeklyXP':      FieldValue.increment(5),
            'pomodoroCount': FieldValue.increment(1),
          }).catchError((_) {});
        }
        _pomodoroPhase = _pomodoroRound % 4 == 0 ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
        _pomodoroSecondsLeft = _pomodoroPhase == PomodoroPhase.longBreak ? _longBreak : _shortBreak;
      } else {
        _pomodoroPhase = PomodoroPhase.work;
        _pomodoroSecondsLeft = _workDuration;
      }
    }
    notifyListeners();
  }

  void pauseStudy() {
    _timer?.cancel();
    _xpTimer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void resumeStudy() {
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isPomodoro) {
        _tickPomodoro();
      } else { _elapsedSeconds++; notifyListeners(); }
    });
    _xpTimer = Timer.periodic(const Duration(minutes: 1), (_) => _awardMinuteXP());
    notifyListeners();
  }

  Future<void> stopStudy() async {
    _timer?.cancel();
    _xpTimer?.cancel();
    _isRunning = false;

    if (_currentCourse != null && _userId != null && _elapsedSeconds > 0) {
      final session = StudySession(
        id: const Uuid().v4(), userId: _userId!, courseId: _currentCourse!.id,
        courseTitleAr: _currentCourse!.titleAr, courseTitleEn: _currentCourse!.titleEn,
        durationSeconds: _elapsedSeconds, date: DateTime.now(),
      );
      await _db.collection('study_progress').doc(session.id).set(session.toMap());
      _courseProgress[_currentCourse!.id] = (_courseProgress[_currentCourse!.id] ?? 0) + _elapsedSeconds;

      // Streak + badge check (no extra XP here — XP is already awarded per minute live)
      await _updateStreakAndBadges(_elapsedSeconds);
    }

    _elapsedSeconds = 0;
    _currentCourse = null;
    _pomodoroPhase = PomodoroPhase.work;
    _pomodoroSecondsLeft = _workDuration;
    notifyListeners();
  }

  Future<void> _updateStreakAndBadges(int seconds) async {
    if (_userId == null) return;
    try {
      final userRef = _db.collection('users').doc(_userId);
      final doc = await userRef.get();
      final data = doc.data() ?? {};
      final lastStudy = data['lastStudyDate'] != null
          ? DateTime.tryParse(data['lastStudyDate'])
          : null;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int streak = data['streakDays'] ?? 0;
      if (lastStudy != null) {
        final lastDay = DateTime(lastStudy.year, lastStudy.month, lastStudy.day);
        final diff = today.difference(lastDay).inDays;
        if (diff == 1) {
          streak++;
        } else if (diff > 1) streak = 1;
      } else {
        streak = 1;
      }

      final totalXP = (data['totalXP'] as int? ?? 0);

      // ── Badge awards ──────────────────────────────────────────────────────
      final earned = List<String>.from(data['earnedBadges'] ?? []);
      final toAdd   = <String>[];

      void tryBadge(String id, bool condition) {
        if (condition && !earned.contains(id)) toAdd.add(id);
      }

      // Streak badges
      tryBadge('first_study', true);           // always on first/any session
      tryBadge('streak_3',  streak >= 3);
      tryBadge('streak_7',  streak >= 7);
      tryBadge('streak_14', streak >= 14);
      tryBadge('streak_30', streak >= 30);
      tryBadge('streak_90', streak >= 90);

      // XP badges (after this session XP already credited per minute)
      tryBadge('xp_100',   totalXP >= 100);
      tryBadge('xp_500',   totalXP >= 500);
      tryBadge('xp_1000',  totalXP >= 1000);
      tryBadge('xp_2000',  totalXP >= 2000);
      tryBadge('xp_5000',  totalXP >= 5000);
      tryBadge('xp_10000', totalXP >= 10000);

      // Habit badges
      final hour = now.hour;
      tryBadge('night_owl',  hour >= 22 || hour < 4);
      tryBadge('early_bird', hour >= 5  && hour < 8);

      final updates = <String, dynamic>{
        'streakDays':    streak,
        'lastStudyDate': now.toIso8601String(),
        if (toAdd.isNotEmpty)
          'earnedBadges': FieldValue.arrayUnion(toAdd),
      };
      await userRef.update(updates);
    } catch (e) {
      debugPrint('Streak/badge update error: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _xpTimer?.cancel();
    super.dispose();
  }
}