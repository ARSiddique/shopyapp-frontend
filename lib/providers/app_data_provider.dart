import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';

class AppDataProvider extends ChangeNotifier {
  Map<String, dynamic>? _loggedInUser;
  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _sales = [];
  final List<Map<String, dynamic>> _editRequests = [];
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> shops = [];
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> get orders => _orders;
  Map<String, dynamic>? get loggedInUser => _loggedInUser;

  void loginUser(Map<String, dynamic> user) {
    _loggedInUser = user;
    notifyListeners();
  }

  Future<bool> loginWithNameAndCode(String name, String code) async {
    final trimmedName = name.trim().toLowerCase(); // 🔹 safer comparison
    final trimmedCode = code.trim();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: trimmedName)
          .where('loginCode', isEqualTo: trimmedCode)
          .limit(1)
          .get();

      log(
        "Trying login with name: $trimmedName and code: $trimmedCode",
        name: 'Auth',
      );

      log("Found users: ${snapshot.docs.length}", name: 'Auth');

      if (snapshot.docs.isEmpty) {
        log("❌ No matching user found", name: 'Auth');

        return false;
      }

      final userData = snapshot.docs.first.data();
      userData['id'] = snapshot.docs.first.id;

      loginUser(userData); // sets _loggedInUser and notifies listeners

