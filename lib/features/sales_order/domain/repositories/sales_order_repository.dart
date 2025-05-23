import '../../data/models/paginated_orders_result.dart';
import '../entities/sales_order_entity.dart';

abstract class SalesOrderRepository {
  Future<PaginatedOrdersResult> getSalesOrders({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo,
    required int pageSize,
  });

  Future<SalesOrderEntity> getSalesOrderDetail(int orderId);

  Future<void> updateSalesOrderStatus(int orderId, int newStatus);
}