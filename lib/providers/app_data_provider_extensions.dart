import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_data_provider.dart';


extension RoleAndRangeHelpers on AppDataProvider {
  /// Normalizes role value safely from loggedInUser (case-insensitive).
  String get roleLower {
    final m = loggedInUser ?? const <String, dynamic>{};
    final raw = (m['role'] ?? m['Role'] ?? m['userRole'] ?? '').toString();
    return raw.toLowerCase().trim();
  }

  bool get isOwnerX => roleLower == 'owner';
  bool get isManagerX => roleLower == 'manager';
  bool get isAdminOrManagerX => isOwnerX || isManagerX;

  /// Date helpers (strip time to midnight and range helpers)
  DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime dayEnd(DateTime d) => dayStart(d).add(const Duration(days: 1));
  DateTime weekStart(DateTime d) => d.subtract(Duration(days: d.weekday - 1)); // Monday
  DateTime weekEnd(DateTime d) => dayStart(weekStart(d)).add(const Duration(days: 7));
  DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 1);

  /// Firestore-safe timestamp getter (createdAt || timestamp || serverTime)
  DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Generic range query for transactions collection
  Future<List<Map<String, dynamic>>> fetchTransactionsBetween({
    required DateTime from,
    required DateTime to,
    String? shopName, // null or 'All' -> all
  }) async {
    Query<Map<String, dynamic>> q = firestore
        .collection('transactions')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('createdAt', isLessThan: Timestamp.fromDate(to));

    if (shopName != null && shopName.isNotEmpty && shopName != 'All') {
      q = q.where('shopName', isEqualTo: shopName);
    }

    final snap = await q.get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList()
        .map((m) {
          // Safe normalization
          final createdAt = _ts(m['createdAt'] ?? m['timestamp']);
          final amount = (m['amount'] ?? m['total'] ?? m['value'] ?? 0);
          final isRefund = (m['refund'] == true) || (m['isRefund'] == true);
          final numAmt = (amount is num) ? amount : num.tryParse(amount.toString()) ?? 0;
          return {
            ...m,
            'createdAt': createdAt,
            'amount': numAmt,
            'isRefund': isRefund,
            'shopName': m['shopName'] ?? m['shop'] ?? m['store'] ?? '',
          };
        })
        .toList();
  }

  /// Generic range query for sales collection
  Future<List<Map<String, dynamic>>> fetchSalesBetween({
    required DateTime from,
    required DateTime to,
    String? shopName,
  }) async {
    Query<Map<String, dynamic>> q = firestore
        .collection('sales')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('createdAt', isLessThan: Timestamp.fromDate(to));

    if (shopName != null && shopName.isNotEmpty && shopName != 'All') {
      q = q.where('shopName', isEqualTo: shopName);
    }

    final snap = await q.get();
    return snap.docs.map((d) {
      final m = d.data();
      final cash = (m['cash'] ?? 0);
      final card = (m['card'] ?? 0);
      final other = (m['other'] ?? 0);
      final totalRaw = (m['total'] ?? (cash is num && card is num && other is num ? (cash + card + other) : 0));
      num toNum(dynamic x) => (x is num) ? x : (num.tryParse(x.toString()) ?? 0);

      return {
        'id': d.id,
        ...m,
        'createdAt': _ts(m['createdAt'] ?? m['timestamp']),
        'shopName': m['shopName'] ?? m['shop'] ?? m['store'] ?? '',
        'cash': toNum(cash),
        'card': toNum(card),
        'other': toNum(other),
        'total': toNum(totalRaw),
      };
    }).toList();
  }

  /// Enforce uniqueness: 1 order per (shopName, wholesalerName, day)
  Future<void> addOrderUnique({
    required String shopName,
    required String wholesalerName,
    required DateTime date,
    required num amount,
    String status = 'Pending',
    String? invoiceImageUrl,
    Map<String, dynamic>? extra,
  }) async {
    final keyDate = dayStart(date);
    final existing = await firestore
        .collection('orders')
        .where('shopName', isEqualTo: shopName)
        .where('wholesalerName', isEqualTo: wholesalerName)
        .where('dayKey', isEqualTo: Timestamp.fromDate(keyDate))
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Order already exists for today for this shop & wholesaler.');
    }

    final payload = <String, dynamic>{
      'shopName': shopName,
      'wholesalerName': wholesalerName,
      'dayKey': Timestamp.fromDate(keyDate),
      'amount': amount,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      if (invoiceImageUrl != null) 'invoiceImageUrl': invoiceImageUrl,
      if (extra != null) ...extra,
    };

    await firestore.collection('orders').add(payload);
  }
}
