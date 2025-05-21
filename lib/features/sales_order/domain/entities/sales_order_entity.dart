// lib/features/sales_order/domain/entities/sales_order_entity.dart
import 'package:equatable/equatable.dart';

class SalesOrderEntity extends Equatable {
  final int? id; // private Long id;
  final String? no; // private String no; (销售单编号)
  final int status; // private Integer status; (销售状态)
  final int? orderType; // private Integer orderType; (销售订单类型)
  final double? shippingFee; // private BigDecimal shippingFee; (销售订单运费)
  final String? customerName; // private String customerName; (客户名称) - nullable based on example
  final DateTime orderTime; // private LocalDateTime orderTime; (下单时间)
  final DateTime leadTime; // private LocalDateTime leadTime; (交货时间)
  final double? totalPrice; // private BigDecimal totalPrice; (最终合计价格)
  final double? depositPrice; // private BigDecimal depositPrice; (定金金额)
  final String? remark; // private String remark; (备注) - nullable based on example
  final String? creatorName; // private String creatorName; (创建人名称) - nullable
  final int? currency; // private Integer currency; (币种)
  final double? receiptPrice; // private BigDecimal receiptPrice; (收取定金)
  final int? creditPeriod; // private Integer creditPeriod; (账期)

  const SalesOrderEntity({
    this.id,
    this.no,
    required this.status,
    this.orderType,
    this.shippingFee,
    this.customerName,
    required this.orderTime,
    required this.leadTime,
    this.totalPrice,
    this.depositPrice,
    this.remark,
    this.creatorName,
    this.currency,
    this.receiptPrice,
    this.creditPeriod,
  });

  @override
  List<Object?> get props => [
    id,
    no,
    status,
    orderType,
    shippingFee,
    customerName,
    orderTime,
    leadTime,
    totalPrice,
    depositPrice,
    remark,
    creatorName,
    currency,
    receiptPrice,
    creditPeriod
  ];

  String get statusString {
    switch (status) {
      case 0:
        return "待审批"; // WAIT_AUDIT
      case 1:
        return "未收款"; // UNPAID
      case 2:
        return "待生产"; // PENDING_PRODUCTION
      case 3:
        return "待出货"; // NOT_SHIPPED
      case 4:
        return "已出货"; // SHIPPED
      case 5:
        return "已出货待报关"; // SHIPPED_NOT_DECLARED
      case 6:
        return "已报关待开票"; // DECLARED_NOT_INVOICED
      case 7:
        return "已出货待开票"; // SHIPPED_NOT_INVOICED
      case 8:
        return "已开票"; // INVOICED
      case 98:
        return "草稿"; // DRAFT
      case 99:
        return "已驳回"; // AUDIT_REJECT
      default:
        return '未知状态 ($status)';
    }
  }

  String get orderTypeString {
    switch (orderType) {
      case 10: return "库存单";       // STOCK_ORDER
      case 11: return "含税运13%";    // HSY_ORDER
      case 12: return "不含税运";     // BHSY_ORDER
      case 13: return "含税不含运13%"; // HSBHY_ORDER
      case 14: return "含运不含税";   // HYBHS_ORDER
      case 15: return "赊销";         // CREDIT_ORDER (Note: also appears as 24)
      case 20: return "一达通订单";   // YIDATONG_ORDER
      case 21: return "翔乐基本户订单"; // XIANGLE_BASIC_ACCOUNT_ORDER
      case 22: return "便捷发货";     // CONVENIENT_SHIPPING
      case 23: return "XT订单";       // XT_ORDER
      case 24: return "赊销";         // EX_CREDIT_ORDER (Note: same as 15)
      default: return '未知类型 ($orderType)';
    }
  }
  String get currencyString {
    switch (currency) {
      case 0:
        return "人民币"; // CNY
      case 1:
        return "美元"; // USD
      default:
        return '未知币种 ($currency)';
    }
  }

  /// Helper to get the currency symbol.
  String get currencySymbol {
    switch (currency) {
      case 0:
        return "¥"; // CNY
      case 1:
        return "\$"; // USD
      default:
        return ""; // No symbol for unknown
    }
  }
}