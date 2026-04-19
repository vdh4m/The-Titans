import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
// ignore: unused_import
import 'paymob_service.dart';
import 'payment_method_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PremiumScreen — Plan comparison + upgrade CTA
//  Plans: Free | Plus (50 EGP/mo) | Pro (100 EGP/mo)
// ─────────────────────────────────────────────────────────────────────────────
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _yearly = false;   // monthly vs yearly toggle

  @override
  Widget build(BuildContext context) {
    final isAr   = context.watch<AppProvider>().isArabic;
    final user   = context.watch<AuthProvider>().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4361EE), Color(0xFF7209B7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 40),
                  const Text('👑', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 8),
                  Text(
                    isAr ? 'ترقية الحساب' : 'Upgrade Your Account',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                  Text(
                    isAr ? 'افتح كل الإمكانيات' : 'Unlock everything',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ])),
              ),
            ),
          ),

          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(children: [

              // ── Current plan badge ─────────────────────────────────────
              if (user != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _planColor(user.planId).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _planColor(user.planId).withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_planEmoji(user.planId),
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      isAr
                          ? 'خطتك الحالية: ${_planNameAr(user.planId)}'
                          : 'Current plan: ${_planNameEn(user.planId)}',
                      style: TextStyle(
                          color: _planColor(user.planId),
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    if (user.isPremium && user.planExpiry != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${isAr ? "تنتهي" : "expires"} ${_fmtDate(user.planExpiry!)}',
                        style: TextStyle(
                            color: _planColor(user.planId).withOpacity(0.7),
                            fontSize: 11),
                      ),
                    ],
                  ]),
                ),
              const SizedBox(height: 20),

              // ── Billing toggle ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1730) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(children: [
                  _ToggleBtn(
                    label: isAr ? 'شهري' : 'Monthly',
                    active: !_yearly,
                    onTap: () => setState(() => _yearly = false),
                  ),
                  _ToggleBtn(
                    label: isAr ? 'سنوي (وفّر 25%)' : 'Yearly (Save 25%)',
                    active: _yearly,
                    onTap: () => setState(() => _yearly = true),
                    badge: isAr ? 'اقتصادي' : 'Best Value',
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Plan cards ─────────────────────────────────────────────
              _PlanCard(
                emoji: '🆓', planId: 'free',
                nameAr: 'مجاني', nameEn: 'Free',
                price: 0, yearly: _yearly,
                color: Colors.grey,
                isAr: isAr, isDark: isDark,
                isCurrent: user?.planId == 'free',
                features: _freeFeatures(isAr),
                onTap: null,
              ),
              const SizedBox(height: 12),
              _PlanCard(
                emoji: '🥈', planId: 'plus',
                nameAr: 'بلص', nameEn: 'Plus',
                price: _yearly ? 450 : 50,
                priceNote: _yearly ? (isAr ? '/سنة (50 × 9 شهور)' : '/yr (50×9 months)') : (isAr ? '/شهر' : '/mo'),
                yearly: _yearly,
                color: const Color(0xFF4361EE),
                isAr: isAr, isDark: isDark,
                isCurrent: user?.isPlus == true,
                features: _plusFeatures(isAr),
                onTap: user?.isPlus == true ? null : () => _upgrade(context, isAr, user, _yearly ? 'plus_yearly' : 'plus_monthly'),
              ),
              const SizedBox(height: 12),
              _PlanCard(
                emoji: '🥇', planId: 'pro',
                nameAr: 'برو', nameEn: 'Pro',
                price: _yearly ? 900 : 100,
                priceNote: _yearly ? (isAr ? '/سنة (100 × 9 شهور)' : '/yr (100×9 months)') : (isAr ? '/شهر' : '/mo'),
                yearly: _yearly,
                color: const Color(0xFFFF9F1C),
                isAr: isAr, isDark: isDark,
                isCurrent: user?.isPro == true,
                features: _proFeatures(isAr),
                highlighted: true,
                onTap: user?.isPro == true ? null : () => _upgrade(context, isAr, user, _yearly ? 'pro_yearly' : 'pro_monthly'),
              ),
              const SizedBox(height: 28),

              // ── Compare all features ───────────────────────────────────
              _FeatureTable(isAr: isAr, isDark: isDark),
              const SizedBox(height: 20),

              // ── Money-back guarantee ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Text('🛡️', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      isAr ? 'ضمان استرداد 7 أيام' : '7-Day Money Back Guarantee',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      isAr
                          ? 'لو مش راضي في أول 7 أيام، هنرجعلك فلوسك كاملة'
                          : 'Not satisfied in the first 7 days? Full refund, no questions.',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12, height: 1.4),
                    ),
                  ])),
                ]),
              ),
            ]),
          )),
        ],
      ),
    );
  }

  void _upgrade(BuildContext ctx, bool isAr, user, String planKey) {
    if (user == null) return;
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => PaymentMethodScreen(
        planKey: planKey,
        uid: user.uid,
        email: user.email,
        isAr: isAr,
      ),
    ));
  }

  Color _planColor(String id) {
    if (id == 'pro')  return const Color(0xFFFF9F1C);
    if (id == 'plus') return const Color(0xFF4361EE);
    return Colors.grey;
  }
  String _planEmoji(String id) => id == 'pro' ? '🥇' : id == 'plus' ? '🥈' : '🆓';
  String _planNameAr(String id) => id == 'pro' ? 'برو' : id == 'plus' ? 'بلص' : 'مجاني';
  String _planNameEn(String id) => id == 'pro' ? 'Pro' : id == 'plus' ? 'Plus' : 'Free';
  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  List<_Feature> _freeFeatures(bool isAr) => [
    _Feature(isAr ? 'مذاكرة + تايمر' : 'Study timer', true),
    _Feature(isAr ? 'XP + Streaks + Badges' : 'XP + Streaks + Badges', true),
    _Feature(isAr ? 'Chat + Community' : 'Chat + Community', true),
    _Feature(isAr ? 'AI (5 مرات/يوم)' : 'AI (5 uses/day)', true),
    _Feature(isAr ? 'Flashcards (3 مجموعات)' : 'Flashcards (3 decks)', true),
    _Feature(isAr ? 'تحميل offline (3 ملفات)' : 'Offline (3 files)', true),
    _Feature(isAr ? 'Streak Freeze (1/أسبوع)' : 'Streak Freeze (1/wk)', false),
    _Feature(isAr ? 'بدون إعلانات' : 'Ad-free', false),
  ];

  List<_Feature> _plusFeatures(bool isAr) => [
    _Feature(isAr ? 'كل مميزات المجاني' : 'All Free features', true),
    _Feature(isAr ? 'AI (20 مرات/يوم)' : 'AI (20 uses/day)', true),
    _Feature(isAr ? 'Flashcards (10 مجموعات)' : 'Flashcards (10 decks)', true),
    _Feature(isAr ? 'Offline (20 ملف)' : 'Offline (20 files)', true),
    _Feature(isAr ? 'Streak Freeze (3/أسبوع)' : 'Streak Freeze (3/wk)', true),
    _Feature(isAr ? 'بدون إعلانات' : 'Ad-free', true),
    _Feature(isAr ? 'شراء مواد الدكاترة' : 'Buy doctor materials', true),
    _Feature(isAr ? 'تقارير متقدمة' : 'Advanced reports', false),
  ];

  List<_Feature> _proFeatures(bool isAr) => [
    _Feature(isAr ? 'كل مميزات بلص' : 'All Plus features', true),
    _Feature(isAr ? 'AI غير محدود ♾️' : 'Unlimited AI ♾️', true),
    _Feature(isAr ? 'Flashcards غير محدودة' : 'Unlimited flashcards', true),
    _Feature(isAr ? 'Offline غير محدود' : 'Unlimited offline', true),
    _Feature(isAr ? 'Streak Freeze غير محدود' : 'Unlimited freezes', true),
    _Feature(isAr ? 'تقارير أسبوعية متقدمة' : 'Advanced weekly reports', true),
    _Feature(isAr ? 'أولوية في Leaderboard' : 'Leaderboard priority badge', true),
    _Feature(isAr ? 'دعم أولوية' : 'Priority support', true),
  ];
}

