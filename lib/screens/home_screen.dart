// lib/screens/home_screen.dart
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/app_data_provider.dart';
import '../screens/add_sale_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';
import '../screens/all_shops_screen.dart';
import '../screens/employees_overview_screen.dart';
// import '../screens/all_shops_summary_screen.dart';
import 'all_shops_hub_screen.dart';
import '../screens/wholesaler_drilldown_screen.dart';
import '../screens/cash_collect_screen.dart';
import '../screens/other_expense_screen.dart'; // ← FAB destination

/// ========= TOKENS =========
const _brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF6D60F7), Color(0xFF5AD7FF), Color(0xFF00E18B)],
);
const _neon = Color(0xFF00FFC6);
const _glassStroke = Color(0x33FFFFFF);
const _glassFill = Color(0x1AFFFFFF);

/// ========= GLASS + NEON CONFIRM DIALOGS =========
Future<bool> showNeonConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
}) async {
  return await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'confirm',
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (ctx, a1, a2) => const SizedBox.shrink(),
        transitionBuilder: (ctx, anim, a2, child) {
          final scale = Tween<double>(begin: 0.96, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack));
          return Transform.scale(
            scale: scale.value,
            child: Opacity(
              opacity: anim.value,
              child: _NeonGlassDialog(
                title: title,
                message: message,
                confirmText: confirmText,
                cancelText: cancelText,
                icon: icon,
              ),
            ),
          );
        },
      ) ??
      false;
}

