import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'cash_collect_mixin.dart';

/// ===== Goal-4 models (TOP-LEVEL; keep outside AppDataProvider) =====

class DateRange {
  final DateTime from; // inclusive
  final DateTime to;   // exclusive
  const DateRange(this.from, this.to);
}

class ShopSummary {
  final String shopName;

  // Sales
  final double cash;
  final double card;
  final double other;
  double get salesTotal => cash + card + other;
  double get posCash => cash + card + other; // POS = cash + card + other

  // Wholesaler
  final double wholesalerInvoiceTotal;
  final double wholesalerPaidTotal;
  double get wholesalerBalance => wholesalerInvoiceTotal - wholesalerPaidTotal;

  // Expenses
  final double employeeExpenseTotal;
  final double otherExpenseTotal;
  double get totalExpense =>
      employeeExpenseTotal + otherExpenseTotal + wholesalerInvoiceTotal;

  // Net
  double get net => salesTotal - totalExpense;

  // Optional: orders snapshot for day
  final List<Map<String, dynamic>> orders;

  ShopSummary({
    required this.shopName,
    required this.cash,
    required this.card,
    required this.other,
    required this.wholesalerInvoiceTotal,
    required this.wholesalerPaidTotal,
    required this.employeeExpenseTotal,
    required this.otherExpenseTotal,
    required this.orders,
  });
}

class AllShopsSummary {
  final DateRange range;
  final String filterShopName;            // 'All' or specific
  final Map<String, ShopSummary> perShop; // key = shopName

  AllShopsSummary({
    required this.range,
    required this.filterShopName,
    required this.perShop,
  });

  double get grandSales =>
      perShop.values.fold(0.0, (s, e) => s + e.salesTotal);
  double get grandCash =>
      perShop.values.fold(0.0, (s, e) => s + e.cash);
  double get grandCard =>
      perShop.values.fold(0.0, (s, e) => s + e.card);
  double get grandOther =>
      perShop.values.fold(0.0, (s, e) => s + e.other);

  double get grandWholesalerInvoices =>
      perShop.values.fold(0.0, (s, e) => s + e.wholesalerInvoiceTotal);
  double get grandWholesalerPaid =>
      perShop.values.fold(0.0, (s, e) => s + e.wholesalerPaidTotal);
  double get grandWholesalerBalance =>
      grandWholesalerInvoices - grandWholesalerPaid;

  double get grandEmployeeExpense =>
      perShop.values.fold(0.0, (s, e) => s + e.employeeExpenseTotal);
  double get grandOtherExpense =>
      perShop.values.fold(0.0, (s, e) => s + e.otherExpenseTotal);
  double get grandTotalExpense =>
      perShop.values.fold(0.0, (s, e) => s + e.totalExpense);

  double get grandNet => grandSales - grandTotalExpense;
}

/// Top-level helper to compute range from a view mode.
DateRange rangeForView(String viewMode, DateTime anchor) {
  final a = DateTime(anchor.year, anchor.month, anchor.day);
  switch (viewMode) {
    case 'Daily':
      return DateRange(a, a.add(const Duration(days: 1)));
    case 'Weekly': {
      final start = a.subtract(Duration(days: a.weekday - 1)); // Monday
      return DateRange(start, start.add(const Duration(days: 7)));
    }
    case 'Monthly': {
      final start = DateTime(a.year, a.month, 1);
      return DateRange(start, DateTime(a.year, a.month + 1, 1));
    }
    case 'Yearly': {
      final start = DateTime(a.year, 1, 1);
      return DateRange(start, DateTime(a.year + 1, 1, 1));
    }
    default:
      return DateRange(a, a.add(const Duration(days: 1)));
  }
}

/// ====================================================================
///                          AppDataProvider
/// ====================================================================
class AppDataProvider extends ChangeNotifier with CashCollectMixin {
  AppDataProvider() {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);

    // 👇 Cash Collect ke local cache/persistence ko init karein
    configureCashCollectPersistence();
  }


  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  DocumentSnapshot? _lastOrderDoc;
  bool _hasMoreOrders = true;
  bool get hasMoreOrders => _hasMoreOrders;

  Map<String, dynamic>? _loggedInUser;
  Map<String, dynamic>? get loggedInUser => _loggedInUser;

  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _sales = [];
  final List<Map<String, dynamic>> _editRequests = [];

  List<Map<String, dynamic>> get orders => _orders;

  final List<Map<String, dynamic>> _expenses = [];
  final List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> get expenses => _expenses;
  List<Map<String, dynamic>> get payments => _payments;

  List<Map<String, dynamic>> shops = [];
  List<Map<String, dynamic>> employees = [];
  final Map<String, String> _shopNameById = {};           // id -> name
final Map<String, String> _shopIdByName = {};           // lowercase(name) -> id

