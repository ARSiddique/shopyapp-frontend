import 'package:flutter/material.dart';

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

  void requestSaleEdit(int saleId, String reason) {
    _editRequests.add({
      'type': 'sale',
      'itemId': saleId,
      'reason': reason,
      'requestedBy': _loggedInUser?['name'],
      'timestamp': DateTime.now(),
    });
    notifyListeners();
  }

  void updateSaleAmount(int saleId, double newAmount) {
    final index = _sales.indexWhere((s) => s['id'] == saleId);
    if (index != -1) {
      _sales[index]['amount'] = newAmount;
      notifyListeners();
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

  void deleteShopByName(String name) {
    shops.removeWhere((shop) => shop['name'] == name);
    notifyListeners();
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

  void addOrder(Map<String, dynamic> order) {
    if (order.isNotEmpty) {
      order['status'] = 'Pending';
      order['createdAt'] = DateTime.now();
      order['canRequestEdit'] = true;
      _orders.add(order);
      notifyListeners();
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

  void deleteOrder(String id) {
    _orders.removeWhere((o) => o['id'] == id);
    notifyListeners();
  }

  void editOrder(Map<String, dynamic> updatedOrder) {
    final index = _orders.indexWhere((o) => o['id'] == updatedOrder['id']);
    if (index != -1) {
      _orders[index] = updatedOrder;
      notifyListeners();
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

 void addSale(Map<String, dynamic> saleData) {
    if (saleData.isNotEmpty && saleData['amount'] != null) {
      saleData['createdAt'] = DateTime.now();
      saleData['canRequestEdit'] = true;
      saleData['addedBy'] = _loggedInUser?['name'];
      _sales.add(saleData);
      notifyListeners();
    }
  }

void updateProfile({String? email, String? phone, String? password}) {
    if (_loggedInUser != null) {
      if (email != null) _loggedInUser!['email'] = email;
      if (phone != null) _loggedInUser!['phone'] = phone;
      if (password != null) _loggedInUser!['password'] = password;
      notifyListeners();
    }
  }


  void editSale(Map<String, dynamic> updatedSale) {
    final index = _sales.indexWhere((s) => s['id'] == updatedSale['id']);
    if (index != -1) {
      _sales[index] = updatedSale;
      notifyListeners();
    }
  }

  void deleteSale(String id) {
    _sales.removeWhere((s) => s['id'] == id);
    notifyListeners();
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
      _sales.fold(0.0, (sum, s) => sum + (s['amount'] ?? 0.0));
  int get totalShops => shops.length;
  int get totalEmployees => employees.length;

  List<Map<String, dynamic>> get pendingOrders =>
      _orders.where((o) => o['status'] == 'Pending').toList();

  List<Map<String, dynamic>> get forwardedOrders =>
      _orders.where((o) => o['status'] == 'Forwarded').toList();

  List<Map<String, dynamic>> get receivedOrders =>
      _orders.where((o) => o['status'] == 'Received').toList();
}
