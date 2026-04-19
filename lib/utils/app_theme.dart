import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // BMC v3 palette
  static const Color primary = Color(0xFF4361EE); // student blue
  static const Color primaryDark = Color(0xFF2340C8);
  static const Color corp = Color(0xFF06D6A0); // mint
  static const Color ads = Color(0xFFF72585); // pink
  static const Color premium = Color(0xFFFF9F1C); // gold
  static const Color ai = Color(0xFF7209B7); // purple
  static const Color verified = Color(0xFF1DA1F2);

  static const Color inkDark = Color(0xFF0A0A0F);
  static const Color paperLight = Color(0xFAF9F6FF);
  static const Color creamLight = Color(0xfff2ede4ff);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF141030);
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color surfDark = Color(0xFF141030);
}

class AppTheme {
  // keep old names for compat
  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.corp;
  static const Color accentColor = AppColors.ads;
  static const Color verifiedColor = AppColors.verified;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      background: const Color(0xFFF5F4F0),
      surface: AppColors.cardLight,
    ),
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: const Color(0xFFF5F4F0),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F4F0),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.inkDark),
      titleTextStyle: TextStyle(
        color: AppColors.inkDark,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Cairo',
        letterSpacing: -0.3,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.black.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      color: AppColors.cardLight,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withOpacity(0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFF5F4F0),
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Color(0xFFADB5BD),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme:
        DividerThemeData(color: Colors.black.withOpacity(0.08), thickness: 1),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.inkDark),
      bodyMedium: TextStyle(color: AppColors.inkDark),
      bodySmall: TextStyle(color: Color(0xFF555555)),
      titleLarge:
          TextStyle(color: AppColors.inkDark, fontWeight: FontWeight.w800),
      titleMedium:
          TextStyle(color: AppColors.inkDark, fontWeight: FontWeight.w700),
      titleSmall:
          TextStyle(color: Color(0xFF444444), fontWeight: FontWeight.w600),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      background: AppColors.bgDark,
      surface: AppColors.surfDark,
    ),
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: AppColors.bgDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Cairo',
        letterSpacing: -0.3,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      color: AppColors.surfDark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgDark,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.white.withOpacity(0.3),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme:
        DividerThemeData(color: Colors.white.withOpacity(0.08), thickness: 1),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Color(0xFFBBBBBB)),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      titleSmall:
          TextStyle(color: Color(0xFFCCCCCC), fontWeight: FontWeight.w600),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
