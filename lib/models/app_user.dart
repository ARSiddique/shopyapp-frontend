class AppUser {
  final String name;
  final String phone;
  final String loginCode;
  final String role; // "Admin", "Manager", "Employee"
  final List<String> assignedShops;

  AppUser({
    required this.name,
    required this.phone,
    required this.loginCode,
    required this.role,
    required this.assignedShops,
  });
}
