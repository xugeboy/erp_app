import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../features/auth/domain/entities/user.dart';
import '../utils/logger.dart';

class TokenStorageService {
  final FlutterSecureStorage _storage;

  // 定义存储用的 Key
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';

  TokenStorageService(this._storage);

  // 保存 Tokens
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      logger.d("Tokens saved successfully."); // 调试信息
    } catch (e) {
      logger.d("Error saving tokens: $e");
      // 可以考虑向上抛出异常或进行错误日志记录
    }
  }

  // 获取 Access Token
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (e) {
      logger.d("Error reading access token: $e");
      return null;
    }
  }

  // 获取 Refresh Token
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      logger.d("Error reading refresh token: $e");
      return null;
    }
  }

  // 删除 Tokens (例如，用于退出登录)
  Future<void> deleteTokens() async {
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      logger.d("Tokens deleted successfully.");
    } catch (e) {
      logger.d("Error deleting tokens: $e");
    }
  }

  // 保存 User 对象 (需要先转换为 JSON 字符串)
  Future<void> saveUser(User user) async {
    try {
      // 注意：User 类需要有 toJson 方法
      final userJson = jsonEncode(user.toJson()); // 序列化 User 对象
      await _storage.write(key: _userKey, value: userJson);
      logger.i("User data saved successfully.");
    } catch (e, stackTrace) {
      logger.e("Error saving user data", error: e, stackTrace: stackTrace);
    }
  }

  // 读取 User 对象 (需要从 JSON 字符串转换回来)
  Future<User?> getUser() async {
    try {
      final userJson = await _storage.read(key: _userKey);
      if (userJson != null && userJson.isNotEmpty) {
        // 注意：User 类需要有 fromJson 工厂构造函数
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        final user = User.fromJson(userMap); // 反序列化
        logger.i("User data loaded successfully.");
        return user;
      }
      logger.w("No user data found in storage.");
      return null;
    } catch (e, stackTrace) {
      logger.e("Error reading user data", error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // 删除 User 信息
  Future<void> deleteUser() async {
    try {
      await _storage.delete(key: _userKey);
      logger.i("User data deleted successfully.");
    } catch (e, stackTrace) {
      logger.e("Error deleting user data", error: e, stackTrace: stackTrace);
    }
  }
}