// lib/features/purchase_order/data/repositories/purchase_order_repository_impl.dart
import 'package:dio/dio.dart'; // Needed if you specifically catch DioException here
import '../../../../core/utils/logger.dart'; // Your logger
import '../../domain/entities/purchase_order_entity.dart';
import '../../domain/repositories/purchase_order_repository.dart';
import '../datasources/purchase_order_remote_data_source.dart';

class PurchaseOrderRepositoryImpl implements PurchaseOrderRepository {
  final PurchaseOrderRemoteDataSource remoteDataSource;

  PurchaseOrderRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<List<PurchaseOrderEntity>> getPurchaseOrders({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo,
    required int pageSize,
  }) async {
    try {
      logger.d('Repository: Calling remoteDataSource.getPurchaseOrders');
      final remoteOrders = await remoteDataSource.getPurchaseOrders(
          orderNumberQuery: orderNumberQuery, statusFilter: statusFilter,
          pageNo: pageNo,
          pageSize: pageSize);
      logger.d(
          'Repository: Received ${remoteOrders.length} orders from remoteDataSource');
      return remoteOrders;
    } on DioException catch (e, s) { // Catch DioException and its stackTrace
      logger.e('Repository: DioException during getPurchaseOrders', error: e, stackTrace: s);
      rethrow;
    } on Exception catch (e, s) { // Catch generic Exception and its stackTrace
      logger.e('Repository: Generic Exception during getPurchaseOrders', error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<PurchaseOrderEntity> getPurchaseOrderDetail(int orderId) async {
    try {
      logger.d(
          'Repository: Calling remoteDataSource.getPurchaseOrderDetail for ID $orderId');
      final remoteOrder =
      await remoteDataSource.getPurchaseOrderDetail(orderId);
      logger.d(
          'Repository: Received order detail for ${remoteOrder.no} from remoteDataSource');
      return remoteOrder;
    } on DioException catch (e, s) {
      logger.e('Repository: DioException during getPurchaseOrderDetail', error: e, stackTrace: s);
      rethrow;
    } on Exception catch (e, s) {
      logger.e('Repository: Generic Exception during getPurchaseOrderDetail', error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<void> updatePurchaseOrderStatus(
      int orderId, int newStatus) async {
    try {
      logger.d(
          'Repository: Calling remoteDataSource.updatePurchaseOrderStatus for ID $orderId to $newStatus');
      await remoteDataSource.updatePurchaseOrderStatus(
          orderId, newStatus);
      logger.d(
          'Repository: Successfully called updatePurchaseOrderStatus for ID $orderId');
    } on DioException catch (e, s) {
      logger.e('Repository: DioException during updatePurchaseOrderStatus', error: e, stackTrace: s);
      rethrow;
    } on Exception catch (e, s) {
      logger.e('Repository: Generic Exception during updatePurchaseOrderStatus', error: e, stackTrace: s);
      rethrow;
    }
  }
}