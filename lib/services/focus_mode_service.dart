import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Singleton ChangeNotifier — manages Focus Mode:
/// - INTERRUPTION_FILTER_NONE: silences all calls & blocks all notifications
class FocusModeService extends ChangeNotifier {
  FocusModeService._();
  static final FocusModeService instance = FocusModeService._();

  static const _channel = MethodChannel('studyhub/focus');

  bool _active = false;
  bool get isActive => _active;

  // ── DND Permission check ──────────────────────────────────────────────────
  Future<bool> hasDndPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Enable Focus Mode ─────────────────────────────────────────────────────
  /// INTERRUPTION_FILTER_NONE → calls silenced + 0 notifications shown at all.
  Future<bool> enable() async {
    try {
      final result = await _channel.invokeMethod<bool>('enableFocus');
      if (result == true) {
        _active = true;
        notifyListeners();
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_REQUIRED') return false;
      return false;
    }
  }

  // ── Disable Focus Mode ────────────────────────────────────────────────────
  Future<void> disable() async {
    try {
      await _channel.invokeMethod('disableFocus');
    } catch (_) {}
    _active = false;
    notifyListeners();
  }

  // ── Toggle ────────────────────────────────────────────────────────────────
  Future<bool> toggle() async {
    if (_active) {
      await disable();
      return false;
    }
    return await enable();
  }
}
