// lib/features/sales_order/domain/usecases/get_production_detail_usecase.dart

import '../entities/sales_order_entity.dart';
import '../repositories/sales_order_repository.dart';

class GetSalesOrderDetailUseCase {
  final SalesOrderRepository repository;

  GetSalesOrderDetailUseCase(this.repository);

  Future<SalesOrderEntity> call(int orderId) async {
    return repository.getSalesOrderDetail(orderId);
  }
}