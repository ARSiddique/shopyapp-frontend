import 'package:flutter/material.dart';

class AppDataProvider extends ChangeNotifier {
  // 🔹 Data Stores
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> shops = [];
  List<Map<String, dynamic>> employees = [];

  // 🔐 Logged-in User
  Map<String, dynamic>? _loggedInUser;

  Map<String, dynamic>? get loggedInUser => _loggedInUser;

  // ✅ Login Function
  bool login(String code) {
    try {
      final user = employees.firstWhere((e) => e['loginCode'] == code);
      _loggedInUser = user;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  void logout() {
    _loggedInUser = null;
    notifyListeners();
  }

  // ✅ Add Employee (via AddEmployeeScreen)
  void addEmployee(Map<String, dynamic> employeeData) {
    employees.add(employeeData);
    notifyListeners();
  }

  // ✅ Assign Role + Shops (via AssignAccessScreen)
  void assignAccess(String name, String role, List<String> assignedShops) {
    final index = employees.indexWhere((e) => e['name'] == name);
    if (index != -1) {
      employees[index]['role'] = role;
      employees[index]['assignedShops'] = assignedShops;
      notifyListeners();
    }
  }

  // 🔹 Add Order
  void addOrder(Map<String, dynamic> order) {
    order['status'] = 'Pending';
    orders.add(order);
    notifyListeners();
  }

  void forwardOrder(int id) {
    int index = orders.indexWhere((order) => order['id'] == id);
    if (index != -1) {
      orders[index]['status'] = 'Forwarded';
      notifyListeners();
    }
  }

  void markOrderReceived(int id) {
    int index = orders.indexWhere((order) => order['id'] == id);
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
    sales.add(saleData);
    notifyListeners();
  }

  void deleteShop(int index) {
    shops.removeAt(index);
    notifyListeners();
  }

  // 📊 Summary Getters
  int get totalOrders => orders.length;
  double get totalSales =>
      sales.fold(0, (sum, sale) => sum + (sale['amount'] ?? 0));
  int get totalShops => shops.length;
  int get totalEmployees => employees.length;

  // Filtered
  List<Map<String, dynamic>> get pendingOrders =>
      orders.where((o) => o['status'] == 'Pending').toList();
  List<Map<String, dynamic>> get forwardedOrders =>
      orders.where((o) => o['status'] == 'Forwarded').toList();
  List<Map<String, dynamic>> get receivedOrders =>
      orders.where((o) => o['status'] == 'Received').toList();
}
