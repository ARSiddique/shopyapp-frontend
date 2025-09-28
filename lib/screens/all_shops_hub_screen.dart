// lib/screens/all_shops_hub_screen.dart
import 'package:flutter/material.dart';

// summaries
import 'all_shops_summary_screen.dart';
import 'sales_summary_screen.dart';
import 'employee_expense_list_screen.dart';

// extra sections
import 'other_expense_screen.dart';
import 'total_expense_screen.dart';
import 'orders_matrix_screen.dart';

// wholesalers list (direct invoices flow)
import 'wholesalers_list_screen.dart';

const _radius = 20.0;

class AllShopsHubScreen extends StatelessWidget {
  const AllShopsHubScreen({super.key});

  void _openAllShopsSummary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AllShopsSummaryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final crossAxisCount = isWide ? 3 : 2;

    return Scaffold(
      appBar: AppBar(title: const Text('All Shops • Overview')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _HubCard(
              title: 'Sale',
              icon: Icons.point_of_sale_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SalesSummaryScreen()),
                );
              },
            ),

            // 👉 Wholesaler Invoices -> open wholesalers list in “invoices” mode
            _HubCard(
              title: 'Wholesaler Invoices',
              icon: Icons.receipt_long_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WholesalersListScreen(
                      openInvoicesDirect: true,
                    ),
                  ),
                );
              },
            ),

            _HubCard(
              title: 'Employee Expense',
              icon: Icons.badge_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmployeeExpenseListScreen(),
                  ),
                );
              },
            ),
            _HubCard(
              title: 'Other Expense',
              icon: Icons.account_balance_wallet_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OtherExpenseScreen()),
                );
              },
            ),
            _HubCard(
              title: 'Total Expense',
              icon: Icons.summarize_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TotalExpenseScreen()),
                );
              },
            ),
            _HubCard(
              title: 'Orders',
              icon: Icons.grid_on_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrdersMatrixScreen()),
                );
              },
            ),

            // Optional — overall summary card
            _HubCard(
              title: 'All Shops Summary',
              icon: Icons.dashboard_customize,
              onTap: () => _openAllShopsSummary(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _HubCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_radius),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: outline.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
              color: theme.shadowColor.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
