import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  BadgesScreen — 50 badges, each with a real unique task
//  Unlocked = automatically from Firestore data OR earnedBadges list
// ─────────────────────────────────────────────────────────────────────────────
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  // ignore: long-method
  static List<Map<String, dynamic>> getBadges(
      dynamic user, List<String> earned) {
    final xp      = user.totalXP   as int? ?? 0;
    final streak  = user.streakDays as int? ?? 0;
    final gpa     = (user.gpa      as double?) ?? 0.0;

    bool e(String id) => earned.contains(id);

    return [
      // ══════════════════════════════════════════════════════════════════
      // 🔥 STREAKS  (6 badges)
      // ══════════════════════════════════════════════════════════════════
      {
        'id': 'first_study', 'emoji': '🎯', 'cat': 'streak',
        'titleAr': 'أول خطوة',        'titleEn': 'First Step',
        'taskAr':  'ذاكر لأول مرة',   'taskEn':  'Study for the first time',
        'unlocked': xp > 0,
      },
      {
        'id': 'streak_3', 'emoji': '🔥', 'cat': 'streak',
        'titleAr': 'ثلاثة أيام',       'titleEn': '3-Day Streak',
        'taskAr':  'ذاكر ٣ أيام متواصلة',  'taskEn': 'Study 3 days in a row',
        'unlocked': streak >= 3,
      },
      {
        'id': 'streak_7', 'emoji': '🌟', 'cat': 'streak',
        'titleAr': 'أسبوع كامل',       'titleEn': 'Week Warrior',
        'taskAr':  'ذاكر ٧ أيام متواصلة',  'taskEn': 'Study 7 days in a row',
        'unlocked': streak >= 7,
      },
      {
        'id': 'streak_14', 'emoji': '⚡', 'cat': 'streak',
        'titleAr': 'أسبوعان',          'titleEn': '2-Week Streak',
        'taskAr':  'ذاكر ١٤ يوم متواصل',   'taskEn': '14 straight study days',
        'unlocked': streak >= 14,
      },
      {
        'id': 'streak_30', 'emoji': '💥', 'cat': 'streak',
        'titleAr': 'شهر لا يتوقف',     'titleEn': 'Unstoppable Month',
        'taskAr':  'ذاكر ٣٠ يوم متواصل',   'taskEn': '30 days without missing',
        'unlocked': streak >= 30,
      },
      {
        'id': 'streak_90', 'emoji': '🦁', 'cat': 'streak',
        'titleAr': 'أسطورة ٩٠ يوم',    'titleEn': '90-Day Legend',
        'taskAr':  'ذاكر ٩٠ يوم متواصل',   'taskEn': '90 consecutive study days',
        'unlocked': streak >= 90,
      },

      // ══════════════════════════════════════════════════════════════════
      // ⭐ XP  (8 badges)
      // ══════════════════════════════════════════════════════════════════
      {
        'id': 'xp_50', 'emoji': '✨', 'cat': 'xp',
        'titleAr': 'الشرارة الأولى',   'titleEn': 'First Spark',
        'taskAr':  'اكسب ٥٠ XP',       'taskEn':  'Earn 50 XP',
        'unlocked': xp >= 50,
      },
      {
        'id': 'xp_100', 'emoji': '⭐', 'cat': 'xp',
        'titleAr': 'مبتدئ',            'titleEn': 'Rookie',
        'taskAr':  'اكسب ١٠٠ XP',      'taskEn':  'Earn 100 XP',
        'unlocked': xp >= 100,
      },
      {
        'id': 'xp_250', 'emoji': '🌠', 'cat': 'xp',
        'titleAr': 'صاعد',             'titleEn': 'Rising Star',
        'taskAr':  'اكسب ٢٥٠ XP',      'taskEn':  'Earn 250 XP',
        'unlocked': xp >= 250,
      },
      {
        'id': 'xp_500', 'emoji': '🏅', 'cat': 'xp',
        'titleAr': 'متعلم',            'titleEn': 'Learner',
        'taskAr':  'اكسب ٥٠٠ XP',      'taskEn':  'Earn 500 XP',
        'unlocked': xp >= 500,
      },
      {
        'id': 'xp_1000', 'emoji': '🏆', 'cat': 'xp',
        'titleAr': 'متقدم',            'titleEn': 'Advanced',
        'taskAr':  'اكسب ١٠٠٠ XP',     'taskEn':  'Earn 1,000 XP',
        'unlocked': xp >= 1000,
      },
      {
        'id': 'xp_2500', 'emoji': '👑', 'cat': 'xp',
        'titleAr': 'النخبة',           'titleEn': 'Elite',
        'taskAr':  'اكسب ٢٥٠٠ XP',     'taskEn':  'Earn 2,500 XP',
        'unlocked': xp >= 2500,
      },
      {
        'id': 'xp_5000', 'emoji': '💎', 'cat': 'xp',
        'titleAr': 'البطل',            'titleEn': 'Champion',
        'taskAr':  'اكسب ٥٠٠٠ XP',     'taskEn':  'Earn 5,000 XP',
        'unlocked': xp >= 5000,
      },
      {
        'id': 'xp_10000', 'emoji': '🌌', 'cat': 'xp',
        'titleAr': 'الأسطورة',         'titleEn': 'Legend',
        'taskAr':  'اكسب ١٠٠٠٠ XP',    'taskEn':  'Earn 10,000 XP',
        'unlocked': xp >= 10000,
      },

      // ══════════════════════════════════════════════════════════════════
      // 📊 GPA  (6 badges)
      // ══════════════════════════════════════════════════════════════════
      {
        'id': 'gpa_50', 'emoji': '📗', 'cat': 'gpa',
        'titleAr': 'الناجح',           'titleEn': 'Passing',
        'taskAr':  'حقق معدل ٥٠٪ أو أكثر',  'taskEn': 'Achieve 50% GPA or higher',
        'unlocked': gpa >= 50,
      },
      {
        'id': 'gpa_65', 'emoji': '📘', 'cat': 'gpa',
        'titleAr': 'جيد',              'titleEn': 'Good',
        'taskAr':  'حقق معدل ٦٥٪ أو أكثر',  'taskEn': 'Achieve 65% GPA or higher',
        'unlocked': gpa >= 65,
      },
      {
        'id': 'gpa_75', 'emoji': '📙', 'cat': 'gpa',
        'titleAr': 'جيد جداً',         'titleEn': 'Very Good',
        'taskAr':  'حقق معدل ٧٥٪ أو أكثر',  'taskEn': 'Achieve 75% GPA or higher',
        'unlocked': gpa >= 75,
      },
      {
        'id': 'gpa_85', 'emoji': '📚', 'cat': 'gpa',
        'titleAr': 'امتياز',           'titleEn': 'Excellent',
        'taskAr':  'حقق معدل ٨٥٪ أو أكثر',  'taskEn': 'Achieve 85% GPA or higher',
        'unlocked': gpa >= 85,
      },
      {
        'id': 'gpa_90', 'emoji': '🎓', 'cat': 'gpa',
        'titleAr': 'نجم الكلية',       'titleEn': 'Faculty Star',
        'taskAr':  'حقق معدل ٩٠٪ أو أكثر',  'taskEn': 'Achieve 90% GPA or higher',
        'unlocked': gpa >= 90,
      },
      {
        'id': 'gpa_95', 'emoji': '🥇', 'cat': 'gpa',
        'titleAr': 'الأول على الكلية', 'titleEn': 'Top of Faculty',
        'taskAr':  'حقق معدل ٩٥٪ أو أكثر',  'taskEn': 'Achieve 95% GPA or higher',
        'unlocked': gpa >= 95,
      },

      // ══════════════════════════════════════════════════════════════════
      // ⏰ TIME HABITS  (7 badges)
      // ══════════════════════════════════════════════════════════════════
      {
        'id': 'night_owl', 'emoji': '🦉', 'cat': 'habit',
        'titleAr': 'بومة الليل',       'titleEn': 'Night Owl',
        'taskAr':  'ذاكر بعد الساعة ١١ مساءً',  'taskEn': 'Study after 11 PM',
        'unlocked': e('night_owl'),
      },
      {
        'id': 'early_bird', 'emoji': '🌅', 'cat': 'habit',
        'titleAr': 'طائر الفجر',       'titleEn': 'Early Bird',
        'taskAr':  'ذاكر قبل الساعة ٦ الصبح',   'taskEn': 'Study before 6 AM',
        'unlocked': e('early_bird'),
      },
      {
        'id': 'weekend_warrior', 'emoji': '🏄', 'cat': 'habit',
        'titleAr': 'محارب العطلة',     'titleEn': 'Weekend Warrior',
        'taskAr':  'ذاكر يوم الجمعة والسبت في نفس الأسبوع',
        'taskEn':  'Study on both weekend days in one week',
        'unlocked': e('weekend_warrior'),
      },
      {
        'id': 'consistent', 'emoji': '🎖️', 'cat': 'habit',
        'titleAr': 'الثبات',           'titleEn': 'Iron Routine',
        'taskAr':  'ذاكر ٥ أسابيع متواصلة (لا تفوّت أسبوع)',
        'taskEn':  'Study at least once every week for 5 weeks',
        'unlocked': e('consistent'),
      },
      {
        'id': 'deep_focus', 'emoji': '🧘', 'cat': 'habit',
        'titleAr': 'التركيز العميق',   'titleEn': 'Deep Focus',
        'taskAr':  'ذاكر جلسة واحدة أكثر من ٩٠ دقيقة متواصلة',
        'taskEn':  'Complete a single study session over 90 minutes',
        'unlocked': e('deep_focus'),
      },
      {
        'id': 'marathon', 'emoji': '🏃', 'cat': 'habit',
        'titleAr': 'الماراثون',        'titleEn': 'Marathon',
        'taskAr':  'اجمع ١٠ ساعات مذاكرة كلية',
        'taskEn':  'Accumulate 10 total study hours',
        'unlocked': e('marathon'),
      },
      {
        'id': 'centurion', 'emoji': '⚔️', 'cat': 'habit',
        'titleAr': 'المئة ساعة',       'titleEn': 'Centurion',
        'taskAr':  'اجمع ١٠٠ ساعة مذاكرة كلية',
        'taskEn':  'Accumulate 100 total study hours',
        'unlocked': e('centurion'),
      },

      // ══════════════════════════════════════════════════════════════════
      // 🍅 POMODORO  (4 badges)
      // ══════════════════════════════════════════════════════════════════
      {
        'id': 'pomodoro_1', 'emoji': '🍅', 'cat': 'tools',
        'titleAr': 'أول طماطم',        'titleEn': 'First Tomato',
        'taskAr':  'أكمل أول جلسة بومودورو',    'taskEn': 'Complete your first Pomodoro',
        'unlocked': e('pomodoro_1'),
      },
      {
        'id': 'pomodoro_5', 'emoji': '🍕', 'cat': 'tools',
        'titleAr': 'بومودورو نشيط',    'titleEn': 'Pomodoro Active',
        'taskAr':  'أكمل ٥ جلسات بومودورو',     'taskEn': 'Complete 5 Pomodoro sessions',
        'unlocked': e('pomodoro_5'),
      },
      {
        'id': 'pomodoro_25', 'emoji': '🔴', 'cat': 'tools',
        'titleAr': 'بومودورو برو',      'titleEn': 'Pomodoro Pro',
        'taskAr':  'أكمل ٢٥ جلسة بومودورو',     'taskEn': 'Complete 25 Pomodoro sessions',
        'unlocked': e('pomodoro_25'),
      },
      {
        'id': 'pomodoro_100', 'emoji': '🌋', 'cat': 'tools',
        'titleAr': 'ملك البومودورو',   'titleEn': 'Pomodoro King',
        'taskAr':  'أكمل ١٠٠ جلسة بومودورو',    'taskEn': 'Complete 100 Pomodoro sessions',
        'unlocked': e('pomodoro_100'),
      },

      // ══════════════════════════════════════════════════════════════════
      // 🃏 FLASHCARDS  (6 badges)
      // ══════════════════════════════════════════════════════════════════
      {
        'id': 'flashcard_first', 'emoji': '🃏', 'cat': 'tools',
        'titleAr': 'أول بطاقة',        'titleEn': 'First Card',
        'taskAr':  'اصنع أول فلاش كارد',         'taskEn': 'Create your first flashcard',
        'unlocked': e('flashcard_first'),
      },
      {
        'id': 'flashcard_5', 'emoji': '🎴', 'cat': 'tools',
        'titleAr': 'بداية القوة',      'titleEn': 'Card Starter',
        'taskAr':  'اصنع ٥ فلاش كارد',           'taskEn': 'Create 5 flashcards',
        'unlocked': e('flashcard_5'),
      },
      {
        'id': 'flashcard_10', 'emoji': '📇', 'cat': 'tools',
        'titleAr': 'صانع البطاقات',    'titleEn': 'Card Maker',
        'taskAr':  'اصنع ١٠ فلاش كارد عبر كل المجموعات',
        'taskEn':  'Create 10 total flashcards across all decks',
        'unlocked': e('flashcard_10'),
      },
      {
        'id': 'flashcard_25', 'emoji': '🗂️', 'cat': 'tools',
        'titleAr': 'المراجعون',        'titleEn': 'Reviewer',
        'taskAr':  'اصنع ٢٥ فلاش كارد',          'taskEn': 'Create 25 total flashcards',
        'unlocked': e('flashcard_25'),
      },
      {
        'id': 'flashcard_50', 'emoji': '📚', 'cat': 'tools',
        'titleAr': 'حافظ البطاقات',   'titleEn': 'Card Master',
        'taskAr':  'اصنع ٥٠ فلاش كارد',          'taskEn': 'Create 50 total flashcards',
        'unlocked': e('flashcard_50'),
      },
      {
        'id': 'deck_collector', 'emoji': '🗃️', 'cat': 'tools',
        'titleAr': 'جامع المجموعات',  'titleEn': 'Deck Collector',
        'taskAr':  'أنشئ ٣ مجموعات فلاش كارد',   'taskEn': 'Create 3 flashcard decks',
        'unlocked': e('deck_collector'),
      },

      // ══════════════════════════════════════════════════════════════════
      // 🤖 AI TOOLS  (5 badges)
      // ══════════════════════════════════════════════════════════════════
      {
        'id': 'ai_first', 'emoji': '🤖', 'cat': 'tools',
        'titleAr': 'أول استخدام للذكاء', 'titleEn': 'AI Explorer',
        'taskAr':  'استخدم المساعد الذكي لأول مرة',  'taskEn': 'Use the AI assistant for the first time',
        'unlocked': e('ai_first'),
      },
      {
        'id': 'quiz_master', 'emoji': '🧠', 'cat': 'tools',
        'titleAr': 'عبقري الكويز',     'titleEn': 'Quiz Master',
        'taskAr':  'انهِ كويز ذكاء اصطناعي كامل',  'taskEn': 'Complete a full AI-generated quiz',
        'unlocked': e('quiz_master'),
      },
      {
        'id': 'pdf_reader', 'emoji': '📄', 'cat': 'tools',
        'titleAr': 'قارئ الملخصات',   'titleEn': 'PDF Reader',
        'taskAr':  'لخّص PDF باستخدام الذكاء الاصطناعي',
        'taskEn':  'Summarize a PDF with AI',
        'unlocked': e('pdf_reader'),
      },
      {
        'id': 'note_taker', 'emoji': '📝', 'cat': 'tools',
        'titleAr': 'الكاتب المثالي',  'titleEn': 'Note Taker',
        'taskAr':  'اكتب ١٠ ملاحظات دراسية',   'taskEn': 'Write 10 study notes',
        'unlocked': e('note_taker'),
      },
      {
        'id': 'formula_master', 'emoji': '🔬', 'cat': 'tools',
        'titleAr': 'سيد المعادلات',   'titleEn': 'Formula Master',
        'taskAr':  'أضف ١٠ معادلات للمذاكرة',   'taskEn': 'Add 10 formulas to your study list',
        'unlocked': e('formula_master'),
      },

      // ══════════════════════════════════════════════════════════════════
      // 👥 SOCIAL  (7 badges)
      // ══════════════════════════════════════════════════════════════════
      {
        'id': 'group_joiner', 'emoji': '👥', 'cat': 'social',
        'titleAr': 'روح الفريق',       'titleEn': 'Team Player',
        'taskAr':  'انضم لأول مجموعة دراسية',   'taskEn': 'Join your first study group',
        'unlocked': e('group_joiner'),
      },
      {
        'id': 'first_message', 'emoji': '💬', 'cat': 'social',
        'titleAr': 'أول رسالة',        'titleEn': 'First Message',
        'taskAr':  'أرسل أول رسالة في مجموعة',   'taskEn': 'Send your first group message',
        'unlocked': e('first_message'),
      },
      {
        'id': 'helper', 'emoji': '🤝', 'cat': 'social',
        'titleAr': 'المساعد',          'titleEn': 'Helper',
        'taskAr':  'أجب على ١٠ أسئلة لزملائك',  'taskEn': 'Answer 10 classmate questions',
        'unlocked': e('helper'),
      },
      {
        'id': 'popular', 'emoji': '⭐', 'cat': 'social',
        'titleAr': 'المشهور',          'titleEn': 'Popular',
        'taskAr':  'أرسل ٥٠ رسالة في المجموعات',  'taskEn': 'Send 50 messages in groups',
        'unlocked': e('popular'),
      },
      {
        'id': 'top_3', 'emoji': '🥉', 'cat': 'social',
        'titleAr': 'من الأوائل',       'titleEn': 'Top 3',
        'taskAr':  'احتل المركز الثالث أو أعلى في اللوحة',
        'taskEn':  'Reach top 3 on the leaderboard',
        'unlocked': e('top_3'),
      },
      {
        'id': 'top_1', 'emoji': '🥇', 'cat': 'social',
        'titleAr': 'رقم واحد',         'titleEn': 'Number One',
        'taskAr':  'احتل المركز الأول في اللوحة',
        'taskEn':  'Reach #1 on the leaderboard',
        'unlocked': e('top_1'),
      },
      {
        'id': 'community_star', 'emoji': '🌟', 'cat': 'social',
        'titleAr': 'نجم المجتمع',      'titleEn': 'Community Star',
        'taskAr':  'انشر ١٠ مشاركات في المجتمع',   'taskEn': 'Post 10 times in the community',
        'unlocked': e('community_star'),
      },

      // ══════════════════════════════════════════════════════════════════
      // 🏆 SPECIAL / RARE  (6 badges)
      // ══════════════════════════════════════════════════════════════════
      {
        'id': 'comeback', 'emoji': '🔄', 'cat': 'special',
        'titleAr': 'العودة القوية',    'titleEn': 'Comeback Kid',
        'taskAr':  'ارجع للمذاكرة بعد انقطاع أسبوع',
        'taskEn':  'Return to studying after a week-long break',
        'unlocked': e('comeback'),
      },
      {
        'id': 'perfect_week', 'emoji': '🗓️', 'cat': 'special',
        'titleAr': 'الأسبوع المثالي',  'titleEn': 'Perfect Week',
        'taskAr':  'ذاكر كل يوم في أسبوع كامل (٧/٧)',
        'taskEn':  'Study every single day for a full week',
        'unlocked': e('perfect_week'),
      },
      {
        'id': 'multi_subject', 'emoji': '🎨', 'cat': 'special',
        'titleAr': 'متعدد المواهب',   'titleEn': 'Multi-Talent',
        'taskAr':  'ذاكر ٥ مواد مختلفة في يوم واحد',
        'taskEn':  'Study 5 different subjects in one day',
        'unlocked': e('multi_subject'),
      },
      {
        'id': 'freeze_master', 'emoji': '🧊', 'cat': 'special',
        'titleAr': 'سيد التجميد',     'titleEn': 'Freeze Master',
        'taskAr':  'استخدم Streak Freeze وارجع في اليوم التالي',
        'taskEn':  'Use a streak freeze and return the next day',
        'unlocked': e('freeze_master'),
      },
      {
        'id': 'all_rounder', 'emoji': '🌈', 'cat': 'special',
        'titleAr': 'الشامل',           'titleEn': 'All Rounder',
        'taskAr':  'احصل على بادج من كل فئة',
        'taskEn':  'Earn at least one badge from every category',
        'unlocked': e('all_rounder'),
      },
      {
        'id': 'diamond', 'emoji': '💠', 'cat': 'special',
        'titleAr': 'الماسة النادرة',  'titleEn': 'Rare Diamond',
        'taskAr':  'احصل على ٢٠ بادج مختلفة',
        'taskEn':  'Unlock 20 different badges',
        'unlocked': earned.length >= 20,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user  = context.watch<AuthProvider>().currentUser;
    final isAr  = context.watch<AppProvider>().isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final earned   = List<String>.from(user.earnedBadges);
    final badges   = getBadges(user, earned);
    final unlocked = badges.where((b) => b['unlocked'] as bool).length;
    final total    = badges.length;

    final cats = [
      {'id': 'all',     'labelAr': 'الكل',       'labelEn': 'All',       'emoji': '🏆'},
      {'id': 'streak',  'labelAr': 'السلاسل',    'labelEn': 'Streaks',   'emoji': '🔥'},
      {'id': 'xp',      'labelAr': 'النقاط',     'labelEn': 'XP',        'emoji': '⭐'},
      {'id': 'gpa',     'labelAr': 'المعدل',      'labelEn': 'GPA',       'emoji': '📊'},
      {'id': 'habit',   'labelAr': 'العادات',     'labelEn': 'Habits',    'emoji': '⏰'},
      {'id': 'tools',   'labelAr': 'الأدوات',     'labelEn': 'Tools',     'emoji': '🛠️'},
      {'id': 'social',  'labelAr': 'التواصل',     'labelEn': 'Social',    'emoji': '👥'},
      {'id': 'special', 'labelAr': 'نادرة',       'labelEn': 'Special',   'emoji': '💠'},
    ];

    return DefaultTabController(
      length: cats.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isAr ? '🏅 البادجات' : '🏅 Badges'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: TabBar(
              isScrollable: true,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12),
              tabAlignment: TabAlignment.start,
              tabs: cats.map((c) => Tab(
                text: '${c['emoji']} ${isAr ? c['labelAr'] : c['labelEn']}',
              )).toList(),
            ),
          ),
        ),
        body: Column(children: [
          // ── Progress bar ──────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, const Color(0xFF7209B7)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  isAr ? 'البادجات المكتسبة' : 'Badges Earned',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '$unlocked / $total',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total > 0 ? unlocked / total : 0,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 8,
                ),
              ),
            ]),
          ),

          // ── Grid ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              children: cats.map((cat) {
                final filtered = cat['id'] == 'all'
                    ? badges
                    : badges.where((b) => b['cat'] == cat['id']).toList();
                return _BadgeGrid(
                    badges: filtered, isAr: isAr, isDark: isDark);
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Badge grid
// ─────────────────────────────────────────────────────────────────────────────
class _BadgeGrid extends StatelessWidget {
  final List<Map<String, dynamic>> badges;
  final bool isAr, isDark;
  const _BadgeGrid(
      {required this.badges, required this.isAr, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return Center(
          child: Text(isAr ? 'لا توجد بادجات في هذه الفئة' : 'No badges here',
              style: TextStyle(color: Colors.grey[500])));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: badges.length,
      itemBuilder: (ctx, i) {
        final b        = badges[i];
        final unlocked = b['unlocked'] as bool;
        return GestureDetector(
          onTap: () => _showDetail(ctx, b, unlocked, isAr),
          child: _BadgeTile(b: b, unlocked: unlocked,
              isAr: isAr, isDark: isDark),
        );
      },
    );
  }

