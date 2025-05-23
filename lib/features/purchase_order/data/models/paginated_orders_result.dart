import 'package:erp_app/features/purchase_order/data/models/purchase_order_model.dart';

class PaginatedOrdersResult {
  final List<PurchaseOrderModel> orders;
  final int totalCount; // 总订单数，API 可能返回也可能不返回

  PaginatedOrdersResult({
    required this.orders,
    required this.totalCount,
  });
}