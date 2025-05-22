// lib/features/sales_order/presentation/pages/sales_order_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:intl/intl.dart'; // For formatting currency and dates

import '../../domain/entities/sales_order_entity.dart'; // Your SalesOrderEntity
import '../../providers/sales_order_providers.dart';
import '../../providers/sales_order_state.dart';
import '../../../../core/utils/logger.dart'; // Your logger
import 'sales_order_detail_page.dart'; // For navigation to the detail page

class SalesOrderListPage extends ConsumerStatefulWidget {
  const SalesOrderListPage({super.key});

  @override
  ConsumerState<SalesOrderListPage> createState() => _SalesOrderListPageState();
}

class _SalesOrderListPageState extends ConsumerState<SalesOrderListPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusString; // UI display string for status filter
  int? _selectedStatusCode;   // Actual status code for filtering

  // This map helps convert the display string from the dropdown back to an integer code
  final Map<String, int> _statusDisplayToCodeMap = {
    "待审批": 0, "未收款": 1, "待生产": 2, "待出货": 3, "已出货": 4,
    "已出货待报关": 5, "已报关待开票": 6, "已出货待开票": 7, "已开票": 8,
    "草稿": 98, "已驳回": 99,
  };
  late List<String> _statusOptions; // Options for the status dropdown

  // For formatting currency. Initialized in didChangeDependencies.
  late NumberFormat _currencyFormatter;

  @override
  void initState() {
    super.initState();
    _statusOptions = ["全部", ..._statusDisplayToCodeMap.keys]; // "全部" means no status filter

    // Fetch initial data using Riverpod
    // We use addPostFrameCallback to ensure `ref` is accessible and providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get current filter values from notifier state (if persisted or set by default)
      final initialNotifierState = ref.read(salesOrderNotifierProvider);
      _searchController.text = initialNotifierState.currentOrderNumberQuery;
      _selectedStatusCode = initialNotifierState.currentStatusFilterCode;

      if (_selectedStatusCode != null) {
        _selectedStatusString = _statusDisplayToCodeMap.entries
            .firstWhere((entry) => entry.value == _selectedStatusCode, orElse: () => const MapEntry("全部",0))
            .key;
        // If the found key is "全部" but there was a code, it means the code wasn't in our map,
        // so we default to "全部" display and null code.
        if (_selectedStatusString == "全部" && _selectedStatusCode != _statusDisplayToCodeMap["全部"]) {
          //This case should ideally not happen if map is complete and status codes are consistent
        }
      } else {
        _selectedStatusString = "全部";
      }
      setState(() {}); // Update UI with initial filter values if they were loaded from state

      logger.d(
          "SalesOrderListPage: Initializing with query: '${_searchController.text}', status code: $_selectedStatusCode");
      ref.read(salesOrderNotifierProvider.notifier).fetchOrders(
        orderNumber: _searchController.text.isEmpty ? null : _searchController.text,
        status: _selectedStatusCode,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize currency formatter that depends on Localizations
    // It's safer to do this here than in initState.
    final String locale = Localizations.localeOf(context).toString();
    // Defaulting to CNY symbol. This will be overridden by order.currencySymbol if available.
    _currencyFormatter = NumberFormat.currency(locale: locale, symbol: "¥");
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper to get status color for UI elements
  Color _getStatusColor(int statusCode) {
    // Create a dummy entity just to use the statusString getter
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
    // Watch the state from Riverpod. This will cause the widget to rebuild when the state changes.
    final salesOrderState = ref.watch(salesOrderNotifierProvider);
    // Get the notifier to call methods (actions).
    final salesOrderNotifier = ref.read(salesOrderNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('销售订单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            // Disable button if already loading to prevent multiple requests
            onPressed: salesOrderState.listState == ScreenState.loading
                ? null
                : () {
              logger.d(
                  "Refresh button pressed. Query: '${_searchController.text}', Status Code: $_selectedStatusCode");
              salesOrderNotifier.fetchOrders(
                orderNumber: _searchController.text.isEmpty ? null : _searchController.text,
                status: _selectedStatusCode,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Filter UI Section ---
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
                      fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white,
                    ),
                    // Call notifier method when text is submitted (e.g., user presses enter)
                    onSubmitted: (value) {
                      logger.d("Search submitted with query: '$value'");
                      salesOrderNotifier.applyOrderNumberFilter(value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3))
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatusString,
                      hint: const Text("订单状态"),
                      isDense: true,
                      items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue == null) return;
                        setState(() {
                          _selectedStatusString = newValue;
                          _selectedStatusCode = (newValue == "全部")
                              ? null
                              : _statusDisplayToCodeMap[newValue];
                        });
                        logger.d(
                            "Status filter changed to: $_selectedStatusString (Code: $_selectedStatusCode)");
                        salesOrderNotifier.applyStatusFilter(_selectedStatusCode);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- Orders List Section ---
          Expanded(
            child: () { // Using an IIFE for cleaner conditional rendering based on state
              if (salesOrderState.listState == ScreenState.loading && salesOrderState.orders.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (salesOrderState.listState == ScreenState.error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('加载失败: ${salesOrderState.listErrorMessage}',
                            textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                          onPressed: () {
                            salesOrderNotifier.fetchOrders(
                              orderNumber: _searchController.text.isEmpty ? null : _searchController.text,
                              status: _selectedStatusCode,
                            );
                          },
                        )
                      ],
                    ),
                  ),
                );
              }
              if (salesOrderState.orders.isEmpty) {
                return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('没有找到相关订单。', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ));
              }
              // Display the list of orders
              return RefreshIndicator(
                onRefresh: () async {
                  await salesOrderNotifier.fetchOrders(
                    orderNumber: _searchController.text.isEmpty ? null : _searchController.text,
                    status: _selectedStatusCode,
                  );
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 16.0),
                  itemCount: salesOrderState.orders.length,
                  itemBuilder: (context, index) {
                    final order = salesOrderState.orders[index];
                    // Use the currency symbol from the order entity
                    final itemCurrencyFormatter = NumberFormat.currency(
                        locale: Localizations.localeOf(context).toString(), // Or a fixed locale
                        symbol: order.currencySymbol);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(order.status),
                          child: Text(
                            order.statusString.isNotEmpty ? order.statusString.substring(0, 1) : "?",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          '订单号: ${order.no}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('客户: ${order.customerName ?? 'N/A'}'),
                              Text('创建人: ${order.creatorName ?? 'N/A'}'),
                              Text('金额: ${itemCurrencyFormatter.format(order.totalPrice)}'),
                              Text('类型: ${order.orderTypeString}'),
                              Text('下单时间: ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_jm().format(order.orderTime)}'),
                              const SizedBox(height: 4),
                              Chip(
                                label: Text(
                                  order.statusString,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                backgroundColor: _getStatusColor(order.status),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                labelPadding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () {
                          logger.d("Tapped on order: ${order.no}, ID: ${order.id}");
                          // Navigate to detail page, passing the order ID
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SalesOrderDetailPage(orderId: order.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              );
            }(), // Invoke the IIFE for conditional rendering
          ),
        ],
      ),
    );
  }
}