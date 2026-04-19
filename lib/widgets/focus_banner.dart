import 'package:flutter/material.dart';
import '../../services/focus_mode_service.dart';
import '../../utils/app_theme.dart';

class FocusBanner extends StatefulWidget {
  final bool isAr;
  const FocusBanner({super.key, required this.isAr});

  @override
  State<FocusBanner> createState() => _FocusBannerState();
}

class _FocusBannerState extends State<FocusBanner>
    with SingleTickerProviderStateMixin {
  final _svc = FocusModeService.instance;
  late AnimationController _pulse;
  late Animation<double> _opacity;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _opacity = Tween(begin: 0.65, end: 1.0).animate(_pulse);
    _svc.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _svc.removeListener(_onServiceChanged);
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    if (_svc.isActive) {
      await _svc.disable();
    } else {
      final ok = await _svc.enable();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isAr
              ? 'امنح صلاحية عدم الإزعاج في الإعدادات ثم حاول مجدداً'
              : 'Grant Do Not Disturb access in Settings, then try again'),
          duration: const Duration(seconds: 4),
        ));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final active = _svc.isActive;
    final isAr = widget.isAr;

    // ── ACTIVE ────────────────────────────────────────────────────────────────
    if (active) {
      return FadeTransition(
        opacity: _opacity,
        child: GestureDetector(
          onTap: _loading ? null : _toggle,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB91C1C), Color(0xFF7C3AED)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(children: [
              const Text('🔕', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'Focus Mode نشط 🟢' : 'Focus Mode Active 🟢',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14),
                      ),
                      Text(
                        isAr
                            ? 'الإشعارات والمكالمات محجوبة بالكامل'
                            : 'All notifications & calls are blocked',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ]),
              ),
              if (_loading)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else
                const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            ]),
          ),
        ),
      );
    }

    // ── INACTIVE ──────────────────────────────────────────────────────────────
    return GestureDetector(
      onTap: _loading ? null : _toggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withOpacity(0.12),
              const Color(0xFF7C3AED).withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('🔕', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'تفعيل Focus Mode' : 'Activate Focus Mode',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  Text(
                    isAr
                        ? 'يحجب الإشعارات والمكالمات خلال المذاكرة'
                        : 'Blocks all notifications & calls while studying',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ]),
          ),
          if (_loading)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isAr ? 'تفعيل' : 'Start',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
        ]),
      ),
    );
  }
}
