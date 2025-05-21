import '../entities/sales_order_entity.dart';

abstract class SalesOrderRepository {
  Future<List<SalesOrderEntity>> getSalesOrders({
    String? orderNumberQuery,
    String? statusFilter,
  });

  Future<SalesOrderEntity> getSalesOrderDetail(String orderId);

  Future<void> updateSalesOrderStatus(String orderId, String newStatus, String? remarks);
}