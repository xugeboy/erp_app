// lib/features/auth/providers/auth_state_notifier.dart (或类似文件)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/token_storage_service.dart';
import '../../../core/utils/logger.dart';
import 'auth_provider.dart';
import 'auth_state.dart'; // 导入 AuthStatus 枚举

class AuthStateNotifier extends StateNotifier<AuthStatus> {
  final TokenStorageService _tokenStorageService;
  final Ref ref;

  AuthStateNotifier(this._tokenStorageService, this.ref) : super(AuthStatus.unknown) {
    // Notifier 初始化时立即检查认证状态
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(milliseconds: 50)); // 保持可选延迟
    try {
      // 同时尝试获取 Token 和 User 数据
      final accessToken = await _tokenStorageService.getAccessToken();
      final storedUser = await _tokenStorageService.getUser(); // <--- 获取存储的 User

      // 只有当 Token 和 User 数据都存在时，才认为是已认证
      if (accessToken != null && accessToken.isNotEmpty && storedUser != null) {
        logger.i("Auth Check: Valid token and user data found. Setting state to authenticated.");
        // 使用存储的 User 更新 userProvider
        ref.read(userProvider.notifier).state = storedUser; // <--- 更新 User Provider
        state = AuthStatus.authenticated;
      } else {
        logger.i("Auth Check: No valid token or user data found. Setting state to unauthenticated.");
        // 如果缺少任何一个，都视为未认证，并确保清除所有相关数据
        await _tokenStorageService.deleteTokens(); // 清除可能残留的 token
        await _tokenStorageService.deleteUser(); // 清除可能残留的 user data
        ref.read(userProvider.notifier).state = null; // 确保 userProvider 为 null
        state = AuthStatus.unauthenticated;
      }
    } catch (e, stackTrace) {
      logger.e("Auth Check: Error checking stored auth state", error: e, stackTrace: stackTrace);
      // 出错时也设置为未认证，并清除数据
      await _tokenStorageService.deleteTokens();
      await _tokenStorageService.deleteUser();
      ref.read(userProvider.notifier).state = null;
      state = AuthStatus.unauthenticated;
    }
  }

  // setAuthenticated 不再需要手动更新 userProvider，因为登录流程会做
  void setAuthenticated() {
    if (state != AuthStatus.authenticated) {
      logger.i("Auth State: Setting to authenticated.");
      // 这里不再需要更新 userProvider，LoginNotifier 会做
      state = AuthStatus.authenticated;
    }
  }

  // setUnauthenticated 需要确保清除 User 数据
  void setUnauthenticated() {
    if (state != AuthStatus.unauthenticated) {
      logger.i("Auth State: Setting to unauthenticated.");
      // 清除 Token 和 User 状态
      // （注意：logout 方法在 Repository 层也会调用 delete，这里是双重保险或状态驱动清理）
      _tokenStorageService.deleteTokens();
      _tokenStorageService.deleteUser(); // <--- 确保清除 User
      ref.read(userProvider.notifier).state = null;
      state = AuthStatus.unauthenticated;
    } else {
      // 如果已经是 unauthenticated，再次确保清除
      _tokenStorageService.deleteTokens();
      _tokenStorageService.deleteUser();
      ref.read(userProvider.notifier).state = null;
    }
  }
}