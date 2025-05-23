import '../../../purchase_order/data/models/paginated_orders_result.dart';
import '../entities/purchase_order_entity.dart';

abstract class PurchaseOrderRepository {
  Future<PaginatedOrdersResult> getPurchaseOrders({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo,
    required int pageSize,
  });

  Future<PurchaseOrderEntity> getPurchaseOrderDetail(int orderId);

  Future<void> updatePurchaseOrderStatus(int orderId, int newStatus);
}