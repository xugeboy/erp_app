import 'package:erp_app/features/production/data/models/production_model.dart';
import 'package:erp_app/features/purchase_order/data/models/purchase_order_model.dart';

class PaginatedResult {
  final List<ProductionModel> orders;
  final int totalCount; // 总订单数，API 可能返回也可能不返回

  PaginatedResult({
    required this.orders,
    required this.totalCount,
  });
}