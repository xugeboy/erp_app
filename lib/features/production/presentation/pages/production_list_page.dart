// lib/features/purchase_order/presentation/pages/production_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:intl/intl.dart'; // For formatting currency and dates

import '../../domain/entities/production_entity.dart'; // Your ProductionEntity
import '../../providers/production_providers.dart';
import '../../providers/production_state.dart';
import '../../../../core/utils/logger.dart'; // Your logger
import 'production_detail_page.dart'; // For navigation to the detail page

class ProductionListPage extends ConsumerStatefulWidget {
  const ProductionListPage({super.key});

  @override
  ConsumerState<ProductionListPage> createState() => _ProductionListPageState();
}

class _ProductionListPageState extends ConsumerState<ProductionListPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusString; // UI display string for status filter
  int? _selectedStatusCode;   // Actual status code for filtering

  // This map helps convert the display string from the dropdown back to an integer code
  final Map<String, int> _statusDisplayToCodeMap = {
    "待排产": 10, "已排产": 20
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
      final initialNotifierState = ref.read(productionNotifierProvider);
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
        _selectedStatusString = "待排产";
        _selectedStatusCode = 10;
      }
      setState(() {}); // Update UI with initial filter values if they were loaded from state

      logger.d(
          "ProductionListPage: Initializing with query: '${_searchController.text}', status code: $_selectedStatusCode");
      ref.read(productionNotifierProvider.notifier).fetchOrders(
        orderNumber: _searchController.text.isEmpty ? null : _searchController.text,
        status: _selectedStatusCode,pageNoToFetch: 1,
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
    final tempEntity = ProductionEntity(
        id: 0, no: '', status: statusCode, saleOrderId: 0,
        createTime: DateTime.now(), orderKeeperName: '');
    String statusDisplay = tempEntity.statusString;

    if (statusDisplay.contains("待排产")) {
      return Colors.orange.shade700;
    }
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    // Watch the state from Riverpod. This will cause the widget to rebuild when the state changes.
    final productionState = ref.watch(productionNotifierProvider);
    // Get the notifier to call methods (actions).
    final productionNotifier = ref.read(productionNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('生产单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            // Disable button if already loading to prevent multiple requests
            onPressed: productionState.listState == ScreenState.loading
                ? null
                : () {
              logger.d(
                  "Refresh button pressed. Query: '${_searchController.text}', Status Code: $_selectedStatusCode");
              productionNotifier.fetchOrders(
                orderNumber: _searchController.text.isEmpty ? null : _searchController.text,
                status: _selectedStatusCode,pageNoToFetch: 1,
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
                      hintText: '单号筛选',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white,
                    ),
                    // Call notifier method when text is submitted (e.g., user presses enter)
                    onSubmitted: (value) {
                      if(value.isNotEmpty) {
                        productionNotifier.applyOrderNumberFilter(value);
                      }
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
                        productionNotifier.applyStatusFilter(_selectedStatusCode);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- Orders List Section ---
          Expanded(
            child: () {
              if (productionState.listState == ScreenState.loading && productionState.orders.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (productionState.listState == ScreenState.error && productionState.orders.isEmpty) {
                return Center( /* ... Error UI ... */
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('加载失败: ${productionState.listErrorMessage}',
                            textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                          onPressed: () {
                            productionNotifier.fetchOrders(
                                orderNumber: _searchController.text.isEmpty ? null : _searchController.text,
                                status: _selectedStatusCode,
                                pageNoToFetch: 1 // 重试时加载第一页
                            );
                          },
                        )
                      ],
                    ),
                  ),
                );
              }
              if (productionState.orders.isEmpty && productionState.listState != ScreenState.loading) {
                return const Center( /* ... Empty State UI ... */
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('没有找到相关订单。', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    )
                );
              }
              // 移除 RefreshIndicator，因为 AppBar 中已有刷新按钮
              return ListView.builder(
                // controller: _scrollController, // 不再需要
                padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 0), // 调整底部 padding
                itemCount: productionState.orders.length, // 只显示当前页的订单
                itemBuilder: (context, index) {
                  // 移除加载更多的逻辑
                  final order = productionState.orders[index];
                  final itemCurrencyFormatter = NumberFormat.currency(
                      locale: Localizations.localeOf(context).toString(),
                      symbol: "¥");

                  return Card( /* ... ListTile UI (保持不变) ... */
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(order.status),
                        radius: 40,
                        child: Text(
                          order.statusString,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        '生产单号: ${order.no}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('业务员: ${order.creatorName ?? ''}'),
                            Text('跟单: ${order.orderKeeperName ?? ''}'),
                            Text('创建时间: ${DateFormat('yyyy/MM/dd HH:mm').format(order.createTime)}'),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        logger.d("Tapped on order: ${order.no}, ID: ${order.id}");
                        ref.read(productionNotifierProvider.notifier).setCurrentlySelectedOrder(order);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductionDetailPage(orderId: order.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }(),
          ),
          // --- 分页控制按钮 ---
          if (productionState.listState == ScreenState.loaded || productionState.orders.isNotEmpty) // 只有在加载完成或列表不为空时显示分页
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    label: const Text("上一页"),
                    onPressed: (productionState.currentPageNo <= 1 || productionState.listState == ScreenState.loading)
                        ? null // 如果是第一页或正在加载，则禁用
                        : () {
                      productionNotifier.goToPreviousPage();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                        '第 ${productionState.currentPageNo} 页'
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward_ios),
                    label: const Text("下一页"),
                    onPressed: (!productionState.canLoadMore || productionState.listState == ScreenState.loading)
                        ? null // 如果不能加载更多或正在加载，则禁用
                        : () {
                      productionNotifier.goToNextPage();
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
