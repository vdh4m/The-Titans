import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';

class MoodSelectorScreen extends StatefulWidget {
  const MoodSelectorScreen({super.key});
  @override State<MoodSelectorScreen> createState() => _MoodSelectorScreenState();
}

class _MoodSelectorScreenState extends State<MoodSelectorScreen> {
  String? _selected;

  static const _moods = [
    {'id': 'tired',     'emoji': '😴', 'labelAr': 'تعبان',   'labelEn': 'Tired',     'descAr': 'مش قادر أركز كتير', 'descEn': 'Low energy, need easy tasks', 'color': 0xFF94A3B8},
    {'id': 'normal',    'emoji': '😊', 'labelAr': 'عادي',    'labelEn': 'Normal',    'descAr': 'مذاكرة عادية', 'descEn': 'Regular study session', 'color': 0xFF4361EE},
    {'id': 'energized', 'emoji': '🔥', 'labelAr': 'نشيط',   'labelEn': 'Energized', 'descAr': 'جاهز للتحدي', 'descEn': 'Ready for hard challenges', 'color': 0xFF06D6A0},
  ];

  static const _moodSuggestions = {
    'tired':     {'ar': ['مراجعة Flashcards خفيفة', 'قراءة ملاحظات قديمة', 'مشاهدة فيديو شرح قصير'], 'en': ['Light flashcard review', 'Read old notes', 'Watch a short explanation video']},
    'normal':    {'ar': ['مذاكرة موضوع جديد', 'حل تمارين متوسطة', 'مراجعة الأسبوع الماضي'], 'en': ['Study a new topic', 'Solve medium exercises', 'Review last week\'s material']},
    'energized': {'ar': ['حل مسائل صعبة', 'امتحان تجريبي كامل', 'استكشاف مواضيع إضافية'], 'en': ['Solve hard problems', 'Take a full mock exam', 'Explore extra topics']},
  };

  void _saveMood() async {
    if (_selected == null) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'lastMood': _selected});
    if (mounted) Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'كيف حالك النهارده؟' : 'How are you feeling?')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Text(isAr ? 'اختر مزاجك وهنقترحلك أفضل طريقة مذاكرة' : 'Choose your mood and we\'ll suggest the best study method',
            style: TextStyle(color: Colors.grey[600], height: 1.4), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ..._moods.map((m) {
            final isSelected = _selected == m['id'];
            final color = Color(m['color'] as int);
            final suggestions = _moodSuggestions[m['id']]!;
            return GestureDetector(
              onTap: () => setState(() => _selected = m['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.1) : Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isSelected ? color : Colors.grey.withOpacity(0.15), width: isSelected ? 2 : 1),
                  boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))] : [],
                ),
                child: Row(children: [
                  Text(m['emoji'] as String, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isAr ? m['labelAr'] as String : m['labelEn'] as String,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isSelected ? color : null)),
                    Text(isAr ? m['descAr'] as String : m['descEn'] as String,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    if (isSelected) ...[
                      const SizedBox(height: 10),
                      Text(isAr ? 'مقترحات:' : 'Suggestions:', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      ...(isAr ? suggestions['ar']! : suggestions['en']!).map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(children: [
                          Container(width: 5, height: 5, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          Text(s, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                        ]),
                      )),
                    ],
                  ])),
                  if (isSelected) Icon(Icons.check_circle_rounded, color: color),
                ]),
              ),
            );
          }),
          const Spacer(),
          ElevatedButton(
            onPressed: _selected == null ? null : _saveMood,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text(isAr ? 'ابدأ المذاكرة' : 'Start Studying', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ]),
      ),
    );
  }
}
