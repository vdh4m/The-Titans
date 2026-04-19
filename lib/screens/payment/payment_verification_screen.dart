import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_theme.dart';
import 'paymob_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PaymentVerificationScreen
//  - Wallet: shows "Check your phone for OTP" + polling button
//  - Fawry:  shows reference number to pay at outlet
// ─────────────────────────────────────────────────────────────────────────────
class PaymentVerificationScreen extends StatefulWidget {
  final PaymobResult result;
  final bool isAr;
  final String planName;
  const PaymentVerificationScreen({
    super.key,
    required this.result,
    required this.isAr,
    required this.planName,
  });
  @override State<PaymentVerificationScreen> createState() =>
      _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState
    extends State<PaymentVerificationScreen> {
  bool _verifying = false;
  bool _verified  = false;
  String _error   = '';
  int _pollCount  = 0;
  Timer? _autoPoller;

  @override
  void initState() {
    super.initState();
    // For wallet payments, auto-poll every 5 seconds (up to 12 times = 1 min)
    if (widget.result.status == PaymobStatus.pending) {
      _autoPoller = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (_pollCount >= 12 || _verified) {
          _autoPoller?.cancel();
          return;
        }
        _pollCount++;
        await _verify(auto: true);
      });
    }
  }

  @override void dispose() { _autoPoller?.cancel(); super.dispose(); }

  Future<void> _verify({bool auto = false}) async {
    final result = widget.result;
    if (result.orderId == null || result.uid == null || result.planKey == null) {
      setState(() => _error = 'Missing payment info');
      return;
    }
    if (!auto) setState(() { _verifying = true; _error = ''; });

    final paid = await PaymobService.verifyAndActivate(
      uid:     result.uid!,
      orderId: result.orderId!,
      planKey: result.planKey!,
    );

    if (!mounted) return;
    if (paid) {
      _autoPoller?.cancel();
      setState(() { _verified = true; _verifying = false; });
    } else if (!auto) {
      setState(() {
        _verifying = false;
        _error = widget.isAr
            ? 'لم يتم تأكيد الدفع بعد — حاول مرة أخرى'
            : 'Payment not confirmed yet — try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr     = widget.isAr;
    final isFawry  = widget.result.status == PaymobStatus.fawry;
    final refNum   = widget.result.fawryReference ?? '';

    if (_verified) return _SuccessView(isAr: isAr, planName: widget.planName);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'تأكيد الدفع' : 'Payment Confirmation'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

          Text(isFawry ? '🏪' : '📱',
              style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 20),

          Text(
            isFawry
                ? (isAr ? 'ادفع في فرع فوري' : 'Pay at a Fawry outlet')
                : (isAr ? 'أكمل الدفع على موبايلك' : 'Complete payment on your phone'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          if (isFawry) ...[
            Text(isAr ? 'الرقم المرجعي:' : 'Reference Number:',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: refNum));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isAr ? 'تم نسخ الرقم' : 'Copied!'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A850).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00A850).withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(refNum,
                      style: const TextStyle(
                          color: Color(0xFF00A850),
                          fontWeight: FontWeight.w900, fontSize: 24,
                          fontFamily: 'monospace', letterSpacing: 2)),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy_rounded,
                      color: Color(0xFF00A850), size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isAr
                    ? '1. اذهب لأي فرع فوري قريب منك\n2. قل للكاشير "دفع فاتورة"\n3. أعطه الرقم المرجعي\n4. ادفع المبلغ\n5. ارجع هنا واضغط "تحقق من الدفع"'
                    : '1. Go to any Fawry outlet near you\n2. Tell the cashier "Bill payment"\n3. Give them the reference number\n4. Pay the amount\n5. Come back here and tap "Verify Payment"',
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 13, height: 1.7),
              ),
            ),
          ] else ...[
            Text(
              isAr
                  ? 'تحقق من موبايلك — هتوصلك رسالة OTP لتأكيد الدفع من فودافون/أورانج/اتصالات كاش'
                  : 'Check your phone — you\'ll receive an OTP to confirm the payment from your mobile wallet',
              style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Auto-polling indicator
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: AppTheme.primaryColor)),
              const SizedBox(width: 8),
              Text(
                isAr ? 'جاري التحقق تلقائياً...' : 'Auto-checking...',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ]),
          ],

          const SizedBox(height: 28),

          if (_error.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error,
                  style: const TextStyle(color: Colors.orange, fontSize: 13)),
            ),

          // Manual verify button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _verifying ? null : () => _verify(),
              icon: _verifying
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.verified_rounded, color: Colors.white),
              label: Text(
                isAr ? 'تحقق من الدفع' : 'Verify Payment',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final bool isAr; final String planName;
  const _SuccessView({required this.isAr, required this.planName});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🎉', style: TextStyle(fontSize: 80)),
        const SizedBox(height: 20),
        Text(isAr ? 'تم الاشتراك بنجاح!' : 'Subscription Activated!',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          isAr
              ? 'مرحباً في خطة $planName 🚀\nاستمتع بكل الميزات الجديدة'
              : 'Welcome to $planName 🚀\nEnjoy all the premium features',
          style: TextStyle(color: Colors.grey[500], fontSize: 15, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            minimumSize: const Size(220, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
          icon: const Icon(Icons.home_rounded, color: Colors.white),
          label: Text(isAr ? 'ابدأ الاستخدام' : 'Start Exploring',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ]),
    )),
  );
}