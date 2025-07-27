import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AppDataProvider extends ChangeNotifier {
  
  Map<String, dynamic>? _loggedInUser;
  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _sales = [];
  final List<Map<String, dynamic>> _editRequests = [];
  List<Map<String, dynamic>> shops = [];
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> get orders => _orders;
  Map<String, dynamic>? get loggedInUser => _loggedInUser;

  void loginUser(Map<String, dynamic> user) {
    _loggedInUser = user;
    notifyListeners();
  }

  bool loginWithNameAndCode(String name, String code) {
    if (name.isEmpty || code.isEmpty || employees.isEmpty) return false;

    final matched = employees.firstWhere(
      (e) =>
          e['name'].toString().toLowerCase() == name.toLowerCase() &&
          e['loginCode'] == code,
      orElse: () => {},
    );

    if (matched.isNotEmpty) {
      _loggedInUser = matched;
      notifyListeners();
      return true;
    }
    return false;
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
      debugPrint('Error submitting sale edit request: $e');
    }
  }

  Future<void> updateSaleAmount(String saleId, double newAmount) async {
    final index = _sales.indexWhere((s) => s['id'] == saleId);
    if (index != -1) {
      _sales[index]['amount'] = newAmount;
      notifyListeners();

      await FirebaseFirestore.instance.collection('sales').doc(saleId).update({
        'amount': newAmount,
      });
    }
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

 Future<void> deleteShopByName(String name) async {
    try {
      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (shopDoc.docs.isNotEmpty) {
        await shopDoc.docs.first.reference.update({
          'isDeleted': true,
          'deletedAt': Timestamp.now(),
        });
      }

      shops.removeWhere((shop) => shop['name'] == name);
      notifyListeners();
    } catch (e) {
      debugPrint('Error soft deleting shop: $e');
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
      order['createdAt'] = DateTime.now();
      order['canRequestEdit'] = true;

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order['id'].toString())
          .set(order);

      _orders.add(order);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding order: $e');
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
      debugPrint('Error deleting order: $e');
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
      debugPrint('Error updating order: $e');
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
    final now = DateTime.now();
    return _sales.where((s) {
      final createdAt = s['createdAt'] as DateTime?;
      final isRecent =
          createdAt != null && now.difference(createdAt).inMinutes < 5;
      final isOwner = s['addedBy'] == _loggedInUser?['name'];
      return isOwner && isRecent;
    }).toList();
  }
  
 Future<void> addSale(Map<String, dynamic> saleData) async {
    if (saleData.isNotEmpty && saleData['total'] != null) {
      try {
        final docRef = await FirebaseFirestore.instance
            .collection('sales')
            .add(saleData);
        saleData['id'] = docRef.id; // store firestore ID as 'id'
        _sales.add(saleData);
        notifyListeners();
      } catch (e) {
        debugPrint('Error adding sale: $e');
      }
    }
  }



/// Returns only the sale‑type edit requests
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
      debugPrint('Error approving sale edit: $e');
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
      debugPrint('Error rejecting sale edit: $e');
    }
  }



Future<void> updateProfile({
    String? email,
    String? phone,
    String? password,
  }) async {
    if (_loggedInUser == null) return;

    final updates = <String, dynamic>{};
    if (email != null) {
      _loggedInUser!['email'] = email;
      updates['email'] = email;
    }
    if (phone != null) {
      _loggedInUser!['phone'] = phone;
      updates['phone'] = phone;
    }
    if (password != null) {
      _loggedInUser!['password'] = password;
      updates['password'] = password;
    }

    notifyListeners();

    // ✅ Firestore Update
    if (_loggedInUser!['id'] != null && updates.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_loggedInUser!['id']) // this is the doc ID
          .update(updates);
    }
  }


  void editSale(Map<String, dynamic> updatedSale) {
    final index = _sales.indexWhere((s) => s['id'] == updatedSale['id']);
    if (index != -1) {
      _sales[index] = updatedSale;
      notifyListeners();
    }
  }

 Future<void> deleteSale(String id) async {
    _sales.removeWhere((s) => s['id'] == id);
    notifyListeners();
    await FirebaseFirestore.instance.collection('sales').doc(id).delete();
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
  double get totalSales =>
      _sales.fold(0.0, (sumValue, s) => sumValue + (s['amount'] ?? 0.0));
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
      final date = sale['createdAt']?.toDate() ?? now;

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
      debugPrint('Error approving edit request: $e');
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
      debugPrint('Error rejecting edit request: $e');
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
      debugPrint('Error fetching users: $e');
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
      debugPrint('Error fetching orders: $e');
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
          return {
            'id': doc.id,
            ...data,
            'createdAt': (data['createdAt'] as Timestamp).toDate(),
          };
        }),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching sales: $e');
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
      debugPrint('Error fetching edit requests: $e');
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
      _sales.addAll(snapshot.docs.map((doc) => doc.data()));
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
