import '../models/sales_order_model.dart'; // 确保 SalesOrderModel 的路径正确

class PaginatedOrdersResult {
  final List<SalesOrderModel> orders;
  final int totalCount; // 总订单数，API 可能返回也可能不返回

  PaginatedOrdersResult({
    required this.orders,
    required this.totalCount,
  });
}