  void _showDetail(BuildContext ctx, Map<String, dynamic> b,
      bool unlocked, bool isAr) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1730) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Emoji circle
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: unlocked
                  ? const LinearGradient(
                      colors: [AppTheme.primaryColor, Color(0xFF7209B7)])
                  : null,
              color: unlocked ? null : Colors.grey.shade200,
            ),
            child: Center(child: unlocked
                ? Text(b['emoji'] as String,
                    style: const TextStyle(fontSize: 44))
                : ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.213, 0.715, 0.072, 0, 0,
                      0.213, 0.715, 0.072, 0, 0,
                      0.213, 0.715, 0.072, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
                    child: Text(b['emoji'] as String,
                        style: const TextStyle(fontSize: 44)),
                  )),
          ),
          const SizedBox(height: 14),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: unlocked
                  ? Colors.green.withOpacity(0.12)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              unlocked
                  ? (isAr ? '✅ تم الحصول عليه' : '✅ Unlocked')
                  : (isAr ? '🔒 مقفول' : '🔒 Locked'),
              style: TextStyle(
                color: unlocked ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w700, fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Title
          Text(isAr ? b['titleAr'] as String : b['titleEn'] as String,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 10),
          // Task description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Column(children: [
              Text(isAr ? '📋 المهمة المطلوبة' : '📋 Task Required',
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                isAr ? b['taskAr'] as String : b['taskEn'] as String,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
          if (!unlocked) ...[
            const SizedBox(height: 12),
            Text(
              isAr ? 'أكمل المهمة للحصول على هذا البادج!'
                   : 'Complete the task above to unlock this badge!',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Single badge tile
// ─────────────────────────────────────────────────────────────────────────────
class _BadgeTile extends StatelessWidget {
  final Map<String, dynamic> b;
  final bool unlocked, isAr, isDark;
  const _BadgeTile({required this.b, required this.unlocked,
      required this.isAr, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1730) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? AppTheme.primaryColor.withOpacity(0.4)
              : Colors.grey.withOpacity(0.15),
          width: unlocked ? 2 : 1,
        ),
        boxShadow: unlocked
            ? [BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.12),
                blurRadius: 10, offset: const Offset(0, 4))]
            : [],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Emoji with glow or grayscale
        Stack(alignment: Alignment.center, children: [
          if (unlocked)
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.15),
                    const Color(0xFF7209B7).withOpacity(0.15),
                  ],
                ),
              ),
            ),
          if (!unlocked)
            ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.213, 0.715, 0.072, 0, 0,
                0.213, 0.715, 0.072, 0, 0,
                0.213, 0.715, 0.072, 0, 0,
                0, 0, 0, 0.5, 0,
              ]),
              child: Text(b['emoji'] as String,
                  style: const TextStyle(fontSize: 32)),
            ),
          if (unlocked)
            Text(b['emoji'] as String,
                style: const TextStyle(fontSize: 32)),
          if (!unlocked)
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 11),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            isAr ? b['titleAr'] as String : b['titleEn'] as String,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: unlocked
                  ? (isDark ? Colors.white : Colors.black87)
                  : Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        // Task hint
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            isAr ? b['taskAr'] as String : b['taskEn'] as String,
            style: TextStyle(
              fontSize: 9,
              color: unlocked
                  ? AppTheme.primaryColor
                  : Colors.grey.shade400,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}