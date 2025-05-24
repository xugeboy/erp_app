// lib/features/purchase_order/data/models/production_model.dart
import '../../../../core/utils/logger.dart';
import '../../domain/entities/production_entity.dart';

class ProductionModel extends ProductionEntity {
  const ProductionModel({
    required super.id,
    required super.no,
    required super.saleOrderId,
    required super.status,
    required super.createTime,
    super.orderKeeperName,
    super.creatorName,
  });

  factory ProductionModel.fromJson(Map<String, dynamic> json) {
    // Safe parsing to int, return null if not parsable
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Safe parsing to DateTime, return null if not parsable
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        if (value is int) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        } else if (value is String) {
          final intValue = int.tryParse(value);
          if (intValue != null) {
            return DateTime.fromMillisecondsSinceEpoch(intValue);
          }
        }
      } catch (e) {
        logger.e("DateTime parse error", error: e);
      }
      return null;
    }

    return ProductionModel(
      id: parseInt(json['id'])?? 0,
      no: json['no'] as String? ?? '',
      status: parseInt(json['status'])?? 0,
      saleOrderId: parseInt(json['saleOrderId'])?? 0,
      orderKeeperName: json['orderKeeperName'] as String?,
      createTime: parseDateTime(json['createTime'] )?? DateTime(2024),
      creatorName: json['creatorName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    // When sending data TO the backend, keys should match what the backend expects.
    return {
      'id': id,
      'no': no,
      'saleOrderId':saleOrderId,
      'status': status,
      'orderKeeperName': orderKeeperName,
      'createTime': createTime,
      'creatorName': creatorName,
    };
  }
}