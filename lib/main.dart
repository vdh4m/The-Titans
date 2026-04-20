import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:studyhub/generated/l10n/app_localizations.dart';
import 'package:studyhub/offline_manager.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/study_provider.dart';
import 'utils/app_theme.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';
import 'services/focus_mode_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: 'https://tejcnrnqugtspzcrutix.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlamNucm5xdWd0c3B6Y3J1dGl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2ODI1NDMsImV4cCI6MjA5MjI1ODU0M30.rM0JfUl98ixEUmDfoou0UGR2qcj43IaMSbwwN-Xy-rs',
  );
  await OfflineManager.init();
  // Auto-enable Focus Mode (DND) on every launch
  try { await FocusModeService.instance.enable(); } catch (_) {}
  runApp(const EduApp());
}

class EduApp extends StatelessWidget {
  const EduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudyProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (_, appProvider, __) => MaterialApp(
          title: 'StudyHub',
          debugShowCheckedModeBanner: false,
          color: const Color(0xFF3A90A3), // matches SplashScreen._bg → no black flash
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          locale: appProvider.locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection:
                appProvider.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
