// lib/features/auth/data/models/sales_order_model.dart
import 'package:equatable/equatable.dart'; // 可选，如果需要比较对象

class LoginRequest extends Equatable {
  final String tenantName;
  final String username;
  final String password;
  final bool rememberMe;

  const LoginRequest({
    required this.tenantName,
    required this.username,
    required this.password,
    required this.rememberMe,
  });

  // 方法：将 LoginRequest 对象转换为 Map<String, dynamic> 以便发送给 API
  Map<String, dynamic> toJson() {
    return {
      'tenantName': tenantName,
      'username': username,
      'password': password,
      'rememberMe': rememberMe,
    };
  }

  @override
  List<Object?> get props => [tenantName, username, password, rememberMe];
}