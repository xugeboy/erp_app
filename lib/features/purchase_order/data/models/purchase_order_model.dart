// lib/features/purchase_order/data/models/purchase_order_model.dart
import '../../../../core/utils/logger.dart';
import '../../domain/entities/purchase_order_entity.dart';

class PurchaseOrderModel extends PurchaseOrderEntity {
  const PurchaseOrderModel({
    required super.id,
    required super.no,
    required super.status,
    super.orderType,
    super.supplierName,
    required super.orderTime,
    required super.leadTime,
    super.totalPrice,
    super.remark,
    super.creatorName,
    super.settlement
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    // Safe parsing to double, return null if not parsable
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

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

    return PurchaseOrderModel(
      id: parseInt(json['id'])?? 0,
      no: json['no'] as String? ?? '',
      status: parseInt(json['status'])?? 0,
      orderType: parseInt(json['orderType']),
      supplierName: json['supplierName'] as String?,
      orderTime: parseDateTime(json['orderTime'] )?? DateTime(2024),
      leadTime: parseDateTime(json['leadTime'] )?? DateTime(2024),
      totalPrice: parseDouble(json['totalPrice'] ),
      remark: json['remark'] as String?,
      creatorName: json['creatorName'] ?? json['creator_name'] as String?,
      settlement: parseInt(json['settlement']),
    );
  }

  Map<String, dynamic> toJson() {
    // When sending data TO the backend, keys should match what the backend expects.
    return {
      'id': id,
      'no': no,
      'status': status,
      'orderType': orderType, // Or 'order_type' if backend expects snake_case
      'supplierName': supplierName,
      'orderTime': orderTime, // Common format for sending DateTime
      'leadTime': leadTime,
      'totalPrice': totalPrice,
      'remark': remark,
      'creatorName': creatorName,
      'settlement': settlement,
    };
  }
}