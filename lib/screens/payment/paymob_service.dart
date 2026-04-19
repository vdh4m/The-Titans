import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PaymobService — Handles payment via Paymob (Egypt)
//  Supports: Vodafone Cash, Orange Cash, Etisalat Cash, WE Pay, Fawry, Meeza
//
//  Setup:
//  1. Create account at paymob.com
//  2. Get API Key from Dashboard → Settings → API Keys
//  3. Create an Integration for each payment method
//  4. Set your Integration IDs below
// ─────────────────────────────────────────────────────────────────────────────
class PaymobService {
  // ── Replace with your actual Paymob credentials ───────────────────────────
  static const _apiKey              = 'ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SmpiR0Z6Y3lJNklrMWxjbU5vWVc1MElpd2ljSEp2Wm1sc1pWOXdheUk2TVRFME16STRNeXdpYm1GdFpTSTZJbWx1YVhScFlXd2lmUS5EcllUcXI5bnk1MFFNOV9ydUxMVDl3bEhvZTROakJ3Ymt5WVhTQ0FXZEVyS3E3M1daVmtpbVNScHV2M2pfdTF4bE1IVmtuOTBseFZ6NTNTcTgtMHJ6dw==';
  static const _mobileWalletIntId   = '5586801';  // Vodafone/Orange/Etisalat Cash
  static const _fawryIntId          = '5586803';
  // ignore: unused_field
  static const _cardIntId           = '5586798';           // Visa/Mastercard/Meeza

  static const _baseUrl = 'https://accept.paymob.com/api';

  // ── Plan prices in piasters (1 EGP = 100 piasters) ───────────────────────
  static const Map<String, Map<String, dynamic>> plans = {
    'plus_monthly': {
      'nameAr': 'بلص شهري',
      'nameEn': 'Plus Monthly',
      'price':  5000,   // 50 EGP
      'planId': 'plus',
      'months': 1,
    },
    'plus_yearly': {
      'nameAr': 'بلص سنوي',
      'nameEn': 'Plus Yearly',
      'price':  45000,  // 450 EGP (save 150)
      'planId': 'plus',
      'months': 12,
    },
    'pro_monthly': {
      'nameAr': 'برو شهري',
      'nameEn': 'Pro Monthly',
      'price':  10000,  // 100 EGP
      'planId': 'pro',
      'months': 1,
    },
    'pro_yearly': {
      'nameAr': 'برو سنوي',
      'nameEn': 'Pro Yearly',
      'price':  90000,  // 900 EGP (save 300)
      'planId': 'pro',
      'months': 12,
    },
  };

