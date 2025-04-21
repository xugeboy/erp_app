import 'package:flutter/material.dart';
import '../../features/auth/presentation/pages/login_page.dart';
// 导入你的首页

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home'; // 你的首页路由

  static Map<String, WidgetBuilder> routes = {
    login: (context) => LoginPage(),
    home: (context) => Placeholder(), // 替换为你的首页 Widget
  };
}