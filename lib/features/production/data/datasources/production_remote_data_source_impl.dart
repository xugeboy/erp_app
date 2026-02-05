// lib/features/purchase_order/data/datasources/production_remote_data_source_impl.dart
import 'dart:io';

import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:erp_app/features/purchase_order/data/models/purchase_order_model.dart';
import 'package:path/path.dart' as path;
import '../../../../core/utils/logger.dart';
import '../models/paginated_result.dart';
import '../models/production_model.dart';
import 'production_remote_data_source.dart';

class ProductionRemoteDataSourceImpl implements ProductionRemoteDataSource {
  final Dio dio;

  final String _getProductionsUrl =
      'http://192.168.0.158:48080/admin-api/erp/production/page';
  final String _getProductionDetailBaseUrl =
      'http://192.168.0.158:48080/admin-api/erp/production/get';
  final String _updateProductionStatusBaseUrl =
      'http://192.168.0.158:48080/admin-api/erp/production/update-status';
  final String _uploadImageUrl =
      'http://192.168.0.158:48080/admin-api/erp/production/update-shipment-pics';
  final String _getShipmentImagesZipUrl =
      'http://192.168.0.158:48080/admin-api/erp/production/get-shipment-pics';
  final String _getRelatedPurchaseOrdersBaseUrl =
      'http://192.168.0.158:48080/admin-api/erp/production/contracts-page';

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
          final List<PurchaseOrderModel> models =
              listData
                  .map(
                    (data) => PurchaseOrderModel.fromJson(
                      data as Map<String, dynamic>,
                    ),
                  )
                  .toList();
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

  @override
  Future<bool> uploadShipmentImage({
    required int productionOrderId,
    required List<File> imageFiles,
  }) async {
    if (imageFiles.isEmpty) {
      logger.i("DataSource: No image files provided for upload.");
      return false; // Return empty list if no files to upload
    }

    logger.d(
      "DataSource: Uploading ${imageFiles.length} shipment image(s) for production order ID $productionOrderId.",
    );

    try {
      // Create a list of MultipartFile
      List<MultipartFile> filesToUpload = [];
      for (File imageFile in imageFiles) {
        String fileName = path.basename(imageFile.path); // Using path package
        filesToUpload.add(
          await MultipartFile.fromFile(imageFile.path, filename: fileName),
        );
      }
      FormData formData = FormData.fromMap({
        "files": filesToUpload, // Sending a list of MultipartFile
        "productionOrderId":
            productionOrderId
                .toString(), // Ensure ID is string if backend expects that for form data
      });

      logger.d(
        "DataSource: FormData created with ${filesToUpload.length} files for order $productionOrderId.",
      );

      final response = await dio.post(
        _uploadImageUrl, // Ensure this endpoint is designed for batch/multiple file uploads
        data: formData,
        onSendProgress: (int sent, int total) {
          if (total > 0) {
            // Avoid division by zero if total is not yet known
            logger.d(
              'Batch image upload progress: ${(sent / total * 100).toStringAsFixed(0)}%',
            );
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        logger.i(
          "DataSource: Batch image upload API request successful (status ${response.statusCode}). Response data: ${response.data}",
        );

        if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;
          return responseMap['data'];
        } else {
          logger.w(
            "DataSource: Batch image upload API response OK, but no valid image URLs found. Response: ${response.data}",
          );
          throw Exception("图片批量上传成功，但未返回有效的图片链接列表。");
        }
      } else {
        logger.e(
          "DataSource: Batch image upload failed with status ${response.statusCode}. Response: ${response.data}",
        );
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: "图片批量上传失败，状态码: ${response.statusCode}",
        );
      }
    } on DioException catch (e) {
      logger.e(
        "DataSource: DioException during batch image upload for order $productionOrderId. Error: ${e.message}",
        error: e,
        stackTrace: e.stackTrace,
      );
      rethrow; // Rethrow to be handled by the UseCase/Notifier
    } catch (e, s) {
      logger.e(
        "DataSource: Unexpected error during batch image upload for order $productionOrderId",
        error: e,
        stackTrace: s,
      );
      throw Exception("图片批量上传时发生意外错误: ${e.toString()}");
    }
  }

