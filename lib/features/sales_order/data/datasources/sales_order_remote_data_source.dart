// lib/features/sales_order/data/datasources/sales_order_remote_data_source.dart
import '../models/sales_order_model.dart';

abstract class SalesOrderRemoteDataSource {
  Future<List<SalesOrderModel>> getSalesOrders({
    String? orderNumberQuery,
    String? statusFilter,
  });

  Future<SalesOrderModel> getSalesOrderDetail(String orderId);

  Future<void> updateSalesOrderStatus(
      String orderId, String newStatus, String? remarks);
}