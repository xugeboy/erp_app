import 'dart:io';

import 'dart:typed_data';
import 'package:erp_app/features/purchase_order/data/models/purchase_order_model.dart';
import '../../data/models/paginated_result.dart';
import '../entities/production_entity.dart';

abstract class ProductionRepository {
  Future<PaginatedResult> getProductions({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo,
    required int pageSize,
  });

  Future<ProductionEntity> getProductionDetail(int orderId);

  Future<void> updateProductionStatus(int orderId, int newStatus);

  // 新增：上传出货图方法
  Future<bool> uploadShipmentImage({ // 返回图片URL或相关ID
    required int productionOrderId,
    required List<File> imageFiles,
  });

  Future<List<Uint8List>> getShipmentImagesZip( int saleOrderId);

  Future<List<PurchaseOrderModel>> relatedPurchaseOrders({required String productionNo});
}