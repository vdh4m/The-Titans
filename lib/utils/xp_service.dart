import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  XpService — Central place for all XP awards across the app
//  Call XpService.award(uid, event) from anywhere
// ─────────────────────────────────────────────────────────────────────────────
enum XpEvent {
  studyMinute,         // 1  XP  — per minute of studying (handled by StudyProvider)
  dailyChallengeRight, // 50 XP  — correct daily challenge answer
  dailyChallengeWrong, // 10 XP  — attempted daily challenge
  uploadMaterial,      // 15 XP  — uploaded a file to a course
  createFlashcard,     //  2 XP  — created a flashcard
  createDeck,          //  5 XP  — created a flashcard deck
  joinGroup,           // 10 XP  — joined a study group
  sendMessage,         //  1 XP  — sent a message in group chat (max 20/day)
  postCommunity,       //  5 XP  — posted in community
  receiveUpvote,       //  3 XP  — someone upvoted your post
  completePomodoro,    //  5 XP  — completed a pomodoro session
  updateGpa,           // 10 XP  — updated GPA tracker
  useAiTool,           //  5 XP  — used an AI feature (quiz gen, summarizer, etc.)
  createSideCourse,    // 20 XP  — created a side course
  perfectWeekStreak,   // 100 XP — 7 day streak achieved
  firstLogin,          // 25 XP  — first time opening the app
}

class XpService {
  static final _db = FirebaseFirestore.instance;

  static const Map<XpEvent, int> _values = {
    XpEvent.studyMinute:         1,
    XpEvent.dailyChallengeRight: 50,
    XpEvent.dailyChallengeWrong: 10,
    XpEvent.uploadMaterial:      15,
    XpEvent.createFlashcard:     2,
    XpEvent.createDeck:          5,
    XpEvent.joinGroup:           10,
    XpEvent.sendMessage:         1,
    XpEvent.postCommunity:       5,
    XpEvent.receiveUpvote:       3,
    XpEvent.completePomodoro:    5,
    XpEvent.updateGpa:           10,
    XpEvent.useAiTool:           5,
    XpEvent.createSideCourse:    20,
    XpEvent.perfectWeekStreak:   100,
    XpEvent.firstLogin:          25,
  };

  static const Map<XpEvent, String> labelAr = {
    XpEvent.studyMinute:         'دقيقة مذاكرة',
    XpEvent.dailyChallengeRight: 'إجابة صحيحة في التحدي اليومي',
    XpEvent.dailyChallengeWrong: 'محاولة في التحدي اليومي',
    XpEvent.uploadMaterial:      'رفع ملف دراسي',
    XpEvent.createFlashcard:     'إنشاء فلاش كارد',
    XpEvent.createDeck:          'إنشاء مجموعة فلاش كارد',
    XpEvent.joinGroup:           'الانضمام لمجموعة دراسية',
    XpEvent.sendMessage:         'إرسال رسالة في المجموعة',
    XpEvent.postCommunity:       'نشر في المجتمع',
    XpEvent.receiveUpvote:       'تلقي تصويت على مشاركتك',
    XpEvent.completePomodoro:    'إتمام جلسة بومودورو',
    XpEvent.updateGpa:           'تحديث متابعة الدرجات',
    XpEvent.useAiTool:           'استخدام أداة الذكاء الاصطناعي',
    XpEvent.createSideCourse:    'إنشاء مادة جانبية',
    XpEvent.perfectWeekStreak:   'أسبوع مذاكرة متكامل',
    XpEvent.firstLogin:          'أول تسجيل دخول',
  };

  static const Map<XpEvent, String> labelEn = {
    XpEvent.studyMinute:         'Study minute',
    XpEvent.dailyChallengeRight: 'Daily challenge correct answer',
    XpEvent.dailyChallengeWrong: 'Daily challenge attempt',
    XpEvent.uploadMaterial:      'Uploaded study material',
    XpEvent.createFlashcard:     'Created a flashcard',
    XpEvent.createDeck:          'Created a flashcard deck',
    XpEvent.joinGroup:           'Joined a study group',
    XpEvent.sendMessage:         'Sent a group message',
    XpEvent.postCommunity:       'Posted in community',
    XpEvent.receiveUpvote:       'Received an upvote',
    XpEvent.completePomodoro:    'Completed a Pomodoro session',
    XpEvent.updateGpa:           'Updated GPA tracker',
    XpEvent.useAiTool:           'Used an AI tool',
    XpEvent.createSideCourse:    'Created a side course',
    XpEvent.perfectWeekStreak:   'Perfect week streak',
    XpEvent.firstLogin:          'First login',
  };

  /// Award XP to a user for a given event.
  /// Returns the amount awarded (0 if uid is null).
  static Future<int> award(String? uid, XpEvent event) async {
    if (uid == null) return 0;
    final amount = _values[event] ?? 0;
    if (amount == 0) return 0;
    try {
      await _db.collection('users').doc(uid).update({
        'totalXP':  FieldValue.increment(amount),
        'weeklyXP': FieldValue.increment(amount),
      });
    } catch (_) {}
    return amount;
  }

  /// Get XP value for an event without awarding
  static int valueOf(XpEvent event) => _values[event] ?? 0;
}