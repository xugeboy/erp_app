// lib/features/sales_order/domain/usecases/update_sales_order_status_usecase.dart

import '../repositories/sales_order_repository.dart';

class UpdateSalesOrderStatusUseCase {
  final SalesOrderRepository repository;

  UpdateSalesOrderStatusUseCase(this.repository);

  Future<void> call({
    required String orderId,
    required String newStatus, // This will be the "Approved" or "Rejected" string
    String? remarks,
  }) async {
    // Here you might map the "Approved" / "Rejected" string to an integer code
    // if your repository/API expects an integer status.
    // For now, assuming repository handles the string status or it's already mapped.
    return repository.updateSalesOrderStatus(orderId, newStatus, remarks);
  }
}