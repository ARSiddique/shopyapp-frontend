import 'package:flutter/material.dart';

class R {
  // Breakpoints
  static const mobile = 600.0;
  static const tablet = 1024.0;
  static const desktop = 1440.0;

  static bool isMobile(BuildContext c) => MediaQuery.of(c).size.width < mobile;
  static bool isTablet(BuildContext c) =>
      MediaQuery.of(c).size.width >= mobile && MediaQuery.of(c).size.width < tablet;
  static bool isDesktop(BuildContext c) => MediaQuery.of(c).size.width >= tablet;

  /// Centered container with a max content width (great for LED/desktop)
  static Widget maxWidth({required Widget child, double max = 1200}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );
  }

  /// Page padding that scales by device size
  static EdgeInsets pagePadding(BuildContext c) {
    if (isDesktop(c)) return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    if (isTablet(c)) return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }
}
