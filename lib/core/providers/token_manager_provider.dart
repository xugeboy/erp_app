import 'dart:async';
import 'package:erp_app/core/providers/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/token_storage_service.dart';
import '../utils/logger.dart';
import '../../features/auth/providers/auth_provider.dart';

class TokenManager {
  final TokenStorageService _tokenStorageService;
  final Ref _ref;
  Timer? _tokenCheckTimer;
  Timer? _autoRefreshTimer;
  static const Duration _checkInterval = Duration(minutes: 1); // 每分钟检查一次
  static const Duration _refreshThreshold = Duration(minutes: 5); // 提前5分钟刷新

  TokenManager(this._tokenStorageService, this._ref);

  // 启动token管理
  void startTokenManagement() {
    logger.i("TokenManager: Starting token management");
    _scheduleTokenCheck();
  }

  // 停止token管理
  void stopTokenManagement() {
    logger.i("TokenManager: Stopping token management");
    _tokenCheckTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _tokenCheckTimer = null;
    _autoRefreshTimer = null;
  }

  // 安排定期检查token
  void _scheduleTokenCheck() {
    _tokenCheckTimer?.cancel();
    _tokenCheckTimer = Timer.periodic(_checkInterval, (timer) {
      _checkAndRefreshTokenIfNeeded();
    });
    
    // 立即执行一次检查
    _checkAndRefreshTokenIfNeeded();
  }

  // 检查并刷新token（如果需要）
  Future<void> _checkAndRefreshTokenIfNeeded() async {
    try {
      // 检查token是否即将过期
      final isExpiringSoon = await _tokenStorageService.isTokenExpiringSoon(
        threshold: _refreshThreshold,
      );

      if (isExpiringSoon) {
        logger.i("TokenManager: Token expiring soon, attempting refresh");
        await _attemptTokenRefresh();
      } else {
        // 检查token是否已过期
        final isExpired = await _tokenStorageService.isTokenExpired();
        if (isExpired) {
          logger.w("TokenManager: Token has expired, logging out user");
          await _handleTokenExpired();
        } else {
          // 获取剩余时间并记录
          final remainingTime = await _tokenStorageService.getTokenRemainingTime();
          if (remainingTime != null) {
            logger.d("TokenManager: Token valid for ${remainingTime.inMinutes} minutes");
          }
        }
      }
    } catch (e, stackTrace) {
      logger.e("TokenManager: Error during token check", error: e, stackTrace: stackTrace);
      // 出错时尝试登出用户
      await _handleTokenExpired();
    }
  }

  // 尝试刷新token
  Future<void> _attemptTokenRefresh() async {
    try {
      // 检查refresh token是否已过期
      final isRefreshTokenExpired = await _tokenStorageService.isRefreshTokenExpired();
      if (isRefreshTokenExpired) {
        logger.w("TokenManager: Refresh token expired, logging out user");
        await _handleTokenExpired();
        return;
      }

      // 这里可以调用你的刷新token的API
      // 由于你的AuthInterceptor已经处理了刷新逻辑，这里主要是触发一个API调用来触发刷新
      logger.i("TokenManager: Triggering token refresh via API call");
      
      // 可以通过调用一个简单的API来触发AuthInterceptor的刷新逻辑
      // 或者直接调用刷新方法（如果暴露的话）
      
    } catch (e, stackTrace) {
      logger.e("TokenManager: Failed to refresh token", error: e, stackTrace: stackTrace);
      await _handleTokenExpired();
    }
  }

  // 处理token过期
  Future<void> _handleTokenExpired() async {
    try {
      logger.w("TokenManager: Handling token expiration");
      
      // 清除所有认证数据
      await _tokenStorageService.clearAllAuthData();
      
      // 通知认证状态变更
      _ref.read(authStateProvider.notifier).setUnauthenticated();
      
      logger.i("TokenManager: User logged out due to token expiration");
    } catch (e, stackTrace) {
      logger.e("TokenManager: Error during logout", error: e, stackTrace: stackTrace);
    }
  }

  // 手动刷新token（供外部调用）
  Future<bool> manualRefreshToken() async {
    try {
      logger.i("TokenManager: Manual token refresh requested");
      await _attemptTokenRefresh();
      return true;
    } catch (e) {
      logger.e("TokenManager: Manual token refresh failed", error: e);
      return false;
    }
  }

  // 检查当前token状态
  Future<Map<String, dynamic>> getTokenStatus() async {
    try {
      final isExpired = await _tokenStorageService.isTokenExpired();
      final isExpiringSoon = await _tokenStorageService.isTokenExpiringSoon();
      final remainingTime = await _tokenStorageService.getTokenRemainingTime();
      final hasToken = await _tokenStorageService.getAccessToken() != null;
      
      return {
        'hasToken': hasToken,
        'isExpired': isExpired,
        'isExpiringSoon': isExpiringSoon,
        'remainingTime': remainingTime?.inMinutes,
        'status': isExpired ? 'expired' : (isExpiringSoon ? 'expiring_soon' : 'valid'),
      };
    } catch (e) {
      logger.e("TokenManager: Error getting token status", error: e);
      return {
        'hasToken': false,
        'isExpired': true,
        'isExpiringSoon': true,
        'remainingTime': 0,
        'status': 'error',
      };
    }
  }
}

// Provider for TokenManager
final tokenManagerProvider = Provider<TokenManager>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return TokenManager(tokenStorage, ref);
});

// Provider for starting/stopping token management
final tokenManagementProvider = StateNotifierProvider<TokenManagementNotifier, bool>((ref) {
  return TokenManagementNotifier(ref);
});

class TokenManagementNotifier extends StateNotifier<bool> {
  final Ref _ref;
  TokenManager? _tokenManager;

  TokenManagementNotifier(this._ref) : super(false);

  void startManagement() {
    if (!state) {
      _tokenManager = _ref.read(tokenManagerProvider);
      _tokenManager!.startTokenManagement();
      state = true;
      logger.i("TokenManagement: Started");
    }
  }

  void stopManagement() {
    if (state) {
      _tokenManager?.stopTokenManagement();
      _tokenManager = null;
      state = false;
      logger.i("TokenManagement: Stopped");
    }
  }

  @override
  void dispose() {
    stopManagement();
    super.dispose();
  }
}
