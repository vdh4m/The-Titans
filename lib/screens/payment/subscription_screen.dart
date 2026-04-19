import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import 'paymob_service.dart';
import 'premium_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SubscriptionScreen — Manage current subscription
// ─────────────────────────────────────────────────────────────────────────────
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr   = context.watch<AppProvider>().isArabic;
    final user   = context.watch<AuthProvider>().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? '⭐ اشتراكي' : '⭐ My Subscription'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Current plan card ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: user.isPro
                    ? [const Color(0xFFFF9F1C), const Color(0xFFFF6B35)]
                    : user.isPlus
                        ? [const Color(0xFF4361EE), const Color(0xFF7209B7)]
                        : [Colors.grey.shade600, Colors.grey.shade700],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(user.isPro ? '🥇' : user.isPlus ? '🥈' : '🆓',
                    style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isAr
                        ? (user.isPro ? 'خطة برو' : user.isPlus ? 'خطة بلص' : 'المجاني')
                        : (user.isPro ? 'Pro Plan' : user.isPlus ? 'Plus Plan' : 'Free Plan'),
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                  if (user.isPremium && user.planExpiry != null)
                    Text(
                      '${isAr ? "تنتهي في" : "Expires"} ${_fmtDate(user.planExpiry!)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    )
                  else
                    Text(isAr ? 'مجاني للأبد' : 'Forever free',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ]),

              if (user.isPremium) ...[
                const SizedBox(height: 16),
                // Expiry progress bar
                Builder(builder: (_) {
                  if (user.planExpiry == null) return const SizedBox.shrink();
                  final total = 30.0; // assume monthly
                  final left  = user.planExpiry!.difference(DateTime.now()).inDays.toDouble().clamp(0, 30);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(isAr ? 'أيام متبقية' : 'Days remaining',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('${left.toInt()} ${isAr ? "يوم" : "days"}',
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: left / total,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                  ]);
                }),
              ],
            ]),
          ),
          const SizedBox(height: 24),

          // ── Usage stats ──────────────────────────────────────────────
          Text(isAr ? 'استخدامك اليوم' : 'Today\'s Usage',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _UsageTile(
              icon: Icons.auto_awesome_rounded,
              label: isAr ? 'AI' : 'AI',
              used: user.aiUsesToday,
              limit: user.aiDailyLimit,
              color: const Color(0xFF7209B7),
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _UsageTile(
              icon: Icons.style_rounded,
              label: isAr ? 'Decks' : 'Decks',
              used: user.flashcardDecks,
              limit: user.maxDecks,
              color: AppTheme.primaryColor,
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _UsageTile(
              icon: Icons.offline_bolt_rounded,
              label: isAr ? 'Offline' : 'Offline',
              used: user.offlineFiles,
              limit: user.maxOffline,
              color: const Color(0xFF06D6A0),
              isDark: isDark,
            )),
          ]),
          const SizedBox(height: 24),

          // ── Billing history ──────────────────────────────────────────
          Text(isAr ? 'سجل الدفع' : 'Billing History',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('subscriptions')
                .where('uid', isEqualTo: user.uid)
                .orderBy('activatedAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator());
              }
              if (snap.data!.docs.isEmpty) {
                return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1730) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(isAr ? 'لا يوجد سجل دفع بعد' : 'No billing history yet',
                    style: TextStyle(color: Colors.grey[500])),
              );
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final plan = PaymobService.plans[d['planKey']] ??
                      {'nameAr': d['planId'], 'nameEn': d['planId'], 'price': 0};
                  final date = DateTime.tryParse(d['activatedAt'] ?? '') ?? DateTime.now();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1730) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_rounded,
                            color: AppTheme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isAr ? plan['nameAr'] as String : plan['nameEn'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(_fmtDate(date),
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ])),
                      Text(
                        '${(plan['price'] as int) ~/ 100} ${isAr ? "جنيه" : "EGP"}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor),
                      ),
                    ]),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Upgrade / Cancel buttons ─────────────────────────────────
          if (!user.isPro)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9F1C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PremiumScreen())),
                icon: const Icon(Icons.upgrade_rounded, color: Colors.white),
                label: Text(
                  isAr ? 'ترقية الخطة' : 'Upgrade Plan',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),

          if (user.isPremium) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _confirmCancel(context, isAr, user.uid),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(isAr ? 'إلغاء الاشتراك' : 'Cancel Subscription'),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _confirmCancel(
      BuildContext ctx, bool isAr, String uid) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'إلغاء الاشتراك؟' : 'Cancel Subscription?'),
        content: Text(isAr
            ? 'ستبقى مميزات الاشتراك فعّالة حتى نهاية الفترة المدفوعة'
            : 'Your premium features will remain active until the end of the paid period.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'تراجع' : 'Keep Plan')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'إلغاء الاشتراك' : 'Cancel',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await PaymobService.cancelSubscription(uid);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(isAr ? 'تم إلغاء الاشتراك' : 'Subscription cancelled'),
        behavior: SnackBarBehavior.floating,
      ));
      }
    }
  }
}

class _UsageTile extends StatelessWidget {
  final IconData icon; final String label;
  final int used, limit; final Color color; final bool isDark;
  const _UsageTile({required this.icon, required this.label,
      required this.used, required this.limit,
      required this.color, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final pct  = limit > 900 ? 0.1 : used / limit.toDouble();
    final full = limit > 900;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1730) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          full ? '$used / ♾️' : '$used / $limit',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: full ? 0.15 : pct.clamp(0.0, 1.0),
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
      ]),
    );
  }
}