String? shopNameForId(String id) => _shopNameById[id];
String? shopIdForName(String name) => _shopIdByName[name.trim().toLowerCase()];
  List<Map<String, dynamic>> usersList = [];

  // Role helpers
  bool get isAdmin =>
      ((loggedInUser?['role'] ?? '') as String).toLowerCase() == 'admin';
  bool get isManager =>
      ((loggedInUser?['role'] ?? '') as String).toLowerCase() == 'manager';
  bool get isEmployee =>
      ((loggedInUser?['role'] ?? '') as String).toLowerCase() == 'employee';

  // --------- Session & Login ---------
  void loginUser(Map<String, dynamic> user) {
    final role = (user['role'] ?? user['Role'] ?? user['userRole'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    final assignedShops = ((user['assignedShops'] ?? []) as List)
        .map((e) => e.toString())
        .toList();

    _loggedInUser = {
      ...user,
      'role': role.isEmpty ? 'employee' : role,
      'assignedShops': assignedShops,
    };
    notifyListeners();
  }

  String dayKeyOf(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

  DateTime noonOf(DateTime d) => DateTime(d.year, d.month, d.day, 12, 0, 0);

  double _round2(num v) => (v.toDouble() * 100).roundToDouble() / 100.0;

  void resetOrdersPaging() {
    _orders.clear();
    _lastOrderDoc = null;
    _hasMoreOrders = true;
    notifyListeners();
  }

  Future<void> addTransactionBatch(List<Map<String, dynamic>> entries) async {
    final batch = firestore.batch();
    final col = firestore.collection('transactions');
    for (final e in entries) {
      batch.set(col.doc(), e);
    }
    await batch.commit();
  }

  Future<String?> addOrUpdateWholesaler({
    required String name,
    String? phone,
    String? address,
  }) async {
    try {
      final nameTrim = name.trim();
      if (nameTrim.isEmpty) return 'Name required';

      final nameLower = nameTrim.toLowerCase();

      final dup = await firestore
          .collection('wholesalers')
          .where('nameLower', isEqualTo: nameLower)
          .limit(1)
          .get();

      if (dup.docs.isNotEmpty) {
        await dup.docs.first.reference.update({
          'name': nameTrim,
          'nameLower': nameLower,
          'phone': (phone ?? '').trim(),
          'address': (address ?? '').trim(),
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await firestore.collection('wholesalers').add({
          'name': nameTrim,
          'nameLower': nameLower,
          'phone': (phone ?? '').trim(),
          'address': (address ?? '').trim(),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': _loggedInUser?['name'] ?? _loggedInUser?['email'],
        });
      }

      await fetchWholesalers();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Per-day totals (refund negative).
  Future<Map<String, double>> computeDailyTransactionTotals(
    String shopName,
    DateTime day,
  ) async {
    final key = dayKeyOf(day);

    final qs = await firestore
        .collection('transactions')
        .where('shopName', isEqualTo: shopName)
        .where('dayKey', isEqualTo: key)
        .get();

    double cash = 0, card = 0, other = 0;

    Future<void> addDoc(Map<String, dynamic> d) async {
      final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
      final refund = (d['isRefund'] == true) || (d['refund'] == true);
      final signed = refund ? -amt : amt;
      final m = (d['method'] ?? '').toString();
      if (m == 'cash') {
        cash += signed;
      } else if (m == 'card') {
        card += signed;
      } else {
        other += signed;
      }
    }

    if (qs.docs.isEmpty) 
    {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));

      final fb1 = await firestore
          .collection('transactions')
          .where('shopName', isEqualTo: shopName)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .get();

      if (fb1.docs.isEmpty) {
        final fb2 = await firestore
            .collection('transactions')
            .where('shop', isEqualTo: shopName)
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('createdAt', isLessThan: Timestamp.fromDate(end))
            .get();
        for (final d in fb2.docs) {
          await addDoc(d.data());
        }
      } else {
        for (final d in fb1.docs) {
          await addDoc(d.data());
        }
      }
    } else {
      for (final d in qs.docs) {
        await addDoc(d.data());
      }
    }

    final total = cash + card + other;
    return {
      'cash': _round2(cash),
      'card': _round2(card),
      'other': _round2(other),
      'total': _round2(total),
    };
  }

  /// Close Day → unique sale doc in `sales` (from transactions).
  /// Returns null on success; error string on conflict/failure.
  Future<String?> postDailySaleFromTransactions({
    required String shopName,
    required DateTime day,
  }) async {
    try {
      final user = loggedInUser ?? {};
      final creatorName = (user['name'] ?? user['email'] ?? 'system').toString();
      final creatorUid = (user['uid'] ?? '').toString();

      final totals = await computeDailyTransactionTotals(shopName, day);
      final dayKey = dayKeyOf(day);
      final createdAt = Timestamp.fromDate(noonOf(day));

      final docId = 'sales_${shopName}_$dayKey';
      final salesRef = firestore.collection('sales').doc(docId);

      await firestore.runTransaction((tx) async {
        final snap = await tx.get(salesRef);
        if (snap.exists) {
          throw 'Sale already exists for $shopName on $dayKey';
        }
        tx.set(salesRef, {
          'id': docId,
          'shopName': shopName,
          'shop': shopName, // compatibility
          'cash': totals['cash'],
          'card': totals['card'],
          'other': totals['other'],
          'total': totals['total'],
          'createdAt': createdAt,
          'dayKey': dayKey,
          'source': 'transactions_close_day',
          'createdByUid': creatorUid,
          'createdByName': creatorName,
        });
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<bool> isDayClosed(String shopName, DateTime day) async {
    final key = dayKeyOf(day);
    final qs = await firestore
        .collection('sales')
        .where('shop', isEqualTo: shopName)
        .where('dayKey', isEqualTo: key)
        .limit(1)
        .get();
    return qs.docs.isNotEmpty;
  }

  Future<void> fetchOrdersPage({int pageSize = 20}) async {
    try {
      Query<Map<String, dynamic>> q = firestore
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(pageSize);

      if (_lastOrderDoc != null) {
        q = q.startAfterDocument(_lastOrderDoc!);
      }

      final snap = await q.get();

      if (snap.docs.isNotEmpty) {
        _lastOrderDoc = snap.docs.last;

        _orders.addAll(snap.docs.map((d) {
          final data = d.data();
          final raw = data['createdAt'];
          DateTime? createdAt;
          if (raw is Timestamp) {
            createdAt = raw.toDate();
          } else if (raw is DateTime) {
            createdAt = raw;
          } else if (raw is String) {
            createdAt = DateTime.tryParse(raw);
          }

          return {
            'id': d.id,
            ...data,
            'createdAt': createdAt,
          };
        }));
      }

      if (snap.docs.length < pageSize) {
        _hasMoreOrders = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('fetchOrdersPage error: $e');
    }
  }

  Future<void> addExpense({
    required String shopName,
    required double amount,
    required String category, // Rent, Utility, Misc
    String? note,
  }) async {
    final data = {
      'shopName': shopName,
      'amount': amount,
      'category': category,
      'note': note,
      'createdAt': Timestamp.now(),
      'createdBy': _loggedInUser?['name'] ?? _loggedInUser?['email'],
    };
    final doc = await firestore.collection('expenses').add(data);
    _expenses.add({'id': doc.id, ...data, 'createdAt': DateTime.now()});
    notifyListeners();
  }

  // ===== REPLACE THIS WHOLE FUNCTION (optional if you keep recordWholesalerPayment only) =====
Future<void> addPayment({
  required String shopName,
  required double amount,
  required String toWholesalerName,
  String? note,
  String? mode,
}) async {
  final data = {
    'shopName'        : shopName,
    'amount'          : amount,
    'toWholesalerName': toWholesalerName,
    'note'            : note,
    'mode'            : mode ?? 'Cash', // ✅ ensure stored
    'createdAt'       : Timestamp.now(),
    'createdBy'       : _loggedInUser?['name'] ?? _loggedInUser?['email'],
  };
  final doc = await firestore.collection('payments').add(data);
  _payments.add({'id': doc.id, ...data, 'createdAt': DateTime.now()});
  notifyListeners();
}

  Future<void> fetchExpenses() async {
    final snap = await firestore
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .get();
    _expenses
      ..clear()
      ..addAll(snap.docs.map((d) {
        final m = d.data();
        final ts = m['createdAt'];
        return {
          'id': d.id,
          ...m,
          'createdAt': ts is Timestamp ? ts.toDate() : DateTime.now()
        };
      }));
    notifyListeners();
  }

  Future<void> fetchPayments() async {
    final snap = await firestore
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .get();
    _payments
      ..clear()
      ..addAll(snap.docs.map((d) {
        final m = d.data();
        final ts = m['createdAt'];
        return {
          'id': d.id,
          ...m,
          'createdAt': ts is Timestamp ? ts.toDate() : DateTime.now()
        };
      }));
    notifyListeners();
  }

  Future<void> requestOrderReturn(String id, {String? note}) async {
    await firestore.collection('orders').doc(id).update({
      'isReturnRequested': true,
      'returnNote': note ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await fetchOrders();
  }
Future<double> getWholesalerShopBalance({
  required String shopName,
  required String wholesalerName,
}) async {
  final q = await firestore
      .collection('wholesaler_balances')
      .where('shopName', isEqualTo: shopName)
      .where('wholesalerName', isEqualTo: wholesalerName)
      .limit(1)
      .get();

  if (q.docs.isEmpty) return 0.0;
  final d = q.docs.first.data();
  return (d['balance'] ?? 0).toDouble();
}

Future<void> setWholesalerShopBalance({
  required String shopName,
  required String wholesalerName,
  required double newBalance,
  String? note,
}) async {
  final col = firestore.collection('wholesaler_balances');
  final q = await col
      .where('shopName', isEqualTo: shopName)
      .where('wholesalerName', isEqualTo: wholesalerName)
      .limit(1)
      .get();

  if (q.docs.isEmpty) {
    await col.add({
      'shopName': shopName,
      'wholesalerName': wholesalerName,
      'balance': newBalance,
      'note': note ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } else {
    final doc = q.docs.first.reference;
    await doc.update({
      'balance': newBalance,
      'note': note ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}


Future<Map<String, Map<String, Map<String, dynamic>>>> ordersMatrixForDate({
  required DateTime date,
  List<String>? wholesalersFilter, // optional specific columns
}) async {
  final dayKey = DateFormat('yyyy-MM-dd').format(date);
  final snap = await firestore
      .collection('orders')
      .where('dayKey', isEqualTo: dayKey)
      .get();

  // matrix[shopName][wholesalerName] = {id, amount, status}
  final Map<String, Map<String, Map<String, dynamic>>> matrix = {};

  for (final d in snap.docs) {
    final m = d.data();
    final shop = (m['shopName'] ?? '').toString();
    final wh = (m['wholesalerName'] ?? '').toString();
    if (shop.isEmpty || wh.isEmpty) continue;
    if (wholesalersFilter != null && wholesalersFilter.isNotEmpty &&
        !wholesalersFilter.contains(wh)){

        continue;
        } 

    matrix.putIfAbsent(shop, () => {});
    matrix[shop]![wh] = {
      'id': d.id,
      'amount': (m['amount'] ?? 0).toDouble(),
      'status': m['status'] ?? 'Pending',
    };
  }
  return matrix;
}

final List<Map<String, dynamic>> _ordersMatrix = [];
List<Map<String, dynamic>> get ordersMatrix => List.unmodifiable(_ordersMatrix);


Future<Map<String, List<Map<String, dynamic>>>> pullAllShopOrdersForDate({
  required DateTime date,
}) async {
  final dayKey = DateFormat('yyyy-MM-dd').format(date);
  final snap = await firestore
      .collection('orders')
      .where('dayKey', isEqualTo: dayKey)
      .get();

  // result[wholesalerName] = [ {shopName, amount, status, id}, ... ]
  final Map<String, List<Map<String, dynamic>>> result = {};
  for (final d in snap.docs) {
    final m = d.data();
    final wh = (m['wholesalerName'] ?? '').toString();
    result.putIfAbsent(wh, () => []);
    result[wh]!.add({
      'id': d.id,
      'shopName': m['shopName'] ?? '',
      'amount': (m['amount'] ?? 0).toDouble(),
      'status': m['status'] ?? 'Pending',
    });
  }
  return result;
}

Future<void> addEmployeeExpenseEntry({
  required String shopName,
  required String employeeName,
  required double amount,
  required String type, // 'salary' | 'advance' | 'paid'
  String? note,
  DateTime? when,
}) async {
  final ts = Timestamp.fromDate(when ?? DateTime.now());
  await firestore.collection('employee_expenses').add({
    'shopName': shopName,
    'employeeName': employeeName,
    'amount': amount,
    'type': type,
    'note': note ?? '',
    'createdAt': ts,
  });
}

Future<Map<String, double>> getEmployeeExpenseMonthTotals({
  required String shopName,
  required String employeeName,
  required DateTime monthAnchor, // any day of month
}) async {
  final start = DateTime(monthAnchor.year, monthAnchor.month, 1);
  final end = DateTime(monthAnchor.year, monthAnchor.month + 1, 1);
  final q = await firestore
      .collection('employee_expenses')
      .where('shopName', isEqualTo: shopName)
      .where('employeeName', isEqualTo: employeeName)
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('createdAt', isLessThan: Timestamp.fromDate(end))
      .get();

  double salary = 0, advance = 0, paid = 0;
  for (final d in q.docs) {
    final m = d.data();
    final t = (m['type'] ?? 'salary').toString();
    final a = (m['amount'] ?? 0).toDouble();
    if (t == 'advance') {
      advance += a;
    }
    else if (t == 'paid') {
      paid += a;
    }
    else {

    salary += a;
    } 
  }
  // Remaining = salary + advance - paid
  return {
    'salary': salary,
    'advance': advance,
    'paid': paid,
    'remaining': salary + advance - paid,
  };
}

Future<void> addOtherExpenseEntry({
  required String shopName,
  required double amount,
  required String title, // e.g., 'Gas in car'
  String? note,
  DateTime? when,
}) async {
  await firestore.collection('expenses').add({
    'shopName': shopName,
    'amount': amount,
    'category': title,
    'note': note ?? '',
    'createdAt': Timestamp.fromDate(when ?? DateTime.now()),
  });
}

final List<Map<String, dynamic>> _otherExpenses = [];
List<Map<String, dynamic>> get otherExpenses => List.unmodifiable(_otherExpenses);

Future<double> getOtherExpenseMonthTotal({
  required String shopName,
  required DateTime monthAnchor,
}) async {
  final start = DateTime(monthAnchor.year, monthAnchor.month, 1);
  final end = DateTime(monthAnchor.year, monthAnchor.month + 1, 1);
  final q = await firestore
      .collection('expenses')
      .where('shopName', isEqualTo: shopName)
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('createdAt', isLessThan: Timestamp.fromDate(end))
      .get();
  double sum = 0;
  for (final d in q.docs) {
    sum += (d.data()['amount'] ?? 0).toDouble();
  }
  return sum;
}
Future<void> addEmployeeExpense({
  required String shopName,
  required double amount,
  String type = 'salary', // salary | advance | paid
  String? employeeId,
  String? employeeName,
  String? note,
}) async {
  final data = {
    'shopName': shopName,
    'amount': amount,
    'type': type,
    'employeeId': employeeId ?? '',
    'employeeName': employeeName ?? (_loggedInUser?['name'] ?? ''),
    'note': note ?? '',
    'createdAt': Timestamp.now(),
    'createdBy': _loggedInUser?['name'] ?? _loggedInUser?['email'],
  };
await firestore.collection('employee_expenses').add(data);
  // local cache optional: fetch again to stay consistent
  try { await fetchEmployeeExpenses(from: DateTime.now().subtract(const Duration(days: 1)), to: DateTime.now().add(const Duration(days: 1))); } catch (_) {}
}


Future<Set<String>> shopsWithSaleOn(DateTime day) async {
  final key = dayKeyOf(day);
  final qs = await firestore.collection('sales').where('dayKey', isEqualTo: key).get();
  final set = <String>{};
  for (final d in qs.docs) {
    final m = d.data(); // <-- add this
    final name = (m['shopName'] ?? m['shop'])?.toString();
    if (name != null && name.isNotEmpty) set.add(name);
  }
  return set;
}
  Future<bool> loginWithNameAndCode(String name, String code) async {
    final nameLower = name.trim().toLowerCase();
    final trimmedCode = code.trim();

    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }

      final snapshot = await firestore
          .collection('users')
          .where('loginCode', isEqualTo: trimmedCode)
          .get();

      if (snapshot.docs.isEmpty) {
        return false;
      }

      final matches = snapshot.docs.where((d) {
        final docName = (d.data()['name'] ?? '').toString().toLowerCase();
        return docName == nameLower;
      }).toList();

      if (matches.isEmpty) {
        return false;
      }

      final match = matches.first;
      final data = match.data();

      final role = (data['role'] ?? data['Role'] ?? data['userRole'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      final assignedShops = ((data['assignedShops'] ?? []) as List)
          .map((e) => e.toString())
          .toList();

      loginUser({
        ...data,
        'id': match.id,
        'uid': match.id,
        'role': role.isEmpty ? 'employee' : role,
        'assignedShops': assignedShops,
      });

      await _saveSession(mode: 'code', uid: match.id);
      return true;
    } catch (e) {
      debugPrint('loginWithNameAndCode error: $e');
      return false;
    }
  }

  Future<bool> loginWithEmailAndPassword(
      String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final u = cred.user;
      if (u == null) {
        return false;
      }

      final userSnap = await firestore.collection('users').doc(u.uid).get();
      if (!userSnap.exists) return false;

      final data = userSnap.data()!;
      final roleStr = (data['role'] ?? data['Role'] ?? data['userRole'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      final assignedShops = ((data['assignedShops'] ?? []) as List)
          .map((e) => e.toString())
          .toList();

      _loggedInUser = {
        ...data,
        'uid': u.uid,
        'role': roleStr.isEmpty ? 'employee' : roleStr,
        'assignedShops': assignedShops,
      };
      notifyListeners();

      await _saveSession(mode: 'auth', uid: u.uid);
      return true;
    } catch (e) {
      debugPrint('loginWithEmailAndPassword error: $e');
      return false;
    }
  }

  Future<void> _saveSession({required String mode, required String uid}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('session_mode', mode); // 'auth' | 'code'
    await p.setString('session_uid', uid);
  }

  Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('session_mode');
    await p.remove('session_uid');
  }

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString('session_mode'); // 'auth' | 'code'
      final savedUid = prefs.getString('session_uid');

      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        await _saveSession(mode: 'auth', uid: authUser.uid);

        final snap =
            await firestore.collection('users').doc(authUser.uid).get();
        if (snap.exists) {
          final data = snap.data()!;
          loginUser({...data, 'uid': authUser.uid});
        }
        return;
      }

      if (savedMode == 'code' && savedUid != null && savedUid.isNotEmpty) {
        final snap = await firestore.collection('users').doc(savedUid).get();
        if (snap.exists) {
          final data = snap.data()!;
          loginUser({...data, 'uid': savedUid});
          return;
        } else {
          await clearSession();
        }
      }
    } catch (_) {/* ignore */}
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    _loggedInUser = null;
    _selectedShopId = null;
    _selectedShopName = null;
    await clearSession();
    notifyListeners();
  }

  Future<void> addSaleUniquePerShopPerDay(Map<String, dynamic> saleData) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final shopKey = (saleData['shop'] ?? '').toString().trim();

    if (shopKey.isEmpty) {
      throw 'Shop is required';
    }

    final docId = '$shopKey|$todayStr';
    final docRef = firestore.collection('sales').doc(docId);

    await firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (snap.exists) {
        throw 'Sale already exists for this shop today';
      }

      final data = {
        ...saleData,
        'createdAt': Timestamp.fromDate(now),
        'saleDate': todayStr,
      };
      tx.set(docRef, data);
    });

    _sales.add({
      ...saleData,
      'id': docId,
      'createdAt': now,
      'saleDate': todayStr,
    });
    notifyListeners();
  }

  // --------- Sales querying helpers ---------
  Query<Map<String, dynamic>> buildSalesQuery({
    DateTime? from, // inclusive
    DateTime? to, // exclusive
    String? shop, // null or 'All' => no filter
  }) {
    var q =
        firestore.collection('sales').orderBy('createdAt', descending: true);

    if (from != null) {
      q = q.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('createdAt', isLessThan: Timestamp.fromDate(to));
    }
    if (shop != null && shop.isNotEmpty && shop != 'All') {
      q = q.where('shop', isEqualTo: shop);
    }
    return q;
  }

  Query<Map<String, dynamic>> buildSalesQueryLoose({String? shop}) {
    var q =
        firestore.collection('sales').orderBy('createdAt', descending: true);
    if (shop != null && shop.isNotEmpty && shop != 'All') {
      q = q.where('shop', isEqualTo: shop);
    }
    return q;
  }

 Map<String, dynamic> mapSaleDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> d) {
  final data = d.data();

  DateTime created;
  final raw = data['createdAt'];
  if (raw is Timestamp) {
    created = raw.toDate();
  } else if (raw is DateTime) {
    created = raw;
  } else if (raw is String) {
    created = DateTime.tryParse(raw) ?? DateTime.now();
  } else {
    created = DateTime.now();
  }

  double toD(v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ""}') ?? 0.0;

  final shopName = (data['shop'] ?? data['shopName'] ?? '').toString();
  final shopId = (data['shopId'] ?? '').toString().trim().isNotEmpty
      ? (data['shopId'] as String)
      : (shopIdForName(shopName) ?? '');

  return {
    'id': d.id,
    'shop': shopName,
    'shopId': shopId, // 👈 added for Cash Collect
    'employee': (data['employee'] ?? data['addedBy'] ?? '').toString(),
    'cash': toD(data['cash']),
    'card': toD(data['card']),
    'other': toD(data['other']),
    'total': toD(data['total']),
    'createdAt': created,
    'saleDate': DateFormat('yyyy-MM-dd').format(created),
  };
}

  // --------- Selected Shop (for employee flow) ---------
  String? _selectedShopId;
  String? _selectedShopName;
  String? get selectedShopId => _selectedShopId;
  String? get selectedShopName => _selectedShopName;

  void setSelectedShop(String shopId, String shopName) {
    _selectedShopId = shopId;
    _selectedShopName = shopName;
    notifyListeners();
  }

  // --------- Edit Requests ---------
  List<Map<String, dynamic>> get editRequests => _editRequests;

  void addEditRequest({
    required String type, // 'sale' or 'order'
    required int itemId,
    required String reason,
    required String requestedBy,
  }) {
    _editRequests.add({
      'type': type,
      'itemId': itemId,
      'reason': reason,
      'requestedBy': requestedBy,
      'timestamp': DateTime.now(),
    });
    notifyListeners();
  }

  Future<void> requestSaleEdit(
    int saleId,
    String reason,
    double newAmount,
  ) async {
    try {
      final request = {
        'type': 'sale',
        'itemId': saleId,
        'reason': reason,
        'newAmount': newAmount,
        'requestedBy': _loggedInUser?['name'] ?? 'Unknown',
        'status': 'pending',
        'timestamp': DateTime.now(),
      };

      final docRef =
          await FirebaseFirestore.instance.collection('editRequests').add(
                request,
              );

      _editRequests.add({'firebaseId': docRef.id, ...request});
      notifyListeners();
    } catch (e) {
      log('Error submitting sale edit request: $e', name: 'Sales');
    }
  }

  Future<void> approveSaleEdit(String firebaseId) async {
    try {
      final reqIndex =
          _editRequests.indexWhere((r) => r['firebaseId'] == firebaseId);
      if (reqIndex == -1) return;

      final request = _editRequests[reqIndex];
      final itemId = request['itemId'].toString();
      final newAmount = (request['newAmount'] as num).toDouble();

      await FirebaseFirestore.instance
          .collection('sales')
          .doc(itemId)
          .update({
        'total': newAmount,
        'editedAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection('editRequests')
          .doc(firebaseId)
          .update({'status': 'approved'});

      await fetchEditRequests();
      await fetchSales();
      notifyListeners();
    } catch (e) {
      log('Error approving sale edit: $e', name: 'Sales');
    }
  }

  Future<void> rejectSaleEdit(String firebaseId) async {
    try {
      await FirebaseFirestore.instance
          .collection('editRequests')
          .doc(firebaseId)
          .update({'status': 'rejected'});

      await fetchEditRequests();
      notifyListeners();
    } catch (e) {
      log('Error rejecting sale edit: $e', name: 'Sales');
    }
  }

  Future<void> updateSaleAmount(
      String saleId, double newAmount, String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('sales')
          .doc(saleId)
          .update({
        'total': newAmount,
        'editReason': reason,
        'editedAt': Timestamp.now(),
      });
      await fetchSales();
    } catch (e) {
      log('Error updating sale: $e', name: 'Sales');
    }
  }

  Future<void> updateSale(
      String saleId, Map<String, dynamic> saleData) async {
    try {
      await FirebaseFirestore.instance
          .collection('sales')
          .doc(saleId)
          .update(saleData);
      await fetchSales();
      notifyListeners();
    } catch (e) {
      log('Error updating sale: $e', name: 'Sales');
    }
  }

  // --------- Employees & Shops helpers ---------
  void addEmployee(Map<String, dynamic> employeeData) {
    if (employeeData.isNotEmpty) {
      employees.add(employeeData);
      final name = employeeData['name'];
      final List<String> assignedShops =
          List<String>.from(employeeData['assignedShops'] ?? []);

      for (String shopName in assignedShops) {
        final index = shops.indexWhere((s) => s['name'] == shopName);
        if (index != -1) {
          final existingEmployees =
              List<String>.from(shops[index]['employees'] ?? []);
          if (!existingEmployees.contains(name)) {
            existingEmployees.add(name);
            shops[index]['employees'] = existingEmployees;
          }
        }
      }
      notifyListeners();
    }
  }

  Future<void> cleanupShopFromEmployees(String shopName) async {
    try {
      final empSnap = await firestore.collection('employees').get();
      for (final doc in empSnap.docs) {
        final assigned = List<String>.from(doc.data()['assignedShops'] ?? []);
        if (assigned.contains(shopName)) {
          assigned.remove(shopName);
          await firestore.collection('employees').doc(doc.id).update({
            'assignedShops': assigned,
          });
        }
      }

      final userSnap = await firestore.collection('users').get();
      for (final doc in userSnap.docs) {
        final assigned = List<String>.from(doc.data()['assignedShops'] ?? []);
        if (assigned.contains(shopName)) {
          assigned.remove(shopName);
          await firestore.collection('users').doc(doc.id).update({
            'assignedShops': assigned,
          });
        }
      }
    } catch (e) {
      log('❌ Error cleaning shop from employees/users: $e', name: 'Shop');
    }
  }

  Future<void> cleanupEmployeeFromShops(String employeeName) async {
    try {
      final snap = await firestore.collection('shops').get();
      for (final doc in snap.docs) {
        final emps = List<String>.from(doc.data()['employees'] ?? []);
        if (emps.contains(employeeName)) {
          emps.remove(employeeName);
          await firestore.collection('shops').doc(doc.id).update({
            'employees': emps,
          });
        }
      }
    } catch (e) {
      log('❌ Error cleaning employee from shops: $e', name: 'Employee');
    }
  }

  Future<void> deleteShopByName(String shopName) async {
    try {
      final shopDoc = await firestore
          .collection('shops')
          .where('name', isEqualTo: shopName)
          .limit(1)
          .get();

      if (shopDoc.docs.isEmpty) return;

      final shopId = shopDoc.docs.first.id;

      await firestore.collection('shops').doc(shopId).update({
        'isDeleted': true,
      });

      final employeesSnapshot = await firestore.collection('employees').get();
      for (var doc in employeesSnapshot.docs) {
        final data = doc.data();
        final assignedShops =
            List<String>.from(data['assignedShops'] ?? []);
        if (assignedShops.contains(shopName)) {
          assignedShops.remove(shopName);
          await firestore.collection('employees').doc(doc.id).update({
            'assignedShops': assignedShops,
          });
        }
      }

      await fetchShops();
      await fetchEmployees();
      notifyListeners();
    } catch (e) {
      log("Error deleting shop: $e", name: 'Shop');
    }
  }

  /// NEVER delete admin; delete user/employee safely and clean references in shops
  Future<void> deleteEmployeeById(String uid, String name) async {
    try {
      final userDoc = await firestore.collection('users').doc(uid).get();
      final role =
          ((userDoc.data()?['role'] ?? '') as String).toLowerCase().trim();
      if (role == 'admin') {
        log('Blocked: attempt to delete admin', name: 'Employee');
        return;
      }

      final empDoc = await firestore.collection('employees').doc(uid).get();
      if (empDoc.exists) {
        await firestore.collection('employees').doc(uid).delete();
      }

      await firestore.collection('users').doc(uid).delete();

      final shopsSnapshot = await firestore.collection('shops').get();
      for (var doc in shopsSnapshot.docs) {
        final data = doc.data();
        final emps = List<String>.from(data['employees'] ?? []);
        if (emps.contains(name)) {
          emps.remove(name);
          await firestore.collection('shops').doc(doc.id).update({
            'employees': emps,
          });
        }
      }

      await fetchShops();
      await fetchEmployees();
      await fetchUsers();
      notifyListeners();
    } catch (e) {
      log("Error deleting employee: $e", name: 'Employee');
    }
  }

  void updateShop(String originalName, Map<String, dynamic> updatedData) {
    final index = shops.indexWhere((s) => s['name'] == originalName);
    if (index != -1) {
      shops[index] = {...shops[index], ...updatedData};
      notifyListeners();
    }
  }

  Map<String, dynamic> getEmployeeByName(String name) {
    return employees.firstWhere((e) => e['name'] == name, orElse: () => {});
  }

  void assignAccess(String shopName, String employeeName) {
    final shopIndex = shops.indexWhere((shop) => shop['name'] == shopName);
    if (shopIndex != -1) {
      final currentEmployees =
          List<String>.from(shops[shopIndex]['employees'] ?? []);
      if (!currentEmployees.contains(employeeName)) {
        currentEmployees.add(employeeName);
        shops[shopIndex]['employees'] = currentEmployees;
        notifyListeners();
      }
    }
  }

  void addShop(Map<String, dynamic> shopData) {
    if (shopData.isNotEmpty) {
      shops.add(shopData);
      notifyListeners();
    }
  }

  // --------- Orders ---------
  Future<void> addOrder(Map<String, dynamic> order) async {
    try {
      order['status'] ??= 'Pending';
      order['createdAt'] ??= FieldValue.serverTimestamp(); // ✅ here
order['updatedAt'] = FieldValue.serverTimestamp();   // (optional) keep updatedAt too
      order['canRequestEdit'] ??= true;

      if (order['id'] != null && order['id'].toString().isNotEmpty) {
        final id = order['id'].toString();
        await FirebaseFirestore.instance.collection('orders').doc(id).set(order);
        _orders
            .add({...order, 'id': id, 'createdAt': _toDate(order['createdAt'])});
      } else {
        final docRef =
            await FirebaseFirestore.instance.collection('orders').add(order);
        _orders.add(
            {...order, 'id': docRef.id, 'createdAt': _toDate(order['createdAt'])});
      }

      notifyListeners();
    } catch (e) {
      log('Error adding order: $e', name: 'Orders');
    }
  }

  DateTime _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

Future<void> forwardOrder(String id) async {
  if (!isAdmin && !isManager) {
    throw 'Sirf admin/manager forward kar sakte hain.';
  }
  await updateOrderStatus(id, 'Forwarded');
  final i = _orders.indexWhere((o) => o['id'] == id);
  if (i != -1) {
    _orders[i] = {..._orders[i], 'status': 'Forwarded', 'updatedAt': DateTime.now()};
    notifyListeners();
  }
}

  bool _userBelongsToShop(String shopName) {
  // admin/manager sab shops pe allowed
  if (isAdmin || isManager) return true;

  // employee: selected shop ya assignedShops me hona chahiye
  final sel = selectedShopName ?? '';
  if (sel.isNotEmpty && sel == shopName) return true;

  final assigned = List<String>.from(_loggedInUser?['assignedShops'] ?? const []);
  return assigned.contains(shopName);
}

Future<void> markOrderReceived(String id) async {
  try {
    // read order to verify shop
    final doc = await firestore.collection('orders').doc(id).get();
    if (!doc.exists) throw 'Order not found';
    final shop = (doc.data()?['shopName'] ?? '').toString();

    if (!_userBelongsToShop(shop)) {
      throw 'You can only mark orders for your own shop as received.';
    }

    await updateOrderStatus(id, 'Received');
    final i = _orders.indexWhere((o) => o['id'] == id);
    if (i != -1) {
      _orders[i] = {
        ..._orders[i],
        'status': 'Received',
        'updatedAt': DateTime.now(),
      };
      notifyListeners();
    }
  } catch (e) {
    log('Error marking order received: $e', name: 'Orders');
    rethrow;
  }
}
  Future<void> deleteOrder(String id) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(id).delete();
      _orders.removeWhere((o) => o['id'] == id);
      notifyListeners();
    } catch (e) {
      log('Error deleting order: $e', name: 'Orders');
    }
  }

  Future<void> editOrder(Map<String, dynamic> updatedOrder) async {
    try {
      final orderId = updatedOrder['id'].toString();
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(updatedOrder);

      final index = _orders.indexWhere((o) => o['id'] == updatedOrder['id']);
      if (index != -1) {
        _orders[index] = updatedOrder;
        notifyListeners();
      }
    } catch (e) {
      log('Error updating order: $e', name: 'Orders');
    }
  }

  bool canEditOrder(Map<String, dynamic> order) {
    final raw = order['createdAt'];
    DateTime? createdAt;

    if (raw is DateTime) {
      createdAt = raw;
    } else if (raw is Timestamp) {
      createdAt = raw.toDate();
    }

    if (createdAt == null) {
      return false;
    }

    return DateTime.now().difference(createdAt).inMinutes <= 10;
  }

  List<Map<String, dynamic>> getEmployeeOrders(String employeeName) {
    return _orders.where((o) => o['createdByName'] == employeeName).toList();
  }

Future<void> deleteWholesalerByName(String name) async {
  try {
    final q = await firestore
        .collection('wholesalers')
        .where('name', isEqualTo: name)
        .get();

    for (final d in q.docs) {
      await d.reference.delete();
    }

    wholesalers.removeWhere((w) => (w['name'] ?? '') == name);
    notifyListeners();
  } catch (e) {
    log('deleteWholesalerByName error: $e', name: 'Wholesalers');
  }
}


  // --------- Sales ---------
  List<Map<String, dynamic>> get allSales => [..._sales];

  List<Map<String, dynamic>> get sales {
    final role = _loggedInUser?['role'];
    final name = _loggedInUser?['name'];

    if (role == 'admin' || role == 'manager') {
      return _sales;
    } else if (role == 'employee') {
      return _sales.where((s) => s['employee'] == name).toList();
    } else {
      return [];
    }
  }

  Future<void> addSale(Map<String, dynamic> saleData) async {
    final ts = Timestamp.now();
    saleData['createdAt'] = ts;

    if (saleData.isNotEmpty && saleData['total'] != null) {
      try {
        final docRef =
            await FirebaseFirestore.instance.collection('sales').add(saleData);

        saleData['id'] = docRef.id;

        _sales.add({
          ...saleData,
          'createdAt': ts.toDate(),
        });
        notifyListeners();
      } catch (e) {
        log('Error adding sale: $e');
      }
    }
  }

  List<Map<String, dynamic>> get salesEditRequests =>
      _editRequests.where((r) => r['type'] == 'sale').toList();

  List<Map<String, dynamic>> getEmployeeSales(String employeeName) {
    final now = DateTime.now();
    return _sales.where((sale) {
      final createdAt = sale['createdAt'] as DateTime?;
      final createdBy = sale['addedBy'];
      if (createdAt == null || createdBy != employeeName) return false;
      final diff = now.difference(createdAt);
      return diff.inMinutes <= 5;
    }).toList();
  }

  // --------- Dashboard Counters ---------
  int get totalOrders => _orders.length;

  double get totalSales => sales.fold(0.0, (sumValue, s) {
        final total = double.tryParse(s['total'].toString()) ?? 0.0;
        return sumValue + total;
      });

  int get totalShops => shops.length;
  int get totalEmployees => employees.length;

  List<Map<String, dynamic>> get pendingOrders =>
      _orders.where((o) => o['status'] == 'Pending').toList();

  List<Map<String, dynamic>> get forwardedOrders =>
      _orders.where((o) => o['status'] == 'Forwarded').toList();

  List<Map<String, dynamic>> get receivedOrders =>
      _orders.where((o) => o['status'] == 'Received').toList();

  List<Map<String, dynamic>> getFilteredSales(String filter) {
    final now = DateTime.now();

    return sales.where((sale) {
      final raw = sale['date'] ?? sale['createdAt'];
      final date =
          raw is Timestamp ? raw.toDate() : (raw is DateTime ? raw : now);

      if (filter == 'Daily') {
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      } else if (filter == 'Weekly') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return date.isAfter(startOfWeek);
      } else if (filter == 'Monthly') {
        return date.year == now.year && date.month == now.month;
      }
      return true;
    }).toList();
  }

  Map<String, String> getFilteredTotals(String filter) {
    double cash = 0.0, card = 0.0, other = 0.0;

    final filtered = getFilteredSales(filter);
    for (var sale in filtered) {
      cash += double.tryParse(sale['cash'].toString()) ?? 0.0;
      card += double.tryParse(sale['card'].toString()) ?? 0.0;
      other += double.tryParse(sale['other'].toString()) ?? 0.0;
    }

    return {
      'cash': '\$ ${cash.toStringAsFixed(0)}',
      'card': '\$ ${card.toStringAsFixed(0)}',
      'other': '\$ ${other.toStringAsFixed(0)}',
    };
  }

  Future<void> approveEditRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('editRequests')
          .doc(requestId)
          .update({'status': 'approved'});

      await fetchAllData();
      notifyListeners();
    } catch (e) {
      log('Error approving edit request: $e', name: 'Requests');
    }
  }

  Future<void> rejectEditRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('editRequests')
          .doc(requestId)
          .update({'status': 'rejected'});

      await fetchAllData();
      notifyListeners();
    } catch (e) {
      log('Error rejecting edit request: $e', name: 'Requests');
    }
  }

  String? getShopNameById(String shopId) {
    try {
      final shop = shops.firstWhere((shop) => shop['id'] == shopId);
      return shop['name'];
    } catch (e) {
      return null;
    }
  }

  // --------- Fetchers ---------
  Future<void> fetchUsers() async {
    try {
      final snapshot = await firestore.collection('users').get();
      usersList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          ...data,
          'role': (data['role'] ?? data['Role'] ?? data['userRole'] ?? '')
              .toString()
              .toLowerCase()
              .trim(),
          'assignedShops': ((data['assignedShops'] ?? []) as List)
              .map((e) => e.toString())
              .toList(),
        };
      }).toList();
      notifyListeners();
    } catch (e) {
      log('Error fetching users: $e', name: 'Users');
    }
  }

  Future<void> fetchShops() async {
  final snapshot = await firestore.collection('shops').get();
  shops = snapshot.docs.map((doc) {
    return {...doc.data(), 'id': doc.id};
  }).toList();

  // 👇 build fast lookup maps
  _shopNameById
    ..clear()
    ..addEntries(shops.map((s) => MapEntry(s['id'] as String, (s['name'] ?? '').toString())));
  _shopIdByName
    ..clear()
    ..addEntries(shops.map((s) => MapEntry((s['name'] ?? '').toString().trim().toLowerCase(), s['id'] as String)));

  notifyListeners();
}


  Future<void> fetchEmployees() async {
    try {
      final snapshot = await firestore.collection('employees').get();
      employees = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          ...data,
          'role': (data['role'] ?? data['Role'] ?? data['userRole'] ?? '')
              .toString()
              .toLowerCase()
              .trim(),
          'assignedShops': ((data['assignedShops'] ?? []) as List)
              .map((e) => e.toString())
              .toList(),
        };
      }).toList();
      notifyListeners();
    } catch (e) {
      log('Error fetching employees: $e', name: 'Employees');
    }
  }

  // ---------- Storage: upload invoice image ----------
  Future<String> uploadInvoiceBytes(Uint8List bytes,
      {required String shopName, required String wholesaler}) async {
    final now = DateTime.now();
    final dayKey = DateFormat('yyyyMMdd_HHmmss').format(now);
    final path = 'invoices/$shopName/$wholesaler/$dayKey.jpg';
    final ref = FirebaseStorage.instance.ref(path);
    final task = await ref
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await task.ref.getDownloadURL();
  }

  // ---------- Orders helpers: uniqueness + place ----------
