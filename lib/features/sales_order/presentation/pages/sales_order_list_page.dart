// lib/features/sales_order/presentation/pages/production_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/logger.dart';
import '../../domain/entities/sales_order_entity.dart';
import '../../providers/sales_order_providers.dart';
import '../../providers/sales_order_state.dart';
import 'sales_order_detail_page.dart';

class SalesOrderListPage extends ConsumerStatefulWidget {
  const SalesOrderListPage({super.key});

  @override
  ConsumerState<SalesOrderListPage> createState() => _SalesOrderListPageState();
}

class _SalesOrderListPageState extends ConsumerState<SalesOrderListPage> {
  final TextEditingController _searchController = TextEditingController();

  final Map<String, int> _statusDisplayToCodeMap = {
    '待审批': 0,
    '未收款': 1,
    '待生产': 2,
    '待出货': 3,
    '已出货': 4,
    '已出货待报关': 5,
    '已报关待开票': 6,
    '已出货待开票': 7,
    '已开票': 8,
    '已驳回': 99,
  };

  late final List<String> _statusOptions;

  @override
  void initState() {
    super.initState();
    _statusOptions = ['全部', ..._statusDisplayToCodeMap.keys];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialNotifierState = ref.read(salesOrderNotifierProvider);
      final initialStatusCode = ref.read(salesOrderStatusFilterProvider);
      _searchController.text = initialNotifierState.currentOrderNumberQuery;

      logger.d(
        "SalesOrderListPage: Initializing with query: '${_searchController.text}', status code: $initialStatusCode",
      );
      ref
          .read(salesOrderNotifierProvider.notifier)
          .fetchOrders(
            orderNumber:
                _searchController.text.isEmpty ? null : _searchController.text,
            status: initialStatusCode,
            pageNoToFetch: 1,
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(int statusCode) {
    final tempEntity = SalesOrderEntity(
      id: 0,
      no: '',
      status: statusCode,
      orderType: 0,
      shippingFee: 0,
      orderTime: DateTime.now(),
      leadTime: DateTime.now(),
      totalPrice: 0,
      depositPrice: 0,
      currency: 0,
      receiptPrice: 0,
      creditPeriod: 0,
    );
    final String statusDisplay = tempEntity.statusString;

    if (statusDisplay.contains('待审批') ||
        statusDisplay.contains('待生产') ||
        statusDisplay.contains('待出货') ||
        statusDisplay.contains('草稿')) {
      return Colors.orange.shade700;
    } else if (statusDisplay.contains('已开票') ||
        statusDisplay.contains('已出货') ||
        statusDisplay.contains('已报关')) {
      return Colors.green.shade700;
    } else if (statusDisplay.contains('已驳回') || statusDisplay.contains('未收款')) {
      return Colors.red.shade700;
    }
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final salesOrderState = ref.watch(salesOrderNotifierProvider);
    final salesOrderNotifier = ref.read(salesOrderNotifierProvider.notifier);
    final selectedStatusCode = ref.watch(salesOrderStatusFilterProvider);
    final selectedStatusString =
        selectedStatusCode == null
            ? _statusOptions.first
            : _statusDisplayToCodeMap.entries
                .firstWhere(
                  (entry) => entry.value == selectedStatusCode,
                  orElse:
                      () => MapEntry(_statusOptions.first, selectedStatusCode),
                )
                .key;

    return Scaffold(
      appBar: AppBar(
        title: const Text('销售订单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                salesOrderState.listState == ScreenState.loading
                    ? null
                    : () {
                      logger.d(
                        "Refresh button pressed. Query: '${_searchController.text}', Status Code: $selectedStatusCode",
                      );
                      salesOrderNotifier.fetchOrders(
                        orderNumber:
                            _searchController.text.isEmpty
                                ? null
                                : _searchController.text,
                        status: selectedStatusCode,
                        pageNoToFetch: 1,
                      );
                    },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '订单单号筛选',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor:
                          Theme.of(context).inputDecorationTheme.fillColor ??
                          Colors.white,
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        salesOrderNotifier.applyOrderNumberFilter(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).inputDecorationTheme.fillColor ??
                        Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStatusString,
                      hint: const Text('订单状态'),
                      isDense: true,
                      items:
                          _statusOptions.map((value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue == null) return;
                        final int? nextStatusCode =
                            newValue == '全部'
                                ? null
                                : _statusDisplayToCodeMap[newValue];
                        ref
                            .read(salesOrderStatusFilterProvider.notifier)
                            .state = nextStatusCode;
                        logger.d(
                          "Status filter changed to: $newValue (Code: $nextStatusCode)",
                        );
                        salesOrderNotifier.applyStatusFilter(nextStatusCode);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: () {
              if (salesOrderState.listState == ScreenState.loading &&
                  salesOrderState.orders.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (salesOrderState.listState == ScreenState.error &&
                  salesOrderState.orders.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '加载失败: ${salesOrderState.listErrorMessage}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                          onPressed: () {
                            salesOrderNotifier.fetchOrders(
                              orderNumber:
                                  _searchController.text.isEmpty
                                      ? null
                                      : _searchController.text,
                              status: selectedStatusCode,
                              pageNoToFetch: 1,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (salesOrderState.orders.isEmpty &&
                  salesOrderState.listState != ScreenState.loading) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '没有找到相关订单。',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 0),
                itemCount: salesOrderState.orders.length,
                itemBuilder: (context, index) {
                  final order = salesOrderState.orders[index];
                  final itemCurrencyFormatter = NumberFormat.currency(
                    locale: Localizations.localeOf(context).toString(),
                    symbol: order.currencySymbol,
                  );

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10.0,
                        horizontal: 16.0,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(order.status),
                        radius: 40,
                        child: Text(
                          order.statusString,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        '订单号: ${order.no}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('客户: ${order.customerName ?? 'N/A'}'),
                            Text('创建人: ${order.creatorName ?? 'N/A'}'),
                            Text(
                              '金额: ${itemCurrencyFormatter.format(order.totalPrice)}',
                            ),
                            Text('类型: ${order.orderTypeString}'),
                            Text(
                              '下单时间: ${DateFormat('yyyy/MM/dd HH:mm').format(order.orderTime)}',
                            ),
                          ],
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        logger.d(
                          "Tapped on order: ${order.no}, ID: ${order.id}",
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => SalesOrderDetailPage(orderId: order.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }(),
          ),
          if (salesOrderState.listState == ScreenState.loaded ||
              salesOrderState.orders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    label: const Text('上一页'),
                    onPressed:
                        (salesOrderState.currentPageNo <= 1 ||
                                salesOrderState.listState ==
                                    ScreenState.loading)
                            ? null
                            : () {
                              salesOrderNotifier.goToPreviousPage();
                            },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('第 ${salesOrderState.currentPageNo} 页'),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward_ios),
                    label: const Text('下一页'),
                    onPressed:
                        (!salesOrderState.canLoadMore ||
                                salesOrderState.listState ==
                                    ScreenState.loading)
                            ? null
                            : () {
                              salesOrderNotifier.goToNextPage();
                            },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
