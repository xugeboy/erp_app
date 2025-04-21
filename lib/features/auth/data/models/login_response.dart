// lib/features/auth/data/models/login_response.dart
import 'package:equatable/equatable.dart'; // 可选

// 内部 Data 结构的模型
class LoginResponseData extends Equatable {
  final int userId;
  final String accessToken;
  final String refreshToken;
  final int expiresTime;

  const LoginResponseData({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresTime,
  });

  // 工厂构造函数：从 Map<String, dynamic> 创建 LoginResponseData 实例
  factory LoginResponseData.fromJson(Map<String, dynamic> json) {
    return LoginResponseData(
      userId: json['userId'] as int? ?? -1, // 提供默认值或进行更严格检查
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresTime: json['expiresTime'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [userId, accessToken, refreshToken, expiresTime];
}

// 整体响应结构的模型
class LoginResponse extends Equatable {
  final int code;
  final LoginResponseData? data; // data 可能为 null
  final String msg;

  const LoginResponse({
    required this.code,
    this.data,
    required this.msg,
  });

  // 工厂构造函数：从 Map<String, dynamic> 创建 LoginResponse 实例
  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      code: json['code'] as int? ?? -1, // 提供默认值
      // 如果 'data' 字段存在且不为 null，则解析它，否则为 null
      data: json['data'] != null
          ? LoginResponseData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      msg: json['msg'] as String? ?? '', // 提供默认值
    );
  }

  @override
  List<Object?> get props => [code, data, msg];
}