  // ── Step 1: Authenticate and get auth token ───────────────────────────────
  static Future<String?> _getAuthToken() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/tokens'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': _apiKey}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 201) {
        return jsonDecode(res.body)['token'] as String?;
      }
    } catch (e) { debugPrint('Paymob auth error: $e'); }
    return null;
  }

  // ── Step 2: Create order ──────────────────────────────────────────────────
  static Future<String?> _createOrder(
      String authToken, int amountCents, String planKey) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/ecommerce/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'auth_token':           authToken,
          'delivery_needed':      false,
          'amount_cents':         amountCents,
          'currency':             'EGP',
          'items':                [],
          'merchant_order_id':    'studyhub_${DateTime.now().millisecondsSinceEpoch}',
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 201) {
        return jsonDecode(res.body)['id']?.toString();
      }
    } catch (e) { debugPrint('Paymob order error: $e'); }
    return null;
  }

  // ── Step 3: Get payment key ───────────────────────────────────────────────
  static Future<String?> _getPaymentKey({
    required String authToken,
    required String orderId,
    required int amountCents,
    required String integrationId,
    required Map<String, String> billing,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/acceptance/payment_keys'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'auth_token':     authToken,
          'amount_cents':   amountCents,
          'expiration':     3600,
          'order_id':       orderId,
          'billing_data':   {
            'apartment':       'NA',
            'email':           billing['email'] ?? 'NA',
            'floor':           'NA',
            'first_name':      billing['firstName'] ?? 'Student',
            'last_name':       billing['lastName']?.isNotEmpty == true ? billing['lastName']! : 'NA',
            'street':          'NA',
            'building':        'NA',
            'phone_number':    billing['phone'] ?? '+201000000000',
            'shipping_method': 'NA',
            'postal_code':     'NA',
            'city':            'Cairo',
            'country':         'EG',
            'state':           'Cairo',
          },
          'currency':       'EGP',
          'integration_id': int.parse(integrationId),
          'lock_order_when_paid': true,
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 201) {
        return jsonDecode(res.body)['token'] as String?;
      }
      // ── Log exact error so we can diagnose ──────────────────────────────
      debugPrint('❌ Paymob payment_key failed: status=${res.statusCode}');
      debugPrint('❌ Paymob response body: ${res.body}');
    } catch (e) { debugPrint('Paymob payment key error: $e'); }
    return null;
  }

  // ── Pay with Mobile Wallet (Vodafone Cash etc.) ───────────────────────────
  static Future<PaymobResult> payWithMobileWallet({
    required String uid,
    required String email,
    required String phone,       // e.g. 01012345678
    required String planKey,
    required BuildContext context,
  }) async {
    final plan = plans[planKey];
    if (plan == null) return PaymobResult.error('Invalid plan');

    try {
      // 1. Auth
      final authToken = await _getAuthToken();
      if (authToken == null) return PaymobResult.error('Auth failed');

      // 2. Order
      final orderId = await _createOrder(authToken, plan['price'] as int, planKey);
      if (orderId == null) return PaymobResult.error('Order creation failed');

      // 3. Payment key
      final payKey = await _getPaymentKey(
        authToken: authToken,
        orderId: orderId,
        amountCents: plan['price'] as int,
        integrationId: _mobileWalletIntId,
        billing: {'email': email, 'phone': '+2$phone', 'firstName': 'Student'},
      );
      if (payKey == null) return PaymobResult.error('Payment key failed');

      // 4. Initiate wallet payment
      final walletRes = await http.post(
        Uri.parse('$_baseUrl/acceptance/payments/pay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'source': {
            'identifier': phone,
            'subtype':    'WALLET',
          },
          'payment_token': payKey,
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Wallet status: ${walletRes.statusCode}');
      debugPrint('Wallet body: ${walletRes.body}');

      if (walletRes.statusCode == 200) {
        final data = jsonDecode(walletRes.body);
        final success     = data['success'] as bool? ?? false;
        final pending     = data['pending'] as bool? ?? false;
        final redirectUrl = data['redirect_url'] as String?;

        // Success or pending with redirect → open OTP screen
        if ((success || pending) && redirectUrl != null && redirectUrl.isNotEmpty) {
          if (await canLaunchUrl(Uri.parse(redirectUrl))) {
            await launchUrl(Uri.parse(redirectUrl),
                mode: LaunchMode.externalApplication);
          }
          return PaymobResult.pending(
              orderId: orderId, planKey: planKey, uid: uid);
        }

        // Success but no redirect (already paid?)
        if (success) {
          await _activatePlan(uid: uid, planKey: planKey);
          return PaymobResult.pending(orderId: orderId, planKey: planKey, uid: uid);
        }

        // Failed — extract reason
        final txnResponse = data['transaction_processed_callback_responses'];
        final reason = data['data']?['message']
            ?? data['message']
            ?? (txnResponse?.toString())
            ?? 'Wallet rejected the payment (success=false)';
        debugPrint('❌ Wallet rejected: $reason');
        return PaymobResult.error(reason.toString());
      }

      debugPrint('❌ Wallet HTTP error: status=${walletRes.statusCode}  body=${walletRes.body}');
      return PaymobResult.error('Wallet payment failed (${walletRes.statusCode})');
    } catch (e) {
      return PaymobResult.error('$e');
    }
  }

  // ── Pay with Fawry ─────────────────────────────────────────────────────────
  static Future<PaymobResult> payWithFawry({
    required String uid,
    required String email,
    required String phone,
    required String planKey,
  }) async {
    final plan = plans[planKey];
    if (plan == null) return PaymobResult.error('Invalid plan');

    try {
      final authToken = await _getAuthToken();
      if (authToken == null) return PaymobResult.error('Auth failed');

      final orderId = await _createOrder(authToken, plan['price'] as int, planKey);
      if (orderId == null) return PaymobResult.error('Order creation failed');

      final payKey = await _getPaymentKey(
        authToken: authToken,
        orderId: orderId,
        amountCents: plan['price'] as int,
        integrationId: _fawryIntId,
        billing: {'email': email, 'phone': '+2$phone', 'firstName': 'Student'},
      );
      if (payKey == null) return PaymobResult.error('Payment key failed');

      // Fawry returns a reference number for payment at Fawry outlets
      final fawryRes = await http.post(
        Uri.parse('$_baseUrl/acceptance/payments/pay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'source': {
            'identifier': 'AGGREGATOR',
            'subtype':    'AGGREGATOR',
          },
          'payment_token': payKey,
        }),
      ).timeout(const Duration(seconds: 15));

      if (fawryRes.statusCode == 200) {
        final data  = jsonDecode(fawryRes.body);
        final refNum = data['data']?['bill_reference']?.toString() ?? '';
        return PaymobResult.fawry(
            referenceNumber: refNum, orderId: orderId,
            planKey: planKey, uid: uid);
      }
      return PaymobResult.error('Fawry payment failed');
    } catch (e) {
      return PaymobResult.error('$e');
    }
  }

  // ── Verify payment and upgrade user ──────────────────────────────────────
  static Future<bool> verifyAndActivate({
    required String uid,
    required String orderId,
    required String planKey,
  }) async {
    try {
      final authToken = await _getAuthToken();
      if (authToken == null) return false;

      final res = await http.get(
        Uri.parse('$_baseUrl/ecommerce/orders/$orderId'),
        headers: {'Authorization': 'Bearer $authToken'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data   = jsonDecode(res.body);
        final isPaid = data['payment_status'] == 'PAID' ||
            (data['transactions'] as List?)?.any((t) =>
                t['success'] == true) == true;

        if (isPaid) {
          await _activatePlan(uid: uid, planKey: planKey);
          return true;
        }
      }
    } catch (e) { debugPrint('Verify error: $e'); }
    return false;
  }

  // ── Activate plan in Firestore ────────────────────────────────────────────
  static Future<void> _activatePlan({
    required String uid,
    required String planKey,
  }) async {
    final plan    = plans[planKey]!;
    final months  = plan['months'] as int;
    final expiry  = DateTime.now().add(Duration(days: 30 * months));
    final planId  = plan['planId'] as String;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'planId':     planId,
      'planExpiry': expiry.toIso8601String(),
    });

    // Save subscription record
    await FirebaseFirestore.instance.collection('subscriptions').add({
      'uid':        uid,
      'planKey':    planKey,
      'planId':     planId,
      'activatedAt': DateTime.now().toIso8601String(),
      'expiresAt':   expiry.toIso8601String(),
    });
  }

  // ── Cancel / downgrade to free ────────────────────────────────────────────
  static Future<void> cancelSubscription(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'planId':     'free',
      'planExpiry': null,
    });
  }
}

// ── Result types ──────────────────────────────────────────────────────────────
class PaymobResult {
  final PaymobStatus status;
  final String? orderId;
  final String? planKey;
  final String? uid;
  final String? errorMessage;
  final String? fawryReference;

  const PaymobResult._({
    required this.status,
    this.orderId, this.planKey, this.uid,
    this.errorMessage, this.fawryReference,
  });

  factory PaymobResult.pending({
    required String orderId,
    required String planKey,
    required String uid,
  }) => PaymobResult._(status: PaymobStatus.pending,
      orderId: orderId, planKey: planKey, uid: uid);

  factory PaymobResult.fawry({
    required String referenceNumber,
    required String orderId,
    required String planKey,
    required String uid,
  }) => PaymobResult._(status: PaymobStatus.fawry,
      fawryReference: referenceNumber,
      orderId: orderId, planKey: planKey, uid: uid);

  factory PaymobResult.error(String msg) =>
      PaymobResult._(status: PaymobStatus.error, errorMessage: msg);
}

enum PaymobStatus { pending, fawry, error }