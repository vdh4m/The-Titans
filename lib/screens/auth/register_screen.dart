import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:studyhub/generated/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../home/main_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _sKey = GlobalKey<FormState>();
  final _dKey = GlobalKey<FormState>();
  final _sName = TextEditingController();
  final _sEmail = TextEditingController();
  final _sPass = TextEditingController();
  final _sConfirm = TextEditingController();
  final _dEmail = TextEditingController();
  final _dPass = TextEditingController();
  final _dConfirm = TextEditingController();
  final _dName = TextEditingController();
  Map<String, dynamic>? _sUni, _sFac;
  // Doctor: list of {uni, fac} pairs (CV builder style)
  // ignore: unnecessary_question_mark
  final List<Map<String, dynamic?>> _dTeachingAt = [{'uni': null, 'fac': null}];
  int? _sYear;
  bool _sObs = true, _sObsC = true, _dObs = true, _dObsC = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override
  void dispose() {
    _tabs.dispose(); _sName.dispose(); _sEmail.dispose(); _sPass.dispose(); _sConfirm.dispose();
    _dEmail.dispose(); _dPass.dispose(); _dConfirm.dispose(); _dName.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _sFaculties => _sUni != null ? List<Map<String, dynamic>>.from(_sUni!['faculties']) : [];
  int get _maxYear => _sFac != null ? (_sFac!['years'] as int? ?? 4) : 4;

  String _yearLabel(int y, bool ar) {
    const arLabels = ['', 'الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة'];
    const enLabels = ['', 'First', 'Second', 'Third', 'Fourth', 'Fifth', 'Sixth'];
    return ar ? 'السنة ${arLabels[y]}' : '${enLabels[y]} Year';
  }

  Future<void> _registerStudent() async {
    if (!_sKey.currentState!.validate()) return;
    if (_sUni == null || _sFac == null || _sYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار الجامعة والكلية والسنة'), backgroundColor: Colors.red));
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.registerStudent(
      email: _sEmail.text.trim(), password: _sPass.text,
      fullName: _sName.text.trim(),
      universityAr: _sUni!['nameAr'], universityEn: _sUni!['nameEn'],
      facultyAr: _sFac!['nameAr'], facultyEn: _sFac!['nameEn'], year: _sYear!,
    );
    if (ok && mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainScreen()), (_) => false);
  }

  Future<void> _registerDoctor() async {
    if (!_dKey.currentState!.validate()) return;
    // Validate at least one complete uni+fac pair
    final validPairs = _dTeachingAt.where((e) => e['uni'] != null && e['fac'] != null).toList();
    if (validPairs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يرجى إضافة جامعة وكلية واحدة على الأقل'),
        backgroundColor: Colors.red));
      return;
    }
    final auth = context.read<AuthProvider>();
    final teachingAt = validPairs.map((e) => <String, String>{
      'universityAr': ((e['uni'] as Map)['nameAr'] as String),
      'universityEn': ((e['uni'] as Map)['nameEn'] as String),
      'facultyAr':   ((e['fac'] as Map)['nameAr'] as String),
      'facultyEn':   ((e['fac'] as Map)['nameEn'] as String),
    }).toList();
    final ok = await auth.registerDoctor(
      email: _dEmail.text.trim(), password: _dPass.text, fullName: _dName.text.trim(),
      universityAr: teachingAt.first['universityAr'] as String,
      universityEn: teachingAt.first['universityEn'] as String,
      facultyAr:   teachingAt.first['facultyAr'] as String,
      facultyEn:   teachingAt.first['facultyEn'] as String,
      teachingAt: teachingAt,
    );
    if (ok && mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();
    final ap = context.watch<AppProvider>();
    final isAr = ap.isArabic;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded), onPressed: () => Navigator.pop(context)),
        title: Text(l10n.register),
        actions: [
          IconButton(icon: Icon(ap.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded), onPressed: ap.toggleTheme, color: AppTheme.primaryColor),
          IconButton(
            icon: Text(isAr ? 'EN' : 'ع', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 14)),
            onPressed: () => ap.setLocale(isAr ? const Locale('en') : const Locale('ar')),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: [Tab(text: l10n.student), Tab(text: l10n.doctor)],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // --- STUDENT TAB ---
          Form(
            key: _sKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const SizedBox(height: 8),
                _tf(_sName, l10n.fullName, Icons.person_outline_rounded, TextInputType.text, null, false, () {}, isAr),
                const SizedBox(height: 12),
                _tf(_sEmail, l10n.email, Icons.email_outlined, TextInputType.emailAddress, null, false, () {}, isAr),
                const SizedBox(height: 12),
                _tf(_sPass, l10n.password, Icons.lock_outline_rounded, TextInputType.text, _sObs, true, () => setState(() => _sObs = !_sObs), isAr),
                const SizedBox(height: 12),
                _tf(_sConfirm, l10n.confirmPassword, Icons.lock_outline_rounded, TextInputType.text, _sObsC, true, () => setState(() => _sObsC = !_sObsC), isAr,
                    validator: (v) => v != _sPass.text ? (isAr ? 'كلمات المرور غير متطابقة' : 'Passwords do not match') : null),
                const SizedBox(height: 12),
                _dropdown(l10n.selectUniversity, Icons.account_balance_outlined, _sUni, AppConstants.egyptianUniversities,
                    (u) => isAr ? u['nameAr'] : u['nameEn'], (u) => setState(() { _sUni = u; _sFac = null; _sYear = null; })),
                const SizedBox(height: 12),
                _dropdown(l10n.selectFaculty, Icons.school_outlined, _sFac, _sFaculties,
                    (f) => isAr ? f['nameAr'] : f['nameEn'], (f) => setState(() { _sFac = f; _sYear = null; }), _sUni != null),
                const SizedBox(height: 12),
                _dropdown(l10n.selectYear, Icons.calendar_today_outlined, _sYear,
                    List.generate(_maxYear, (i) => i + 1),
                    (y) => _yearLabel(y, isAr), (y) => setState(() => _sYear = y), _sFac != null),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(auth.errorMessage!, style: const TextStyle(color: Colors.red))),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _registerStudent,
                  child: auth.isLoading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(l10n.register),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(l10n.alreadyHaveAccount),
                  TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: Text(l10n.login, style: const TextStyle(color: AppTheme.primaryColor))),
                ]),
              ]),
            ),
          ),

          // --- DOCTOR TAB ---
          Form(
            key: _dKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const SizedBox(height: 8),
                _tf(_dName, l10n.fullName, Icons.person_outline_rounded, TextInputType.text, null, false, () {}, isAr),
                const SizedBox(height: 12),
                _tf(_dEmail, l10n.email, Icons.email_outlined, TextInputType.emailAddress, null, false, () {}, isAr),
                const SizedBox(height: 12),
                _tf(_dPass, l10n.password, Icons.lock_outline_rounded, TextInputType.text, _dObs, true, () => setState(() => _dObs = !_dObs), isAr),
                const SizedBox(height: 12),
                _tf(_dConfirm, l10n.confirmPassword, Icons.lock_outline_rounded, TextInputType.text, _dObsC, true, () => setState(() => _dObsC = !_dObsC), isAr,
                    validator: (v) => v != _dPass.text ? (isAr ? 'كلمات المرور غير متطابقة' : 'Passwords do not match') : null),
                const SizedBox(height: 20),

                // Teaching positions (CV builder style)
                Row(children: [
                  const Icon(Icons.account_balance_outlined, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(isAr ? 'جامعاتك وكلياتك' : 'Universities & Faculties',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
                const SizedBox(height: 4),
                Text(isAr ? 'أضف كل الجامعات والكليات التي تدرّس فيها' : 'Add all universities and faculties where you teach',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 12),

                ...List.generate(_dTeachingAt.length, (i) {
                  final entry = _dTeachingAt[i];
                  final selUni = entry['uni'] as Map<String, dynamic>?;
                  final selFac = entry['fac'] as Map<String, dynamic>?;
                  final facs = selUni != null ? List<Map<String, dynamic>>.from(selUni['faculties']) : <Map<String, dynamic>>[];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15))),
                    child: Column(children: [
                      Row(children: [
                        Container(width: 28, height: 28, decoration: BoxDecoration(
                          color: AppTheme.primaryColor, shape: BoxShape.circle),
                          child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(isAr ? 'موقع ${i + 1}' : 'Position ${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                        if (_dTeachingAt.length > 1)
                          IconButton(
                            onPressed: () => setState(() => _dTeachingAt.removeAt(i)),
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      _dropdown(l10n.selectUniversity, Icons.account_balance_outlined, selUni, AppConstants.egyptianUniversities,
                        (u) => isAr ? u['nameAr'] : u['nameEn'],
                        (u) => setState(() { _dTeachingAt[i]['uni'] = u; _dTeachingAt[i]['fac'] = null; })),
                      const SizedBox(height: 10),
                      _dropdown(l10n.selectFaculty, Icons.school_outlined, selFac, facs,
                        (f) => isAr ? f['nameAr'] : f['nameEn'],
                        (f) => setState(() => _dTeachingAt[i]['fac'] = f),
                        selUni != null),
                    ]),
                  );
                }),

                // Add more button
                TextButton.icon(
                  onPressed: () => setState(() => _dTeachingAt.add({'uni': null, 'fac': null})),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: Text(isAr ? '+ إضافة جامعة أخرى' : '+ Add another university'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                ),

                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(auth.errorMessage!, style: const TextStyle(color: Colors.red))),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _registerDoctor,
                  child: auth.isLoading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(l10n.register),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tf(TextEditingController ctrl, String label, IconData icon, TextInputType type,
      bool? obs, bool hasToggle, VoidCallback onToggle, bool isAr, {String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl, obscureText: obs ?? false, keyboardType: type,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon),
        suffixIcon: hasToggle ? IconButton(
          icon: Icon(obs! ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: onToggle,
        ) : null,
      ),
      validator: validator ?? (v) => v == null || v.isEmpty ? (isAr ? 'هذا الحقل مطلوب' : 'Required') : null,
    );
  }

  Widget _dropdown<T>(String label, IconData icon, T? value, List<T> items,
      String Function(T) getLabel, ValueChanged<T?> onChange, [bool enabled = true]) {
    return DropdownButtonFormField<T>(
      initialValue: value, isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), enabled: enabled),
      items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(getLabel(e), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: enabled ? onChange : null,
    );
  }
}
