// lib/providers/cash_collect_mixin.dart
import 'package:cloud_firestore/cloud_firestore.dart';

mixin CashCollectMixin {
  final FirebaseFirestore _ccDb = FirebaseFirestore.instance;

  final Map<String, bool> _ccCache = {};

  String _ccYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  String _ccRangeKey(DateTime from, DateTime to) => '${_ccYmd(from)}__${_ccYmd(to)}';
  String _ccDocId(String shopId, DateTime from, DateTime to) =>
      '${shopId.trim()}__${_ccRangeKey(from, to)}';

  DateTime? _ccParseSaleDateYmd(Object? v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.length < 10) return null;
    try {
      final y = int.parse(s.substring(0, 4));
      final m = int.parse(s.substring(5, 7));
      final d = int.parse(s.substring(8, 10));
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  bool _ccWithin(DateTime day, DateTime from, DateTime to) {
    final df = DateTime(from.year, from.month, from.day);
    final dt = DateTime(to.year, to.month, to.day);
    final dd = DateTime(day.year, day.month, day.day);
    return !dd.isBefore(df) && !dd.isAfter(dt);
  }

  void configureCashCollectPersistence() {
    _ccDb.settings = const Settings(persistenceEnabled: true);
  }

  double computeCashForShop(String shopId, DateTime from, DateTime to) {
    final self = this as dynamic;
    final List<Map<String, dynamic>> allSales =
        (self.sales as List<Map<String, dynamic>>?) ?? const [];

    final sid = shopId.trim();
    double sum = 0.0;

    for (final s in allSales) {
      final sShopId = (s['shopId'] ?? s['shop'] ?? '').toString().trim();
      if (sShopId != sid) continue;

      final saleDate = _ccParseSaleDateYmd(s['saleDate']) ??
          (s['createdAt'] is Timestamp
              ? (s['createdAt'] as Timestamp).toDate()
              : null);
      if (saleDate == null || !_ccWithin(saleDate, from, to)) continue;

      num n = 0;
      final pm = (s['paymentMethod'] ?? '').toString().toLowerCase();
      final candidates = [s['cash'], s['cashAmount'], s['totalCash'], s['cash_total']];

      for (final c in candidates) {
        if (c is num) { n = c; break; }
        final str = c?.toString();
        final parsed = str == null ? null : num.tryParse(str);
        if (parsed != null) { n = parsed; break; }
      }

      if (n == 0 && pm == 'cash') {
        final total = s['total'] ?? s['grandTotal'] ?? s['amount'];
        if (total is num) n = total;
        else {
          final tStr = total?.toString();
          final parsed = tStr == null ? null : num.tryParse(tStr);
          if (parsed != null) n = parsed!;
        }
      }

      sum += n.toDouble();
    }

    return sum;
  }

  Future<bool> isCashCollected({
    required String shopId,
    required DateTime from,
    required DateTime to,
  }) async {
    final id = _ccDocId(shopId, from, to);
    if (_ccCache.containsKey(id)) return _ccCache[id]!;
    final doc = await _ccDb.collection('cash_collect').doc(id).get();
    final ok = doc.exists && (doc.data()?['collected'] == true);
    _ccCache[id] = ok;
    return ok;
  }

  Future<void> setCashCollected({
    required String shopId,
    String? shopName,
    required DateTime from,
    required DateTime to,
    required bool collected,
    required double cashAmount,
    String? byUserId,
    String? byUserName,
  }) async {
    final id = _ccDocId(shopId, from, to);
    final payload = <String, Object?>{
      'shopId': shopId.trim(),
      if (shopName != null) 'shopName': shopName,
      'rangeKey': _ccRangeKey(from, to),
      'fromYmd': _ccYmd(from),
      'toYmd': _ccYmd(to),
      'from': Timestamp.fromDate(DateTime(from.year, from.month, from.day)),
      'to': Timestamp.fromDate(DateTime(to.year, to.month, to.day)),
      'collected': collected,
      'cashAmount': cashAmount,
      'updatedAt': FieldValue.serverTimestamp(),
      if (collected) 'collectedAt': FieldValue.serverTimestamp(),
      if (byUserId != null) 'byUserId': byUserId,
      if (byUserName != null) 'byUserName': byUserName,
    };

    await _ccDb.collection('cash_collect').doc(id).set(payload, SetOptions(merge: true));
    _ccCache[id] = collected;

    final self = this as dynamic;
    try { self.notifyListeners(); } catch (_) {}
  }

  Future<Map<String, dynamic>> getCashCollectRow({
    required String shopId,
    String? shopName,
    required DateTime from,
    required DateTime to,
  }) async {
    final cash = computeCashForShop(shopId, from, to);
    final collected = await isCashCollected(shopId: shopId, from: from, to: to);
    return {
      'shopId': shopId,
      'shopName': shopName,
      'from': from,
      'to': to,
      'cash': cash,
      'collected': collected,
    };
  }
}
