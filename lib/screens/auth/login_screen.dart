import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:studyhub/generated/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../home/main_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (ok && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();
    final ap = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final isAr = ap.isArabic;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.login),
        actions: [_TopActions(ap: ap)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Header
              Text(
                l10n.welcomeBack,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAr ? 'سجل دخولك للمتابعة' : 'Sign in to continue',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 36),

              // Email field
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? l10n.email : null,
              ),
              const SizedBox(height: 16),

              // Password field
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    v == null || v.length < 6 ? l10n.password : null,
              ),

              const SizedBox(height: 6),

              // Forgot password
              Align(
                alignment: isAr
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showResetDialog(context, l10n, ap),
                  child: Text(
                    l10n.forgotPassword,
                    style:
                        const TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
              ),

              // Error message
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    auth.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Login button
              ElevatedButton(
                onPressed: auth.isLoading ? null : _login,
                child: auth.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(l10n.login),
              ),

              const SizedBox(height: 20),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.dontHaveAccount),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    ),
                    child: Text(
                      l10n.register,
                      style: const TextStyle(
                          color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetDialog(
      BuildContext context, AppLocalizations l10n, AppProvider ap) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.resetPassword),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: l10n.email),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final ok =
                  await auth.resetPassword(ctrl.text.trim());
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? (ap.isArabic
                              ? 'تم إرسال رابط إعادة التعيين'
                              : 'Reset link sent successfully')
                          : l10n.error,
                    ),
                    backgroundColor:
                        ok ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: Text(l10n.send),
          ),
        ],
      ),
    );
  }
}

// Top bar actions (theme + language toggle)
class _TopActions extends StatelessWidget {
  final AppProvider ap;
  const _TopActions({required this.ap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            ap.isDarkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
          ),
          onPressed: ap.toggleTheme,
          color: AppTheme.primaryColor,
        ),
        IconButton(
          icon: Text(
            ap.isArabic ? 'EN' : 'ع',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
              fontSize: 14,
            ),
          ),
          onPressed: () => ap.setLocale(
            ap.isArabic
                ? const Locale('en')
                : const Locale('ar'),
          ),
        ),
      ],
    );
  }
}
