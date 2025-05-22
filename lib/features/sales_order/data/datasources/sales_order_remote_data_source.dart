// lib/features/sales_order/data/datasources/sales_order_remote_data_source.dart
import '../models/sales_order_model.dart';

abstract class SalesOrderRemoteDataSource {
  Future<List<SalesOrderModel>> getSalesOrders({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo, // Added
    required int pageSize, // Added
  });

  Future<SalesOrderModel> getSalesOrderDetail(int orderId);

  Future<void> updateSalesOrderStatus(
      int orderId, int newStatus);
}