Future<String?> placeOrderUniquePerDay({
  required String shopName,
  String? wholesalerId,
  required String wholesalerName,
  required double amount,
  double? amount2,
  String? note,
  String? invoiceUrl,
}) async {
  final user = _loggedInUser ?? {};
  final dayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ✅ shop + day unique (wholesaler se independent)
  final dup = await firestore
      .collection('orders')
      .where('shopName', isEqualTo: shopName)
      .where('dayKey', isEqualTo: dayKey)
      .limit(1)
      .get();

  if (dup.docs.isNotEmpty) {
    return 'Is shop se aaj ka order already mojood hai.';
  }

  final data = {
  'shopName': shopName,
  'wholesalerId': wholesalerId ?? '',
  'wholesalerName': wholesalerName,
  'amount': amount,
  if (amount2 != null) 'amount2': amount2,
  'status': 'Pending',
  'invoiceUrl': invoiceUrl,
  'note': note,
  'createdAt': FieldValue.serverTimestamp(), // ✅ here
  'updatedAt': FieldValue.serverTimestamp(), // ✅ and here
  'createdByUid': user['uid'],
  'createdByName': user['name'] ?? user['email'],
  'dayKey': dayKey,
};

  await addOrder(data);
  return null;
}

  List<Map<String, dynamic>> wholesalers = [];

  Future<void> fetchWholesalers() async {
  final snap = await firestore
      .collection('wholesalers')
      .where('isActive', isEqualTo: true)
      .get();

  wholesalers = snap.docs.map((d) {
    final m = d.data();
    return {
      'id': d.id,
      ...m,
      'name': (m['name'] ?? '').toString(),
      'nameLower': (m['nameLower'] ?? (m['name'] ?? '')).toString().toLowerCase(),
      'phone': (m['phone'] ?? '').toString(),
      'address': (m['address'] ?? '').toString(),
    };
  }).toList()
    ..sort((a, b) => (a['nameLower'] as String).compareTo(b['nameLower'] as String));

  notifyListeners();
}
  Future<List<Map<String, dynamic>>> fetchSalesBetween({
    required DateTime from,
    required DateTime to,
    String? shopName, // null => all shops
  }) async {
    final q = buildSalesQuery(
        from: from,
        to: to,
        shop: (shopName == null || shopName == 'All') ? null : shopName);
    final snap = await q.get();
    return snap.docs.map(mapSaleDoc).toList();
  }

  Future<List<Map<String, dynamic>>> fetchWholesalerInvoices({
    required DateTime from,
    required DateTime to,
    String? shopName, // optional
  }) async {
    var q = firestore
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('createdAt', isLessThan: Timestamp.fromDate(to));

    if (shopName != null && shopName != 'All') {
      q = q.where('shopName', isEqualTo: shopName);
    }

    final snap = await q.get();
    return snap.docs.map((d) {
      final m = d.data();
      final raw = m['createdAt'];
      DateTime? created = raw is Timestamp
          ? raw.toDate()
          : (raw is String ? DateTime.tryParse(raw) : null);
      return {
        'id': d.id,
        'wholesalerId': m['wholesalerId'] ?? '',
        'wholesalerName': m['wholesalerName'] ?? m['toWholesalerName'] ?? '',
        'amount': (m['amount'] ?? m['invoiceAmount'] ?? 0).toDouble(),
        'status': m['status'] ?? 'Pending',
        'invoiceUrl': m['invoiceUrl'] ?? '',
        'createdAt': created,
        'dayKey': m['dayKey'] ?? '',
        'shopName': m['shopName'] ?? m['shop'] ?? '',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchEmployeeExpenses({
    required DateTime from,
    required DateTime to,
    String? shopName,
  }) async {
    var q = firestore
        .collection('employee_expenses')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('createdAt', isLessThan: Timestamp.fromDate(to));
    if (shopName != null && shopName != 'All') {
      q = q.where('shopName', isEqualTo: shopName);
    }
    final snap = await q.get();
    return snap.docs.map((d) {
      final m = d.data();
      final raw = m['createdAt'];
      DateTime? created = raw is Timestamp
          ? raw.toDate()
          : (raw is String ? DateTime.tryParse(raw) : null);
      return {
        'id': d.id,
        'employeeId': m['employeeId'] ?? '',
        'employeeName': m['employeeName'] ?? '',
        'amount': (m['amount'] ?? 0).toDouble(),
        'type': m['type'] ?? 'salary', // salary|advance|paid
        'note': m['note'] ?? '',
        'createdAt': created,
        'shopName': m['shopName'] ?? '',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchOtherExpenses({
    required DateTime from,
    required DateTime to,
    String? shopName,
  }) async {
    var q = firestore
        .collection('expenses')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('createdAt', isLessThan: Timestamp.fromDate(to));
    if (shopName != null && shopName != 'All') {
      q = q.where('shopName', isEqualTo: shopName);
    }
    final snap = await q.get();
    return snap.docs.map((d) {
      final m = d.data();
      final raw = m['createdAt'];
      DateTime? created = raw is Timestamp
          ? raw.toDate()
          : (raw is String ? DateTime.tryParse(raw) : null);
      return {
        'id': d.id,
        'title': m['category'] ?? 'Expense',
        'amount': (m['amount'] ?? 0).toDouble(),
        'note': m['note'] ?? '',
        'createdAt': created,
        'shopName': m['shopName'] ?? '',
      };
    }).toList();
  }


Future<void> fetchOtherExpensesForMonth(DateTime anchor, {String shopName = 'All'}) async {
  final from = DateTime(anchor.year, anchor.month, 1);
  final to   = DateTime(anchor.year, anchor.month + 1, 1);

  var q = firestore.collection('expenses')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .where('createdAt', isLessThan: Timestamp.fromDate(to));

  if (shopName != 'All' && shopName.isNotEmpty) {
    q = q.where('shopName', isEqualTo: shopName);
  }

  final snap = await q.orderBy('createdAt', descending: true).get();
  _otherExpenses
    ..clear()
    ..addAll(snap.docs.map((d) {
      final m = d.data();
      return {
        'id': d.id,
        'title': (m['category'] ?? 'Expense').toString(),
        'amount': (m['amount'] ?? 0).toDouble(),
        'note': m['note'] ?? '',
        'createdAt': (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        'shopName': (m['shopName'] ?? '').toString(),
      };
    }));
  notifyListeners();
}

double sumOtherExpenseMonth() {
  double s = 0;
  for (final e in _otherExpenses) {
    s += (e['amount'] as num?)?.toDouble() ?? 0.0;
  }
  return s;
}

// Convenience: simple add (UI FAB se call)
Future<void> addOtherExpense({
  required String title,
  required double amount,
  DateTime? date,
  String shopName = '',
  String? note,
}) async {
  await firestore.collection('expenses').add({
    'shopName': shopName,
    'amount': amount,
    'category': title,
    'note': note ?? '',
    'createdAt': Timestamp.fromDate(date ?? DateTime.now()),
    'createdBy': _loggedInUser?['name'] ?? _loggedInUser?['email'],
  });
  // list refresh
  await fetchOtherExpensesForMonth(date ?? DateTime.now(), shopName: shopName.isEmpty ? 'All' : shopName);
}


Future<double> fetchEmployeeExpenseSumForMonth(DateTime anchor, {String shopName = 'All'}) async {
  final from = DateTime(anchor.year, anchor.month, 1);
  final to   = DateTime(anchor.year, anchor.month + 1, 1);
  final list = await fetchEmployeeExpenses(from: from, to: to, shopName: shopName == 'All' ? null : shopName);
  double s = 0;
  for (final e in list) { s += (e['amount'] as num?)?.toDouble() ?? 0.0; }
  return s;
}



// Build matrix rows for UI (shops × wholesalers) and keep in _ordersMatrix
Future<void> fetchOrdersMatrix(DateTime day, List<String> shopsList, List<String> wholesalersList) async {
  final matrix = await ordersMatrixForDate(date: day);

  final rows = <Map<String, dynamic>>[];
  for (final shop in shopsList) {
    final row = <String, dynamic>{'shopName': shop};
    for (final w in wholesalersList) {
      row[w] = matrix[shop]?[w]; // {id, amount, status} or null
    }
    rows.add(row);
  }
  _ordersMatrix
    ..clear()
    ..addAll(rows);
  notifyListeners();
}

/// Place OR update order for (day, shop, wholesaler). 1 cell = 1 order.
/// (Unique by dayKey+shopName+wholesalerName)
Future<void> placeOrUpdateOrder({
  required DateTime day,
  required String shopName,
  required String wholesalerName,
  required double amount,
}) async {
  final dayKey = DateFormat('yyyy-MM-dd').format(day);

  final q = await firestore.collection('orders')
      .where('dayKey', isEqualTo: dayKey)
      .where('shopName', isEqualTo: shopName)
      .where('wholesalerName', isEqualTo: wholesalerName)
      .limit(1).get();

  final payload = {
    'dayKey': dayKey,
    'shopName': shopName,
    'wholesalerName': wholesalerName,
    'amount': amount,
    'status': 'Pending',
    'updatedAt': FieldValue.serverTimestamp(),
    'createdAt': FieldValue.serverTimestamp(),
    'createdByUid': _loggedInUser?['uid'],
    'createdByName': _loggedInUser?['name'] ?? _loggedInUser?['email'],
  };

  if (q.docs.isEmpty) {
    await firestore.collection('orders').add(payload);
  } else {
    await firestore.collection('orders').doc(q.docs.first.id).update(payload);
  }
}

/// Delete the cell’s order (if exists)
Future<void> deleteOrderForCell({
  required DateTime day,
  required String shopName,
  required String wholesalerName,
}) async {
  final dayKey = DateFormat('yyyy-MM-dd').format(day);
  final q = await firestore.collection('orders')
      .where('dayKey', isEqualTo: dayKey)
      .where('shopName', isEqualTo: shopName)
      .where('wholesalerName', isEqualTo: wholesalerName)
      .limit(1).get();
  if (q.docs.isNotEmpty) {
    await firestore.collection('orders').doc(q.docs.first.id).delete();
  }
}


  // 🔁 REPLACE this whole function in AppDataProvider
// ===== REPLACE THIS WHOLE FUNCTION =====
Future<List<Map<String, dynamic>>> fetchOrdersForDate({
  String? shopName, // null or 'All' => all shops
  required DateTime date,
}) async {
  try {
    final dayKey = DateFormat('yyyy-MM-dd').format(date);

    Query<Map<String, dynamic>> q =
        firestore.collection('orders').where('dayKey', isEqualTo: dayKey);

    if (shopName != null && shopName.isNotEmpty && shopName != 'All') {
      q = q.where('shopName', isEqualTo: shopName);
    }

    final snap = await q.get();

    DateTime toDateLocal(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return snap.docs.map((d) {
      final m = d.data();
      final rawTs = m['createdAt'] ?? m['updatedAt'];
      final created = toDateLocal(rawTs);
      return {
        'id'             : d.id,
        'wholesalerName' : (m['wholesalerName'] ?? m['toWholesalerName'] ?? '').toString(),
        'amount'         : (m['amount'] ?? m['invoiceAmount'] ?? 0).toDouble(),
        'status'         : (m['status'] ?? 'Pending').toString(),
        'invoiceUrl'     : (m['invoiceUrl'] ?? '').toString(),
        'createdAt'      : created,
        'dayKey'         : (m['dayKey'] ?? '').toString(),
        'shopName'       : (m['shopName'] ?? m['shop'] ?? '').toString(),
      };
    }).toList();
  } catch (e) {
    debugPrint('fetchOrdersForDate error: $e');
    return <Map<String, dynamic>>[]; // ✅ no “body might complete normally”
  }
}

// ===== REPLACE THIS WHOLE FUNCTION =====
Future<void> recordWholesalerPayment({
  required String shopName,
  required String wholesalerName,
  required double amount,
  String? note,
  String? mode, // keep optional in signature (UI already sends it)
}) async {
  final user = loggedInUser ?? {};
  final createdBy = (user['name'] ?? user['email'] ?? '').toString();

  // 1) Resolve (or create) wholesaler doc by nameLower
  final qs = await firestore
      .collection('wholesalers')
      .where('nameLower', isEqualTo: wholesalerName.trim().toLowerCase())
      .limit(1)
      .get();

  DocumentReference<Map<String, dynamic>> whRef;
  if (qs.docs.isEmpty) {
    whRef = firestore.collection('wholesalers').doc();
    await whRef.set({
      'name': wholesalerName.trim(),
      'nameLower': wholesalerName.trim().toLowerCase(),
      'phone': '',
      'address': '',
      'openingBalance': 0.0,
      'totalPurchases': 0.0,
      'totalPayments': 0.0,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } else {
    whRef = qs.docs.first.reference;
  }

  // 2) Batch: add payment + increment wholesaler aggregates
  final batch = firestore.batch();

  final payRef = firestore.collection('payments').doc();
  batch.set(payRef, {
    'id'               : payRef.id,
    'shopName'         : shopName,
    'toWholesalerName' : wholesalerName,
    'amount'           : amount,
    'mode'             : (mode ?? 'Cash'),
    'note'             : note ?? '',
    'createdAt'        : FieldValue.serverTimestamp(),
    'createdBy'        : createdBy,
  });

  batch.update(whRef, {
    'totalPayments' : FieldValue.increment(amount),
    'updatedAt'     : FieldValue.serverTimestamp(),
    'isActive'      : true,
  });

  await batch.commit();

  await fetchPayments(); // keep local in sync
  notifyListeners();
}


  // ---------- Query builder for Orders ----------
  Query<Map<String, dynamic>> buildOrdersQuery({
    String? shopName, // null => all
    String? status, // null => all
    String? wholesalerName, // null => all
    DateTime? from, // inclusive
    DateTime? to, // exclusive
  }) {
    var q =
        firestore.collection('orders').orderBy('createdAt', descending: true);
    if (shopName != null && shopName.isNotEmpty && shopName != 'All') {
      q = q.where('shopName', isEqualTo: shopName);
    }
    if (status != null && status.isNotEmpty && status != 'All') {
      q = q.where('status', isEqualTo: status);
    }
    if (wholesalerName != null && wholesalerName.isNotEmpty) {
      q = q.where('wholesalerName', isEqualTo: wholesalerName);
    }
    if (from != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('createdAt', isLessThan: Timestamp.fromDate(to));
    }
    return q;
  }

  // ---------- Status update ----------
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
  // Optional central validation
  if (newStatus == 'Forwarded' && !(isAdmin || isManager)) {
    throw 'Only Admin/Manager can forward orders.';
  }

  if (newStatus == 'Deleted') {
    await firestore.collection('orders').doc(orderId).delete();
    _orders.removeWhere((o) => o['id'] == orderId);
  } else {
    await firestore.collection('orders').doc(orderId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final i = _orders.indexWhere((o) => o['id'] == orderId);
    if (i != -1) _orders[i]['status'] = newStatus;
  }

  // keep local + remote in sync
  await fetchOrders();
  notifyListeners();
}

  Future<void> markOrderForwarded(String id) async {
    try {
      await firestore.collection('orders').doc(id).update({
        'status': 'Forwarded',
        'updatedAt': Timestamp.now(),
      });

      final i = _orders.indexWhere((o) => o['id'].toString() == id);
      if (i != -1) {
        _orders[i] = {
          ..._orders[i],
          'status': 'Forwarded',
          'updatedAt': DateTime.now(),
        };
        notifyListeners();
      }
    } catch (e) {
      debugPrint('markOrderForwarded error: $e');
    }
  }

 Future<void> fetchOrders() async {
  try {
    Query<Map<String, dynamic>> q =
        firestore.collection('orders').orderBy('createdAt', descending: true);

    if (isEmployee) {
      final assigned = List<String>.from(
          (loggedInUser?['assignedShops'] ?? const [])).where((e) => e.toString().trim().isNotEmpty).toList();

      final from = DateTime.now().subtract(const Duration(days: 60));
      q = q
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));

      // Agar employee ke paas selectedShop set hai to wohi; warna assigned list (agar 10+ ho to client-side filter)
      final sel = _selectedShopName;
      if ((sel ?? '').isNotEmpty) {
        q = q.where('shopName', isEqualTo: sel);
      } else if (assigned.length == 1) {
        q = q.where('shopName', isEqualTo: assigned.first);
      }
      // multiple assigned shops ke liye Firestore me 'whereIn' max 10 — agar >10 ho to client filter niche ho jayega
    }

    final snap = await q.get();

    _orders
      ..clear()
      ..addAll(snap.docs.map((d) {
        final data = d.data();
        final createdAt = _toDate(data['createdAt']);
        return {'id': d.id, ...data, 'createdAt': createdAt};
      }));

    // client-side extra filter (employee + multiple assigned shops > 1)
    if (isEmployee) {
      final assigned = (loggedInUser?['assignedShops'] ?? const [])
          .map<String>((e) => e.toString())
          .toSet();
      final from = DateTime.now().subtract(const Duration(days: 60));
      _orders.removeWhere((o) =>
          !assigned.contains(o['shopName']) ||
          (o['createdAt'] is DateTime && (o['createdAt'] as DateTime).isBefore(from)));
    }

    notifyListeners();
  } catch (e) {
    log('Error fetching orders: $e', name: 'Orders');
  }
}

  Future<void> fetchSales() async {
  try {
    final snap = await firestore.collection('sales').get();

    _sales
      ..clear()
      ..addAll(snap.docs.map((doc) {
        final data = doc.data();

        // ---- createdAt normalize ----
        DateTime created;
        final raw = data['createdAt'];
        if (raw is Timestamp) {
          created = raw.toDate();
        } else if (raw is DateTime) {
          created = raw;
        } else if (raw is String) {
          created = DateTime.tryParse(raw) ??
              (DateTime.tryParse('${data['date'] ?? ''}') ?? DateTime.now());
        } else {
          created = DateTime.tryParse('${data['date'] ?? ''}') ?? DateTime.now();
        }

        // ---- numeric coercion ----
        double toD(dynamic v) =>
            v is num ? v.toDouble() : double.tryParse('${v ?? ""}') ?? 0.0;

        // ---- shop name + id (fast lookup via maps we added earlier) ----
        final shopName = (data['shop'] ?? data['shopName'] ?? '').toString();
        final shopId = (data['shopId'] ?? '').toString().trim().isNotEmpty
            ? (data['shopId'] as String)
            : (shopIdForName(shopName) ?? '');

        return {
          'id': doc.id,
          'shop': shopName,
          'shopId': shopId, // 👈 needed by Cash Collect
          'employee': (data['employee'] ?? data['addedBy'] ?? '').toString(),
          'cash': toD(data['cash']),
          'card': toD(data['card']),
          'other': toD(data['other']),
          'total': toD(data['total']),
          'createdAt': created,
          'saleDate': DateFormat('yyyy-MM-dd').format(created),
        };
      }));
    notifyListeners();
  } catch (e) {
    log('Error fetching sales: $e', name: 'Sales');
  }
}

  Future<void> fetchEditRequests() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('editRequests').get();
      _editRequests.clear();
      _editRequests.addAll(
        snapshot.docs.map((doc) => {'firebaseId': doc.id, ...doc.data()}),
      );
    } catch (e) {
      log('Error fetching edit requests: $e', name: 'Requests');
    }
  }

  Future<void> fetchAllData() async {
    await fetchUsers();
    await fetchShops();
    await fetchOrders();
    await fetchSales();
    await fetchEditRequests();
    await fetchEmployees();
    notifyListeners();
  }

  // --------- Assignments sync (bidirectional) ---------
  Future<void> updateShopAssignments({
    required String userId,
    required String userName,
    required List<String> newAssignedShops,
  }) async {
    final desired =
        newAssignedShops.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();

    final empRef = firestore.collection('employees').doc(userId);
    final empSnap = await empRef.get();
    final currentList =
        List<String>.from(empSnap.data()?['assignedShops'] ?? const []);
    final current =
        currentList.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();

    final toRemove = current.difference(desired);
    final toAdd = desired.difference(current);

    final batch = firestore.batch();

    for (final oldShopName in toRemove) {
      final q = await firestore
          .collection('shops')
          .where('name', isEqualTo: oldShopName)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final shopRef = q.docs.first.reference;
        batch.update(shopRef, {
          'employees': FieldValue.arrayRemove([userName]),
          'updatedAt': DateTime.now(),
        });
      }
    }

    for (final newShopName in toAdd) {
      final q = await firestore
          .collection('shops')
          .where('name', isEqualTo: newShopName)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final shopRef = q.docs.first.reference;
        batch.update(shopRef, {
          'employees': FieldValue.arrayUnion([userName]),
          'updatedAt': DateTime.now(),
        });
      }
    }

    batch.update(empRef, {
      'assignedShops': desired.toList(),
      'updatedAt': DateTime.now(),
    });

    final userRef = firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'assignedShops': desired.toList(),
      'updatedAt': DateTime.now(),
    });

    await batch.commit();

    try {
      final i = employees.indexWhere((e) => e['uid'] == userId);
      if (i != -1) {
        employees[i] = {
          ...employees[i],
          'assignedShops': desired.toList(),
        };
      }
      notifyListeners();
    } catch (_) {}
  }

  bool _listenersStarted = false;

  // --------- Live listeners ---------
  void startFirebaseListeners() {
    if (_listenersStarted) return;
    _listenersStarted = true;

    firestore.collection('shops').snapshots().listen((snapshot) {
  shops = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();

  _shopNameById
    ..clear()
    ..addEntries(shops.map((s) => MapEntry(s['id'] as String, (s['name'] ?? '').toString())));
  _shopIdByName
    ..clear()
    ..addEntries(shops.map((s) => MapEntry((s['name'] ?? '').toString().trim().toLowerCase(), s['id'] as String)));

  notifyListeners();
});


    firestore.collection('employees').snapshots().listen((snapshot) {
      employees = snapshot.docs.map((d) {
        final data = d.data();
        return {
          'uid': d.id,
          ...data,
          'role': (data['role'] ?? data['Role'] ?? data['userRole'] ?? '')
              .toString()
              .toLowerCase()
              .trim(),
          'assignedShops': ((data['assignedShops'] ?? []) as List)
              .map((e) => e.toString())
              .toList(),
        };
      }).toList();
      notifyListeners();
    });

    firestore.collection('users').snapshots().listen((snapshot) {
      usersList = snapshot.docs.map((d) {
        final data = d.data();
        return {
          'uid': d.id,
          ...data,
          'role': (data['role'] ?? data['Role'] ?? data['userRole'] ?? '')
              .toString()
              .toLowerCase()
              .trim(),
          'assignedShops': ((data['assignedShops'] ?? []) as List)
              .map((e) => e.toString())
              .toList(),
        };
      }).toList();
      notifyListeners();
    });

    firestore.collection('orders').snapshots().listen((snapshot) {
      _orders
        ..clear()
        ..addAll(snapshot.docs.map((d) {
          final data = d.data();
          final createdAt = _toDate(data['createdAt']);
          return {'id': d.id, ...data, 'createdAt': createdAt};
        }));
      notifyListeners();
    });

    firestore.collection('sales').snapshots().listen((snapshot) {
      _sales
        ..clear()
        ..addAll(snapshot.docs.map((d) {
          final data = d.data();
          final raw = data['createdAt'];
          DateTime? createdAt;

          if (raw is Timestamp) {
            createdAt = raw.toDate();
          } else if (raw is DateTime) {
            createdAt = raw;
          } else if (raw is String) {
            createdAt = DateTime.tryParse(raw);
          }

          return {'id': d.id, ...data, 'createdAt': createdAt};
        }));
      notifyListeners();
    });

    firestore.collection('editRequests').snapshots().listen((snapshot) {
      _editRequests
        ..clear()
        ..addAll(snapshot.docs
            .map((d) => {'firebaseId': d.id, ...d.data()}));
      notifyListeners();
    });
  }

  // --------- Profile ---------
  Future<void> updateProfile({
    String? email,
    String? phone,
    String? password,
  }) async {
    if (_loggedInUser == null) return;

    final updates = <String, dynamic>{};
    final userDocId = _loggedInUser!['uid'];

    if (email != null) {
      _loggedInUser!['email'] = email;
      updates['email'] = email;
    }
    if (phone != null) {
      _loggedInUser!['phone'] = phone;
      updates['phone'] = phone;
    }

    if (password != null) {
      try {
        await FirebaseAuth.instance.currentUser!.updatePassword(password);
        log("✅ Password updated successfully", name: 'Profile');
      } catch (e) {
        log("❌ Failed to update password: $e", name: 'Profile');
      }
    }

    if (userDocId != null && updates.isNotEmpty) {
      await firestore.collection('users').doc(userDocId).update(updates);
    }

    notifyListeners();
  }

  Future<void> deleteSale(String saleId) async {
    try {
      await firestore.collection('sales').doc(saleId).delete();
      _sales.removeWhere((sale) => sale['id'] == saleId);
      notifyListeners();
      log('Sale deleted: $saleId', name: 'Sales');
    } catch (e) {
      log('Error deleting sale: $e', name: 'Sales');
      rethrow;
    }
  }

  Future<void> editSale(Map<String, dynamic> updatedSale) async {
    try {
      final saleId =
          (updatedSale['id'] ?? updatedSale['saleId'] ?? '').toString();
      if (saleId.isEmpty) {
        log('editSale: missing sale id in map', name: 'Sales');
        return;
      }

      final dataToUpdate = {...updatedSale}..remove('id');
      dataToUpdate['updatedAt'] = FieldValue.serverTimestamp();

      await firestore.collection('sales').doc(saleId).update(dataToUpdate);

      final idx = _sales.indexWhere((s) => s['id'] == saleId);
      if (idx != -1) {
        _sales[idx] = {
          ..._sales[idx],
          ...updatedSale,
          'id': saleId,
        };
        notifyListeners();
      } else {
        await fetchSales();
      }

      log('Sale updated: $saleId', name: 'Sales');
    } catch (e) {
      log('Error editing sale (single-arg): $e', name: 'Sales');
      rethrow;
    }
  }

  // --------- Utility ---------
  List<String> getAssignedShopsForUser(String userId) {
    final emp = employees.firstWhere(
      (e) => e['uid'] == userId,
      orElse: () => {},
    );
    List list = emp['assignedShops'] ?? [];

    if ((list.isEmpty) &&
        _loggedInUser != null &&
        _loggedInUser!['uid'] == userId) {
      list = (_loggedInUser!['assignedShops'] ?? []) as List;
    }

    return list.map((e) => e.toString()).toList();
  }

  /// ====== Goal-4: Payments (already used by UI) ======
Future<List<Map<String, dynamic>>> fetchWholesalerPaymentsBetween({
  required DateTime from,
  required DateTime to,
  String? shopName,      // null or 'All' => all
  String? wholesalerName // optional
}) async {
  var q = firestore
      .collection('payments')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .where('createdAt', isLessThan: Timestamp.fromDate(to));

  if (shopName != null && shopName != 'All') {
    q = q.where('shopName', isEqualTo: shopName);
  }
  if (wholesalerName != null && wholesalerName.isNotEmpty) {
    q = q.where('toWholesalerName', isEqualTo: wholesalerName);
  }

  final snap = await q.get();
  return snap.docs.map((d) {
    final m = d.data();
    final ts = m['createdAt'];
    final created = ts is Timestamp ? ts.toDate() : DateTime.now();
    return {
      'id'               : d.id,
      'shopName'         : m['shopName'] ?? '',
      'toWholesalerName' : m['toWholesalerName'] ?? '',
      'amount'           : (m['amount'] ?? 0).toDouble(),
      'note'             : m['note'] ?? '',
      'mode'             : (m['mode'] ?? m['method'] ?? 'Cash').toString(), // ✅
      'createdAt'        : created,
    };
  }).toList();
}


Future<List<Map<String, dynamic>>> fetchWholesalerInvoicesByName({
  required DateTime from,
  required DateTime to,
  String? shopName,
  required String wholesalerName,
}) async {
  var q = firestore.collection('orders')
    .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
    .where('createdAt', isLessThan: Timestamp.fromDate(to))
    .where('wholesalerName', isEqualTo: wholesalerName);
  if (shopName != null && shopName != 'All') {
    q = q.where('shopName', isEqualTo: shopName);
  }
  final snap = await q.get();
  return snap.docs.map((d) {
    final m = d.data();
    final ts = m['createdAt'];
    final created = ts is Timestamp
        ? ts.toDate()
        : (ts is DateTime ? ts : DateTime.tryParse('$ts'));
    return {
      'id': d.id,
      'shopName': m['shopName'] ?? m['shop'] ?? '',
      'wholesalerName': m['wholesalerName'] ?? '',
      'amount': (m['amount'] ?? m['invoiceAmount'] ?? 0).toDouble(),
      'status': m['status'] ?? 'Pending',
      'invoiceUrl': m['invoiceUrl'] ?? '',
      'createdAt': created,
    };
  }).toList();
}


Future<double> sumCashPickedBetween({
  required DateTime from,
  required DateTime to,      // 'to' exclusive aa rahi hoti hai tumhari screens me
  String? shopName,          // null/'All' => all shops
}) async {
  // dayKey helpers
  String k(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

  final startKey = k(from);
  final endInc   = DateTime(to.year, to.month, to.day).subtract(const Duration(days: 1));
  final endKey   = k(endInc);

  // ⚠️ Sirf 1 field (dayKey) par range => NO composite index required
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance
      .collection('cash_collect')
      .where('dayKey', isGreaterThanOrEqualTo: startKey)
      .where('dayKey', isLessThanOrEqualTo: endKey);

  final snap = await q.get();

  double sum = 0.0;
  for (final d in snap.docs) {
    final m = d.data();

    // client-side filters (index ki need se bachne ke liye)
    if (shopName != null && shopName.isNotEmpty && shopName != 'All') {
      final sn = (m['shopName'] ?? '').toString();
      if (sn != shopName) continue;
    }
    if (m['collected'] != true) continue;

    final v = m['cashAmount'];
    sum += (v is num) ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0.0);
  }
  return sum;
}



Future<void> updateOtherExpenseEntry({
  required String id,
  required double amount,
  required String title,
  String? note,
  DateTime? when,
}) async {
  await firestore.collection('expenses').doc(id).update({
    'amount': amount,
    'category': title,
    'note': note ?? '',
    'createdAt': Timestamp.fromDate(when ?? DateTime.now()),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

// Delete an "other expense" document by id.
Future<void> deleteOtherExpenseEntry(String id) async {
  await firestore.collection('expenses').doc(id).delete();
}

// ===== REPLACE THIS WHOLE FUNCTION =====
Future<List<Map<String, dynamic>>> fetchWholesalerPaymentsByName({
  required DateTime from,
  required DateTime to,
  String? shopName,
  required String wholesalerName,
}) async {
  var q = firestore.collection('payments')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .where('createdAt', isLessThan: Timestamp.fromDate(to))
      .where('toWholesalerName', isEqualTo: wholesalerName);

  if (shopName != null && shopName != 'All') {
    q = q.where('shopName', isEqualTo: shopName);
  }

  final snap = await q.get();
  return snap.docs.map((d) {
    final m = d.data();
    final ts = m['createdAt'];
    final created = ts is Timestamp
        ? ts.toDate()
        : (ts is DateTime ? ts : DateTime.tryParse('$ts')) ?? DateTime.now();
    return {
      'id'               : d.id,
      'shopName'         : m['shopName'] ?? '',
      'toWholesalerName' : m['toWholesalerName'] ?? '',
      'amount'           : (m['amount'] ?? 0).toDouble(),
      'note'             : m['note'] ?? '',
      'mode'             : (m['mode'] ?? m['method'] ?? 'Cash').toString(), // ✅
      'createdAt'        : created,
    };
  }).toList();
}

Future<void> updateEmployeeExpenseEntry({
  required String id,
  required double amount,
  required String type, // salary | advance | paid
  String? note,
}) async {
  await firestore.collection('employee_expenses').doc(id).update({
    'amount': amount,
    'type': type,
    'note': note ?? '',
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> deleteEmployeeExpenseEntry(String id) async {
  await firestore.collection('employee_expenses').doc(id).delete();
}


  /// ====== Goal-4: One-call aggregator (for AllShopsSummaryScreen) ======
  Future<AllShopsSummary> loadAllShopsSummary({
    required String viewMode, // 'Daily' | 'Weekly' | 'Monthly' | 'Yearly'
    required DateTime anchor,
    String shopName = 'All',
    bool includeOrdersSnapshotForDay = true,
  }) async {
    if (!isAdmin && !isManager) {
      final r = rangeForView(viewMode, anchor);
      return AllShopsSummary(range: r, filterShopName: shopName, perShop: {});
    }

    final range = rangeForView(viewMode, anchor);

    final sales = await fetchSalesBetween(
        from: range.from, to: range.to, shopName: shopName);
    final invoices = await fetchWholesalerInvoices(
        from: range.from, to: range.to, shopName: shopName);
    final pays = await fetchWholesalerPaymentsBetween(
        from: range.from, to: range.to, shopName: shopName);
    final empExpenses = await fetchEmployeeExpenses(
        from: range.from, to: range.to, shopName: shopName);
    final othExpenses = await fetchOtherExpenses(
        from: range.from, to: range.to, shopName: shopName);

    final Set<String> shopSet = {};
    void addShopIfPresent(String? n) {
      if (n != null && n.isNotEmpty) shopSet.add(n);
    }

    for (final s in sales) {
      addShopIfPresent(s['shop']);}
    for (final i in invoices) {addShopIfPresent(i['shopName']);}
    for (final p in pays) {addShopIfPresent(p['shopName']);}
    for (final e in empExpenses) {addShopIfPresent(e['shopName']);}
    for (final e in othExpenses) {addShopIfPresent(e['shopName']);}

    if (shopName != 'All' && shopName.isNotEmpty) {
      shopSet.add(shopName);
    }

    final Map<String, ShopSummary> perShop = {};

    for (final sName in shopSet) {
      double cash = 0, card = 0, other = 0;
      for (final s in sales.where((x) => (x['shop'] ?? '') == sName)) {
        cash += (s['cash'] ?? 0).toDouble();
        card += (s['card'] ?? 0).toDouble();
        other += (s['other'] ?? 0).toDouble();
      }

      double invTotal = 0;
      for (final inv
          in invoices.where((x) => (x['shopName'] ?? '') == sName)) {
        invTotal += (inv['amount'] ?? 0).toDouble();
      }

      double paidTotal = 0;
      for (final p in pays.where((x) => (x['shopName'] ?? '') == sName)) {
        paidTotal += (p['amount'] ?? 0).toDouble();
      }

      double empTotal = 0;
      for (final e
          in empExpenses.where((x) => (x['shopName'] ?? '') == sName)) {
        empTotal += (e['amount'] ?? 0).toDouble();
      }

      double othTotal = 0;
      for (final e
          in othExpenses.where((x) => (x['shopName'] ?? '') == sName)) {
        othTotal += (e['amount'] ?? 0).toDouble();
      }

      List<Map<String, dynamic>> dayOrders = const [];
      if (includeOrdersSnapshotForDay && viewMode == 'Daily') {
        dayOrders = await fetchOrdersForDate(shopName: sName, date: range.from);
      }

      perShop[sName] = ShopSummary(
        shopName: sName,
        cash: _round2(cash),
        card: _round2(card),
        other: _round2(other),
        wholesalerInvoiceTotal: _round2(invTotal),
        wholesalerPaidTotal: _round2(paidTotal),
        employeeExpenseTotal: _round2(empTotal),
        otherExpenseTotal: _round2(othTotal),
        orders: dayOrders,
      );
    }

    return AllShopsSummary(
        range: range, filterShopName: shopName, perShop: perShop);
  }
}
