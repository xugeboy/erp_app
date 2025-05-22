// lib/features/sales_order/data/repositories/sales_order_repository_impl.dart
import 'package:dio/dio.dart'; // Needed if you specifically catch DioException here
import '../../../../core/utils/logger.dart'; // Your logger
import '../../domain/entities/sales_order_entity.dart';
import '../../domain/repositories/sales_order_repository.dart';
import '../datasources/sales_order_remote_data_source.dart';

class SalesOrderRepositoryImpl implements SalesOrderRepository {
  final SalesOrderRemoteDataSource remoteDataSource;

  SalesOrderRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<List<SalesOrderEntity>> getSalesOrders({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo,
    required int pageSize,
  }) async {
    try {
      logger.d('Repository: Calling remoteDataSource.getSalesOrders');
      final remoteOrders = await remoteDataSource.getSalesOrders(
          orderNumberQuery: orderNumberQuery, statusFilter: statusFilter,
          pageNo: pageNo,
          pageSize: pageSize);
      logger.d(
          'Repository: Received ${remoteOrders.length} orders from remoteDataSource');
      return remoteOrders;
    } on DioException catch (e, s) { // Catch DioException and its stackTrace
      logger.e('Repository: DioException during getSalesOrders', error: e, stackTrace: s);
      rethrow;
    } on Exception catch (e, s) { // Catch generic Exception and its stackTrace
      logger.e('Repository: Generic Exception during getSalesOrders', error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<SalesOrderEntity> getSalesOrderDetail(int orderId) async {
    try {
      logger.d(
          'Repository: Calling remoteDataSource.getSalesOrderDetail for ID $orderId');
      final remoteOrder =
      await remoteDataSource.getSalesOrderDetail(orderId);
      logger.d(
          'Repository: Received order detail for ${remoteOrder.no} from remoteDataSource');
      return remoteOrder;
    } on DioException catch (e, s) {
      logger.e('Repository: DioException during getSalesOrderDetail', error: e, stackTrace: s);
      rethrow;
    } on Exception catch (e, s) {
      logger.e('Repository: Generic Exception during getSalesOrderDetail', error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<void> updateSalesOrderStatus(
      int orderId, int newStatus) async {
    try {
      logger.d(
          'Repository: Calling remoteDataSource.updateSalesOrderStatus for ID $orderId to $newStatus');
      await remoteDataSource.updateSalesOrderStatus(
          orderId, newStatus);
      logger.d(
          'Repository: Successfully called updateSalesOrderStatus for ID $orderId');
    } on DioException catch (e, s) {
      logger.e('Repository: DioException during updateSalesOrderStatus', error: e, stackTrace: s);
      rethrow;
    } on Exception catch (e, s) {
      logger.e('Repository: Generic Exception during updateSalesOrderStatus', error: e, stackTrace: s);
      rethrow;
    }
  }
}