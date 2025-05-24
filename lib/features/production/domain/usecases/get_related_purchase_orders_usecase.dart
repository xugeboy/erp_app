// lib/features/production_order/domain/usecases/get_related_purchase_orders_usecase.dart

import 'package:erp_app/features/purchase_order/data/models/purchase_order_model.dart';
import '../repositories/production_repository.dart'; // 假设您的生产单仓库接口定义在这里

class GetRelatedPurchaseOrdersUseCase {
  final ProductionRepository repository;

  GetRelatedPurchaseOrdersUseCase(this.repository);

  Future<List<PurchaseOrderModel>> call({
    required String productionNo,
  }) async {
    return repository.relatedPurchaseOrders(
      productionNo: productionNo,
    );
  }
}