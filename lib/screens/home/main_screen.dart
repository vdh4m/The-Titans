import 'dart:ui' show clampDouble;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:studyhub/generated/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/study_provider.dart';
import '../../utils/responsive.dart';
import '../courses/courses_screen.dart';
import '../study/study_mode_screen.dart';
import '../ai/ai_screen.dart';
import '../profile/profile_screen.dart';
import '../social/community_screen.dart';
import '../offline/offline_screen.dart';
import 'home_screen.dart';
import '../admin/doctor_approval_screen.dart';
// ignore: unused_import
import '../admin/support_screen.dart';
import '../auth/pending_approval_screen.dart';
import '../../widgets/study_timer_bubble.dart';
import '../../utils/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _idx = 0;
  bool _isOnline = true;

  final Set<int> _built = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) context.read<StudyProvider>().setUserId(uid);
    });
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted && online != _isOnline) setState(() => _isOnline = online);
    });
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOnline = results.any((r) => r != ConnectivityResult.none));
  }

  @override
  Widget build(BuildContext context) {
    final l10n    = AppLocalizations.of(context)!;
    final study   = context.watch<StudyProvider>();
    final user    = context.watch<AuthProvider>().currentUser;
    final isAr    = Localizations.localeOf(context).languageCode == 'ar';

    if (user != null && user.isDoctor && !user.isVerified) {
      return const PendingApprovalScreen();
    }

    final isDoctor = user?.isDoctor ?? false;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final isWide   = R.isWide(context);

    const studyTabIndex = 2;

    final screens = isDoctor
        ? [
            const HomeScreen(),
            const CoursesScreen(),
            const CommunityScreen(),
            const AIScreen(),
            const ProfileScreen(),
          ]
        : [
            const HomeScreen(),
            const CoursesScreen(),
            const StudyModeScreen(),
            const CommunityScreen(),
            const AIScreen(),
            const OfflineScreen(),
            const ProfileScreen(),
          ];

    _built.add(_idx);

    final navItems = _buildNavItems(isDoctor, isAr, l10n);

    // ── Build the page stack ──────────────────────────────────────────────────
    final pageStack = Stack(
      children: List.generate(screens.length, (i) {
        final active = i == _idx;
        final built  = _built.contains(i);
        return IgnorePointer(
          ignoring: !active,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            opacity: active ? 1.0 : 0.0,
            child: built ? screens[i] : const SizedBox.shrink(),
          ),
        );
      }),
    );

    // ── Wide layout: NavigationRail + content side by side ────────────────────
    if (isWide) {
      return Stack(children: [
        Scaffold(
          body: Column(children: [
            if (!_isOnline) _OfflineBanner(isAr: isAr),
            Expanded(
              child: Row(
                children: [
                  // ── Side Navigation Rail ──────────────────────────────────
                  _SideRail(
                    idx: _idx,
                    items: navItems,
                    isDoctor: isDoctor,
                    isDark: isDark,
                    isAr: isAr,
                    l10n: l10n,
                    showLabels: R.isDesktop(context),
                    onTap: (i) => setState(() => _idx = i),
                  ),

                  // ── Vertical divider ──────────────────────────────────────
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.06),
                  ),

                  // ── Main content (max-width centered) ─────────────────────
                  Expanded(child: pageStack),
                ],
              ),
            ),
          ]),
        ),

        // Admin FAB
        if (user != null && (user as dynamic).isAdmin == true)
          Positioned(
            top: 56, right: 12,
            child: FloatingActionButton.small(
              heroTag: 'admin_fab',
              backgroundColor: Colors.red.shade700,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DoctorApprovalScreen())),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.white, size: 18),
            ),
          ),

        // Study timer bubble
        if (study.isRunning && !isDoctor && _idx != studyTabIndex)
          Positioned(
            bottom: 16, right: 16,
            child: StudyTimerBubble(
                onTap: () => setState(() => _idx = studyTabIndex)),
          ),
      ]);
    }

    // ── Narrow layout: classic bottom nav ─────────────────────────────────────
    return Stack(children: [
      Scaffold(
        body: Column(children: [
          if (!_isOnline) _OfflineBanner(isAr: isAr),
          Expanded(child: pageStack),
        ]),
        bottomNavigationBar: _BottomNav(
          idx: _idx,
          items: navItems,
          isDark: isDark,
          onTap: (i) => setState(() => _idx = i),
        ),
      ),

      // Admin FAB
      if (user != null && (user as dynamic).isAdmin == true)
        Positioned(
          top: 56, right: 12,
          child: FloatingActionButton.small(
            heroTag: 'admin_fab',
            backgroundColor: Colors.red.shade700,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DoctorApprovalScreen())),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 18),
          ),
        ),

      // Study timer bubble
      if (study.isRunning && !isDoctor && _idx != studyTabIndex)
        Positioned(
          bottom: 90, right: 16,
          child: StudyTimerBubble(
              onTap: () => setState(() => _idx = studyTabIndex)),
        ),
    ]);
  }

  List<_NavItem> _buildNavItems(bool isDoctor, bool isAr, AppLocalizations l10n) {
    if (isDoctor) {
      return [
        _NavItem(Icons.home_rounded,         Icons.home_outlined,           l10n.home),
        _NavItem(Icons.menu_book_rounded,    Icons.menu_book_outlined,      l10n.courses),
        _NavItem(Icons.people_rounded,       Icons.people_outline_rounded,  isAr ? 'المجتمع' : 'Community'),
        _NavItem(Icons.auto_awesome_rounded, Icons.auto_awesome_outlined,   l10n.aiAssistant),
        _NavItem(Icons.person_rounded,       Icons.person_outline_rounded,  l10n.profile),
      ];
    }
    return [
      _NavItem(Icons.home_rounded,          Icons.home_outlined,           l10n.home),
      _NavItem(Icons.menu_book_rounded,     Icons.menu_book_outlined,      l10n.courses),
      _NavItem(Icons.timer_rounded,         Icons.timer_outlined,          l10n.studyMode),
      _NavItem(Icons.people_rounded,        Icons.people_outline_rounded,  isAr ? 'المجتمع' : 'Community'),
      _NavItem(Icons.auto_awesome_rounded,  Icons.auto_awesome_outlined,   l10n.aiAssistant),
      _NavItem(Icons.offline_bolt_rounded,  Icons.offline_bolt_outlined,   isAr ? 'حفظ' : 'Offline'),
      _NavItem(Icons.person_rounded,        Icons.person_outline_rounded,  l10n.profile),
    ];
  }
}

