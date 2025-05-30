// lib/features/purchase_order/data/repositories/production_repository_impl.dart
import 'dart:io';
import 'dart:nativewrappers/_internal/vm/lib/typed_data_patch.dart';

import 'package:dio/dio.dart'; // Needed if you specifically catch DioException here
import 'package:erp_app/features/purchase_order/data/models/purchase_order_model.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/production_entity.dart';
import '../../domain/repositories/production_repository.dart';
import '../datasources/production_remote_data_source.dart';
import '../models/paginated_result.dart';

class ProductionRepositoryImpl implements ProductionRepository {
  final ProductionRemoteDataSource remoteDataSource;

  ProductionRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<PaginatedResult> getProductions({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo,
    required int pageSize,
  }) async {
    try {
      logger.d('Repository: Calling remoteDataSource.getProductions');
      final remoteOrders = await remoteDataSource.getProductions(
          orderNumberQuery: orderNumberQuery, statusFilter: statusFilter,
          pageNo: pageNo,
          pageSize: pageSize);
      logger.d(
          'Repository: Received ${remoteOrders.orders.length} orders from remoteDataSource');
      return remoteOrders;
    } on DioException catch (e, s) { // Catch DioException and its stackTrace
      logger.e('Repository: DioException during getProductions', error: e, stackTrace: s);
      rethrow;
    } on Exception catch (e, s) { // Catch generic Exception and its stackTrace
      logger.e('Repository: Generic Exception during getProductions', error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<ProductionEntity> getProductionDetail(int orderId) async {
    try {
      logger.d(
          'Repository: Calling remoteDataSource.getProductionDetail for ID $orderId');
      final remoteOrder =
      await remoteDataSource.getProductionDetail(orderId);
      logger.d(
          'Repository: Received order detail for ${remoteOrder.no} from remoteDataSource');
      return remoteOrder;
    } on DioException catch (e, s) {
      logger.e('Repository: DioException during getProductionDetail', error: e, stackTrace: s);
      rethrow;
    } on Exception catch (e, s) {
      logger.e('Repository: Generic Exception during getProductionDetail', error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<void> updateProductionStatus(
      int orderId, int newStatus) async {
    try {
      logger.d(
          'Repository: Calling remoteDataSource.updateProductionStatus for ID $orderId to $newStatus');
      await remoteDataSource.updateProductionStatus(
          orderId, newStatus);
      logger.d(
          'Repository: Successfully called updateProductionStatus for ID $orderId');
    } on DioException catch (e, s) {
      logger.e('Repository: DioException during updateProductionStatus', error: e, stackTrace: s);
      rethrow;
    } on Exception catch (e, s) {
      logger.e('Repository: Generic Exception during updateProductionStatus', error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<bool> uploadShipmentImage({
    required int productionOrderId,
    required List<File> imageFiles,
  }) async {
    // if (await networkInfo.isConnected) { // 如果使用网络检查
    try {
      return await remoteDataSource.uploadShipmentImage(
        productionOrderId: productionOrderId,
        imageFiles: imageFiles,
      );
    } on DioException { // 更具体地捕获DioException
      // 可以选择在这里将 DioException 映射为领域层的 Failure 对象
      // 例如: throw UploadFailure.fromDioError(e);
      rethrow;
    } on Exception { // 捕获其他来自数据源的通用 Exception
      // 例如: throw UploadFailure.unexpectedError(e);
      rethrow;
    }
    // } else {
    //   throw NetworkException(); // 如果使用网络检查
    // }
  }

  @override
  Future<List<PurchaseOrderModel>> relatedPurchaseOrders({required String productionNo}) async {
    try {
      logger.d('Repository: Calling remoteDataSource.getRelatedPurchaseOrders');
      final remoteOrders = await remoteDataSource.getRelatedPurchaseOrders(
          productionNo: productionNo);
      logger.d(
          'Repository: Received ${remoteOrders.length} orders from remoteDataSource');
      return remoteOrders;
    } on DioException catch (e, s) {
      logger.e('Repository: DioException during getRelatedPurchaseOrders', error: e, stackTrace: s);
      rethrow;
    } on Exception catch (e, s) {
      logger.e('Repository: Generic Exception during getRelatedPurchaseOrders', error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<List<Uint8List>> getShipmentImagesZip(int saleOrderId) async {
    try {
      return await remoteDataSource.getShipmentImagesZip(saleOrderId);
    } on DioException {
      // 可以选择在这里将 DioException 映射为领域层的 Failure 对象
      rethrow;
    } on Exception {
      rethrow;
    }
  }
}