class _Feature { final String label; final bool included;
  const _Feature(this.label, this.included); }

class _ToggleBtn extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  final String? badge;
  const _ToggleBtn({required this.label, required this.active,
      required this.onTap, this.badge});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(children: [
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? Colors.white : Colors.grey,
                fontWeight: FontWeight.w700, fontSize: 12)),
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(active ? 0.3 : 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badge!, style: TextStyle(
                  color: active ? Colors.greenAccent : Colors.green,
                  fontSize: 9, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    ),
  );
}

class _PlanCard extends StatelessWidget {
  final String emoji, planId, nameAr, nameEn;
  final int price; final String? priceNote;
  final bool yearly, isAr, isDark, isCurrent, highlighted;
  final Color color;
  final List<_Feature> features;
  final VoidCallback? onTap;
  const _PlanCard({
    required this.emoji, required this.planId,
    required this.nameAr, required this.nameEn,
    required this.price, this.priceNote,
    required this.yearly, required this.color,
    required this.isAr, required this.isDark,
    required this.isCurrent, required this.features,
    required this.onTap, this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1730) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? color : color.withOpacity(0.3),
          width: highlighted ? 2.5 : 1.5,
        ),
        boxShadow: highlighted ? [BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 20, offset: const Offset(0, 6))] : [],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(highlighted ? 0.12 : 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAr ? nameAr : nameEn,
                  style: TextStyle(color: color,
                      fontWeight: FontWeight.w900, fontSize: 18)),
              if (price > 0)
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$price جنيه', style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 22)),
                  if (priceNote != null)
                    Text(priceNote!, style: TextStyle(
                        color: color.withOpacity(0.7), fontSize: 12)),
                ])
              else
                Text(isAr ? 'مجاني للأبد' : 'Forever free',
                    style: TextStyle(color: color.withOpacity(0.8), fontSize: 14)),
            ])),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(isAr ? 'خطتك' : 'Current',
                    style: TextStyle(color: color,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        // Features
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(
                  f.included ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: f.included ? Colors.green : Colors.grey.shade400,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(f.label, style: TextStyle(
                    fontSize: 13,
                    color: f.included ? null : Colors.grey.shade400,
                    fontWeight: f.included ? FontWeight.w500 : FontWeight.w400)),
              ]),
            )),
            if (onTap != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onTap,
                  child: Text(
                    isAr ? 'اشترك الآن' : 'Subscribe Now',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _FeatureTable extends StatelessWidget {
  final bool isAr, isDark;
  const _FeatureTable({required this.isAr, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rows = [
      [isAr ? 'الميزة' : 'Feature', isAr ? 'مجاني' : 'Free', isAr ? 'بلص' : 'Plus', isAr ? 'برو' : 'Pro'],
      [isAr ? 'AI يومياً' : 'Daily AI', '5', '20', '♾️'],
      [isAr ? 'Flashcard Decks' : 'Flashcard Decks', '3', '10', '♾️'],
      [isAr ? 'تحميل Offline' : 'Offline Download', '3', '20', '♾️'],
      [isAr ? 'Streak Freeze' : 'Streak Freeze', '1/أسبوع', '3/أسبوع', '♾️'],
      [isAr ? 'بدون إعلانات' : 'Ad-free', '❌', '✅', '✅'],
      [isAr ? 'مواد الدكاترة' : 'Buy Materials', '❌', '✅', '✅'],
      [isAr ? 'تقارير متقدمة' : 'Advanced Reports', '❌', '❌', '✅'],
      [isAr ? 'أولوية Leaderboard' : 'Leaderboard Badge', '❌', '❌', '✅'],
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1730) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key; final row = entry.value;
          final isHeader = i == 0;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: isHeader
                  ? AppTheme.primaryColor.withOpacity(0.08)
                  : (i.isEven ? Colors.transparent : Colors.grey.withOpacity(0.03)),
              borderRadius: i == 0
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : i == rows.length - 1
                      ? const BorderRadius.vertical(bottom: Radius.circular(16))
                      : null,
            ),
            child: Row(children: [
              Expanded(flex: 3, child: Text(row[0],
                  style: TextStyle(
                      fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 12,
                      color: isHeader ? AppTheme.primaryColor : null))),
              ...row.skip(1).toList().asMap().entries.map((e) {
                final colors = [Colors.grey, const Color(0xFF4361EE), const Color(0xFFFF9F1C)];
                return Expanded(child: Text(e.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
                        color: isHeader ? colors[e.key] : null)));
              }),
            ]),
          );
        }).toList(),
      ),
    );
  }
}