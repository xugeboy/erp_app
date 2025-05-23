// lib/features/purchase_order/data/datasources/purchase_order_remote_data_source.dart
import '../../../purchase_order/data/models/paginated_orders_result.dart';
import '../models/purchase_order_model.dart';

abstract class PurchaseOrderRemoteDataSource {
  Future<PaginatedOrdersResult> getPurchaseOrders({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo, // Added
    required int pageSize, // Added
  });

  Future<PurchaseOrderModel> getPurchaseOrderDetail(int orderId);

  Future<void> updatePurchaseOrderStatus(
      int orderId, int newStatus);
}