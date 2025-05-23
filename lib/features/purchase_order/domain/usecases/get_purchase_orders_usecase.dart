// lib/features/sales_order/domain/usecases/get_purchase_orders_usecase.dart
import '../entities/purchase_order_entity.dart';
import '../repositories/purchase_order_repository.dart';
// Assuming you have a base UseCase or will define one
// For now, let's assume a simple structure

class GetPurchaseOrdersUseCase {
  final PurchaseOrderRepository repository;

  GetPurchaseOrdersUseCase(this.repository);

  Future<List<PurchaseOrderEntity>> call({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo,
    required int pageSize,
  }) async {
    // In a more complex scenario, you might add more business logic here
    return repository.getPurchaseOrders(
      orderNumberQuery: orderNumberQuery,
      statusFilter: statusFilter,
      pageNo: pageNo,
      pageSize: pageSize,
    );
  }
}



