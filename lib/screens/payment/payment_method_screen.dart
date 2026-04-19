import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_theme.dart';
import 'paymob_service.dart';
import 'payment_verification_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PaymentMethodScreen — Choose payment method + enter phone number
// ─────────────────────────────────────────────────────────────────────────────
class PaymentMethodScreen extends StatefulWidget {
  final String planKey, uid, email;
  final bool isAr;
  const PaymentMethodScreen({
    super.key,
    required this.planKey,
    required this.uid,
    required this.email,
    required this.isAr,
  });
  @override State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final _phoneCtrl = TextEditingController();
  String _method   = 'vodafone';   // vodafone | orange | etisalat | fawry
  bool   _loading  = false;
  String _error    = '';

  @override void dispose() { _phoneCtrl.dispose(); super.dispose(); }

  Map<String, dynamic> get _plan => PaymobService.plans[widget.planKey]!;

  Future<void> _pay() async {
    var phone = _phoneCtrl.text.trim();

    // ── Normalize to 01XXXXXXXXX (10 digits) ──────────────────────────────
    if (phone.startsWith('+2'))  phone = phone.substring(2);  // +201... → 01...
    if (phone.startsWith('20') && phone.length == 12) phone = phone.substring(2); // 2001... → 01...
    if (phone.length != 11 || !phone.startsWith('0')) {
      setState(() => _error = widget.isAr
          ? 'أدخل الرقم بصيغة 01XXXXXXXXX (11 رقم)' : 'Enter number as 01XXXXXXXXX (11 digits)');
      return;
    }

    setState(() { _loading = true; _error = ''; });

    PaymobResult result;
    if (_method == 'fawry') {
      result = await PaymobService.payWithFawry(
        uid: widget.uid, email: widget.email,
        phone: phone, planKey: widget.planKey,
      );
    } else {
      result = await PaymobService.payWithMobileWallet(
        uid: widget.uid, email: widget.email,
        phone: phone, planKey: widget.planKey,
        context: context,
      );
    }

    setState(() => _loading = false);

    if (!mounted) return;

    if (result.status == PaymobStatus.error) {
      setState(() => _error = result.errorMessage ?? 'Payment failed');
      return;
    }

    // Navigate to verification screen
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => PaymentVerificationScreen(
        result: result,
        isAr: widget.isAr,
        planName: widget.isAr
            ? (_plan['nameAr'] as String)
            : (_plan['nameEn'] as String),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr   = widget.isAr;
    final plan   = _plan;
    final price  = plan['price'] as int;
    final priceEgp = price ~/ 100;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'طريقة الدفع' : 'Payment Method'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Order summary ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1730) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.25)),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('👑',
                    style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAr ? plan['nameAr'] as String : plan['nameEn'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                Text(isAr ? 'اشتراك StudyHub' : 'StudyHub Subscription',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ])),
              Text(
                '$priceEgp ${isAr ? 'جنيه' : 'EGP'}',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 18,
                    color: AppTheme.primaryColor),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Method selector ─────────────────────────────────────────
          Text(isAr ? 'اختر طريقة الدفع' : 'Choose payment method',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),

          ..._methods(isAr).map((m) => _MethodTile(
            id: m['id'] as String,
            logo: m['logo'] as String,
            nameAr: m['nameAr'] as String,
            nameEn: m['nameEn'] as String,
            subtitle: m['sub'] as String,
            selected: _method == m['id'],
            isAr: isAr, isDark: isDark,
            onTap: () => setState(() => _method = m['id'] as String),
          )),
          const SizedBox(height: 20),

          // ── Phone number ────────────────────────────────────────────
          Text(
            _method == 'fawry'
                ? (isAr ? 'رقم الموبايل (للإشعار)' : 'Phone (for notification)')
                : (isAr ? 'رقم المحفظة' : 'Wallet Number'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: InputDecoration(
              hintText: '01XXXXXXXXX',
              prefixIcon: const Icon(Icons.phone_rounded),
              suffixIcon: _method != 'fawry'
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _methodPrefix(_method),
                        style: TextStyle(color: _methodColor(_method),
                            fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _method == 'fawry'
                ? (isAr
                    ? 'ستصلك رسالة برقم مرجعي، ادفع في أي فرع فوري'
                    : 'You\'ll get a reference number to pay at any Fawry outlet')
                : (isAr
                    ? 'ستصلك رسالة OTP على رقمك لتأكيد الدفع'
                    : 'You\'ll receive an OTP to confirm the payment'),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),

          // ── Error ───────────────────────────────────────────────────
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error,
                    style: const TextStyle(color: Colors.red, fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 28),

          // ── Pay button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _methodColor(_method),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _loading ? null : _pay,
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_methodIcon(_method),
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Text(
                        isAr
                            ? 'ادفع $priceEgp جنيه'
                            : 'Pay $priceEgp EGP',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── Security note ───────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_rounded, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              isAr
                  ? 'الدفع مؤمّن عبر Paymob'
                  : 'Secured by Paymob',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ]),
        ]),
      ),
    );
  }

  List<Map<String, String>> _methods(bool isAr) => [
    {
      'id':    'vodafone',
      'logo':  '📱',
      'nameAr': 'فودافون كاش',
      'nameEn': 'Vodafone Cash',
      'sub':   isAr ? 'ادفع من محفظتك مباشرة' : 'Pay directly from your wallet',
    },
    {
      'id':    'orange',
      'logo':  '🟠',
      'nameAr': 'أورانج كاش',
      'nameEn': 'Orange Cash',
      'sub':   isAr ? 'محفظة أورانج الإلكترونية' : 'Orange electronic wallet',
    },
    {
      'id':    'etisalat',
      'logo':  '🔵',
      'nameAr': 'اتصالات كاش',
      'nameEn': 'Etisalat Cash',
      'sub':   isAr ? 'محفظة اتصالات الإلكترونية' : 'Etisalat electronic wallet',
    },
    {
      'id':    'fawry',
      'logo':  '🏪',
      'nameAr': 'فوري',
      'nameEn': 'Fawry',
      'sub':   isAr ? 'ادفع في أي نقطة فوري قريبة منك' : 'Pay at any nearby Fawry outlet',
    },
  ];

  Color  _methodColor(String m)  => m == 'vodafone' ? const Color(0xFFE60026)
      : m == 'orange' ? const Color(0xFFFF6600)
      : m == 'etisalat' ? const Color(0xFF00A850)
      : m == 'fawry' ? const Color(0xFF0033A0) : AppTheme.primaryColor;

  String _methodIcon(String m)   => m == 'vodafone' ? '📱' : m == 'orange'
      ? '🟠' : m == 'etisalat' ? '🔵' : '🏪';

  String _methodPrefix(String m) => m == 'vodafone' ? 'Vodafone'
      : m == 'orange' ? 'Orange' : 'Etisalat';
}

class _MethodTile extends StatelessWidget {
  final String id, logo, nameAr, nameEn, subtitle;
  final bool selected, isAr, isDark;
  final VoidCallback onTap;
  const _MethodTile({required this.id, required this.logo,
      required this.nameAr, required this.nameEn, required this.subtitle,
      required this.selected, required this.isAr, required this.isDark,
      required this.onTap});

  Color get _color => id == 'vodafone' ? const Color(0xFFE60026)
      : id == 'orange' ? const Color(0xFFFF6600)
      : id == 'etisalat' ? const Color(0xFF00A850)
      : const Color(0xFF0033A0);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? _color.withOpacity(0.08)
            : (isDark ? const Color(0xFF1A1730) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? _color : Colors.grey.withOpacity(0.2),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(children: [
        Text(logo, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isAr ? nameAr : nameEn,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14,
                  color: selected ? _color : null)),
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ])),
        Icon(
          selected ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          color: selected ? _color : Colors.grey,
        ),
      ]),
    ),
  );
}