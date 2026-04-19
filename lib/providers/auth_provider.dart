import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  /// Completes once the first Firebase auth-state event has been fully processed
  /// (including loading the user document from Firestore, if signed in).
  late final Future<void> authReady;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _auth.currentUser != null && _currentUser != null;

  AuthProvider() {
    // Resolve authReady after the very first auth-state event.
    // Capped at 6 seconds so the splash never hangs indefinitely.
    authReady = _auth.authStateChanges().first.then((user) async {
      if (user != null) await _loadUser(user.uid);
    }).timeout(
      const Duration(seconds: 6),
      onTimeout: () {/* just proceed — show login */},
    );

    // Keep listening for subsequent changes (login / logout).
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _loadUser(user.uid);
      } else { _currentUser = null; notifyListeners(); }
    });
  }

  Future<void> _loadUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Load user error: $e');
      // Don't rethrow — let authReady complete and show login
    }
  }

  /// Re-fetch the current user's Firestore document and update state.
  Future<void> reloadCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _loadUser(uid);
  }

  // ── REGISTER STUDENT ───────────────────────────────────────────────────────
  Future<bool> registerStudent({
    required String email,
    required String password,
    String? fullName,                         // ← الاسم اختياري، fallback للإيميل
    required String universityAr,
    required String universityEn,
    required String facultyAr,
    required String facultyEn,
    required int year,
  }) async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final user = UserModel(
        uid: cred.user!.uid,
        email: email,
        role: 'student',
        fullName: (fullName != null && fullName.trim().isNotEmpty)
            ? fullName.trim()
            : null,
        universityAr: universityAr, universityEn: universityEn,
        facultyAr: facultyAr,       facultyEn: facultyEn,
        year: year,
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(user.uid).set({
        ...user.toMap(),
        'verificationStatus': 'pending',   // admin must approve
        'isVerified': false,
      });
      _currentUser = user; _isLoading = false; notifyListeners(); return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseErr(e.code); _isLoading = false; notifyListeners(); return false;
    }
  }

  // ── REGISTER DOCTOR ────────────────────────────────────────────────────────
  Future<bool> registerDoctor({
    required String email,
    required String password,
    required String fullName,
    required String universityAr,
    required String universityEn,
    required String facultyAr,
    required String facultyEn,
    List<Map<String, String>>? teachingAt,
  }) async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Auto-build teachingAt from the first university/faculty if not provided
      final finalTeachingAt = (teachingAt != null && teachingAt.isNotEmpty)
          ? teachingAt
          : [
              if (universityAr.isNotEmpty || universityEn.isNotEmpty)
                {
                  'uniAr': universityAr,
                  'uniEn': universityEn,
                  'facAr': facultyAr,
                  'facEn': facultyEn,
                }
            ];

      final user = UserModel(
        uid: cred.user!.uid,
        email: email,
        role: 'doctor',
        fullName: fullName.trim().isEmpty ? null : fullName.trim(),
        universityAr: universityAr, universityEn: universityEn,
        facultyAr: facultyAr,       facultyEn: facultyEn,
        teachingAt: finalTeachingAt
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(user.uid).set({
        ...user.toMap(),
        'verificationStatus': 'pending',   // admin must approve
        'isVerified': false,
      });
      _currentUser = user; _isLoading = false; notifyListeners(); return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseErr(e.code); _isLoading = false; notifyListeners(); return false;
    }
  }

  // ── LOGIN ──────────────────────────────────────────────────────────────────
  Future<bool> login({required String email, required String password}) async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      await _loadUser(cred.user!.uid);
      _isLoading = false; notifyListeners(); return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseErr(e.code); _isLoading = false; notifyListeners(); return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    try { await _auth.sendPasswordResetEmail(email: email); return true; }
    catch (_) { return false; }
  }

  // ── YEAR PROMOTION ─────────────────────────────────────────────────────────
  int getMaxYearForUser() {
    if (_currentUser == null) return 4;
    final fac = _currentUser!.facultyAr;
    if (fac.contains('الطب') && !fac.contains('الأسنان')) return 6;
    if (fac.contains('الأسنان') || fac.contains('الصيدلة') ||
        fac.contains('العلاج الطبيعي') || fac.contains('الهندسة')) {
      return 5;
    }
    return 4;
  }

  /// Promotes student to next year. Returns new year on success, null on fail/max.
  Future<int?> promoteToNextYear() async {
    if (_currentUser == null || !_currentUser!.isStudent) return null;
    final currentYear = _currentUser!.year ?? 1;
    final maxYear = getMaxYearForUser();
    if (currentYear >= maxYear) return null;
    final newYear = currentYear + 1;
    try {
      await _db.collection('users').doc(_currentUser!.uid).update({'year': newYear});
      _currentUser = _currentUser!.copyWith(year: newYear);
      notifyListeners();
      return newYear;
    } catch (e) {
      debugPrint('Promote year error: $e');
      return null;
    }
  }

  // ── ERROR PARSER ───────────────────────────────────────────────────────────
  String _parseErr(String code) {
    switch (code) {
      case 'email-already-in-use': return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password':        return 'كلمة المرور ضعيفة جداً (6 أحرف على الأقل)';
      case 'invalid-email':        return 'البريد الإلكتروني غير صحيح';
      case 'user-not-found':       return 'المستخدم غير موجود';
      case 'wrong-password':       return 'كلمة المرور غير صحيحة';
      case 'too-many-requests':    return 'محاولات كثيرة، حاول لاحقاً';
      case 'network-request-failed': return 'تحقق من اتصالك بالإنترنت';
      default:                     return 'حدث خطأ، يرجى المحاولة مرة أخرى';
    }
  }
}