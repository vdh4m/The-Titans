import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../admin/support_screen.dart';
import 'welcome_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PendingApprovalScreen
//  Shown to doctors whose account is pending admin review.
//  Auto-refreshes when admin approves → navigates to MainScreen.
// ─────────────────────────────────────────────────────────────────────────────
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});
  @override State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  // ignore: unused_field
  final String _status = 'pending';
  // ignore: unused_field
  final String _rejectionReason = '';

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final data   = snap.data!.data() as Map<String, dynamic>? ?? {};
        final status = data['verificationStatus'] as String? ?? 'pending';
        final reason = data['rejectionReason']    as String? ?? '';

        // Auto-navigate when approved
        if (status == 'approved') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pushReplacementNamed('/main');
          });
        }

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon / status
                  _StatusIcon(status: status),
                  const SizedBox(height: 24),

                  Text(
                    status == 'pending'
                        ? (isAr ? 'طلبك قيد المراجعة' : 'Request Under Review')
                        : status == 'approved'
                            ? (isAr ? 'تم قبول حسابك! 🎉' : 'Account Approved! 🎉')
                            : (isAr ? 'تم رفض الطلب' : 'Request Rejected'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  Text(
                    status == 'pending'
                        ? (isAr
                            ? 'يراجع فريقنا طلبك للتحقق من هويتك كدكتور.\nعادةً يستغرق الأمر بضع ساعات.'
                            : 'Our team is reviewing your request to verify your identity as a doctor.\nThis usually takes a few hours.')
                        : status == 'rejected'
                            ? (isAr
                                ? (reason.isNotEmpty ? 'السبب: $reason' : 'يرجى التواصل مع الدعم للمزيد من التفاصيل.')
                                : (reason.isNotEmpty ? 'Reason: $reason' : 'Please contact support for more details.'))
                            : (isAr ? 'يمكنك الآن استخدام الأب.' : 'You can now use the app.'),
                    style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Steps (pending only)
                  if (status == 'pending') ...[
                    _Step(number: '1', isAr: isAr,
                        titleAr: 'أكملت التسجيل',    titleEn: 'Registration complete',
                        done: true),
                    _Step(number: '2', isAr: isAr,
                        titleAr: 'مراجعة الفريق',    titleEn: 'Team review',
                        active: true),
                    _Step(number: '3', isAr: isAr,
                        titleAr: 'تأكيد الحساب',     titleEn: 'Account confirmed'),
                    const SizedBox(height: 28),
                  ],

                  // Contact support button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SupportScreen())),
                      icon: const Icon(Icons.headset_mic_rounded, color: Colors.white),
                      label: Text(
                        isAr ? 'تواصل مع الدعم الفني' : 'Contact Support',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Logout
                  TextButton(
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                          (_) => false,
                        );
                      }
                    },
                    child: Text(isAr ? 'تسجيل الخروج' : 'Log Out',
                        style: TextStyle(color: Colors.grey[500])),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});
  @override
  Widget build(BuildContext context) {
    if (status == 'approved') return const Text('🎉', style: TextStyle(fontSize: 80));
    if (status == 'rejected') return const Text('❌', style: TextStyle(fontSize: 80));
    // Pending — animated spinner
    return Stack(alignment: Alignment.center, children: [
      SizedBox(
        width: 90, height: 90,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: const Center(child: Text('🔐', style: TextStyle(fontSize: 34))),
      ),
    ]);
  }
}

class _Step extends StatelessWidget {
  final String number, titleAr, titleEn; final bool isAr, done, active;
  const _Step({required this.number, required this.isAr,
      required this.titleAr, required this.titleEn,
      this.done = false, this.active = false});
  @override
  Widget build(BuildContext context) {
    final color = done ? Colors.green : active ? AppTheme.primaryColor : Colors.grey.shade400;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(child: done
              ? Icon(Icons.check_rounded, color: color, size: 16)
              : active
                  ? SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(color: color, strokeWidth: 2))
                  : Text(number, style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 12))),
        ),
        const SizedBox(width: 12),
        Text(isAr ? titleAr : titleEn,
            style: TextStyle(
              fontWeight: active || done ? FontWeight.w700 : FontWeight.w400,
              color: done ? Colors.green : active ? null : Colors.grey,
            )),
      ]),
    );
  }
}