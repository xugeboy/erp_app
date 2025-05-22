// lib/features/sales_order/data/datasources/sales_order_remote_data_source_impl.dart
import 'package:dio/dio.dart';
import '../../../../core/utils/logger.dart';
import '../models/sales_order_model.dart';
import 'sales_order_remote_data_source.dart';

class SalesOrderRemoteDataSourceImpl implements SalesOrderRemoteDataSource {
  final Dio dio;

  final String _getSalesOrdersUrl =
      'https://erp.xiangletools.store:30443/admin-api/erp/sale-order/page';
  final String _getSalesOrderDetailBaseUrl =
      'https://erp.xiangletools.store:30443/admin-api/erp/sale-order/get';
  final String _updateSalesOrderStatusBaseUrl =
      'https://erp.xiangletools.store:30443/admin-api/erp/sale-order/update-status';

  SalesOrderRemoteDataSourceImpl(this.dio);

  @override
  Future<List<SalesOrderModel>> getSalesOrders({
    String? orderNumberQuery,
    int? statusFilter, // Changed to int? to match the interface
    required int pageNo,
    required int pageSize,
  }) async {
    // Prepare query parameters
    Map<String, dynamic> queryParams = {
      'pageNo': pageNo,
      'pageSize': pageSize,
    };

    if (orderNumberQuery != null && orderNumberQuery.isNotEmpty) {
      queryParams['orderNumber'] = orderNumberQuery;
    }

    // Add statusFilter if it's provided (it's an int?, convert to String for query)
    if (statusFilter != null) {
      queryParams['status'] = statusFilter;
    }

    logger.d(
        'DataSource: Attempting to get sales orders from $_getSalesOrdersUrl with params: $queryParams');

    try {
      final response = await dio.get(
        _getSalesOrdersUrl,
        queryParameters: queryParams,
        // Add Options here if needed for specific headers for this request,
        // e.g., if your AuthInterceptor doesn't cover it or special headers are needed.
        // options: Options(headers: {'Custom-Sales-Header': 'value'}),
      );

      // Check the structure of the response data
      // Your API might return a list directly, or a map containing the list and total count.
      if (response.data is List) {
        // Case 1: API returns a list directly
        final List<dynamic> responseData = response.data as List<dynamic>;
        logger.d(
            'DataSource: Sales orders data (direct list) received for page $pageNo, count: ${responseData.length}');
        return responseData
            .map((data) =>
            SalesOrderModel.fromJson(data as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map<String, dynamic>) {
        // Case 2: API returns a map, e.g., {"data": {"list": [...], "total": ...}} or {"list": [...]}
        final Map<String, dynamic> responseMap = response.data as Map<String, dynamic>;
        List<dynamic>? listData;

        // Try to find the list in common structures
        if (responseMap.containsKey('list') && responseMap['list'] is List) {
          listData = responseMap['list'] as List<dynamic>;
        } else if (responseMap.containsKey('data') && responseMap['data'] is Map) {
          final dataMap = responseMap['data'] as Map<String, dynamic>;
          if (dataMap.containsKey('list') && dataMap['list'] is List) {
            listData = dataMap['list'] as List<dynamic>;
          }
          // You could also extract total count here if needed by your notifier:
          int? totalCount = dataMap['total'] as int?;
        }
        // Add more checks if your API has a different structure for the list

        if (listData != null) {
          logger.d(
              'DataSource: Sales orders data (from wrapped list) received for page $pageNo, count: ${listData.length}');
          return listData
              .map((data) =>
              SalesOrderModel.fromJson(data as Map<String, dynamic>))
              .toList();
        } else {
          logger.w(
              'DataSource: Response is a Map, but "list" key not found or not a List. Data: ${response.data}');
          throw Exception(
              'Invalid response format: Expected a list of orders or a map containing a list.');
        }
      } else {
        // Fallback for unexpected response types
        logger.w(
            'DataSource: Invalid response format for sales orders. Expected List or Map, got ${response.data?.runtimeType}. Data: ${response.data}');
        throw Exception(
            'Invalid response format received from server for sales orders.');
      }
    } on DioException catch (e) {
      // Consistent with your AuthRemoteDataSourceImpl: log and rethrow
      logger.d(
          "DataSource: DioException in getSalesOrders (page $pageNo): ${e.response?.statusCode} - ${e.response?.data ?? e.message}");
      rethrow; // Rethrow for the repository to handle
    } catch (e, s) {
      // Catch any other unexpected errors
      logger.e("DataSource: Unexpected error in getSalesOrders (page $pageNo)", error: e, stackTrace: s);
      throw Exception('Data source error in getSalesOrders: ${e.toString()}');
    }
  }

  @override
  Future<SalesOrderModel> getSalesOrderDetail(int orderId) async {
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
      int orderId, int newStatus) async {
    logger.d(
        'Attempting to update sales order status for $orderId to $newStatus at $_updateSalesOrderStatusBaseUrl');

    try {
      final response = await dio.put( // Or dio.patch, depending on your API
        _updateSalesOrderStatusBaseUrl,
        data: {
          'id': newStatus,
          'status': newStatus,
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