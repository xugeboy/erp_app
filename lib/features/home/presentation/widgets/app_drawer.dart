import 'package:erp_app/features/production/presentation/pages/production_list_page.dart';
import 'package:erp_app/features/purchase_order/presentation/pages/purchase_order_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sales_order/presentation/pages/sales_order_list_page.dart';

// StateProvider 来管理当前选中的页面名称 (或者你可以用索引、枚举等)
// 添加新的页面键名
final selectedPageProvider = StateProvider<String>((ref) => 'Dashboard'); // 默认选中 Dashboard

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // 使用深色主题 (保持不变)
    final drawerTheme = ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.blueGrey[900],
      canvasColor: Colors.grey[900],
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        secondary: Colors.tealAccent,
        surface: Color(0xFF2A2D3E), // 选中项背景色
        onSurface: Colors.white70,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white70,
      ),
    );

    // 监听选中的页面
    final selectedPage = ref.watch(selectedPageProvider);

    return Theme(
      data: drawerTheme,
      child: Drawer(
        child: Column(
          children: [
            // --- Drawer Header (保持不变) ---
            SizedBox(
              height: 120,
              child: DrawerHeader(
                decoration: BoxDecoration(color: drawerTheme.primaryColor),
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business_rounded, size: 24, color: theme.colorScheme.onPrimary),
                        const SizedBox(width: 12),
                        Text(
                          'Xiangle ERP',
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                      color: theme.colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),

            // --- 修改后的 Navigation List ---
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  // 添加 采购订单
                  _buildDrawerItem(
                    icon: Icons.shopping_cart_checkout_rounded, // 示例图标
                    text: '采购订单', // Purchase Orders
                    isSelected: selectedPage == 'Purchase Orders',
                    onTap: () {
                      ref.read(selectedPageProvider.notifier).state = 'Purchase Orders';
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PurchaseOrderListPage()),
                      );
                    },
                    theme: drawerTheme,
                  ),
                  // 添加 销售订单
                  _buildDrawerItem(
                    icon: Icons.point_of_sale_rounded, // 示例图标
                    text: '销售订单', // Sales Orders
                    isSelected: selectedPage == 'Sales Orders',
                    onTap: () {
                      ref.read(selectedPageProvider.notifier).state = 'Sales Orders';
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SalesOrderListPage()),
                      );
                    },
                    theme: drawerTheme,
                  ),
                  // 添加 生产单
                  _buildDrawerItem(
                    icon: Icons.production_quantity_limits, // 示例图标
                    text: '生产单', // Production
                    isSelected: selectedPage == 'Sales Orders',
                    onTap: () {
                      ref.read(selectedPageProvider.notifier).state = 'Production Orders';
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProductionListPage()),
                      );
                    },
                    theme: drawerTheme,
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build drawer items consistently (保持不变)
  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isSelected = false,
    // bool isTeam = false, // isTeam 不再需要
  }) {
    final Color selectedColor = theme.colorScheme.surface;
    final Color selectedTextColor = theme.colorScheme.primary;
    final Color defaultTextColor = theme.listTileTheme.textColor ?? Colors.white70;
    final Color defaultIconColor = theme.listTileTheme.iconColor ?? Colors.white70;

    // 不再需要区分 team item 的图标
    Widget leadingWidget = Icon(icon, color: isSelected ? selectedTextColor : defaultIconColor);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        leading: leadingWidget,
        title: Text(
          text,
          style: TextStyle(color: isSelected ? selectedTextColor : defaultTextColor, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
        ),
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      ),
    );
  }
}