      log("✅ Login success: ${userData['name']}", name: 'Auth');
      return true;
    } catch (e) {
      log("🔥 Login error: $e", name: 'Auth');
      return false;
    }
  }

  Future<bool> loginWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) return false;

      log('Logged in UID: ${user.uid}', name: 'Auth');

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!snapshot.exists) {
        log('User document not found in Firestore', name: 'Auth');
        return false;
      }

      log('Fetched user data: ${snapshot.data()}', name: 'Auth');

      _loggedInUser = snapshot.data()!..['uid'] = user.uid;
      notifyListeners();
      return true;
    } catch (e) {
      log('Login failed: $e', name: 'Auth');
      return false;
    }
  }

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

  void logout() {
    _loggedInUser = null;
    notifyListeners();
  }

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

  void requestOrderEdit(int orderId, String reason) {
    _editRequests.add({
      'type': 'order',
      'itemId': orderId,
      'reason': reason,
      'requestedBy': _loggedInUser?['name'],
      'timestamp': DateTime.now(),
    });
    notifyListeners();
  }

  Future<void> cleanupShopFromEmployees(String shopName) async {
    try {
      // Remove shop from all employees
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

      // Remove shop from all users
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

      final docRef = await FirebaseFirestore.instance
          .collection('editRequests')
          .add(request);

      // Add to local list with firebaseId
      _editRequests.add({'firebaseId': docRef.id, ...request});

      notifyListeners();
    } catch (e) {
      log('Error submitting sale edit request: $e', name: 'Sales');
    }
  }

  Future<void> updateSaleAmount(
    String saleId,
    double newAmount,
    String reason,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('sales').doc(saleId).update({
        'total': newAmount,
        'editReason': reason,
        'editedAt': Timestamp.now(),
      });
      await fetchSales(); // to refresh the local _sales list
    } catch (e) {
      log('Error updating sale: $e', name: 'Sales');
    }
  }

  Future<void> updateSale(String saleId, Map<String, dynamic> saleData) async {
    try {
      await FirebaseFirestore.instance
          .collection('sales')
          .doc(saleId)
          .update(saleData);
      await fetchSales(); // refresh local list
      notifyListeners();
    } catch (e) {
      log('Error updating sale: $e', name: 'Sales');
    }
  }

  List<String> getAssignedShopsForUser(String userId) {
    final user = employees.firstWhere(
      (emp) => emp['uid'] == userId,
      orElse: () => {},
    );

    final assigned = user['assignedShops'] ?? [];
    if (assigned is List) {
      return List<String>.from(assigned.map((s) => s.toString()));
    }
    return [];
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

  // void requestOrderEdit(String orderId) {
  //     final orderIndex = _orders.indexWhere(
  //       (order) => order['id'].toString() == orderId.toString(),
  //     );
  //     if (orderIndex != -1) {
  //       _orders[orderIndex]['editRequested'] = true;
  //       notifyListeners();
  //     }
  //   }
  Future<void> fetchEmployees() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('employees')
        .get();
    employees = snapshot.docs
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .toList();
    notifyListeners();
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

      // Soft delete the shop
      await firestore.collection('shops').doc(shopId).update({
        'isDeleted': true,
      });

      // Remove this shop from all employees' assignedShops
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

      await fetchShops(); // Update local cache
      await fetchEmployees(); // To update removed shop assignments

      notifyListeners();
    } catch (e) {
      log("Error deleting shop: $e", name: 'Shop');
    }
  }

  Future<void> deleteEmployeeById(String uid, String name) async {
    try {
      // Delete employee from 'employees' collection
      await firestore.collection('employees').doc(uid).delete();

      // Also delete from 'users' collection
      await firestore.collection('users').doc(uid).delete();

      // Remove this employee's name from all shops' employees list
      final shopsSnapshot = await firestore.collection('shops').get();
      for (var doc in shopsSnapshot.docs) {
        final data = doc.data();
        final employees = List<String>.from(data['employees'] ?? []);

        if (employees.contains(name)) {
          employees.remove(name);
          await firestore.collection('shops').doc(doc.id).update({
            'employees': employees,
          });
        }
      }

      await fetchShops();
      await fetchEmployees();
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

  // ---------------------------
  // Orders
  // ---------------------------
  // List<Map<String, dynamic>> get orders => [..._orders];

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
    final createdAt = order['createdAt'] as DateTime?;
    if (createdAt == null) return false;

    final diff = DateTime.now().difference(createdAt);
    return diff.inMinutes <= 10;
  }

  List<Map<String, dynamic>> getEmployeeOrders(String employeeName) {
    return _orders
        .where((order) => order['createdBy'] == employeeName)
        .toList();
  }

  // ---------------------------
  // Sales
  // ---------------------------
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
    saleData['createdAt'] = Timestamp.now();
    if (saleData.isNotEmpty && saleData['total'] != null) {
      try {
        final docRef = await FirebaseFirestore.instance
            .collection('sales')
            .add(saleData);
        saleData['id'] = docRef.id; // store firestore ID as 'id'
        _sales.add(saleData);
        notifyListeners();
      } catch (e) {
        log('Error adding sale: $e');
      }
    }
  }

  List<Map<String, dynamic>> get salesEditRequests =>
      _editRequests.where((r) => r['type'] == 'sale').toList();

  Future<void> approveSaleEdit(String firebaseId) async {
    try {
      final reqIndex = _editRequests.indexWhere(
        (r) => r['firebaseId'] == firebaseId,
      );
      if (reqIndex == -1) return;

      final request = _editRequests[reqIndex];
      final itemId = request['itemId'];
      final newAmount = request['newAmount'];

      // Update sale amount in Firebase
      await FirebaseFirestore.instance.collection('sales').doc(itemId).update({
        'amount': newAmount,
      });

      // Mark request as approved
      await FirebaseFirestore.instance
          .collection('editRequests')
          .doc(firebaseId)
          .update({'status': 'approved'});

      // Refresh locally
      await fetchEditRequests();
      await fetchSales();
      notifyListeners();
    } catch (e) {
      log('Error approving sale edit: $e', name: 'Sales');
    }
  }

  /// Reject a sale‑edit request (just removes it)
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

  Future<void> updateProfile({
    String? email,
    String? phone,
    String? password,
  }) async {
    if (_loggedInUser == null) return;

    final updates = <String, dynamic>{};
    final userDocId = _loggedInUser!['id'];

    // 🔹 Update email and phone in Firestore
    if (email != null) {
      _loggedInUser!['email'] = email;
      updates['email'] = email;
    }
    if (phone != null) {
      _loggedInUser!['phone'] = phone;
      updates['phone'] = phone;
    }

    // 🔐 Directly update password in Firebase Auth
    if (password != null) {
      try {
        await FirebaseAuth.instance.currentUser!.updatePassword(password);
        log("✅ Password updated successfully", name: 'Profile');
      } catch (e) {
        log("❌ Failed to update password: $e", name: 'Profile');
      }
    }

    // 🔁 Update Firestore document (without password)
    if (userDocId != null && updates.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .update(updates);
    }

    notifyListeners();
  }

  void editSale(Map<String, dynamic> updatedSale) {
    final index = _sales.indexWhere((s) => s['id'] == updatedSale['id']);
    if (index != -1) {
      _sales[index] = updatedSale;
      notifyListeners();
    }
  }

  Future<void> deleteSale(String saleId) async {
    try {
      await FirebaseFirestore.instance.collection('sales').doc(saleId).delete();
      await fetchSales(); // to refresh list after delete
    } catch (e) {
      log('Error deleting sale: $e', name: 'Sales');
    }
  }

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

  // ---------------------------
  // Dashboard Counters
  // ---------------------------
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
      final date = raw is Timestamp
          ? raw.toDate()
          : (raw is DateTime ? raw : now);

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
    double cash = 0.0;
    double card = 0.0;
    double other = 0.0;

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

      // Refresh local data
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

      // Refresh local data
      await fetchAllData();
      notifyListeners();
    } catch (e) {
      log('Error rejecting edit request: $e', name: 'Requests');
    }
  }

  Future<void> fetchUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      employees.clear();
      employees.addAll(snapshot.docs.map((doc) => doc.data()));
    } catch (e) {
      log('Error fetching users: $e', name: 'Users');
    }
  }

  Future<void> fetchShops() async {
    final snapshot = await FirebaseFirestore.instance.collection('shops').get();
    shops = snapshot.docs
        .map((doc) => doc.data())
        .where((shop) => shop['isDeleted'] != true) // ✅ Ignore deleted shops
        .toList();
    notifyListeners();
  }

  Future<void> fetchOrders() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();
      _orders.clear();
      _orders.addAll(snapshot.docs.map((doc) => doc.data()));
    } catch (e) {
      log('Error fetching orders: $e', name: 'Orders');
    }
  }

  Future<void> fetchSales() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sales')
          .get();

      _sales.clear();
      _sales.addAll(
        snapshot.docs.map((doc) {
          final data = doc.data();
          final rawDate = data['createdAt'];
          DateTime? saleDate;

          if (rawDate is Timestamp) {
            saleDate = rawDate.toDate();
          } else if (rawDate is String) {
            saleDate = DateTime.tryParse(rawDate);
          }

          return {
            'id': doc.id,
            'shop': data['shop'] ?? '',
            'employee': data['employee'] ?? '',
            'cash': (data['cash'] ?? 0).toDouble(),
            'card': (data['card'] ?? 0).toDouble(),
            'other': (data['other'] ?? 0).toDouble(),
            'total': (data['total'] ?? 0).toDouble(),
            'saleDate': saleDate != null
                ? DateFormat('yyyy-MM-dd').format(saleDate)
                : '',
            'createdAt': saleDate,
          };
        }),
      );
      notifyListeners();
    } catch (e) {
      log('Error fetching sales: $e', name: 'Sales');
    }
  }

  Future<void> fetchEditRequests() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('editRequests')
          .get();
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
    await fetchEditRequests(); // fetches editRequests from Firebase
    notifyListeners();
  }

  Future<void> updateShopAssignments({
    required String userId,
    required String userName,
    required List<String> newAssignedShops,
  }) async {
    try {
      final employeeDoc = await firestore
          .collection('employees')
          .doc(userId)
          .get();
      final oldAssignedShops = List<String>.from(
        employeeDoc.data()?['assignedShops'] ?? [],
      );

      // Step 1: Remove employee from shops they are unassigned from
      for (final oldShop in oldAssignedShops) {
        if (!newAssignedShops.contains(oldShop)) {
          final query = await firestore
              .collection('shops')
              .where('name', isEqualTo: oldShop)
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            final shopDoc = query.docs.first;
            final List<dynamic> currentEmployees = List.from(
              shopDoc['employees'] ?? [],
            );
            currentEmployees.remove(userName);

            await firestore.collection('shops').doc(shopDoc.id).update({
              'employees': currentEmployees,
              'updatedAt': DateTime.now(),
            });
          }
        }
      }

      // Step 2: Add employee to newly assigned shops
      for (final newShop in newAssignedShops) {
        if (!oldAssignedShops.contains(newShop)) {
          final query = await firestore
              .collection('shops')
              .where('name', isEqualTo: newShop)
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            final shopDoc = query.docs.first;
            final List<dynamic> currentEmployees = List.from(
              shopDoc['employees'] ?? [],
            );
            if (!currentEmployees.contains(userName)) {
              currentEmployees.add(userName);
            }

            await firestore.collection('shops').doc(shopDoc.id).update({
              'employees': currentEmployees,
              'updatedAt': DateTime.now(),
            });
          }
        }
      }

      // Step 3: Update employee and user documents with new shop list
      await firestore.collection('employees').doc(userId).update({
        'assignedShops': newAssignedShops,
        'updatedAt': DateTime.now(),
      });

      final userDoc = await firestore
          .collection('users')
          .where('name', isEqualTo: userName)
          .limit(1)
          .get();

      if (userDoc.docs.isNotEmpty) {
        await firestore.collection('users').doc(userDoc.docs.first.id).update({
          'assignedShops': newAssignedShops,
          'updatedAt': DateTime.now(),
        });
      }

      notifyListeners();
    } catch (e) {
      log('❌ Error updating assignments: $e');
    }
  }

  void startFirebaseListeners() {
    FirebaseFirestore.instance.collection('shops').snapshots().listen((
      snapshot,
    ) {
      shops = snapshot.docs.map((doc) => doc.data()).toList();
      notifyListeners();
    });

    FirebaseFirestore.instance.collection('employees').snapshots().listen((
      snapshot,
    ) {
      employees = snapshot.docs.map((doc) => doc.data()).toList();
      notifyListeners();
    });

    FirebaseFirestore.instance.collection('orders').snapshots().listen((
      snapshot,
    ) {
      _orders.clear();
      _orders.addAll(snapshot.docs.map((doc) => doc.data()));
      notifyListeners();
    });

    FirebaseFirestore.instance.collection('sales').snapshots().listen((
      snapshot,
    ) {
      _sales.clear();
      _sales.addAll(
        snapshot.docs.map((doc) {
          final data = doc.data();
          final rawCreatedAt = data['createdAt'];
          DateTime? createdAt;

          if (rawCreatedAt is Timestamp) {
            createdAt = rawCreatedAt.toDate();
          } else if (rawCreatedAt is DateTime) {
            createdAt = rawCreatedAt;
          } else if (rawCreatedAt is String) {
            createdAt = DateTime.tryParse(rawCreatedAt);
          } else {
            createdAt = null;
          }

          return {'id': doc.id, ...data, 'createdAt': createdAt};
        }),
      );
      notifyListeners();
    });

    FirebaseFirestore.instance.collection('editRequests').snapshots().listen((
      snapshot,
    ) {
      _editRequests.clear();
      _editRequests.addAll(snapshot.docs.map((doc) => doc.data()));
      notifyListeners();
    });
  }
}
