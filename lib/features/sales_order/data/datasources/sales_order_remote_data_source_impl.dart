// lib/features/sales_order/data/datasources/sales_order_remote_data_source_impl.dart
import 'package:dio/dio.dart';
import '../../../../core/utils/logger.dart';
import '../models/sales_order_model.dart';
import 'sales_order_remote_data_source.dart';

class SalesOrderRemoteDataSourceImpl implements SalesOrderRemoteDataSource {
  final Dio dio;

  final String _getSalesOrdersUrl =
      'https://erp.xiangletools.store:30443/admin-api/sales-orders'; // Example
  final String _getSalesOrderDetailBaseUrl =
      'https://erp.xiangletools.store:30443/admin-api/sales-orders'; // Example, ID will be appended
  final String _updateSalesOrderStatusBaseUrl =
      'https://erp.xiangletools.store:30443/admin-api/sales-orders'; // Example, ID and possibly /status will be appended

  SalesOrderRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<SalesOrderModel>> getSalesOrders({
    String? orderNumberQuery,
    String? statusFilter,
  }) async {
    Map<String, dynamic> queryParams = {};
    if (orderNumberQuery != null && orderNumberQuery.isNotEmpty) {
      queryParams['orderNumber'] = orderNumberQuery;
    }
    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter.toLowerCase() != 'all') {
      queryParams['status'] = statusFilter;
    }

    logger.d(
        'Attempting to get sales orders from $_getSalesOrdersUrl with params: $queryParams');

    try {
      final response = await dio.get(
        _getSalesOrdersUrl,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.data is List) {
        final List<dynamic> responseData = response.data as List<dynamic>;
        logger.d('Sales orders data received, count: ${responseData.length}');
        return responseData
            .map((data) =>
            SalesOrderModel.fromJson(data as Map<String, dynamic>))
            .toList();
      } else {
        logger.w(
            'Invalid response format for sales orders. Expected List, got ${response.data?.runtimeType}');
        throw Exception(
            'Invalid response format received from server for sales orders.');
      }
    } on DioException catch (e) {
      logger.d(
          "DioException in getSalesOrders: ${e.response?.statusCode} - ${e.response?.data ?? e.message}");
      rethrow; // Rethrow for the repository to handle
    } catch (e) {
      logger.e("Unexpected error in getSalesOrders: $e", stackTrace: (e is Error ? e.stackTrace : null));
      throw Exception('Data source error in getSalesOrders: $e');
    }
  }

  @override
  Future<SalesOrderModel> getSalesOrderDetail(String orderId) async {
    final String url = '$_getSalesOrderDetailBaseUrl/$orderId';
    logger.d('Attempting to get sales order detail from $url');

    try {
      final response = await dio.get(url);

      if (response.data is Map<String, dynamic>) {
        logger.d('Sales order detail data received: ${response.data}');
        return SalesOrderModel.fromJson(
            response.data as Map<String, dynamic>);
      } else {
        logger.w(
            'Invalid response format for sales order detail. Expected Map, got ${response.data?.runtimeType}');
        throw Exception(
            'Invalid response format received from server for sales order detail.');
      }
    } on DioException catch (e) {
      logger.d(
          "DioException in getSalesOrderDetail: ${e.response?.statusCode} - ${e.response?.data ?? e.message}");
      rethrow;
    } catch (e) {
      logger.e("Unexpected error in getSalesOrderDetail: $e", stackTrace: (e is Error ? e.stackTrace : null));
      throw Exception('Data source error in getSalesOrderDetail: $e');
    }
  }

  @override
  Future<void> updateSalesOrderStatus(
      String orderId, String newStatus, String? remarks) async {
    // Adjust the URL path as per your API design (e.g., /status, /approve, etc.)
    final String url = '$_updateSalesOrderStatusBaseUrl/$orderId/status';
    logger.d(
        'Attempting to update sales order status for $orderId to $newStatus at $url');

    try {
      final response = await dio.put( // Or dio.patch, depending on your API
        url,
        data: {
          'status': newStatus,
          if (remarks != null) 'remarks': remarks, // Include remarks only if provided
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      logger.d(
          'Sales order status update successful for $orderId. Status: ${response.statusCode}');
    } on DioException catch (e) {
      logger.d(
          "DioException in updateSalesOrderStatus: ${e.response?.statusCode} - ${e.response?.data ?? e.message}");
      rethrow;
    } catch (e) {
      logger.e("Unexpected error in updateSalesOrderStatus: $e", stackTrace: (e is Error ? e.stackTrace : null));
      throw Exception('Data source error in updateSalesOrderStatus: $e');
    }
  }
}