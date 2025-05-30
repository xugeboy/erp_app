// lib/features/production_order/domain/usecases/get_shipment_images_usecase.dart
import '../repositories/production_repository.dart';
import 'dart:nativewrappers/_internal/vm/lib/typed_data_patch.dart';

class GetShipmentImagesUseCase {
  final ProductionRepository repository;

  GetShipmentImagesUseCase(this.repository);

  Future<List<Uint8List>> call(int saleOrderId) async {
    return repository.getShipmentImagesZip(saleOrderId);
  }
}