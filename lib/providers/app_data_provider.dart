import 'package:flutter/material.dart';

class AppDataProvider extends ChangeNotifier {
  // Data Stores
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> shops = [];
  List<Map<String, dynamic>> employees = [];

  // Logged-in User
  Map<String, dynamic>? _loggedInUser;
  Map<String, dynamic>? get loggedInUser => _loggedInUser;

  Map<String, dynamic> getEmployeeByName(String name) {
    return employees.firstWhere((e) => e['name'] == name, orElse: () => {});
  }

  // ✅ Admin Manual Login
  void loginUser(Map<String, dynamic> user) {
    _loggedInUser = user;
    notifyListeners();
  }

  // Employee Login
  bool login(String code) {
    if (code.isEmpty || employees.isEmpty) return false;

    final matched = employees.firstWhere(
      (e) => e['loginCode'] == code,
      orElse: () => {},
    );

    if (matched.isNotEmpty) {
      _loggedInUser = matched;
      notifyListeners();
      return true;
    }
    return false;
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

  void assignAccess(String shopName, String employeeName) {
    final shopIndex = shops.indexWhere((shop) => shop['name'] == shopName);
    if (shopIndex != -1) {
      final shop = shops[shopIndex];
      final currentEmployees = List<String>.from(shop['employees'] ?? []);
      if (!currentEmployees.contains(employeeName)) {
        currentEmployees.add(employeeName);
        shops[shopIndex]['employees'] = currentEmployees;
        notifyListeners();
      }
    }
  }

 void addOrder(Map<String, dynamic> order) {
    if (order.isNotEmpty) {
      order['status'] = 'Pending';
      order['createdAt'] = DateTime.now();
      order['canRequestEdit'] = true;
      orders.add(order);
      notifyListeners();
    }
  }

  void forwardOrder(int id) {
    final index = orders.indexWhere((order) => order['id'] == id);
    if (index != -1) {
      orders[index]['status'] = 'Forwarded';
      notifyListeners();
    }
  }

  void markOrderReceived(int id) {
    final index = orders.indexWhere((order) => order['id'] == id);
    if (index != -1) {
      orders[index]['status'] = 'Received';
      notifyListeners();
    }
  }

  void deleteOrder(int id) {
    orders.removeWhere((order) => order['id'] == id);
    notifyListeners();
  }

void addSale(Map<String, dynamic> saleData) {
    if (saleData.isNotEmpty && saleData['amount'] != null) {
      saleData['createdAt'] = DateTime.now();
      saleData['canRequestEdit'] = true;
      sales.add(saleData);
      notifyListeners();
    }
  }

  void addShop(Map<String, dynamic> shopData) {
    if (shopData.isNotEmpty) {
      shops.add(shopData);
      notifyListeners();
    }
  }

  void deleteShop(int index) {
    if (index >= 0 && index < shops.length) {
      shops.removeAt(index);
      notifyListeners();
    }
  }

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



  int get totalOrders => orders.length;
  double get totalSales => sales.fold(0, (sum, s) => sum + (s['amount'] ?? 0));
  int get totalShops => shops.length;
  int get totalEmployees => employees.length;

  List<Map<String, dynamic>> get pendingOrders =>
      orders.where((o) => o['status'] == 'Pending').toList();
  List<Map<String, dynamic>> get forwardedOrders =>
      orders.where((o) => o['status'] == 'Forwarded').toList();
  List<Map<String, dynamic>> get receivedOrders =>
      orders.where((o) => o['status'] == 'Received').toList();
}
