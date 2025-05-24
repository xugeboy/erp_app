// lib/features/purchase_order/domain/usecases/update_production_status_usecase.dart

import '../repositories/purchase_order_repository.dart';

class UpdatePurchaseOrderStatusUseCase {
  final PurchaseOrderRepository repository;

  UpdatePurchaseOrderStatusUseCase(this.repository);

  Future<void> call({
    required int orderId,
    required int newStatus
  }) async {
    // Here you might map the "Approved" / "Rejected" string to an integer code
    // if your repository/API expects an integer status.
    // For now, assuming repository handles the string status or it's already mapped.
    return repository.updatePurchaseOrderStatus(orderId, newStatus);
  }
}