// lib/features/purchase_order/domain/usecases/update_production_status_usecase.dart

import '../repositories/production_repository.dart';

class UpdateProductionStatusUseCase {
  final ProductionRepository repository;

  UpdateProductionStatusUseCase(this.repository);

  Future<void> call({
    required int orderId,
    required int newStatus
  }) async {
    return repository.updateProductionStatus(orderId, newStatus);
  }
}