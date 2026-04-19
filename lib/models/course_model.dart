class CourseModel {
  final String id, titleAr, titleEn, doctorId, doctorName;
  final String universityAr, universityEn, facultyAr, facultyEn, type;
  final int year;
  final DateTime createdAt;

  CourseModel({required this.id, required this.titleAr, required this.titleEn,
    required this.doctorId, required this.doctorName,
    required this.universityAr, required this.universityEn,
    required this.facultyAr, required this.facultyEn,
    required this.year, required this.type, required this.createdAt});

  Map<String, dynamic> toMap() => {
    'id': id, 'titleAr': titleAr, 'titleEn': titleEn,
    'doctorId': doctorId, 'doctorName': doctorName,
    'universityAr': universityAr, 'universityEn': universityEn,
    'facultyAr': facultyAr, 'facultyEn': facultyEn,
    'year': year, 'type': type, 'createdAt': createdAt.toIso8601String(),
  };

  factory CourseModel.fromMap(Map<String, dynamic> m) => CourseModel(
    id: m['id'] ?? '', titleAr: m['titleAr'] ?? '', titleEn: m['titleEn'] ?? '',
    doctorId: m['doctorId'] ?? '', doctorName: m['doctorName'] ?? '',
    universityAr: m['universityAr'] ?? '', universityEn: m['universityEn'] ?? '',
    facultyAr: m['facultyAr'] ?? '', facultyEn: m['facultyEn'] ?? '',
    year: m['year'] ?? 1, type: m['type'] ?? 'main',
    createdAt: _safeDate(m['createdAt']),
  );

  static DateTime _safeDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return raw;
    try { return (raw as dynamic).toDate() as DateTime; } catch (_) {}
    try { return DateTime.parse(raw.toString()); } catch (_) { return DateTime.now(); }
  }
}

class MaterialModel {
  final String id, courseId, titleAr, titleEn, fileUrl, fileType, uploadedBy;
  final DateTime uploadedAt;

  MaterialModel({required this.id, required this.courseId, required this.titleAr,
    required this.titleEn, required this.fileUrl, required this.fileType,
    required this.uploadedBy, required this.uploadedAt});

  Map<String, dynamic> toMap() => {
    'id': id, 'courseId': courseId, 'titleAr': titleAr, 'titleEn': titleEn,
    'fileUrl': fileUrl, 'fileType': fileType, 'uploadedBy': uploadedBy,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  factory MaterialModel.fromMap(Map<String, dynamic> m) => MaterialModel(
    id: m['id'] ?? '', courseId: m['courseId'] ?? '',
    titleAr: m['titleAr'] ?? '', titleEn: m['titleEn'] ?? '',
    fileUrl: m['fileUrl'] ?? '', fileType: m['fileType'] ?? '',
    uploadedBy: m['uploadedBy'] ?? '',
    uploadedAt: _safeDate(m['uploadedAt']),
  );

  static DateTime _safeDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return raw;
    try { return (raw as dynamic).toDate() as DateTime; } catch (_) {}
    try { return DateTime.parse(raw.toString()); } catch (_) { return DateTime.now(); }
  }
}

class AnnouncementModel {
  final String id, courseId, titleAr, titleEn, bodyAr, bodyEn;
  final bool isExam;
  final bool isQuiz;
  final List<Map<String, dynamic>> questions;
  final String annType; // general | exam | summary | assignment | reminder
  final DateTime createdAt;

  AnnouncementModel({required this.id, required this.courseId,
    required this.titleAr, required this.titleEn,
    required this.bodyAr, required this.bodyEn,
    required this.isExam, this.isQuiz = false,
    this.questions = const [], this.annType = 'general', required this.createdAt});

  Map<String, dynamic> toMap() => {
    'id': id, 'courseId': courseId, 'titleAr': titleAr, 'titleEn': titleEn,
    'bodyAr': bodyAr, 'bodyEn': bodyEn, 'isExam': isExam,
    'isQuiz': isQuiz, 'questions': questions,
    'annType': annType,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AnnouncementModel.fromMap(Map<String, dynamic> m) => AnnouncementModel(
    id: m['id'] ?? '', courseId: m['courseId'] ?? '',
    titleAr: m['titleAr'] ?? '', titleEn: m['titleEn'] ?? '',
    bodyAr: m['bodyAr'] ?? '', bodyEn: m['bodyEn'] ?? '',
    isExam: m['isExam'] ?? false,
    isQuiz: m['isQuiz'] ?? false,
    questions: (m['questions'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? [],
    annType: m['annType'] ?? (m['isExam'] == true ? 'exam' : 'general'),
    createdAt: _parseDate(m['createdAt']),
  );

  /// Safely parses Firestore Timestamp, ISO string, or null → DateTime
  static DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    // Firestore Timestamp has a .toDate() method
    if (raw is DateTime) return raw;
    try {
      // duck-type Timestamp: has toDate()
      return (raw as dynamic).toDate() as DateTime;
    } catch (_) {}
    try {
      // fallback: ISO string
      return DateTime.parse(raw.toString());
    } catch (_) {
      return DateTime.now();
    }
  }
}