class _NeonGlassDialog extends StatelessWidget {
  final String title, message, confirmText, cancelText;
  final IconData icon;
  const _NeonGlassDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(false),
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _glassStroke),
              boxShadow: const [
                BoxShadow(color: Color(0x2200FFC6), blurRadius: 24, offset: Offset(0, 12)),
                BoxShadow(color: Color(0x44000000), blurRadius: 28, offset: Offset(0, 18)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  color: _glassFill,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (r) => _brandGradient.createShader(r),
                        child: Icon(icon, size: 32, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      ShaderMask(
                        shaderCallback: (r) => _brandGradient.createShader(r),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _NeonButton.tonal(
                              label: cancelText,
                              onTap: () => Navigator.of(context).pop(false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _NeonButton.solid(
                              label: confirmText,
                              onTap: () => Navigator.of(context).pop(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool solid;
  const _NeonButton._(this.label, this.onTap, this.solid);

  factory _NeonButton.solid({required String label, required VoidCallback onTap}) =>
      _NeonButton._(label, onTap, true);
  factory _NeonButton.tonal({required String label, required VoidCallback onTap}) =>
      _NeonButton._(label, onTap, false);

  @override
  Widget build(BuildContext context) {
    final isDanger =
        label.toLowerCase().contains('logout') || label.toLowerCase().contains('quit');

    final Gradient solidGradient = isDanger
        ? const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF3B3B)])
        : _brandGradient;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: solid ? solidGradient : null,
          color: solid ? null : Colors.white.withValues(alpha: 0.10),
          border: Border.all(
            color: solid ? Colors.transparent : Colors.white.withValues(alpha: 0.22),
          ),
          boxShadow: solid
              ? const [BoxShadow(color: Color(0x3300FFC6), blurRadius: 16, offset: Offset(0, 8))]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: solid ? Colors.black.withValues(alpha: 0.9) : Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// ========= 3D GLASS APPBAR =========
class NeonGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onLogout;
  const NeonGlassAppBar({super.key, required this.title, required this.onLogout});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Container(
          height: 64,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _glassFill,
            border: Border.all(color: _glassStroke),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x3300FFC6), blurRadius: 24, offset: Offset(0, 10)),
              BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 14)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Row(
                children: [
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (rect) => _brandGradient.createShader(rect),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.3),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded, size: 22, color: _neon),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ========= HOME =========
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    Provider.of<AppDataProvider>(context, listen: false).startFirebaseListeners();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _bgCtrl.dispose(); super.dispose(); }

  Future<void> _onLogoutTap() async {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final ok = await showNeonConfirm(
      context: context,
      title: 'Logout?',
      message: 'Are you sure you want to logout from Shopy App?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
      icon: Icons.logout_rounded,
    );
    if (ok) {
      appData.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  /// Animated nebula-like background
  Widget _animatedBG({required Widget child}) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, _) {
        final t = _bgCtrl.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.8 + 0.6 * t, -1),
              end: Alignment(1, 0.8 - 0.6 * t),
              colors: [
                const Color(0xFF0A1220),
                Color.lerp(const Color(0xFF101B31), const Color(0xFF0E1A2C), t)!,
                const Color(0xFF0A1120)
              ],
            ),
          ),
          child: Stack(children: [
            Positioned.fill(child: IgnorePointer(child: Opacity(opacity: 0.35, child: DecoratedBox(
              decoration: BoxDecoration(gradient: RadialGradient(
                center: Alignment(0.9 - t, -0.8 + t), radius: 0.9, colors: const [Color(0xFF143B5B), Colors.transparent])))))),
            Positioned.fill(child: IgnorePointer(child: Opacity(opacity: 0.35, child: DecoratedBox(
              decoration: BoxDecoration(gradient: RadialGradient(
                center: Alignment(-0.8 + t, 0.9 - t), radius: 0.9, colors: const [Color(0xFF0B5C58), Colors.transparent])))))),
            child,
          ]),
        );
      },
    );
  }

  /// Responsive grid params
  (int cols, double aspect, double gap) _gridForWidth(double w) {
    if (w >= 1800) return (6, 1.05, 18);
    if (w >= 1200) return (4, 1.05, 16);
    if (w >= 800)  return (3, 1.05, 14);
    return (2, 1.05, 12);
  }

  /// 3D glass action card
  Widget _interactiveGlassCard({
    required Key key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return _PressHover(
      key: key,
      builder: (pressed, hovering) {
        final scale = pressed ? 0.97 : (hovering ? 1.02 : 1.0);
        final blur = pressed ? 10.0 : 18.0;
        final lift = pressed ? 6.0 : 16.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(scale),
          decoration: BoxDecoration(
            color: _glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _glassStroke, width: 1),
            boxShadow: [
              BoxShadow(color: const Color(0x2200FFC6), blurRadius: lift, offset: const Offset(0, 10)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: lift, offset: const Offset(0, 14)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                splashColor: _neon.withValues(alpha: 0.15),
                highlightColor: Colors.white.withValues(alpha: 0.24),
                onTap: onTap,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShaderMask(shaderCallback: (r) => _brandGradient.createShader(r),
                          child: Icon(icon, size: 30, color: Colors.white)),
                        const SizedBox(height: 10),
                        Text(title, textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                        const SizedBox(height: 6),
                        Container(height: 2, width: 34,
                          decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(2),
                            boxShadow: const [BoxShadow(color: Color(0x3300FFC6), blurRadius: 6)])),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Employee metric card
  Widget _metricCard({
    required Key key,
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return _PressHover(
      key: key,
      builder: (pressed, hovering) {
        final scale = pressed ? 0.97 : (hovering ? 1.02 : 1.0);
        final lift = pressed ? 6.0 : 14.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(scale),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(color: const Color(0x2200FFC6), blurRadius: lift, offset: const Offset(0, 10)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: lift, offset: const Offset(0, 14)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              splashColor: _neon.withValues(alpha: 0.15),
              highlightColor: Colors.white.withValues(alpha: 0.24),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(shaderCallback: (r) => _brandGradient.createShader(r),
                      child: Icon(icon, size: 28, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(value, style: const TextStyle(color: _neon, fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final user = app.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toString().toLowerCase();
    final isEmployee = role == 'employee';
    final isAdmin = role == 'admin';
    final isManager = role == 'manager';
    final isAdminOrManager = isAdmin || isManager; // ← who can see the FAB
    final employeeName = (user['name'] ?? '').toString();
    final titleText =
        '${user['name'] ?? ''} (${role.isNotEmpty ? role[0].toUpperCase() + role.substring(1) : 'Employee'})';

    // Employee metrics
    final employeeOrders =
        app.orders.where((o) => (o['createdByName'] ?? o['employee']) == employeeName).toList();
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final assignedShops =
        (user['assignedShops'] as List? ?? const []).map((e) => e.toString()).toList();
    final todayShopSales = app.sales.where((s) {
      final saleDate = s['saleDate'];
      final shopName = s['shop'];
      return saleDate == todayStr && (isEmployee ? assignedShops.contains(shopName) : true);
    }).toList();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final ok = await showNeonConfirm(
            context: context,
            title: 'Exit App?',
            message: 'Do you want to quit the app?',
            confirmText: 'Quit',
            cancelText: 'Cancel',
            icon: Icons.power_settings_new_rounded,
          );
          if (ok) exit(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        appBar: _selectedIndex == 0
            ? NeonGlassAppBar(title: titleText, onLogout: _onLogoutTap)
            : null,

        // ========= Admin/Manager-only FAB for Other Expense =========
        floatingActionButton: isAdminOrManager
            ? FloatingActionButton.extended(
                heroTag: 'fab_other_expense',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OtherExpenseScreen()),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Other Expense'),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        // ============================================================

        body: _animatedBG(
          child: _selectedIndex == 1
              ? const ProfileScreen()
              : LayoutBuilder(
                  builder: (ctx, cs) {
                    final (cols, aspect, gap) = _gridForWidth(cs.maxWidth);
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('shops').snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: _neon));
                        }
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 4),
                                Column(children: [
                                  ShaderMask(
                                    shaderCallback: (r) => _brandGradient.createShader(r),
                                    child: const Text('Dashboard Overview',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20,
                                            letterSpacing: 0.4)),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                      height: 3,
                                      width: 120,
                                      decoration: BoxDecoration(
                                          gradient: _brandGradient,
                                          borderRadius: BorderRadius.circular(3),
                                          boxShadow: const [
                                            BoxShadow(color: Color(0x3300FFC6), blurRadius: 8)
                                          ])),
                                ]),
                                const SizedBox(height: 14),

                                if (!isEmployee)
                                  Expanded(
                                    child: GridView.count(
                                      crossAxisCount: cols,
                                      mainAxisSpacing: gap,
                                      crossAxisSpacing: gap,
                                      childAspectRatio: aspect,
                                      children: [
                                        _interactiveGlassCard(
                                          key: const ValueKey('card_allshops'),
                                          icon: Icons.dashboard_customize,
                                          title: 'All Shops Summary',
                                          onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => const AllShopsHubScreen())),
                                        ),
                                        _interactiveGlassCard(
                                          key: const ValueKey('card_wholesalers'),
                                          icon: Icons.store_mall_directory,
                                          title: 'Wholesalers',
                                          onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const WholesalerDrilldownScreen())),
                                        ),
                                        _interactiveGlassCard(
                                          key: const ValueKey('card_employees'),
                                          icon: Icons.people,
                                          title: 'Employees',
                                          onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const EmployeesOverviewScreen())),
                                        ),
                                        _interactiveGlassCard(
                                          key: const ValueKey('card_shops'),
                                          icon: Icons.store,
                                          title: 'Shops',
                                          onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => const AllShopsScreen())),
                                        ),
                                        _interactiveGlassCard(
                                          key: const ValueKey('card_sales'),
                                          icon: Icons.trending_up,
                                          title: 'Sales',
                                          onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => const SalesScreen())),
                                        ),
                                        _interactiveGlassCard(
                                          key: const ValueKey('card_orders'),
                                          icon: Icons.shopping_bag,
                                          title: 'Orders',
                                          onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => const OrdersScreen())),
                                        ),
                                        if (isAdmin) // ONLY Admin sees this card
                                          _interactiveGlassCard(
                                            key: const ValueKey('card_cash_collect'),
                                            icon: Icons.attach_money_rounded,
                                            title: 'Cash Collect',
                                            onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const CashCollectScreen())),
                                          ),
                                      ],
                                    ),
                                  ),

                                if (isEmployee)
                                  Expanded(
                                    child: GridView.count(
                                      crossAxisCount: cols,
                                      mainAxisSpacing: gap,
                                      crossAxisSpacing: gap,
                                      childAspectRatio: aspect,
                                      children: [
                                        _metricCard(
                                          key: const ValueKey('metric_orders'),
                                          icon: Icons.shopping_bag,
                                          title: 'Orders',
                                          value: employeeOrders.length.toString(),
                                          onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => const OrdersScreen())),
                                        ),
                                        _metricCard(
                                          key: const ValueKey('metric_sales'),
                                          icon: Icons.trending_up,
                                          title: 'Sales (Today)',
                                          value: todayShopSales.length.toString(),
                                          onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => const AddSaleScreen())),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        bottomNavigationBar: _FrostedBottomBar(
          index: _selectedIndex,
          onChanged: (i) => setState(() => _selectedIndex = i),
        ),
      ),
    );
  }
}

/// ========= 3D FROSTED BOTTOM BAR =========
class _FrostedBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _FrostedBottomBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x22FFFFFF), Color(0x12FFFFFF)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x2200FFC6), blurRadius: 16, offset: Offset(0, 10)),
          BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 16)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: _neon,
            unselectedItemColor: Colors.white.withValues(alpha: 0.85),
            currentIndex: index,
            onTap: onChanged,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

/// ========= PRESS + HOVER =========
class _PressHover extends StatefulWidget {
  final Widget Function(bool pressed, bool hovering) builder;
  const _PressHover({super.key, required this.builder});
  @override
  State<_PressHover> createState() => _PressHoverState();
}

class _PressHoverState extends State<_PressHover> {
  bool _pressed = false;
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: widget.builder(_pressed, _hovering),
      ),
    );
  }
}
