// lib/core/network/interceptors/auth_interceptor.dart (修改)
import 'dart:async'; // 需要 Completer
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/data/models/login_response.dart';
import '../../storage/token_storage_service.dart';
import '../../utils/logger.dart'; // 确保导入路径正确

class BusinessLevelAuthException implements Exception {
  final String message;
  final RequestOptions requestOptions;
  final Response? originalResponse; // 保留原始响应以供参考

  BusinessLevelAuthException(
      this.message, {
        required this.requestOptions,
        this.originalResponse,
      });

  @override
  String toString() => message;
}

// 自定义异常 (保持不变)
class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException([
    this.message = 'Session expired or refresh failed. Please login again.',
  ]);
  @override
  String toString() => message;
}

class AuthInterceptor extends Interceptor {
  final TokenStorageService _tokenStorageService;
  final Dio _dio; // 仍然需要主 Dio 实例来重试请求
  final Dio _refreshDio; // 干净的 Dio 实例用于刷新
  final String _refreshTokenUrl;
  final Function()? _onSessionExpired; // 新增：会话过期回调

  final String businessErrorCodeField = 'code'; // 例如: 'code'
  final dynamic businessAuthErrorCodeValue = 401; // 例如: 401 (int) 或 "401" (String)

  bool _isRefreshing = false; // 标记刷新状态
  Completer<void>? _refreshCompleter; // 用于等待刷新完成

  AuthInterceptor(
    this._tokenStorageService,
    this._dio, {
    Dio? refreshDio,
    Function()? onSessionExpired, // 新增：会话过期回调参数
  }) : _refreshDio = refreshDio ?? Dio(),
       _refreshTokenUrl = '${_dio.options.baseUrl}/admin-api/system/auth/refresh-token',
       _onSessionExpired = onSessionExpired;

  // --- onRequest ---
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    logger.d("AuthInterceptor: Checking request path: ${options.path}");
    final List<String> excludedPaths = [
      '/admin-api/system/auth/login',
      '/admin-api/system/auth/refresh-token',
    ];
    bool needsAuth = !excludedPaths.any((path) => options.path.endsWith(path));
    logger.d("AuthInterceptor: Needs auth? $needsAuth");