// ── Offline banner ─────────────────────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  final bool isAr;
  const _OfflineBanner({required this.isAr});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 7),
    color: Colors.orange.shade700,
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          isAr ? '⚡ وضع عدم الاتصال — تصفح المحتوى المحفوظ'
               : '⚡ Offline Mode — browsing downloaded content',
          style: const TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]),
  );
}

// ── Mobile Bottom Nav ─────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int idx;
  final List<_NavItem> items;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.idx,
    required this.items,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w    = MediaQuery.sizeOf(context).width;
    final bg   = isDark ? const Color(0xFF0E0C1E) : Colors.white;
    final sel  = AppTheme.primaryColor;
    final unsel = isDark ? Colors.white38 : Colors.grey.shade500;

    // Adaptive sizing based on screen width and item count
    final iconSize   = clampDouble(w / (items.length * 5.5), 18, 26);
    final labelSize  = clampDouble(w / (items.length * 8.0), 8.5, 12);
    final navHeight  = clampDouble(w / 8, 56, 70);
    final showLabels = w / items.length > 52; // hide labels if items too crammed

    return Container(
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
          blurRadius: 20, offset: const Offset(0, -4),
        )],
        border: Border(top: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        )),
      ),
      child: SafeArea(
        child: SizedBox(
          height: navHeight,
          child: Row(
            children: List.generate(items.length, (i) {
              final item   = items[i];
              final active = idx == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: clampDouble(w / (items.length * 6), 6, 16),
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: active ? sel.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          active ? item.activeIcon : item.icon,
                          color: active ? sel : unsel,
                          size: iconSize,
                        ),
                      ),
                      if (showLabels) ...[
                        const SizedBox(height: 1),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: labelSize,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                            color: active ? sel : unsel,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Desktop/Tablet Side Rail ───────────────────────────────────────────────────
class _SideRail extends StatelessWidget {
  final int idx;
  final List<_NavItem> items;
  final bool isDoctor, isDark, isAr, showLabels;
  final AppLocalizations l10n;
  final ValueChanged<int> onTap;

  const _SideRail({
    required this.idx,
    required this.items,
    required this.isDoctor,
    required this.isDark,
    required this.isAr,
    required this.l10n,
    required this.showLabels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg   = isDark ? const Color(0xFF0E0C1E) : Colors.white;
    final sel  = AppTheme.primaryColor;
    final unsel = isDark ? Colors.white38 : Colors.grey.shade500;

    return Container(
      width: showLabels ? 200 : 72,
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            // ── App logo / branding ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: showLabels
                  ? Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text('StudyHub',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16,
                              color: AppTheme.primaryColor)),
                    ])
                  : Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                      ),
                    ),
            ),

            const SizedBox(height: 8),

            // ── Nav items ──
            ...List.generate(items.length, (i) {
              final item   = items[i];
              final active = idx == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: showLabels ? 14 : 0,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: active ? sel.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: showLabels
                        ? Row(children: [
                            Icon(active ? item.activeIcon : item.icon,
                                color: active ? sel : unsel, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                  color: active ? sel : unsel,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ])
                        : Center(
                            child: Icon(active ? item.activeIcon : item.icon,
                                color: active ? sel : unsel, size: 24),
                          ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Nav item data ──────────────────────────────────────────────────────────────
class _NavItem {
  final IconData activeIcon, icon;
  final String label;
  const _NavItem(this.activeIcon, this.icon, this.label);
}
