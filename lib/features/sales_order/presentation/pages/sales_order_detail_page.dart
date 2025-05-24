// lib/features/sales_order/presentation/pages/production_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/sales_order_entity.dart';
import '../../../../core/utils/logger.dart';
import '../../providers/sales_order_providers.dart';
import '../../providers/sales_order_state.dart';
import 'sales_order_approval_page.dart'; // For navigation

class SalesOrderDetailPage extends ConsumerStatefulWidget {
  final int orderId;

  const SalesOrderDetailPage({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<SalesOrderDetailPage> createState() =>
      _SalesOrderDetailPageState();
}

class _SalesOrderDetailPageState extends ConsumerState<SalesOrderDetailPage> {
  @override
  void initState() {
    super.initState();
    // Fetch order details when the page loads
    // and reset any previous approval messages.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logger.d("SalesOrderDetailPage: Fetching details for order ID ${widget.orderId}");
      ref
          .read(salesOrderNotifierProvider.notifier)
          .fetchOrderDetail(widget.orderId);
      ref.read(salesOrderNotifierProvider.notifier).resetApprovalStatus();
    });
  }

  Widget _buildDetailRow(BuildContext context, String label, String? value,
      {bool isStatus = false, Color? statusColor, IconData? icon}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7)),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: isStatus && statusColor != null
                ? Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(value ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: statusColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
                : Text(
              value ?? '',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context, int statusCode) {
    // Create a dummy entity just to use the statusString getter logic
    final tempEntity = SalesOrderEntity(
        id: 0, no: '', status: statusCode, orderType: 0, shippingFee: 0,
        orderTime: DateTime.now(), leadTime: DateTime.now(), totalPrice: 0,
        depositPrice: 0, currency: 0, receiptPrice: 0, creditPeriod: 0);
    String statusDisplay = tempEntity.statusString;

    if (statusDisplay.contains("待审批") || statusDisplay.contains("待生产") || statusDisplay.contains("待出货") || statusDisplay.contains("草稿")) {
      return Colors.orange.shade700;
    } else if (statusDisplay.contains("已开票") || statusDisplay.contains("已出货") || statusDisplay.contains("已报关")) {
      return Colors.green.shade700;
    } else if (statusDisplay.contains("已驳回") || statusDisplay.contains("未收款")) {
      return Colors.red.shade700;
    }
    return Colors.grey.shade600;
  }


  @override
  Widget build(BuildContext context) {
    final salesOrderState = ref.watch(salesOrderNotifierProvider);
    final notifier = ref.read(salesOrderNotifierProvider.notifier);
    final SalesOrderEntity? order = salesOrderState.selectedOrder;
    final theme = Theme.of(context);

    final String locale = Localizations.localeOf(context).toString();
    final DateFormat dateFormatter = DateFormat('yyyy/MM/dd');


    Widget content;

    if (salesOrderState.detailState == ScreenState.loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (salesOrderState.detailState == ScreenState.error || order == null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                  salesOrderState.detailErrorMessage.isNotEmpty
                      ? '加载失败: ${salesOrderState.detailErrorMessage}'
                      : '未找到订单详情。',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                onPressed: () {
                  notifier.fetchOrderDetail(widget.orderId);
                },
              )
            ],
          ),
        ),
      );
    } else {
      // Order details are loaded
      final NumberFormat currencyFormatter = NumberFormat.currency(
          locale: locale, symbol: order.currencySymbol);

      content = SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    '订单详情',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),
                _buildDetailRow(context, '订单单号:', order.no, icon: Icons.receipt_long),
                _buildDetailRow(context, '客户名称:', order.customerName, icon: Icons.person_outline),
                _buildDetailRow(context, '创建人:', order.creatorName, icon: Icons.account_circle_outlined),
                _buildDetailRow(context, '订单状态:', order.statusString,
                    isStatus: true, statusColor: _getStatusColor(context, order.status), icon: Icons.flag_outlined),
                _buildDetailRow(context, '订单类型:', order.orderTypeString, icon: Icons.category_outlined),
                _buildDetailRow(context, '币种:', order.currencyString, icon: Icons.attach_money),
                const SizedBox(height: 10),
                Text("价格信息", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(height: 20, thickness: 1),
                _buildDetailRow(context, '总金额:', currencyFormatter.format(order.totalPrice)),
                _buildDetailRow(context, '定金金额:', currencyFormatter.format(order.depositPrice)),
                _buildDetailRow(context, '已收定金:', currencyFormatter.format(order.receiptPrice)),
                _buildDetailRow(context, '运费:', currencyFormatter.format(order.shippingFee)),
                const SizedBox(height: 10),
                Text("时间与条款", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(height: 20, thickness: 1),
                _buildDetailRow(context, '下单时间:', dateFormatter.format(order.orderTime), icon: Icons.calendar_today_outlined),
                _buildDetailRow(context, '交货时间:', dateFormatter.format(order.leadTime), icon: Icons.schedule_outlined),
                if (order.orderTypeString == "赊销") // "赊销" 是您在 SalesOrderEntity 中定义的 orderTypeString
                  _buildDetailRow(context, '账期 (天):', order.creditPeriod.toString(), icon: Icons.timer_outlined),                const SizedBox(height: 10),
                Text("其他信息", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(height: 20, thickness: 1),
                _buildDetailRow(context, '备注:', order.remark, icon: Icons.notes_outlined),
                const SizedBox(height: 30),
                if (order.statusString == "待审批") // Check against the display string from your entity
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.approval_outlined),
                      label: const Text('进入审批'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      onPressed: () {
                        logger.d("Navigating to approval page for order ID: ${order.id}");
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SalesOrderApprovalPage(orderId: order.id),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(order != null ? '订单: ${order.no}' : '订单详情'),
      ),
      body: content,
    );
  }
}