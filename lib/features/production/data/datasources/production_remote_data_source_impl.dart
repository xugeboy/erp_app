// lib/features/purchase_order/data/datasources/production_remote_data_source_impl.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:erp_app/features/purchase_order/data/models/purchase_order_model.dart';
import 'package:erp_app/features/purchase_order/domain/entities/purchase_order_entity.dart';
import 'package:path/path.dart' as path;
import '../../../../core/utils/logger.dart';
import '../models/paginated_result.dart';
import '../models/production_model.dart';
import 'production_remote_data_source.dart';

class ProductionRemoteDataSourceImpl implements ProductionRemoteDataSource {
  final Dio dio;

  final String _getProductionsUrl =
      'https://erp.xiangletools.store:30443/admin-api/erp/production/page';
  final String _getProductionDetailBaseUrl =
      'https://erp.xiangletools.store:30443/admin-api/erp/production/get';
  final String _updateProductionStatusBaseUrl =
      'https://erp.xiangletools.store:30443/admin-api/erp/production/update-status';
  final String _uploadImageUrl =
      'https://erp.xiangletools.store:30443/admin-api/erp/production/update-status';
  final String _getRelatedPurchaseOrdersBaseUrl =
      'https://erp.xiangletools.store:30443/admin-api/erp/production/contracts-page';

  ProductionRemoteDataSourceImpl(this.dio);

  @override
  Future<PaginatedResult> getProductions({
    String? orderNumberQuery,
    int? statusFilter, // Changed to int? to match the interface
    required int pageNo,
    required int pageSize,
  }) async {
    // Prepare query parameters
    Map<String, dynamic> queryParams = {'pageNo': pageNo, 'pageSize': pageSize};

    if (orderNumberQuery != null && orderNumberQuery.isNotEmpty) {
      queryParams['no'] = orderNumberQuery;
    }

    // Add statusFilter if it's provided (it's an int?, convert to String for query)
    if (statusFilter != null) {
      queryParams['status'] = statusFilter;
    }

    logger.d(
      'DataSource: Attempting to get purchase orders from $_getProductionsUrl with params: $queryParams',
    );

    try {
      final response = await dio.get(
        _getProductionsUrl,
        queryParameters: queryParams,
      );

      int totalCount = 0;
      if (response.data is Map<String, dynamic>) {
        // Case 2: API returns a map, e.g., {"data": {"list": [...], "total": ...}} or {"list": [...]}
        final Map<String, dynamic> responseMap =
            response.data as Map<String, dynamic>;
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

          List<dynamic> filteredList =
              listData.where((orderData) {
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
            'DataSource: Purchase orders data (from wrapped list) received for page $pageNo, count: ${listData.length}',
          );
          final List<ProductionModel> models =
              filteredList
                  .map(
                    (data) =>
                        ProductionModel.fromJson(data as Map<String, dynamic>),
                  )
                  .toList();
          return PaginatedResult(orders: models, totalCount: totalCount);
        } else {
          logger.w(
            'DataSource: Response is a Map, but "list" key not found or not a List. Data: ${response.data}',
          );
          throw Exception(
            'Invalid response format: Expected a list of orders or a map containing a list.',
          );
        }
      } else {
        // Fallback for unexpected response types
        logger.w(
          'DataSource: Invalid response format for purchase orders. Expected List or Map, got ${response.data?.runtimeType}. Data: ${response.data}',
        );
        throw Exception(
          'Invalid response format received from server for purchase orders.',
        );
      }
    } on DioException catch (e) {
      // Consistent with your AuthRemoteDataSourceImpl: log and rethrow
      logger.d(
        "DataSource: DioException in getProductions (page $pageNo): ${e.response?.statusCode} - ${e.response?.data ?? e.message}",
      );
      rethrow; // Rethrow for the repository to handle
    } catch (e, s) {
      // Catch any other unexpected errors
      logger.e(
        "DataSource: Unexpected error in getProductions (page $pageNo)",
        error: e,
        stackTrace: s,
      );
      throw Exception('Data source error in getProductions: ${e.toString()}');
    }
  }

