// lib/features/sales_order/presentation/providers/production_providers.dart
import 'package:dio/dio.dart';
import 'package:erp_app/features/sales_order/providers/sales_order_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/datasources/sales_order_remote_data_source.dart';
import '../data/datasources/sales_order_remote_data_source_impl.dart';
import '../data/repositories/sales_order_repository_impl.dart';
import '../domain/repositories/sales_order_repository.dart';
import '../domain/usecases/get_sales_orders_usecase.dart';
import '../domain/usecases/get_sales_order_detail_usecase.dart';
import '../domain/usecases/update_sales_order_status_usecase.dart';
import '../presentation/notifiers/sales_order_notifier.dart';

// --- Data Layer Providers ---

// Provider for Dio instance (if you don't have a global one already)
// If you have a global Dio provider, use that instead.

final salesOrderRemoteDataSourceProvider = Provider<SalesOrderRemoteDataSource>(
      (ref) => SalesOrderRemoteDataSourceImpl(ref.read(dioProvider)),
);

final salesOrderRepositoryProvider = Provider<SalesOrderRepository>((ref) {
  return SalesOrderRepositoryImpl(
    remoteDataSource: ref.read(salesOrderRemoteDataSourceProvider),
    // networkInfo: ref.watch(networkInfoProvider), // Removed as per your setup
  );
});

// --- Domain Layer (Use Case) Providers ---
final getSalesOrdersUseCaseProvider = Provider<GetSalesOrdersUseCase>((ref) {
  return GetSalesOrdersUseCase(ref.read(salesOrderRepositoryProvider));
});

final getSalesOrderDetailUseCaseProvider =
Provider<GetSalesOrderDetailUseCase>((ref) {
  return GetSalesOrderDetailUseCase(ref.read(salesOrderRepositoryProvider));
});

final updateSalesOrderStatusUseCaseProvider =
Provider<UpdateSalesOrderStatusUseCase>((ref) {
  return UpdateSalesOrderStatusUseCase(
      ref.read(salesOrderRepositoryProvider));
});

// --- Presentation Layer (Notifier) Provider ---
final salesOrderNotifierProvider =
StateNotifierProvider<SalesOrderNotifier, SalesOrderState>((ref) {
  return SalesOrderNotifier(
    getSalesOrdersUseCase: ref.read(getSalesOrdersUseCaseProvider),
    getSalesOrderDetailUseCase: ref.read(getSalesOrderDetailUseCaseProvider),
    updateSalesOrderStatusUseCase:
    ref.read(updateSalesOrderStatusUseCaseProvider),
  );
});