// lib/features/sales_order/domain/entities/production_entity.dart
import 'package:equatable/equatable.dart';

class ProductionEntity extends Equatable {
  final int id;
  final String no;
  final int saleOrderId;
  final int status;
  final DateTime createTime;
  final String? orderKeeperName;
  final String? creatorName;

  const ProductionEntity({
    required this.id,
    required this.no,
    required this.saleOrderId,
    required this.status,
    required this.createTime,
    this.orderKeeperName,
    this.creatorName,
  });

  @override
  List<Object?> get props => [
    id,
    no,
    saleOrderId,
    status,
    createTime,
    orderKeeperName,
    creatorName,
  ];

  String get statusString {
    switch (status) {
      case 10:
        return "待排产"; // UNPAID
      case 20:
        return "已排产"; // PENDING_PRODUCTION
      default:
        return '未知状态 ($status)';
    }
  }
}