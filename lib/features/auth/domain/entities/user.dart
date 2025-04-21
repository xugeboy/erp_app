import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id; // User ID from login/profile response
  final String username; // Username used for login
  final String nickname; // From profile API
  final int? deptId;     // From profile API
  final List<String> roles; // From profile API

  const User({
    required this.id,
    required this.username,
    required this.nickname, // Make nullable or provide default
    this.deptId,   // Make nullable or provide default
    this.roles = const [], // Default to empty list
  });

  bool hasRole(String role) => roles.contains(role);

  bool get isBoss => hasRole('super_admin');
  bool get isPurchaser => hasRole('cg') || hasRole('cg_manager');

  @override
  List<Object?> get props => [id, username, nickname, deptId, roles];

  // 添加 fromJson 工厂构造函数
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '', // 从 JSON 读取 id (假设存储为 String)
      username: json['username'] as String? ?? '', // 从 JSON 读取 username
      nickname: json['nickname'] as String,
      deptId: json['deptId'] as int?,
      roles: List<String>.from(json['roles'] as List? ?? []), // 读取 roles 列表
    );
  }

  // 添加 toJson 方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'deptId': deptId,
      'roles': roles,
    };
  }

  // A convenience method to create a copy with optional modifications
  User copyWith({
    String? id,
    String? username,
    String? nickname,
    String? avatar,
    int? deptId,
    List<String>? roles,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      deptId: deptId ?? this.deptId,
      roles: roles ?? this.roles,
    );
  }
}