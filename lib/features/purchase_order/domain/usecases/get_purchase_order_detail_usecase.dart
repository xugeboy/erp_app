// lib/features/purchase_order/domain/usecases/get_purchase_order_detail_usecase.dart

import '../entities/purchase_order_entity.dart';
import '../repositories/purchase_order_repository.dart';

class GetPurchaseOrderDetailUseCase {
  final PurchaseOrderRepository repository;

  GetPurchaseOrderDetailUseCase(this.repository);

  Future<PurchaseOrderEntity> call(int orderId) async {
    return repository.getPurchaseOrderDetail(orderId);
  }
}