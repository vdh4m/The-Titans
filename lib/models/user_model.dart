class UserModel {
  final String uid, email, role, universityAr, universityEn, facultyAr, facultyEn;
  final String? fullName, fcmToken;
  final int? year;
  final bool isVerified;
  final DateTime createdAt;
  // Gamification
  final int streakDays;
  final int totalXP;
  final DateTime? lastStudyDate;
  final int streakFreezes;       // how many freezes available
  final int streakFreezeUsed;    // used this week
  // GPA
  final List<Map<String, dynamic>> grades;
  // Study Mood
  final String lastMood;         // 'tired' | 'normal' | 'energized'
  // Weekly XP snapshot (for report)
  final int weeklyXP;
  final String weeklyXPDate;     // ISO date of last reset
  // Badges earned (list of badge IDs)
  final List<String> earnedBadges;
  // Subscription
  final String planId;          // 'free' | 'plus' | 'pro'
  final DateTime? planExpiry;   // null = free forever
  final int aiUsesToday;        // reset daily
  final String aiUsesDate;      // ISO date of last reset
  final int flashcardDecks;     // count of created decks (for free limit)
  final int offlineFiles;       // count of downloaded files (for free limit)
  // Doctor: list of {uniAr, uniEn, facAr, facEn} teaching positions
  final List<Map<String, dynamic>> teachingAt;
  // Admin
  final bool isAdmin;

  UserModel({
    required this.uid, required this.email, required this.role,
    required this.universityAr, required this.universityEn,
    required this.facultyAr, required this.facultyEn,
    this.fullName, this.year, this.isVerified = false,
    this.fcmToken, required this.createdAt,
    this.streakDays = 0, this.totalXP = 0,
    this.lastStudyDate, this.grades = const [],
    this.streakFreezes = 1, this.streakFreezeUsed = 0,
    this.lastMood = 'normal',
    this.weeklyXP = 0, this.weeklyXPDate = '',
    this.earnedBadges = const [],
    this.planId = 'free',
    this.planExpiry,
    this.aiUsesToday = 0,
    this.aiUsesDate = '',
    this.flashcardDecks = 0,
    this.offlineFiles = 0,
    this.teachingAt = const [],
    this.isAdmin = false,
  });

  bool get isDoctor => role == 'doctor';
  bool get isPlus  => planId == 'plus' && (planExpiry == null || planExpiry!.isAfter(DateTime.now()));
  bool get isPro   => planId == 'pro'  && (planExpiry == null || planExpiry!.isAfter(DateTime.now()));
  bool get isPremium => isPlus || isPro;
  int  get aiDailyLimit => isPro ? 999 : isPlus ? 20 : 5;
  int  get maxDecks     => isPro ? 999 : isPlus ? 10 : 3;
  int  get maxOffline   => isPro ? 999 : isPlus ? 20 : 3;
  int  get maxStreakFreezes => isPro ? 999 : isPlus ? 3 : 1;
  bool get isStudent => role == 'student';
  bool get canUseStreakFreeze => streakFreezes > 0 && streakFreezeUsed == 0;

  double get gpa {
    if (grades.isEmpty) return 0.0;
    final total = grades.fold<double>(0, (sum, g) => sum + (g['grade'] as num? ?? 0));
    return total / grades.length;
  }

  Map<String, dynamic> toMap() => {
    'uid': uid, 'email': email, 'role': role,
    'universityAr': universityAr, 'universityEn': universityEn,
    'facultyAr': facultyAr, 'facultyEn': facultyEn,
    'fullName': fullName, 'year': year, 'isVerified': isVerified,
    'fcmToken': fcmToken, 'createdAt': createdAt.toIso8601String(),
    'streakDays': streakDays, 'totalXP': totalXP,
    'lastStudyDate': lastStudyDate?.toIso8601String(),
    'grades': grades,
    'streakFreezes': streakFreezes, 'streakFreezeUsed': streakFreezeUsed,
    'lastMood': lastMood,
    'weeklyXP': weeklyXP, 'weeklyXPDate': weeklyXPDate,
    'earnedBadges': earnedBadges,
    'planId': planId,
    'planExpiry': planExpiry?.toIso8601String(),
    'aiUsesToday': aiUsesToday,
    'aiUsesDate': aiUsesDate,
    'flashcardDecks': flashcardDecks,
    'offlineFiles': offlineFiles,
    'teachingAt': teachingAt,
    'isAdmin': isAdmin,
  };

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
    uid: m['uid'] ?? '', email: m['email'] ?? '', role: m['role'] ?? 'student',
    universityAr: m['universityAr'] ?? '', universityEn: m['universityEn'] ?? '',
    facultyAr: m['facultyAr'] ?? '', facultyEn: m['facultyEn'] ?? '',
    fullName: m['fullName'], year: m['year'],
    isVerified: m['isVerified'] ?? false, fcmToken: m['fcmToken'],
    createdAt: m['createdAt'] != null ? DateTime.parse(m['createdAt']) : DateTime.now(),
    streakDays: m['streakDays'] ?? 0, totalXP: m['totalXP'] ?? 0,
    lastStudyDate: m['lastStudyDate'] != null ? DateTime.tryParse(m['lastStudyDate']) : null,
    grades: _safeListOfMaps(m['grades']),
    streakFreezes: m['streakFreezes'] ?? 1,
    streakFreezeUsed: m['streakFreezeUsed'] ?? 0,
    lastMood: m['lastMood'] ?? 'normal',
    weeklyXP: m['weeklyXP'] ?? 0,
    weeklyXPDate: m['weeklyXPDate'] ?? '',
    earnedBadges: List<String>.from(m['earnedBadges'] ?? []),
    planId: m['planId'] ?? 'free',
    planExpiry: m['planExpiry'] != null ? DateTime.tryParse(m['planExpiry']) : null,
    aiUsesToday: m['aiUsesToday'] ?? 0,
    aiUsesDate: m['aiUsesDate'] ?? '',
    flashcardDecks: m['flashcardDecks'] ?? 0,
    offlineFiles: m['offlineFiles'] ?? 0,
    teachingAt: _safeListOfMaps(m['teachingAt']),
    isAdmin: m['isAdmin'] ?? false,
  );

  static List<Map<String, dynamic>> _safeListOfMaps(dynamic raw) {
    if (raw == null) return [];
    try {
      return (raw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) { return []; }
  }

  UserModel copyWith({
    String? uid, String? email, String? role,
    String? universityAr, String? universityEn, String? facultyAr, String? facultyEn,
    String? fullName, int? year, bool? isVerified, String? fcmToken, DateTime? createdAt,
    int? streakDays, int? totalXP, DateTime? lastStudyDate,
    List<Map<String, dynamic>>? grades,
    int? streakFreezes, int? streakFreezeUsed,
    String? lastMood, int? weeklyXP, String? weeklyXPDate,
    List<String>? earnedBadges,
    String? planId, DateTime? planExpiry,
    int? aiUsesToday, String? aiUsesDate,
    int? flashcardDecks, int? offlineFiles,
    List<Map<String, dynamic>>? teachingAt,
    bool? isAdmin,
  }) => UserModel(
    uid: uid ?? this.uid, email: email ?? this.email, role: role ?? this.role,
    universityAr: universityAr ?? this.universityAr, universityEn: universityEn ?? this.universityEn,
    facultyAr: facultyAr ?? this.facultyAr, facultyEn: facultyEn ?? this.facultyEn,
    fullName: fullName ?? this.fullName, year: year ?? this.year,
    isVerified: isVerified ?? this.isVerified, fcmToken: fcmToken ?? this.fcmToken,
    createdAt: createdAt ?? this.createdAt,
    streakDays: streakDays ?? this.streakDays, totalXP: totalXP ?? this.totalXP,
    lastStudyDate: lastStudyDate ?? this.lastStudyDate, grades: grades ?? this.grades,
    streakFreezes: streakFreezes ?? this.streakFreezes,
    streakFreezeUsed: streakFreezeUsed ?? this.streakFreezeUsed,
    lastMood: lastMood ?? this.lastMood,
    weeklyXP: weeklyXP ?? this.weeklyXP,
    weeklyXPDate: weeklyXPDate ?? this.weeklyXPDate,
    earnedBadges: earnedBadges ?? this.earnedBadges,
    planId: planId ?? this.planId,
    planExpiry: planExpiry ?? this.planExpiry,
    aiUsesToday: aiUsesToday ?? this.aiUsesToday,
    aiUsesDate: aiUsesDate ?? this.aiUsesDate,
    flashcardDecks: flashcardDecks ?? this.flashcardDecks,
    offlineFiles: offlineFiles ?? this.offlineFiles,
    teachingAt: teachingAt ?? this.teachingAt,
    isAdmin: isAdmin ?? this.isAdmin,
  );
}