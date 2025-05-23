// lib/features/purchase_order/presentation/providers/purchase_order_providers.dart
import 'package:dio/dio.dart';
import 'package:erp_app/features/purchase_order/providers/purchase_order_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/datasources/purchase_order_remote_data_source.dart';
import '../data/datasources/purchase_order_remote_data_source_impl.dart';
import '../data/repositories/purchase_order_repository_impl.dart';
import '../domain/repositories/purchase_order_repository.dart';
import '../domain/usecases/get_purchase_orders_usecase.dart';
import '../domain/usecases/get_purchase_order_detail_usecase.dart';
import '../domain/usecases/update_purchase_order_status_usecase.dart';
import '../presentation/notifiers/purchase_order_notifier.dart';

// --- Data Layer Providers ---

// Provider for Dio instance (if you don't have a global one already)
// If you have a global Dio provider, use that instead.

final purchaseOrderRemoteDataSourceProvider = Provider<PurchaseOrderRemoteDataSource>(
      (ref) => PurchaseOrderRemoteDataSourceImpl(ref.read(dioProvider)),
);

final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>((ref) {
  return PurchaseOrderRepositoryImpl(
    remoteDataSource: ref.read(purchaseOrderRemoteDataSourceProvider),
    // networkInfo: ref.watch(networkInfoProvider), // Removed as per your setup
  );
});

// --- Domain Layer (Use Case) Providers ---
final getPurchaseOrdersUseCaseProvider = Provider<GetPurchaseOrdersUseCase>((ref) {
  return GetPurchaseOrdersUseCase(ref.read(purchaseOrderRepositoryProvider));
});

final getPurchaseOrderDetailUseCaseProvider =
Provider<GetPurchaseOrderDetailUseCase>((ref) {
  return GetPurchaseOrderDetailUseCase(ref.read(purchaseOrderRepositoryProvider));
});

final updatePurchaseOrderStatusUseCaseProvider =
Provider<UpdatePurchaseOrderStatusUseCase>((ref) {
  return UpdatePurchaseOrderStatusUseCase(
      ref.read(purchaseOrderRepositoryProvider));
});

// --- Presentation Layer (Notifier) Provider ---
final purchaseOrderNotifierProvider =
StateNotifierProvider<PurchaseOrderNotifier, PurchaseOrderState>((ref) {
  return PurchaseOrderNotifier(
    getPurchaseOrdersUseCase: ref.read(getPurchaseOrdersUseCaseProvider),
    getPurchaseOrderDetailUseCase: ref.read(getPurchaseOrderDetailUseCaseProvider),
    updatePurchaseOrderStatusUseCase:
    ref.read(updatePurchaseOrderStatusUseCaseProvider),
  );
});