import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

class AppDataProvider extends ChangeNotifier {
  AppDataProvider() {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _loggedInUser;
  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _sales = [];
  final List<Map<String, dynamic>> _editRequests = [];

  List<Map<String, dynamic>> shops = [];
  List<Map<String, dynamic>> employees = []; // from 'employees' collection
  List<Map<String, dynamic>> usersList = []; // from 'users' collection

  List<Map<String, dynamic>> get orders => _orders;
  Map<String, dynamic>? get loggedInUser => _loggedInUser;

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

  Future<bool> loginWithNameAndCode(String name, String code) async {
    final nameLower = name.trim().toLowerCase();
    final trimmedCode = code.trim();

    try {
      // block/cleanup any stale auth user before code login
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }

      final snapshot = await firestore
          .collection('users')
          .where('loginCode', isEqualTo: trimmedCode)
          .get();

      if (snapshot.docs.isEmpty) return false;

      final matches = snapshot.docs.where((d) {
        final docName = (d.data()['name'] ?? '').toString().toLowerCase();
        return docName == nameLower;
      }).toList();

      if (matches.isEmpty) return false;

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
      if (u == null) return false;

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

  Future<void> _saveSession(
      {required String mode, required String uid}) async {
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
    final savedUid  = prefs.getString('session_uid');

    // ✅ Always trust FirebaseAuth first
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      // Overwrite any stale 'code' session
      await _saveSession(mode: 'auth', uid: authUser.uid);

      final snap = await firestore.collection('users').doc(authUser.uid).get();
      if (snap.exists) {
        final data = snap.data()!;
        loginUser({...data, 'uid': authUser.uid});
      }
      return;
    }

    // ✅ Only if no auth user, fallback to code session
    if (savedMode == 'code' && savedUid != null && savedUid.isNotEmpty) {
      final snap = await firestore.collection('users').doc(savedUid).get();
      if (snap.exists) {
        final data = snap.data()!;
        loginUser({...data, 'uid': savedUid});
        return;
      } else {
        // stale code session -> clear
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

  // local cache update
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
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
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

    return {
      'id': d.id,
      'shop': (data['shop'] ?? '').toString(),
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

  // --------- Edit Requests (Local list + Firestore) ---------
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
      await FirebaseFirestore.instance.collection('sales').doc(saleId).update({
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
      final List<String> assignedShops = List<String>.from(
        employeeData['assignedShops'] ?? [],
      );

      for (String shopName in assignedShops) {
        final index = shops.indexWhere((s) => s['name'] == shopName);
        if (index != -1) {
          final existingEmployees = List<String>.from(
            shops[index]['employees'] ?? [],
          );
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
        final assignedShops = List<String>.from(data['assignedShops'] ?? []);
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
      // guard admin
      final userDoc = await firestore.collection('users').doc(uid).get();
      final role =
          ((userDoc.data()?['role'] ?? '') as String).toLowerCase().trim();
      if (role == 'admin') {
        log('Blocked: attempt to delete admin', name: 'Employee');
        return;
      }

      // delete from 'employees' if exists
      final empDoc = await firestore.collection('employees').doc(uid).get();
      if (empDoc.exists) {
        await firestore.collection('employees').doc(uid).delete();
      }

      // delete from 'users'
      await firestore.collection('users').doc(uid).delete();

      // remove from shops.employees[]
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
      final currentEmployees = List<String>.from(
        shops[shopIndex]['employees'] ?? [],
      );
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
      order['status'] = 'Pending';
      order['createdAt'] = Timestamp.now();
      order['canRequestEdit'] = true;

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order['id'].toString())
          .set(order);

      _orders.add(order);
      notifyListeners();
    } catch (e) {
      log('Error adding order: $e', name: 'Orders');
    }
  }

  void forwardOrder(int id) {
    final index = _orders.indexWhere((order) => order['id'] == id);
    if (index != -1) {
      _orders[index]['status'] = 'Forwarded';
      notifyListeners();
    }
  }

  void markOrderReceived(String id) {
    final index = _orders.indexWhere((o) => o['id'] == id);
    if (index != -1) {
      _orders[index]['status'] = 'Received';
      notifyListeners();
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
    if (raw is DateTime) createdAt = raw;
    else if (raw is Timestamp) createdAt = raw.toDate();
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt).inMinutes <= 10;
  }

  List<Map<String, dynamic>> getEmployeeOrders(String employeeName) {
    return _orders.where((order) => order['createdBy'] == employeeName).toList();
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
      'cash': 'Rs. ${cash.toStringAsFixed(0)}',
      'card': 'Rs. ${card.toStringAsFixed(0)}',
      'other': 'Rs. ${other.toStringAsFixed(0)}',
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

  Future<void> fetchOrders() async {
    try {
      final snap = await firestore.collection('orders').get();

      _orders
        ..clear()
        ..addAll(snap.docs.map((d) {
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

          DateTime? created;
          final raw = data['createdAt'];
          if (raw is Timestamp) {
            created = raw.toDate();
          } else if (raw is DateTime) {
            created = raw;
          } else if (raw is String) {
            created = DateTime.tryParse(raw);
          }
          created ??= DateTime.tryParse('${data['date'] ?? ''}') ??
              DateTime.now();

          double numOrZero(v) => v is num
              ? v.toDouble()
              : double.tryParse(v?.toString() ?? '') ??
                  0.0;

          return {
            'id': doc.id,
            'shop': (data['shop'] ?? '').toString(),
            'employee': (data['employee'] ?? data['addedBy'] ?? '').toString(),
            'cash': numOrZero(data['cash']),
            'card': numOrZero(data['card']),
            'other': numOrZero(data['other']),
            'total': numOrZero(data['total']),
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
    required List<String> newAssignedShops, // shop NAMES
  }) async {
    final desired = newAssignedShops
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();

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

  // --------- Live listeners ---------
  void startFirebaseListeners() {
    firestore.collection('shops').snapshots().listen((snapshot) {
      shops = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
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

    // users list (separate)
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
        ..addAll(snapshot.docs.map((d) => {'id': d.id, ...d.data()}));
      notifyListeners();
    });

    firestore.collection('sales').snapshots().listen((snapshot) {
      _sales
        ..clear()
        ..addAll(snapshot.docs.map((d) {
          final data = d.data();
          final raw = data['createdAt'];
          DateTime? createdAt;
          if (raw is Timestamp) createdAt = raw.toDate();
          else if (raw is DateTime) createdAt = raw;
          else if (raw is String) createdAt = DateTime.tryParse(raw);
          return {'id': d.id, ...data, 'createdAt': createdAt};
        }));
      notifyListeners();
    });

    firestore.collection('editRequests').snapshots().listen((snapshot) {
      _editRequests
        ..clear()
        ..addAll(snapshot.docs.map((d) => {'firebaseId': d.id, ...d.data()}));
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

  /// 🗑️ Delete a sale by its document ID
  /// 🗑️ Delete a sale by its document ID
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

  /// ✏️ Edit/Update a sale
  /// ✏️ Backward-compatible single-arg edit (matches old calls from UI)
Future<void> editSale(Map<String, dynamic> updatedSale) async {
  try {
    final saleId = (updatedSale['id'] ?? updatedSale['saleId'] ?? '').toString();
    if (saleId.isEmpty) {
      log('editSale: missing sale id in map', name: 'Sales');
      return;
    }

    // Firestore me 'id' field nahi rakhte — copy bana ke 'id' hata do
    final dataToUpdate = {...updatedSale}..remove('id');
    dataToUpdate['updatedAt'] = FieldValue.serverTimestamp();

    await firestore.collection('sales').doc(saleId).update(dataToUpdate);

    // Local list update for instant UI refresh
    final idx = _sales.indexWhere((s) => s['id'] == saleId);
    if (idx != -1) {
      _sales[idx] = {
        ..._sales[idx],
        ...updatedSale,
        'id': saleId,
      };
      notifyListeners();
    } else {
      // If not found locally, just refetch
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
}
