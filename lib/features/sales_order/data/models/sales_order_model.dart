// lib/features/sales_order/data/models/sales_order_model.dart
import '../../domain/entities/sales_order_entity.dart';

class SalesOrderModel extends SalesOrderEntity {
  const SalesOrderModel({
    super.id,
    super.no,
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
    // Helper function to safely parse numbers to double, returning 0.0 if null or not a number
    double parseDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0; // Default or throw error
    }

    // Helper function to safely parse numbers to int, returning 0 if null or not a number
    int parseInt(dynamic value) {
      if (value is num) {
        return value.toInt();
      } else if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0; // Default or throw error
    }

    // Helper function to safely parse string to DateTime
    DateTime parseDateTime(dynamic value) {
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          throw FormatException('Invalid DateTime format: $value');
        }
      }
      throw FormatException('Expected String for DateTime, got ${value.runtimeType}');
    }

    return SalesOrderModel(
      id: parseInt(json['id']),
      no: json['no'] as String? ?? '', // Provide default if it can be null but entity requires non-null
      status: parseInt(json['status']),
      orderType: parseInt(json['orderType'] ?? json['order_type']), // Example: trying both camelCase and snake_case
      shippingFee: parseDouble(json['shippingFee'] ?? json['shipping_fee']),
      customerName: json['customerName'] ?? json['customer_name'] as String?,
      orderTime: parseDateTime(json['orderTime'] ?? json['order_time']),
      leadTime: parseDateTime(json['leadTime'] ?? json['lead_time']),
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
      'orderTime': orderTime.toIso8601String(), // Common format for sending DateTime
      'leadTime': leadTime.toIso8601String(),
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