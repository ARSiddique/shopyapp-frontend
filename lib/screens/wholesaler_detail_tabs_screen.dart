import 'package:flutter/material.dart';
import 'wholesaler_invoices_screen.dart';
import 'wholesaler_payments_screen.dart';
import 'wholesaler_balance_screen.dart';

class WholesalerDetailTabsScreen extends StatefulWidget {
  final String wholesalerName;
  const WholesalerDetailTabsScreen({super.key, required this.wholesalerName});

  @override
  State<WholesalerDetailTabsScreen> createState() => _WholesalerDetailTabsScreenState();
}

class _WholesalerDetailTabsScreenState extends State<WholesalerDetailTabsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wholesalerName;
    return Scaffold(
      appBar: AppBar(
        title: Text(w),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Invoices'),
            Tab(text: 'Payments'),
            Tab(text: 'Balance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          WholesalerInvoicesScreen(wholesalerName: w),
          WholesalerPaymentsScreen(wholesalerName: w),
          WholesalerBalanceScreen(wholesalerName: w),
        ],
      ),
    );
  }
}
