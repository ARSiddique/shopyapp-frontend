import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final TextEditingController cashController = TextEditingController();
  final TextEditingController cardController = TextEditingController();
  final TextEditingController otherController = TextEditingController();

  Timer? _countdownTimer;
  Duration? _remainingTime;
  Map<String, dynamic>? _lastSale;

  @override
  void initState() {
    super.initState();
    _initCountdown();
  }

  void _initCountdown() {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final user = appData.loggedInUser;
    if (user == null) return;

    final employeeName = user['name'];
    final sales = appData.sales
        .where((s) => s['employee'] == employeeName)
        .toList();

    if (sales.isNotEmpty) {
      final recentSale = sales.last;
      final createdAtRaw = recentSale['createdAt'];
      final createdAt = createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : (createdAtRaw is DateTime ? createdAtRaw : DateTime.now());

      final elapsed = DateTime.now().difference(createdAt);

      if (elapsed.inMinutes < 5) {
        setState(() {
          _lastSale = recentSale;
          _remainingTime = const Duration(minutes: 5) - elapsed;
        });
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingTime != null && _remainingTime!.inSeconds > 0) {
        setState(() {
          _remainingTime = _remainingTime! - const Duration(seconds: 1);
        });
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _remainingTime = null;
          _lastSale = null;
        });
      }
    });
  }

  void _submitSale() {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final user = appData.loggedInUser;
    if (user == null) return;

    final double cash = double.tryParse(cashController.text.trim()) ?? 0;
    final double card = double.tryParse(cardController.text.trim()) ?? 0;
    final double other = double.tryParse(otherController.text.trim()) ?? 0;
    final double total = cash + card + other;

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one valid amount')),
      );
      return;
    }
final now = DateTime.now();
   final sale = {
      'id': now.millisecondsSinceEpoch.toString(),
      'employee': user['name'],
      'shop': user['assignedShops']?[0] ?? '',
      'cash': cash,
      'card': card,
      'other': other,
      'total': total,
      'createdAt': now,
      'date': Timestamp.fromDate(
        DateTime(now.year, now.month, now.day),
      ), // ✅ Added!
    };

    appData.addSale(sale);
    cashController.clear();
    cardController.clear();
    otherController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale submitted successfully')),
    );
    _initCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    cashController.dispose();
    cardController.dispose();
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Report Daily Sale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cash Amount',
                prefixIcon: Icon(Icons.money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cardController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Credit/Debit Amount',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: otherController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cash App / Venmo Amount',
                prefixIcon: Icon(Icons.account_balance_wallet),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _submitSale,
              icon: const Icon(Icons.check),
              label: const Text('Submit'),
            ),
            if (_remainingTime != null) ...[
              const SizedBox(height: 16),
              Text(
                '⏱ Edit Available: ${_remainingTime!.inMinutes.remainder(60).toString().padLeft(2, '0')}:${_remainingTime!.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Logout?'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Logout'),
              onPressed: () {
                Navigator.of(context).pop();
                appData.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () {
                Navigator.of(context).pop();
                appData.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      );
    }
  }
}
