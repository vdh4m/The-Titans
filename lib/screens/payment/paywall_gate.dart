import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../payment/premium_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PaywallGate — Wraps any feature with a premium check
//
//  Usage:
//    PaywallGate(
//      feature: PremiumFeature.unlimitedAi,
//      child: AiScreen(),
//    )
//
//  Or check programmatically:
//    if (!PaywallGate.canAccess(user, PremiumFeature.unlimitedAi)) {
//      PaywallGate.showUpgradeSheet(context);
//    }
// ─────────────────────────────────────────────────────────────────────────────
enum PremiumFeature {
  unlimitedAi,        // Pro only
  extraFlashcards,    // Plus: 10 decks, Pro: unlimited
  extraOffline,       // Plus: 20 files, Pro: unlimited
  extraStreakFreezes, // Plus: 3/wk, Pro: unlimited
  adFree,             // Plus+
  buyMaterials,       // Plus+
  advancedReports,    // Pro only
  leaderboardBadge,   // Pro only
}

class PaywallGate extends StatelessWidget {
  final PremiumFeature feature;
  final Widget child;
  final String? customTitleAr;
  final String? customTitleEn;

  const PaywallGate({
    super.key,
    required this.feature,
    required this.child,
    this.customTitleAr,
    this.customTitleEn,
  });

  static bool canAccess(dynamic user, PremiumFeature feature) {
    if (user == null) return false;
    // Doctors get ALL features for free
    if (user.isDoctor == true) return true;
    switch (feature) {
      case PremiumFeature.unlimitedAi:
        return user.isPro == true;
      case PremiumFeature.extraOffline:
        return true; // ✅ Offline is FREE for all users
      case PremiumFeature.extraFlashcards:
      case PremiumFeature.extraStreakFreezes:
      case PremiumFeature.adFree:
      case PremiumFeature.buyMaterials:
        return user.isPremium == true;
      case PremiumFeature.advancedReports:
      case PremiumFeature.leaderboardBadge:
        return user.isPro == true;
    }
  }

  static String requiredPlan(PremiumFeature feature) {
    switch (feature) {
      case PremiumFeature.unlimitedAi:
      case PremiumFeature.advancedReports:
      case PremiumFeature.leaderboardBadge:
        return 'pro';
      default:
        return 'plus';
    }
  }

  static void showUpgradeSheet(BuildContext context, {
    PremiumFeature? feature,
    String? titleAr,
    String? titleEn,
  }) {
    final isAr = context.read<AppProvider>().isArabic;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UpgradeSheet(
        isAr: isAr,
        feature: feature,
        titleAr: titleAr,
        titleEn: titleEn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (canAccess(user, feature)) return child;

    final isAr = context.watch<AppProvider>().isArabic;
    return GestureDetector(
      onTap: () => showUpgradeSheet(context,
          feature: feature,
          titleAr: customTitleAr,
          titleEn: customTitleEn),
      child: Stack(children: [
        // Blurred / greyed child
        IgnorePointer(
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix([
              0.3,0,0,0,0,  0,0.3,0,0,0,  0,0,0.3,0,0,  0,0,0,0.4,0,
            ]),
            child: child,
          ),
        ),
        // Lock overlay
        Positioned.fill(child: Center(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔒', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 6),
              Text(
                isAr ? 'ميزة مدفوعة' : 'Premium Feature',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                requiredPlan(feature) == 'pro'
                    ? (isAr ? 'يتطلب خطة برو' : 'Requires Pro plan')
                    : (isAr ? 'يتطلب خطة بلص أو برو' : 'Requires Plus or Pro'),
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(isAr ? 'اشترك الآن' : 'Upgrade Now',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]))),
      ]),
    );
  }
}

// ── Upgrade bottom sheet ──────────────────────────────────────────────────────
class _UpgradeSheet extends StatelessWidget {
  final bool isAr;
  final PremiumFeature? feature;
  final String? titleAr, titleEn;
  const _UpgradeSheet({required this.isAr, this.feature, this.titleAr, this.titleEn});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPro  = feature != null && PaywallGate.requiredPlan(feature!) == 'pro';
    final color  = isPro ? const Color(0xFFFF9F1C) : const Color(0xFF4361EE);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1730) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),

        Text(isPro ? '🥇' : '🥈', style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),

        Text(
          titleAr != null && isAr ? titleAr!
              : titleEn != null && !isAr ? titleEn!
              : (isAr ? 'هذه الميزة حصرية للمشتركين' : 'This feature is for subscribers'),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isPro
              ? (isAr
                  ? 'اشترك في برو بـ 100 جنيه/شهر وافتح كل الإمكانيات'
                  : 'Subscribe to Pro for 100 EGP/month and unlock everything')
              : (isAr
                  ? 'اشترك في بلص بـ 50 جنيه/شهر أو برو بـ 100 جنيه/شهر'
                  : 'Subscribe to Plus for 50 EGP/mo or Pro for 100 EGP/mo'),
          style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // What you get
        ..._perks(isAr, isPro).map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(Icons.check_circle_rounded, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(p, style: const TextStyle(fontSize: 13))),
          ]),
        )),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const PremiumScreen()));
            },
            child: Text(
              isAr ? 'اشترك الآن 👑' : 'Subscribe Now 👑',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isAr ? 'ربما لاحقاً' : 'Maybe Later',
              style: TextStyle(color: Colors.grey[500])),
        ),
      ]),
    );
  }

  List<String> _perks(bool isAr, bool isPro) {
    if (isPro) {
      return isAr
        ? ['AI غير محدود ♾️', 'تقارير أسبوعية متقدمة', 'Streak Freezes غير محدودة',
           'شارة مميزة في الـ Leaderboard', 'بدون إعلانات تماماً']
        : ['Unlimited AI ♾️', 'Advanced weekly reports', 'Unlimited streak freezes',
           'Premium leaderboard badge', 'Completely ad-free'];
    }
    return isAr
        ? ['AI 20 مرة/يوم', 'حتى 10 مجموعات فلاش كارد', 'تحميل 20 ملف offline',
           'شراء مواد الدكاترة', 'بدون إعلانات']
        : ['20 AI uses/day', 'Up to 10 flashcard decks', 'Download 20 files offline',
           'Buy doctor materials', 'Ad-free experience'];
  }
}