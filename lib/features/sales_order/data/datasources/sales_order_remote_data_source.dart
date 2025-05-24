// lib/features/sales_order/data/datasources/production_remote_data_source.dart
import '../models/paginated_orders_result.dart';
import '../models/sales_order_model.dart';

abstract class SalesOrderRemoteDataSource {
  Future<PaginatedOrdersResult> getSalesOrders({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo, // Added
    required int pageSize, // Added
  });

  Future<SalesOrderModel> getSalesOrderDetail(int orderId);

  Future<void> updateSalesOrderStatus(
      int orderId, int newStatus);
}