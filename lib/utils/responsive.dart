import 'dart:ui' show clampDouble;
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Responsive utility — use anywhere in the app to adapt UI to screen size.
///
///  Breakpoints:
///    mobile  : width < 600
///    tablet  : 600 ≤ width < 900
///    desktop : width ≥ 900
/// ─────────────────────────────────────────────────────────────────────────────
class R {
  R._();

  // ── Breakpoints ────────────────────────────────────────────────────────────
  static const double _kMobileMax  = 600;
  static const double _kTabletMax  = 900;

  /// Max width for body content on large screens.
  static const double contentMaxWidth = 900;

  // ── Screen-size helpers ────────────────────────────────────────────────────
  static double width(BuildContext ctx)   => MediaQuery.sizeOf(ctx).width;
  static double height(BuildContext ctx)  => MediaQuery.sizeOf(ctx).height;

  static bool isMobile(BuildContext ctx)  => width(ctx) < _kMobileMax;
  static bool isTablet(BuildContext ctx)  => width(ctx) >= _kMobileMax && width(ctx) < _kTabletMax;
  static bool isDesktop(BuildContext ctx) => width(ctx) >= _kTabletMax;
  static bool isWide(BuildContext ctx)    => width(ctx) >= _kMobileMax; // tablet OR desktop

  // ── Responsive value helper ────────────────────────────────────────────────
  /// Returns [mobile], [tablet], or [desktop] value based on screen width.
  static T value<T>(
    BuildContext ctx, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(ctx)) return desktop;
    if (isTablet(ctx))  return tablet ?? desktop;
    return mobile;
  }

  // ── Padding helpers ────────────────────────────────────────────────────────
  static EdgeInsets pagePadding(BuildContext ctx) =>
      EdgeInsets.symmetric(
        horizontal: isWide(ctx) ? 32 : 16,
        vertical: 16,
      );

  // ── Font-size helpers ──────────────────────────────────────────────────────
  static double navLabelSize(BuildContext ctx) =>
      clampDouble(width(ctx) / 55, 9, 13);

  static double navIconSize(BuildContext ctx) =>
      clampDouble(width(ctx) / 30, 20, 26);

  // ── Grid columns ──────────────────────────────────────────────────────────
  static int gridCols(BuildContext ctx, {int mobile = 1, int tablet = 2, int desktop = 3}) =>
      value(ctx, mobile: mobile, tablet: tablet, desktop: desktop);
}

/// Wraps [child] in a horizontally-centered, max-width-constrained box.
/// Use this inside every Scaffold body on screens that need it.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = R.contentMaxWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}