    if (needsAuth) {
      // 如果正在刷新，等待
      if (_isRefreshing) {
        logger.d("AuthInterceptor: Refresh in progress, waiting...");
        await _refreshCompleter?.future;
        logger.d("AuthInterceptor: Refresh completed, proceeding with request.");
      }
      
      // 检查token是否已过期
      final isExpired = await _tokenStorageService.isTokenExpired();
      if (isExpired) {
        logger.w("AuthInterceptor: Token expired before request. Triggering session expired.");
        _handleSessionExpired();
        return handler.reject(DioException(
          requestOptions: options,
          error: SessionExpiredException('Token expired before request'),
        ));
      }
      
      final String? accessToken = await _tokenStorageService.getAccessToken();
      logger.d(
        "AuthInterceptor: Retrieved token: ${accessToken != null ? 'found' : 'not found'}",
      );
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
        logger.d("AuthInterceptor: Added Authorization header.");
      } else {
        logger.d(
          "AuthInterceptor: Warning - Request needs auth but no token found.",
        );
        _handleSessionExpired();
        return handler.reject(DioException(
          requestOptions: options,
          error: SessionExpiredException('No access token found'),
        ));
      }
    } else {
      logger.d("AuthInterceptor: Request path excluded from auth.");
    }
    // QueuedInterceptorsWrapper 要求在最后调用 super
    return super.onRequest(options, handler);
  }

  @override
  Future<void> onResponse(
      Response response, ResponseInterceptorHandler handler) async {
    logger.d("AuthInterceptor: onResponse for path: ${response.requestOptions.path}, HTTP Status: ${response.statusCode}");

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      final responseData = response.data as Map<String, dynamic>;
      final dynamic actualBusinessCode = responseData[businessErrorCodeField];

      logger.d("AuthInterceptor: Checking business code. Expected field: '$businessErrorCodeField', Expected value for auth error: '$businessAuthErrorCodeValue', Actual value from API: '$actualBusinessCode'");

      if (actualBusinessCode != null && actualBusinessCode == businessAuthErrorCodeValue) {
        // 检测到业务层认证错误 (例如 code: 401)
        logger.w("AuthInterceptor: Business-level auth error (code $actualBusinessCode) detected in HTTP 200 response for ${response.requestOptions.path}. Attempting token refresh.");

        try {
          // 调用核心的刷新和重试逻辑
          final refreshedResponse = await _performTokenRefreshAndRetry(
            DioException( // 我们需要一个DioException来传递给刷新逻辑
              requestOptions: response.requestOptions,
              response: response, // 包含业务错误的原始响应
              error: BusinessLevelAuthException( // 标记这是业务层认证错误
                "Business code $actualBusinessCode detected.",
                requestOptions: response.requestOptions,
                originalResponse: response,
              ),
              type: DioExceptionType.unknown, // 或者自定义一个类型
            ),
            // 这里没有 ErrorInterceptorHandler，所以我们需要一个方式来处理最终结果
            // _performTokenRefreshAndRetry 现在需要能够返回 Response 或者抛出错误
          );
          // 如果 _performTokenRefreshAndRetry 成功并返回了重试后的响应
          logger.d("AuthInterceptor: Token refresh and retry successful within onResponse. Resolving with new response.");
          return handler.resolve(refreshedResponse); // 用重试后的成功响应解决
        } on DioException catch (e) {
          // 如果刷新或重试过程中发生错误 (例如，SessionExpiredException 被包装在 DioException 中)
          logger.e("AuthInterceptor: Token refresh or retry failed within onResponse. Rejecting. Error: ${e.error}");
          return handler.reject(e);
        } catch (e) {
          logger.e("AuthInterceptor: Unexpected error during refresh attempt from onResponse. Rejecting. Error: $e");
          return handler.reject(DioException(requestOptions: response.requestOptions, error: e));
        }
      }
    }
    // 如果不是业务层认证错误，正常处理响应
    return super.onResponse(response, handler);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    logger.d("AuthInterceptor: onError ENTERED. Path: ${err.requestOptions.path}, Type: ${err.type}, Error: ${err.error}, HTTP Status: ${err.response?.statusCode}");

    // 现在 onError 主要处理网络错误、服务器错误（非200的业务错误）、
    // 或者由 onResponse 中 token 刷新失败后 reject 出来的错误。
    // 对于 HTTP 401，如果你的后端"总是"返回200并在body里给业务错误码，那么下面这个if分支可能永远不会因为HTTP 401被触发。
    // 但保留它以处理真正的网络层401（例如，如果网关层面返回401）仍然是好的。
    bool isActualHttp401 = err.response?.statusCode == 401;
    bool isNotRefreshTokenPath = !err.requestOptions.path.endsWith('/refresh-token');
    final bool isRefreshPath = err.requestOptions.path.endsWith('/refresh-token');

    // 如果是刷新接口本身报错，无论错误类型，都视为会话不可恢复，强制登出
    if (isRefreshPath) {
      logger.w('AuthInterceptor: Refresh-token request failed. Forcing logout. Path: ${err.requestOptions.path}');
      _handleSessionExpired();
      return super.onError(err, handler);
    }

    if (isActualHttp401 && isNotRefreshTokenPath) {
      logger.w('AuthInterceptor: Actual HTTP 401 error (not business code in 200). Path: ${err.requestOptions.path}. Attempting refresh.');
      // 调用核心的刷新和重试逻辑
      // 注意：_performTokenRefreshAndRetry 现在应该直接使用 handler.resolve/reject
      _performTokenRefreshAndRetry(err);
    } else if (err.error is SessionExpiredException) {
      // 如果是刷新失败导致的 SessionExpiredException，通常意味着无法恢复，直接传递错误
      logger.w("AuthInterceptor: SessionExpiredException caught in onError. User should be logged out. Path: ${err.requestOptions.path}");
      _handleSessionExpired();
    }

    // 对于其他类型的错误，或者刷新token接口本身的错误，直接传递
    logger.d("AuthInterceptor: onError - Error not requiring auth refresh or is for refresh-token path itself. Passing error along.");
    return super.onError(err, handler);
  }

  // 新增：处理会话过期
  void _handleSessionExpired() {
    logger.w("AuthInterceptor: Handling session expired");
    try {
      // 清除所有认证数据
      _tokenStorageService.clearAllAuthData();
      
      // 调用回调函数通知上层
      if (_onSessionExpired != null) {
        _onSessionExpired!();
      }
      
      logger.i("AuthInterceptor: Session expired handled successfully");
    } catch (e) {
      logger.e("AuthInterceptor: Error handling session expired", error: e);
    }
  }

  // 核心的Token刷新和请求重试逻辑
  Future<Response<dynamic>> _performTokenRefreshAndRetry( // 改为返回 Future<Response>
      DioException originalError, // 原始错误，包含RequestOptions和可能的原始Response
      // ErrorInterceptorHandler handler, // 不再直接使用handler，而是返回Response或抛出新Error
      ) async {
    final requestOptions = originalError.requestOptions;

    if (_isRefreshing) {
      logger.d('AuthInterceptor: Already refreshing, request for ${requestOptions.path} will wait.');
      try {
        await _refreshCompleter!.future; // 等待进行中的刷新
        logger.d('AuthInterceptor: Ongoing refresh completed. Retrying ${requestOptions.path} with potentially new token.');
        final newAccessToken = await _tokenStorageService.getAccessToken();
        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          logger.d('AuthInterceptor: Retrying waiting request ${requestOptions.path} with new token.');
          return await _dio.fetch(requestOptions); // 直接返回重试后的Response
        } else {
          logger.w('AuthInterceptor: Refresh completed but no new token for waiting request ${requestOptions.path}.');
          throw originalError; // 抛出原始错误，因为没有新token
        }
      } catch (e) { // 这里的e可能是刷新过程的错误，也可能是等待超时等
        logger.e('AuthInterceptor: Waiting request for ${requestOptions.path} failed because refresh process itself failed: $e.');
        throw originalError; // 抛出原始错误
      }
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<void>();
    logger.d('AuthInterceptor: Starting new token refresh process for ${requestOptions.path}.');

    try {
      final refreshToken = await _tokenStorageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        logger.w('AuthInterceptor: No refresh token found. Session expired.');
        await _tokenStorageService.deleteTokens();
        _handleSessionExpired();
        final error = SessionExpiredException('No refresh token available.');
        _isRefreshing = false;
        _refreshCompleter!.completeError(error);
        throw DioException(requestOptions: requestOptions, error: error, response: originalError.response);
      }

      // 检查refresh token是否已过期
      final isRefreshTokenExpired = await _tokenStorageService.isRefreshTokenExpired();
      if (isRefreshTokenExpired) {
        logger.w('AuthInterceptor: Refresh token expired. Session expired.');
        await _tokenStorageService.deleteTokens();
        _handleSessionExpired();
        final error = SessionExpiredException('Refresh token expired.');
        _isRefreshing = false;
        _refreshCompleter!.completeError(error);
        throw DioException(requestOptions: requestOptions, error: error, response: originalError.response);
      }

      logger.d('AuthInterceptor: Calling refresh token API: $_refreshTokenUrl');
      final refreshResponse = await _refreshDio.post(
        _refreshTokenUrl,
        queryParameters: {
          'refreshToken': refreshToken
        },
      );
      logger.d('AuthInterceptor: Refresh API response: ${refreshResponse.data}');

      if (refreshResponse.data is Map<String, dynamic>) {
        final loginResponse = LoginResponse.fromJson(refreshResponse.data as Map<String, dynamic>);
        if (loginResponse.code == 0 && loginResponse.data != null) {
          final newData = loginResponse.data!;
          logger.i('AuthInterceptor: Token refresh successful.');
          
          // 计算新的过期时间（假设token有效期为2小时，refresh token为7天）
          final now = DateTime.now();
          final accessTokenExpiry = now.add(const Duration(hours: 2));
          final refreshTokenExpiry = now.add(const Duration(days: 7));
          
          await _tokenStorageService.saveTokens(
            accessToken: newData.accessToken,
            refreshToken: newData.refreshToken.isNotEmpty ? newData.refreshToken : refreshToken,
            accessTokenExpiry: accessTokenExpiry,
            refreshTokenExpiry: refreshTokenExpiry,
          );
          logger.d('AuthInterceptor: New tokens saved with expiry times.');
          _isRefreshing = false;
          _refreshCompleter!.complete();

          requestOptions.headers['Authorization'] = 'Bearer ${newData.accessToken}';
          logger.d('AuthInterceptor: Retrying original request ${requestOptions.path} with new token.');
          return await _dio.fetch(requestOptions); // 返回重试后的Response
        } else {
          logger.w('AuthInterceptor: Refresh API business error. Code=${loginResponse.code}, Msg=${loginResponse.msg}. Deleting tokens.');
          await _tokenStorageService.deleteTokens();
          _handleSessionExpired();
          final error = SessionExpiredException('Refresh token invalid/expired. API Msg: ${loginResponse.msg}');
          _isRefreshing = false;
          _refreshCompleter!.completeError(error);
          throw DioException(requestOptions: requestOptions, error: error, response: originalError.response);
        }
      } else {
        logger.w('AuthInterceptor: Invalid refresh API response format. Deleting tokens.');
        await _tokenStorageService.deleteTokens();
        _handleSessionExpired();
        final error = SessionExpiredException('Invalid response format from refresh API.');
        _isRefreshing = false;
        _refreshCompleter!.completeError(error);
        throw DioException(requestOptions: requestOptions, error: error, response: originalError.response);
      }
    } catch (e) {
      logger.e('AuthInterceptor: Exception during token refresh flow: $e. Deleting tokens.');
      await _tokenStorageService.deleteTokens();
      _handleSessionExpired();
      final error = SessionExpiredException('Failed to refresh token: $e');
      _isRefreshing = false;
      if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
        _refreshCompleter!.completeError(error);
      }
      // 如果e本身就是DioException，且包含requestOptions，可能直接抛出e更好
      if (e is DioException) throw e;
      throw DioException(requestOptions: requestOptions, error: error, response: originalError.response);
    }
  }
}
