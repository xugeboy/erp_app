// lib/features/sales_order/domain/entities/purchase_order_entity.dart
import 'package:equatable/equatable.dart';

class PurchaseOrderEntity extends Equatable {
  final int id; // private Long id;
  final String no; // private String no; (编号)
  final int status; // private Integer status; (状态)
  final int? orderType; // private Integer orderType; (订单类型)
  final String? supplierName; // private String customerName; (客户名称) - nullable based on example
  final DateTime orderTime; // private LocalDateTime orderTime; (下单时间)
  final DateTime leadTime; // private LocalDateTime leadTime; (交货时间)
  final double? totalPrice; // private BigDecimal totalPrice; (最终合计价格)
  final String? remark; // private String remark; (备注) - nullable based on example
  final String? creatorName; // private String creatorName; (创建人名称) - nullable
  final int? settlement; // private Integer settlement; (结算方式)

  const PurchaseOrderEntity({
    required this.id,
    required this.no,
    required this.status,
    this.orderType,
    this.supplierName,
    required this.orderTime,
    required this.leadTime,
    this.totalPrice,
    this.remark,
    this.creatorName,
    this.settlement,
  });

  @override
  List<Object?> get props => [
    id,
    no,
    status,
    orderType,
    supplierName,
    orderTime,
    leadTime,
    totalPrice,
    remark,
    creatorName,
    settlement,
  ];

  String get statusString {
    switch (status) {
      // case 0:
        // return "草稿"; // WAIT_AUDIT
      case 10:
        return "待初审"; // UNPAID
      case 20:
        return "待终审"; // PENDING_PRODUCTION
      case 30:
        return "已审核"; // NOT_SHIPPED
      case 40:
        return "已传"; // SHIPPED
      case 99:
        return "驳回"; // AUDIT_REJECT
      default:
        return '未知状态 ($status)';
    }
  }

  String get orderTypeString {
    switch (orderType) {
      case 0: return "库存单";       // STOCK_ORDER
      case 1: return "非库存单";       // STOCK_ORDER
      default: return '未知类型 ($orderType)';
    }
  }
  String get settlementString {
    switch (settlement) {
      case 1:
        return "开票后30天内付清全款"; // CNY
      case 2:
        return "款到发货"; // USD
      case 3:
        return "预付_____%定金，出货前付清全款"; // CNY
      case 4:
        return "含税运，开专票，发货前付款"; // USD
      default:
        return '未设置结算方式 ($settlement)';
    }
  }
}