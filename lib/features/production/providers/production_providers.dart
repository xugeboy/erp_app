// lib/features/purchase_order/presentation/providers/production_providers.dart
import 'package:dio/dio.dart';
import 'package:erp_app/features/production/domain/usecases/get_shipment_images_usecase.dart';
import 'package:erp_app/features/production/domain/usecases/upload_shipment_image_usecase.dart';
import 'package:erp_app/features/production/providers/production_state.dart';
import 'package:erp_app/features/purchase_order/providers/purchase_order_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/datasources/production_remote_data_source.dart';
import '../data/datasources/production_remote_data_source_impl.dart';
import '../data/repositories/production_repository_impl.dart';
import '../domain/repositories/production_repository.dart';
import '../domain/usecases/get_production_usecase.dart';
import '../domain/usecases/get_related_purchase_orders_usecase.dart';
import '../presentation/notifiers/production_notifier.dart';

// --- Data Layer Providers ---

// Provider for Dio instance (if you don't have a global one already)
// If you have a global Dio provider, use that instead.

final productionRemoteDataSourceProvider = Provider<ProductionRemoteDataSource>(
      (ref) => ProductionRemoteDataSourceImpl(ref.read(dioProvider)),
);

final productionRepositoryProvider = Provider<ProductionRepository>((ref) {
  return ProductionRepositoryImpl(
    remoteDataSource: ref.read(productionRemoteDataSourceProvider),
    // networkInfo: ref.watch(networkInfoProvider), // Removed as per your setup
  );
});

// --- Domain Layer (Use Case) Providers ---
final getProductionsUseCaseProvider = Provider<GetProductionsUseCase>((ref) {
  return GetProductionsUseCase(ref.read(productionRepositoryProvider));
});

final uploadShipmentImageUseCaseProvider =
Provider<UploadShipmentImageUseCase>((ref) {
  return UploadShipmentImageUseCase(
      ref.read(productionRepositoryProvider));
});

final getShipmentImagesUseCaseProvider =
Provider<GetShipmentImagesUseCase>((ref) {
  return GetShipmentImagesUseCase(
      ref.read(productionRepositoryProvider));
});

final getRelatedPurchaseOrdersUseCaseProvider =
Provider<GetRelatedPurchaseOrdersUseCase>((ref) {
  return GetRelatedPurchaseOrdersUseCase(
      ref.read(productionRepositoryProvider));
});

// --- Presentation Layer (Notifier) Provider ---
final productionNotifierProvider =
StateNotifierProvider<ProductionNotifier, ProductionState>((ref) {
  return ProductionNotifier(
    getProductionsUseCase: ref.read(getProductionsUseCaseProvider),
    uploadShipmentImageUseCase :ref.read(uploadShipmentImageUseCaseProvider),
    getShipmentImagesUseCase :ref.read(getShipmentImagesUseCaseProvider),
    getRelatedPurchaseOrdersUseCase :ref.read(getRelatedPurchaseOrdersUseCaseProvider)
  );
});