import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/storage_provider.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/state/login_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../widgets/app_drawer.dart';

// 1. 改为 ConsumerStatefulWidget
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

// 2. 创建对应的 ConsumerState
class _HomePageState extends ConsumerState<HomePage> {

  // 将 _signOut 方法移到这里
  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // 1. 清除 token
      final tokenService = ref.read(tokenStorageProvider);
      await tokenService.deleteTokens();
      await tokenService.deleteUser(); // 确保也清除用户数据

      if (!context.mounted) return;

      // 2. 更新认证状态
      ref.read(authStateProvider.notifier).setUnauthenticated();
      ref.read(userProvider.notifier).state = null; // 清除用户状态
      logger.i("Auth state set to unauthenticated.");

      // 3. 导航到登录页面，并清除所有其他页面
      if (!context.mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false, // 移除所有其他页面
      );
    } catch (e) {
      logger.e("Sign out failed", error: e);
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('登出失败: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听状态变化以处理副作用 (导航, SnackBar) - 保持不变
    ref.listen<LoginState>(loginNotifierProvider, (previousState, nextState) {
      // (这里的代码与之前相同，用于处理登录/登出后的导航或提示)
      // 比如登出时，如果 AuthStateNotifier 触发状态改变，这个监听器可能不需要再做导航
      // 但如果 _signOut 直接导航，这个监听器主要处理登录成功的情况
      if (previousState?.status != LoginStatus.success && nextState.status == LoginStatus.success) {
        // 可能是登录成功，但 HomePage 一般是登录后才进入，所以此处的导航可能不需要
        // 主要依赖 AuthStateProvider 驱动页面切换
        logger.i("Login state changed to success while on HomePage?");
      } else if (previousState?.status != LoginStatus.failure && nextState.status == LoginStatus.failure) {
        if (nextState.errorMessage != null && mounted) { // 增加 mounted 检查
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(nextState.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });

    // 监听认证状态提供者以获取最新状态（如果需要根据User更新UI）
    final user = ref.watch(userProvider);
    if (user == null) {
      logger.w("HomePage build: User is null! This indicates an inconsistent state. Forcing unauthenticated check.");
      // 添加一个延迟回调来触发状态检查或导航，避免在 build 中直接修改状态或导航
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authStateProvider.notifier).setUnauthenticated(); // 强制重新检查或设置为未认证
      });
      // 显示加载或错误提示，而不是整个 HomePage
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 更好的方式可能是有一个专门的 userProvider
    // final user = ref.watch(userProvider);
    // --- 从 user 对象获取信息 ---
    final username = user.username; // 登录名
    final nickname = user.nickname; // 昵称
    final roles = user.roles; // 角色列表


    // 监听当前选中的页面 (用于更新 Body)
    final selectedPage = ref.watch(selectedPageProvider);
    logger.d("Building HomePage body for selected page: $selectedPage"); // 调试日志

    return Scaffold(
      appBar: AppBar(
        // 左侧菜单按钮 (使用 Builder)
        leading: Builder(
          builder: (BuildContext scaffoldContext) { // 使用不同的 context 名称避免混淆
            return IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Open navigation menu',
              onPressed: () {
                Scaffold.of(scaffoldContext).openDrawer(); // 使用 Builder 的 context 打开 Drawer
              },
            );
          },
        ),
        // 标题可以根据选中的页面动态改变
        title: Text(selectedPage), // 例如，显示当前选中的页面名称
        actions: <Widget>[
          // 右侧用户头像和弹出菜单
          PopupMenuButton<String>(
            onSelected: (String result) {
              if (result == 'signOut') {
                _signOut(); // 调用 State 内的登出方法
              }
              // 可以添加其他菜单项的处理，如 'profile'
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'profile',
                enabled: false, // 暂不实现 "Profile"
                child: Text('Profile ($nickname)'), // 显示用户名
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'signOut',
                child: Text('Sign out'),
              ),
            ],
            // 使用 CircleAvatar 作为按钮图标
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer, // 使用主题颜色
              child: Text(
                nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold
                ),
              ),
            ),
            tooltip: 'User options',
          ),
          const SizedBox(width: 8), // 提供一些右边距
        ],
      ),
      // 侧边栏 Drawer
      drawer: const AppDrawer(),
      // 主体内容区域 (使用 Consumer 监听 selectedPageProvider)
      // 注意：如果 AppDrawer 内部的 onTap 已经更新了 selectedPageProvider，
      // 这里的 Consumer 会自动重建 body 部分。
      body: _buildBodyContent(selectedPage, roles),
    );
  }

  // 根据选中的页面构建 Body 内容的辅助方法
  Widget _buildBodyContent(String selectedPage,List<String> roles) {
    logger.d("Building body content for: $selectedPage"); // 调试日志
    // TODO: 在这里根据 selectedPage 返回不同的页面 Widget
    // 例如，创建 DashboardPage, TeamPage, ProjectsPage 等 Widget
    switch (selectedPage) {
      case 'Dashboard':
      // return DashboardPage(); // 替换为实际页面
        return const Center(child: Text('Dashboard Content Area'));
      case 'Team':
      // return TeamPage();
        return const Center(child: Text('Team Content Area'));
      case 'Projects':
      // return ProjectsPage();
        return const Center(child: Text('Projects Content Area'));
      case 'Calendar':
        return const Center(child: Text('Calendar Content Area'));
      case 'Documents':
        return const Center(child: Text('Documents Content Area'));
      case 'Reports':
        return const Center(child: Text('Reports Content Area'));
      case 'Settings':
      // return SettingsPage();
      default:
        return Center(child: Text('Content for $selectedPage'));
    }
  }
}