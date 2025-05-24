// lib/features/sales_order/domain/usecases/get_production_usecase.dart
import '../../data/models/paginated_result.dart';
import '../repositories/production_repository.dart';

class GetProductionsUseCase {
  final ProductionRepository repository;

  GetProductionsUseCase(this.repository);

  Future<PaginatedResult> call({
    String? orderNumberQuery,
    int? statusFilter,
    required int pageNo,
    required int pageSize,
  }) async {
    // In a more complex scenario, you might add more business logic here
    return repository.getProductions(
      orderNumberQuery: orderNumberQuery,
      statusFilter: statusFilter,
      pageNo: pageNo,
      pageSize: pageSize,
    );
  }
}



