import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:studyhub/generated/l10n/app_localizations.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ap = context.watch<AppProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        _LangBtn(label: 'ع', selected: ap.isArabic, onTap: () => ap.setLocale(const Locale('ar'))),
                        _LangBtn(label: 'EN', selected: !ap.isArabic, onTap: () => ap.setLocale(const Locale('en'))),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: ap.toggleTheme,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(ap.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
                ),
                child: const Icon(Icons.school_rounded, size: 65, color: Colors.white),
              ).animate().fadeIn(duration: 600.ms).scale(),
              const SizedBox(height: 28),
              Text(l10n.appName, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 36, fontWeight: FontWeight.bold))
                  .animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 10),
              Text(ap.isArabic ? 'منصتك التعليمية المتكاملة' : 'Your Complete Educational Platform',
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  textAlign: TextAlign.center).animate().fadeIn(delay: 300.ms),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: Text(l10n.register),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  foregroundColor: AppTheme.primaryColor,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                child: Text(l10n.login),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangBtn extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _LangBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(
        color: selected ? Colors.white : Colors.grey,
        fontWeight: FontWeight.bold, fontFamily: 'Cairo',
      )),
    ),
  );
}