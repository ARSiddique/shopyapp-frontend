import '../providers/app_data_provider.dart';

class ShopMetricsHelper {
  static int getOrderCount(AppDataProvider appData, String shopName) {
    return appData.orders.where((o) => o['shop'] == shopName).length;
  }

  static double getTotalSales(AppDataProvider appData, String shopName) {
    final sales = appData.sales.where((s) => s['shop'] == shopName);
    return sales.fold(0, (sum, sale) => sum + (sale['amount'] ?? 0));
  }

  static int getCheckinCount(String shopName) {
    // Placeholder: Replace with actual check-in tracking
    return 0;
  }
}
