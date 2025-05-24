// lib/features/sales_order/domain/usecases/get_production_usecase.dart
import '../../data/models/paginated_orders_result.dart';
import '../repositories/purchase_order_repository.dart';

class GetPurchaseOrdersUseCase {
  final PurchaseOrderRepository repository;

  GetPurchaseOrdersUseCase(this.repository);

  Future<PaginatedOrdersResult> call({
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



