// lib/features/sales_order/domain/usecases/get_sales_orders_usecase.dart
import '../entities/sales_order_entity.dart';
import '../repositories/sales_order_repository.dart';
// Assuming you have a base UseCase or will define one
// For now, let's assume a simple structure

class GetSalesOrdersUseCase {
  final SalesOrderRepository repository;

  GetSalesOrdersUseCase(this.repository);

  Future<List<SalesOrderEntity>> call({
    String? orderNumberQuery,
    String? statusFilter,
  }) async {
    // In a more complex scenario, you might add more business logic here
    return repository.getSalesOrders(
      orderNumberQuery: orderNumberQuery,
      statusFilter: statusFilter,
    );
  }
}



