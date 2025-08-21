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
  static const String _tokenExpiryKey = 'token_expiry'; // 新增：token过期时间
  static const String _refreshTokenExpiryKey = 'refresh_token_expiry'; // 新增：refresh token过期时间

  TokenStorageService(this._storage);

  // 保存 Tokens (增强版，包含过期时间)
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? accessTokenExpiry, // 新增：access token过期时间
    DateTime? refreshTokenExpiry, // 新增：refresh token过期时间
  }) async {
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      
      // 保存过期时间
      if (accessTokenExpiry != null) {
        await _storage.write(key: _tokenExpiryKey, value: accessTokenExpiry.millisecondsSinceEpoch.toString());
      }
      if (refreshTokenExpiry != null) {
        await _storage.write(key: _refreshTokenExpiryKey, value: refreshTokenExpiry.millisecondsSinceEpoch.toString());
      }
      
      logger.d("Tokens and expiry times saved successfully.");
    } catch (e) {
      logger.d("Error saving tokens: $e");
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

  // 新增：检查token是否即将过期（默认提前5分钟）
  Future<bool> isTokenExpiringSoon({Duration threshold = const Duration(minutes: 5)}) async {
    try {
      final expiryStr = await _storage.read(key: _tokenExpiryKey);
      if (expiryStr == null) return true; // 如果没有过期时间，认为需要刷新
      
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
      final now = DateTime.now();
      final timeUntilExpiry = expiryTime.difference(now);
      
      return timeUntilExpiry <= threshold;
    } catch (e) {
      logger.d("Error checking token expiry: $e");
      return true; // 出错时认为需要刷新
    }
  }

  // 新增：检查token是否已过期
  Future<bool> isTokenExpired() async {
    try {
      final expiryStr = await _storage.read(key: _tokenExpiryKey);
      if (expiryStr == null) return true;
      
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
      final now = DateTime.now();
      
      return now.isAfter(expiryTime);
    } catch (e) {
      logger.d("Error checking if token expired: $e");
      return true;
    }
  }

  // 新增：检查refresh token是否已过期
  Future<bool> isRefreshTokenExpired() async {
    try {
      final expiryStr = await _storage.read(key: _refreshTokenExpiryKey);
      if (expiryStr == null) return true;
      
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
      final now = DateTime.now();
      
      return now.isAfter(expiryTime);
    } catch (e) {
      logger.d("Error checking if refresh token expired: $e");
      return true;
    }
  }

  // 新增：获取token剩余有效时间
  Future<Duration?> getTokenRemainingTime() async {
    try {
      final expiryStr = await _storage.read(key: _tokenExpiryKey);
      if (expiryStr == null) return null;
      
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
      final now = DateTime.now();
      
      return expiryTime.difference(now);
    } catch (e) {
      logger.d("Error getting token remaining time: $e");
      return null;
    }
  }

  // 删除 Tokens (例如，用于退出登录)
  Future<void> deleteTokens() async {
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _tokenExpiryKey);
      await _storage.delete(key: _refreshTokenExpiryKey);
      logger.d("Tokens and expiry times deleted successfully.");
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

  // 新增：清理所有认证相关数据
  Future<void> clearAllAuthData() async {
    try {
      await deleteTokens();
      await deleteUser();
      logger.i("All authentication data cleared successfully.");
    } catch (e, stackTrace) {
      logger.e("Error clearing all auth data", error: e, stackTrace: stackTrace);
    }
  }
}