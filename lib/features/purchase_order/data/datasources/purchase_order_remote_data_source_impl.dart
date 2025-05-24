// lib/features/purchase_order/data/datasources/production_remote_data_source_impl.dart
import 'package:dio/dio.dart';
import '../../../../core/utils/logger.dart';
import '../models/paginated_orders_result.dart';
import '../models/purchase_order_model.dart';
import 'purchase_order_remote_data_source.dart';


class PurchaseOrderRemoteDataSourceImpl implements PurchaseOrderRemoteDataSource {
  final Dio dio;

  final String _getPurchaseOrdersUrl =
      'https://erp.xiangletools.store:30443/admin-api/erp/purchase-order/page';
  final String _getPurchaseOrderDetailBaseUrl =
      'https://erp.xiangletools.store:30443/admin-api/erp/purchase-order/get';
  final String _updatePurchaseOrderStatusBaseUrl =
      'https://erp.xiangletools.store:30443/admin-api/erp/purchase-order/update-status';

  PurchaseOrderRemoteDataSourceImpl(this.dio);


  @override
  Future<PaginatedOrdersResult> getPurchaseOrders({
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
      queryParams['no'] = orderNumberQuery;
    }

    // Add statusFilter if it's provided (it's an int?, convert to String for query)
    if (statusFilter != null) {
      queryParams['status'] = statusFilter;
    }

    logger.d(
        'DataSource: Attempting to get purchase orders from $_getPurchaseOrdersUrl with params: $queryParams');

    try {
      final response = await dio.get(
        _getPurchaseOrdersUrl,
        queryParameters: queryParams,
        // Add Options here if needed for specific headers for this request,
        // e.g., if your AuthInterceptor doesn't cover it or special headers are needed.
        // options: Options(headers: {'Custom-Purchase-Header': 'value'}),
      );

      int totalCount = 0;
      // Check the structure of the response data
      // Your API might return a list directly, or a map containing the list and total count.
      if (response.data is Map<String, dynamic>) {
        // Case 2: API returns a map, e.g., {"data": {"list": [...], "total": ...}} or {"list": [...]}
        final Map<String, dynamic> responseMap = response.data as Map<String, dynamic>;
        List<dynamic>? listData;

        // Try to find the list in common structures
        if (responseMap.containsKey('data') && responseMap['data'] is Map) {
          final dataMap = responseMap['data'] as Map<String, dynamic>;
          if (dataMap.containsKey('list') && dataMap['list'] is List) {
            listData = dataMap['list'] as List<dynamic>;
          }
          totalCount = dataMap['total'] as int;
        }
        // Add more checks if your API has a different structure for the list

        if (listData != null) {
          const int draftStatusCode = 98;

          List<dynamic> filteredList = listData.where((orderData) {
            if (orderData is Map<String, dynamic>) {
              // Assuming 'status' field contains the integer status code
              final dynamic statusValue = orderData['status'];
              int? orderStatus;
              if (statusValue is int) {
                orderStatus = statusValue;
              } else if (statusValue is String) {
                orderStatus = int.tryParse(statusValue);
              }
              return orderStatus != draftStatusCode;
            }
            return true; // Keep if not a map, though unlikely for valid data
          }).toList();

          logger.d(
              'DataSource: Purchase orders data (from wrapped list) received for page $pageNo, count: ${listData.length}');
          final List<PurchaseOrderModel> models = filteredList
              .map((data) =>
              PurchaseOrderModel.fromJson(data as Map<String, dynamic>))
              .toList();
          return PaginatedOrdersResult(orders: models, totalCount: totalCount);
        } else {
          logger.w(
              'DataSource: Response is a Map, but "list" key not found or not a List. Data: ${response.data}');
          throw Exception(
              'Invalid response format: Expected a list of orders or a map containing a list.');
        }
      } else {
        // Fallback for unexpected response types
        logger.w(
            'DataSource: Invalid response format for purchase orders. Expected List or Map, got ${response.data?.runtimeType}. Data: ${response.data}');
        throw Exception(
            'Invalid response format received from server for purchase orders.');
      }
    } on DioException catch (e) {
      // Consistent with your AuthRemoteDataSourceImpl: log and rethrow
      logger.d(
          "DataSource: DioException in getPurchaseOrders (page $pageNo): ${e.response?.statusCode} - ${e.response?.data ?? e.message}");
      rethrow; // Rethrow for the repository to handle
    } catch (e, s) {
      // Catch any other unexpected errors
      logger.e("DataSource: Unexpected error in getPurchaseOrders (page $pageNo)", error: e, stackTrace: s);
      throw Exception('Data source error in getPurchaseOrders: ${e.toString()}');
    }
  }

  @override
  Future<PurchaseOrderModel> getPurchaseOrderDetail(int orderId) async {
    final String url = '$_getPurchaseOrderDetailBaseUrl?id=$orderId';
    logger.d('Attempting to get purchase order detail from $url');

    try {
      final response = await dio.get(url);
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> responseMap = response.data as Map<String, dynamic>;
        final dataMap = responseMap['data'] as Map<String, dynamic>;
        logger.d('Purchase order detail data received: ${response.data}');
        return PurchaseOrderModel.fromJson(dataMap);
      } else {
        logger.w(
            'Invalid response format for purchase order detail. Expected Map, got ${response.data?.runtimeType}');
        throw Exception(
            'Invalid response format received from server for purchase order detail.');
      }
    } on DioException catch (e) {
      logger.d(
          "DioException in getPurchaseOrderDetail: ${e.response?.statusCode} - ${e.response?.data ?? e.message}");
      rethrow;
    } catch (e) {
      logger.e("Unexpected error in getPurchaseOrderDetail: $e", stackTrace: (e is Error ? e.stackTrace : null));
      throw Exception('Data source error in getPurchaseOrderDetail: $e');
    }
  }

  @override
  Future<void> updatePurchaseOrderStatus(
      int orderId, int newStatus) async {
    logger.d(
        'Attempting to update purchase order status for $orderId to $newStatus at $_updatePurchaseOrderStatusBaseUrl');

    try {
      final response = await dio.put( // Or dio.patch, depending on your API
        _updatePurchaseOrderStatusBaseUrl,
        queryParameters: {
          'id': orderId,       // 订单ID
          'status': newStatus, // 新的状态码
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      logger.d(
          'Purchase order status update successful for $orderId. Status: ${response.statusCode}');
    } on DioException catch (e) {
      logger.d(
          "DioException in updatePurchaseOrderStatus: ${e.response?.statusCode} - ${e.response?.data ?? e.message}");
      rethrow;
    } catch (e) {
      logger.e("Unexpected error in updatePurchaseOrderStatus: $e", stackTrace: (e is Error ? e.stackTrace : null));
      throw Exception('Data source error in updatePurchaseOrderStatus: $e');
    }
  }
}