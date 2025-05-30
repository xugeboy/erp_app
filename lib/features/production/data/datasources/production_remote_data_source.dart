// lib/features/purchase_order/data/datasources/production_remote_data_source.dart
import 'dart:io';
import 'dart:nativewrappers/_internal/vm/lib/typed_data_patch.dart';

import 'package:erp_app/features/production/data/models/paginated_result.dart';

import '../models/production_model.dart';

abstract class ProductionRemoteDataSource {
  Future<PaginatedResult> getProductions({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo, // Added
    required int pageSize, // Added
  });

  Future<ProductionModel> getProductionDetail(int orderId);

  Future<void> updateProductionStatus(
      int orderId, int newStatus);

  Future<bool> uploadShipmentImage({required int productionOrderId, required List<File> imageFiles});
  Future<List<Uint8List>> getShipmentImagesZip(int saleOrderId);
  Future getRelatedPurchaseOrders({required String productionNo});
}