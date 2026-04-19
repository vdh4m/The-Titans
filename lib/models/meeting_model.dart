class MeetingModel {
  final String id;
  final String courseId;
  final String doctorId;
  final String titleAr;
  final String titleEn;
  final String roomName;   // Jitsi room name (used instead of external link)
  final String link;       // legacy — kept for backward compat
  final String startedAt;
  final bool isActive;

  const MeetingModel({
    required this.id,
    required this.courseId,
    required this.doctorId,
    required this.titleAr,
    required this.titleEn,
    required this.roomName,
    required this.link,
    required this.startedAt,
    required this.isActive,
  });

  factory MeetingModel.fromMap(Map<String, dynamic> m, String id) => MeetingModel(
        id:        id,
        courseId:  m['courseId']  as String? ?? '',
        doctorId:  m['doctorId']  as String? ?? '',
        titleAr:   m['titleAr']   as String? ?? 'اجتماع',
        titleEn:   m['titleEn']   as String? ?? 'Meeting',
        roomName:  m['roomName']  as String? ?? '',
        link:      m['link']      as String? ?? '',
        startedAt: m['startedAt'] as String? ?? '',
        isActive:  m['isActive']  as bool?   ?? false,
      );

  Map<String, dynamic> toMap() => {
        'courseId':  courseId,
        'doctorId':  doctorId,
        'titleAr':   titleAr,
        'titleEn':   titleEn,
        'roomName':  roomName,
        'link':      link,
        'startedAt': startedAt,
        'isActive':  isActive,
      };
}
