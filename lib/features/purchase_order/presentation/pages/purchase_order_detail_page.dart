// lib/features/purchase_order/presentation/pages/production_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/purchase_order_entity.dart';
import '../../../../core/utils/logger.dart';
import '../../providers/purchase_order_providers.dart';
import '../../providers/purchase_order_state.dart';
import 'purchase_order_approval_page.dart'; // For navigation

class PurchaseOrderDetailPage extends ConsumerStatefulWidget {
  final int orderId;

  const PurchaseOrderDetailPage({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<PurchaseOrderDetailPage> createState() =>
      _PurchaseOrderDetailPageState();
}

class _PurchaseOrderDetailPageState extends ConsumerState<PurchaseOrderDetailPage> {
  @override
  void initState() {
    super.initState();
    // Fetch order details when the page loads
    // and reset any previous approval messages.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logger.d("PurchaseOrderDetailPage: Fetching details for order ID ${widget.orderId}");
      ref
          .read(purchaseOrderNotifierProvider.notifier)
          .fetchOrderDetail(widget.orderId);
      ref.read(purchaseOrderNotifierProvider.notifier).resetApprovalStatus();
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
    final tempEntity = PurchaseOrderEntity(
        id: 0, no: '', status: statusCode, orderType: 0,
        orderTime: DateTime.now(), leadTime: DateTime.now(), totalPrice: 0, settlement: 1);
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
    final purchaseOrderState = ref.watch(purchaseOrderNotifierProvider);
    final notifier = ref.read(purchaseOrderNotifierProvider.notifier);
    final PurchaseOrderEntity? order = purchaseOrderState.selectedOrder;
    final theme = Theme.of(context);

    final String locale = Localizations.localeOf(context).toString();
    final DateFormat dateFormatter = DateFormat('yyyy/MM/dd');


    Widget content;

    if (purchaseOrderState.detailState == ScreenState.loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (purchaseOrderState.detailState == ScreenState.error || order == null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                  purchaseOrderState.detailErrorMessage.isNotEmpty
                      ? '加载失败: ${purchaseOrderState.detailErrorMessage}'
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
          locale: locale, symbol: "¥");

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
                _buildDetailRow(context, '供应商:', order.supplierName, icon: Icons.person_outline),
                _buildDetailRow(context, '创建人:', order.creatorName, icon: Icons.account_circle_outlined),
                _buildDetailRow(context, '订单状态:', order.statusString,
                    isStatus: true, statusColor: _getStatusColor(context, order.status), icon: Icons.flag_outlined),
                _buildDetailRow(context, '订单类型:', order.orderTypeString, icon: Icons.category_outlined),
                _buildDetailRow(context, '结算方式:', order.settlementString, icon: Icons.attach_money),
                const SizedBox(height: 10),
                Text("价格信息", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(height: 20, thickness: 1),
                _buildDetailRow(context, '总金额:', currencyFormatter.format(order.totalPrice)),
                const SizedBox(height: 10),
                Text("时间与条款", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(height: 20, thickness: 1),
                _buildDetailRow(context, '下单时间:', dateFormatter.format(order.orderTime), icon: Icons.calendar_today_outlined),
                _buildDetailRow(context, '交货时间:', dateFormatter.format(order.leadTime), icon: Icons.schedule_outlined),
                Text("其他信息", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(height: 20, thickness: 1),
                _buildDetailRow(context, '备注:', order.remark, icon: Icons.notes_outlined),
                const SizedBox(height: 30),
                if (order.statusString == "待初审"|| order.statusString == "待终审") // Check against the display string from your entity
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
                            builder: (_) => PurchaseOrderApprovalPage(orderId: order.id),
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