import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {

  bool _isDarkMode =
      PlatformDispatcher.instance.platformBrightness == Brightness.dark;

  Locale _locale = PlatformDispatcher.instance.locale;

  bool get isDarkMode => _isDarkMode;
  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  AppProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey('isDarkMode')) {
      _isDarkMode = prefs.getBool('isDarkMode')!;
    }

    if (prefs.containsKey('language')) {
      _locale = Locale(prefs.getString('language')!);
    }

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);

    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', locale.languageCode);

    notifyListeners();
  }
}