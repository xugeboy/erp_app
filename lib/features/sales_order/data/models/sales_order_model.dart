// lib/features/sales_order/data/models/sales_order_model.dart
import '../../../../core/utils/logger.dart';
import '../../domain/entities/sales_order_entity.dart';

class SalesOrderModel extends SalesOrderEntity {
  const SalesOrderModel({
    required super.id,
    required super.no,
    required super.status,
    super.orderType,
    super.shippingFee,
    super.customerName,
    required super.orderTime,
    required super.leadTime,
    super.totalPrice,
    super.depositPrice,
    super.remark,
    super.creatorName,
    super.currency,
    super.receiptPrice,
    super.creditPeriod,
  });

  factory SalesOrderModel.fromJson(Map<String, dynamic> json) {
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

    return SalesOrderModel(
      id: parseInt(json['id'])?? 0,
      no: json['no'] as String? ?? '',
      status: parseInt(json['status'])?? 0,
      orderType: parseInt(json['orderType'] ?? json['order_type']),
      shippingFee: parseDouble(json['shippingFee'] ?? json['shipping_fee']),
      customerName: json['customerName'] ?? json['customer_name'] as String?,
      orderTime: parseDateTime(json['orderTime'] ?? json['order_time'])?? DateTime(2024),
      leadTime: parseDateTime(json['leadTime'] ?? json['lead_time'])?? DateTime(2024),
      totalPrice: parseDouble(json['totalPrice'] ?? json['total_price']),
      depositPrice: parseDouble(json['depositPrice'] ?? json['deposit_price']),
      remark: json['remark'] as String?,
      creatorName: json['creatorName'] ?? json['creator_name'] as String?,
      currency: parseInt(json['currency']),
      receiptPrice: parseDouble(json['receiptPrice'] ?? json['receipt_price']),
      creditPeriod: parseInt(json['creditPeriod'] ?? json['credit_period']),
    );
  }

  Map<String, dynamic> toJson() {
    // When sending data TO the backend, keys should match what the backend expects.
    return {
      'id': id,
      'no': no,
      'status': status,
      'orderType': orderType, // Or 'order_type' if backend expects snake_case
      'shippingFee': shippingFee,
      'customerName': customerName,
      'orderTime': orderTime, // Common format for sending DateTime
      'leadTime': leadTime,
      'totalPrice': totalPrice,
      'depositPrice': depositPrice,
      'remark': remark,
      'creatorName': creatorName,
      'currency': currency,
      'receiptPrice': receiptPrice,
      'creditPeriod': creditPeriod,
    };
  }
}