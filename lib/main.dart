// lib/main.dart (修改后)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/utils/logger.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/providers/auth_provider.dart'; // 导入 authStateProvider
import 'features/auth/providers/auth_state.dart';
import 'features/home/presentation/pages/home_page.dart'; // 导入 AuthStatus

void main() {
  // 如果需要，可以在这里进行其他初始化 (如 setupLocator for GetIt)
  runApp(
    const ProviderScope( // ProviderScope 保持不变
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget { // MyApp 必须是 ConsumerWidget 来监听 Provider
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
// --- 添加日志 ---
    logger.d("--- MyApp build method START ---"); // 1. 检查 build 是否被调用

    final authStatus = ref.watch(authStateProvider);

    // --- 添加日志 ---
    logger.d("MyApp watched Auth Status: $authStatus"); // 2. 检查监听到的状态

    final homeWidget = _buildHome(authStatus);

    // --- 添加日志 ---
    logger.d("MyApp _buildHome returned widget of type: ${homeWidget.runtimeType}"); // 3. 检查返回的 Widget 类型

    return MaterialApp(
      title: 'ERP App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // ... 其他主题设置 ...
      ),
      // 根据认证状态决定显示的第一个页面
      home: homeWidget,
      // 你也可以在这里设置路由表 (routes) 或 onGenerateRoute
    );
  }

  // 根据认证状态返回对应的 Widget
  Widget _buildHome(AuthStatus authStatus) {
    switch (authStatus) {
      case AuthStatus.unknown:
      // 初始状态，显示加载指示器或启动页
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
      // 已认证，显示主页
        return const HomePage();
      case AuthStatus.unauthenticated:
      // 未认证，显示登录页
        return const LoginPage();
    }
  }
}