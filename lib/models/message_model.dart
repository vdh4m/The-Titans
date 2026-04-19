class MessageModel {
  final String id, courseId, senderId, senderName, senderRole, text, messageType;
  final String? replyToId, replyToText, replyToSenderName;
  final DateTime createdAt;

  MessageModel({required this.id, required this.courseId, required this.senderId,
    required this.senderName, required this.senderRole, required this.text,
    required this.messageType, this.replyToId, this.replyToText,
    this.replyToSenderName, required this.createdAt});

  Map<String, dynamic> toMap() => {
    'id': id, 'courseId': courseId, 'senderId': senderId,
    'senderName': senderName, 'senderRole': senderRole,
    'text': text, 'messageType': messageType,
    'replyToId': replyToId, 'replyToText': replyToText,
    'replyToSenderName': replyToSenderName,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MessageModel.fromMap(Map<String, dynamic> m) => MessageModel(
    id: m['id'] ?? '', courseId: m['courseId'] ?? '',
    senderId: m['senderId'] ?? '', senderName: m['senderName'] ?? '',
    senderRole: m['senderRole'] ?? 'student',
    text: m['text'] ?? '', messageType: m['messageType'] ?? 'normal',
    replyToId: m['replyToId'], replyToText: m['replyToText'],
    replyToSenderName: m['replyToSenderName'],
    createdAt: m['createdAt'] != null ? DateTime.parse(m['createdAt']) : DateTime.now(),
  );
}

class StudySession {
  final String id, userId, courseId, courseTitleAr, courseTitleEn;
  final int durationSeconds;
  final DateTime date;

  StudySession({required this.id, required this.userId, required this.courseId,
    required this.courseTitleAr, required this.courseTitleEn,
    required this.durationSeconds, required this.date});

  Map<String, dynamic> toMap() => {
    'id': id, 'userId': userId, 'courseId': courseId,
    'courseTitleAr': courseTitleAr, 'courseTitleEn': courseTitleEn,
    'durationSeconds': durationSeconds, 'date': date.toIso8601String(),
  };

  factory StudySession.fromMap(Map<String, dynamic> m) => StudySession(
    id: m['id'] ?? '', userId: m['userId'] ?? '',
    courseId: m['courseId'] ?? '', courseTitleAr: m['courseTitleAr'] ?? '',
    courseTitleEn: m['courseTitleEn'] ?? '',
    durationSeconds: m['durationSeconds'] ?? 0,
    date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
  );
}