// lib/features/production_order/domain/usecases/upload_shipment_image_usecase.dart
import 'dart:io';
import '../repositories/production_repository.dart'; // 假设您的生产单仓库接口

class UploadShipmentImageUseCase {
  final ProductionRepository repository;

  UploadShipmentImageUseCase(this.repository);

  Future<String> call({ // 返回图片URL或相关ID
    required int productionOrderId,
    required File imageFile,
  }) async {
    return repository.uploadShipmentImage(
      productionOrderId: productionOrderId,
      imageFile: imageFile,
    );
  }
}