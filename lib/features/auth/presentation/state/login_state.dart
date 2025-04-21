import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart'; // 确保路径正确

enum LoginStatus {
  initial, // 初始状态，用户还未进行任何操作
  loading, // 正在登录，与服务器交互中
  success, // 登录成功
  failure  // 登录失败
}

class LoginState extends Equatable {
  final LoginStatus status;
  final User? user; // 登录成功时存储用户信息
  final String? errorMessage; // 登录失败时存储错误信息

  // 构造函数，提供默认值代表初始状态
  const LoginState({
    this.status = LoginStatus.initial,
    this.user,
    this.errorMessage,
  });

  // copyWith 方法，用于创建状态的修改版本
  // 允许部分更新状态属性
  LoginState copyWith({
    LoginStatus? status,
    User? user,
    String? errorMessage,
    // 添加一个显式的方式来清除 nullable 字段可能更健壮，
    // 但通常直接传递 null 给 copyWith 也可以工作。
    // 例如: copyWith(errorMessage: null)
  }) {
    return LoginState(
      // 如果没有提供新的 status，则使用当前的 status
      status: status ?? this.status,
      // 如果没有提供新的 user，则使用当前的 user
      user: user ?? this.user,
      // 如果没有提供新的 errorMessage，则使用当前的 errorMessage
      // 如果显式传递 null，则会设置为 null
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // Equatable 实现：指定哪些属性用于比较相等性
  @override
  List<Object?> get props => [status, user, errorMessage];
}