  @override
  Future<ProductionModel> getProductionDetail(int orderId) async {
    final String url = '$_getProductionDetailBaseUrl?id=$orderId';
    logger.d('Attempting to get purchase order detail from $url');

    try {
      final response = await dio.get(url);
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> responseMap =
            response.data as Map<String, dynamic>;
        final dataMap = responseMap['data'] as Map<String, dynamic>;
        logger.d('Purchase order detail data received: ${response.data}');
        return ProductionModel.fromJson(dataMap);
      } else {
        logger.w(
          'Invalid response format for purchase order detail. Expected Map, got ${response.data?.runtimeType}',
        );
        throw Exception(
          'Invalid response format received from server for purchase order detail.',
        );
      }
    } on DioException catch (e) {
      logger.d(
        "DioException in getProductionDetail: ${e.response?.statusCode} - ${e.response?.data ?? e.message}",
      );
      rethrow;
    } catch (e) {
      logger.e(
        "Unexpected error in getProductionDetail: $e",
        stackTrace: (e is Error ? e.stackTrace : null),
      );
      throw Exception('Data source error in getProductionDetail: $e');
    }
  }

  @override
  Future<void> updateProductionStatus(int orderId, int newStatus) async {
    logger.d(
      'Attempting to update purchase order status for $orderId to $newStatus at $_updateProductionStatusBaseUrl',
    );

    try {
      final response = await dio.put(
        // Or dio.patch, depending on your API
        _updateProductionStatusBaseUrl,
        queryParameters: {
          'id': orderId, // 订单ID
          'status': newStatus, // 新的状态码
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      logger.d(
        'Purchase order status update successful for $orderId. Status: ${response.statusCode}',
      );
    } on DioException catch (e) {
      logger.d(
        "DioException in updateProductionStatus: ${e.response?.statusCode} - ${e.response?.data ?? e.message}",
      );
      rethrow;
    } catch (e) {
      logger.e(
        "Unexpected error in updateProductionStatus: $e",
        stackTrace: (e is Error ? e.stackTrace : null),
      );
      throw Exception('Data source error in updateProductionStatus: $e');
    }
  }

  @override
  Future<String> uploadShipmentImage({
    required int productionOrderId,
    required File imageFile,
  }) async {
    logger.d(
      "DataSource: Uploading shipment image for production order ID $productionOrderId. File: ${imageFile.path}",
    );
    try {
      String fileName = path.basename(imageFile.path); // 使用 path 包获取文件名
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
        "productionOrderId": productionOrderId.toString(), // 将ID作为表单字段传递
        // 您可能还需要传递其他参数，例如 "imageType": "shipment"
      });

      final response = await dio.post(
        _uploadImageUrl, // 确保这是正确的上传端点
        data: formData,
        options: Options(
          headers: {
            // Dio 会自动为 multipart/form-data 设置 Content-Type
            // 但如果您的后端有特殊要求，可以在这里添加
          },
          // 如果上传需要较长时间，可以调整超时
          // sendTimeout: Duration(seconds: 60),
          // receiveTimeout: Duration(seconds: 60),
        ),
        onSendProgress: (int sent, int total) {
          logger.d(
            'Image upload progress: ${(sent / total * 100).toStringAsFixed(0)}%',
          );
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // **重要：根据您的API响应调整如何提取图片URL**
        // 假设API返回 {"data": {"imageUrl": "..."}} 或 {"imageUrl": "..."}
        if (response.data is Map<String, dynamic>) {
          final responseData = response.data as Map<String, dynamic>;
          String? imageUrl;
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            imageUrl = responseData['data']['imageUrl'] as String?;
          } else if (responseData.containsKey('imageUrl')) {
            imageUrl = responseData['imageUrl'] as String?;
          }

          if (imageUrl != null && imageUrl.isNotEmpty) {
            logger.i("DataSource: Image uploaded successfully. URL: $imageUrl");
            return imageUrl;
          } else {
            logger.w(
              "DataSource: Image upload API response OK, but imageUrl not found or empty. Response: $responseData",
            );
            throw Exception("图片上传成功，但未返回有效的图片链接。");
          }
        } else {
          logger.w(
            "DataSource: Image upload API response OK, but format is not Map. Response: ${response.data}",
          );
          throw Exception("图片上传成功，但响应格式不正确。");
        }
      } else {
        logger.e(
          "DataSource: Image upload failed with status ${response.statusCode}. Response: ${response.data}",
        );
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: "图片上传失败，状态码: ${response.statusCode}",
        );
      }
    } on DioException catch (e) {
      logger.e(
        "DataSource: DioException during image upload for $productionOrderId",
        error: e,
        stackTrace: e.stackTrace,
      );
      rethrow;
    } catch (e, s) {
      logger.e(
        "DataSource: Unexpected error during image upload for $productionOrderId",
        error: e,
        stackTrace: s,
      );
      throw Exception("图片上传时发生意外错误: ${e.toString()}");
    }
  }

  @override
  Future<List<PurchaseOrderModel>> getRelatedPurchaseOrders({
    required String productionNo,
  }) async {
    Map<String, dynamic> queryParams = {'pageNo': 1, 'pageSize': 20};

    queryParams['productionNo'] = productionNo;

    logger.d(
      'DataSource: Attempting to get purchase orders from $_getProductionsUrl with params: $queryParams',
    );

    try {
      final response = await dio.get(
        _getRelatedPurchaseOrdersBaseUrl,
        queryParameters: queryParams,
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> responseMap =
            response.data as Map<String, dynamic>;
        List<dynamic>? listData;

        // Try to find the list in common structures
        if (responseMap.containsKey('data') && responseMap['data'] is Map) {
          final dataMap = responseMap['data'] as Map<String, dynamic>;
          if (dataMap.containsKey('list') && dataMap['list'] is List) {
            listData = dataMap['list'] as List<dynamic>;
          }
        }

        if (listData != null) {
          final List<PurchaseOrderModel> models = listData.map(
                (data) =>
                PurchaseOrderModel.fromJson(data as Map<String, dynamic>),
          ).toList();
          return models;
        } else {
          logger.w(
            'DataSource: Response is a Map, but "list" key not found or not a List. Data: ${response.data}',
          );
          throw Exception(
            'Invalid response format: Expected a list of orders or a map containing a list.',
          );
        }
      } else {
        // Fallback for unexpected response types
        logger.w(
          'DataSource: Invalid response format for purchase orders. Expected List or Map, got ${response.data?.runtimeType}. Data: ${response.data}',
        );
        throw Exception(
          'Invalid response format received from server for purchase orders.',
        );
      }
    } on DioException catch (e) {
      // Consistent with your AuthRemoteDataSourceImpl: log and rethrow
      logger.d(
        "DataSource: DioException in getProductions: ${e.response?.statusCode} - ${e.response?.data ?? e.message}",
      );
      rethrow; // Rethrow for the repository to handle
    } catch (e, s) {
      // Catch any other unexpected errors
      logger.e(
        "DataSource: Unexpected error in getProductions",
        error: e,
        stackTrace: s,
      );
      throw Exception('Data source error in getProductions: ${e.toString()}');
    }
  }
}