  @override
  Future<List<Uint8List>> getShipmentImagesZip(int saleOrderId) async {
    final String metaUrl = '$_getShipmentImagesZipUrl?saleOrderId=$saleOrderId';
    logger.d("DataSource: Fetching direct ZIP URL from $metaUrl for production order $saleOrderId");

    String directZipFileUrl;

    try {
      final metaResponse = await dio.get(metaUrl);
      if (metaResponse.data != null) {
        // **重要: 根据您的API实际响应调整此处的JSON解析逻辑**

        if(metaResponse.data['data'] == null){
          logger.w("DataSource: No direct ZIP URL found for production order $saleOrderId");
          return [];
        } else {
          directZipFileUrl = metaResponse.data['data'];
        }

        if (directZipFileUrl.isEmpty || (!Uri.tryParse(directZipFileUrl)!.hasAbsolutePath)) {
          logger.e("DataSource: Invalid or empty direct ZIP URL received: $directZipFileUrl");
          throw Exception("获取到的直接ZIP文件链接无效。");
        }
        logger.d("DataSource: Received direct ZIP URL: $directZipFileUrl");

      } else {
        logger.e("DataSource: Failed to get direct ZIP URL, status: ${metaResponse.statusCode}");
        throw DioException(
          requestOptions: metaResponse.requestOptions,
          response: metaResponse,
          error: "获取ZIP文件链接失败，状态码: ${metaResponse.statusCode}",
        );
      }
    } on DioException catch (e) {
      logger.e("DataSource: DioException while fetching direct ZIP URL for $saleOrderId: ${e.message}", error: e, stackTrace: e.stackTrace);
      rethrow;
    } catch (e, s) {
      logger.e("DataSource: Unexpected error while fetching direct ZIP URL for $saleOrderId", error: e, stackTrace: s);
      throw Exception("获取ZIP文件链接时发生意外错误: ${e.toString()}");
    }

    // **步骤 2: 使用获取到的 directZipFileUrl 下载并解压ZIP文件**
    logger.d("DataSource: Downloading shipment images ZIP from direct URL: $directZipFileUrl");
    try {
      final response = await dio.get(
        directZipFileUrl, // 使用从上一步获取的直接URL
        options: Options(
          responseType: ResponseType.bytes, // 期望接收字节流
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        if (response.data is! List<int>) {
          logger.e("DataSource: ZIP download response data is not List<int>. Type: ${response.data.runtimeType}");
          throw Exception("下载的ZIP文件格式不正确。");
        }
        final List<int> zipBytes = response.data as List<int>;
        logger.d("DataSource: ZIP file downloaded successfully, size: ${zipBytes.length} bytes.");

        if (zipBytes.isEmpty) {
          logger.w("DataSource: Downloaded ZIP file is empty for production order $saleOrderId.");
          return [];
        }

        final archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
        final List<Uint8List> imageBytesList = [];

        if (archive.isEmpty && zipBytes.isNotEmpty) {
          logger.w("DataSource: ZIP file was not empty but ZipDecoder returned empty archive. Possible corrupted ZIP for production order $saleOrderId.");
          throw Exception("无法解析下载的ZIP文件，可能已损坏或格式不正确。");
        }

        for (final fileInArchive in archive) {
          if (fileInArchive.isFile) {
            final fileNameLower = fileInArchive.name.toLowerCase();
            if (fileNameLower.endsWith('.jpg') ||
                fileNameLower.endsWith('.jpeg') ||
                fileNameLower.endsWith('.png') ||
                fileNameLower.endsWith('.gif') ||
                fileNameLower.endsWith('.webp')) {
              imageBytesList.add(Uint8List.fromList(fileInArchive.content as List<int>));
              logger.d("DataSource: Extracted image from ZIP: ${fileInArchive.name}");
            } else {
              logger.w("DataSource: Skipped non-image file in ZIP: ${fileInArchive.name}");
            }
          }
        }
        if (imageBytesList.isEmpty && archive.isNotEmpty) {
          logger.w("DataSource: ZIP file was not empty but contained no recognized image files.");
        }
        return imageBytesList;
      } else {
        logger.e("DataSource: Failed to download ZIP file from direct URL, status: ${response.statusCode}");
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: "下载出货图片ZIP失败 (直接链接)，状态码: ${response.statusCode}",
        );
      }
    } on DioException catch (e) {
      logger.e("DataSource: DioException downloading/processing ZIP from direct URL for $saleOrderId: ${e.message}", error: e, stackTrace: e.stackTrace);
      rethrow;
    } on ArchiveException catch (e,s) {
      logger.e("DataSource: ArchiveException (ZIP decoding) for $saleOrderId: ${e.message}", error: e, stackTrace: s);
      throw Exception("解压出货图片ZIP文件失败: ${e.message}");
    }
    catch (e, s) {
      logger.e("DataSource: Unexpected error downloading/processing ZIP from direct URL for $saleOrderId", error: e, stackTrace: s);
      throw Exception("处理出货图片ZIP时发生意外错误: ${e.toString()}");
    }
  }
}
