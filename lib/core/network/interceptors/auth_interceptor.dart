// lib/core/network/interceptors/auth_interceptor.dart (修改)
import 'dart:async'; // 需要 Completer
import 'package:dio/dio.dart';
import '../../../features/auth/data/models/login_response.dart';
import '../../storage/token_storage_service.dart';
import '../../utils/logger.dart'; // 确保导入路径正确

// 自定义异常 (保持不变)
class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException([
    this.message = 'Session expired or refresh failed. Please login again.',
  ]);
  @override
  String toString() => message;
}

class AuthInterceptor extends QueuedInterceptorsWrapper {
  final TokenStorageService _tokenStorageService;
  final Dio _dio; // 仍然需要主 Dio 实例来重试请求
  final Dio _refreshDio; // 干净的 Dio 实例用于刷新
  final String _refreshTokenUrl;

  bool _isRefreshing = false; // 标记刷新状态
  Completer<void>? _refreshCompleter; // 用于等待刷新完成

  AuthInterceptor(
    this._tokenStorageService,
    this._dio, {
    Dio? refreshDio,
  }) : _refreshDio = refreshDio ?? Dio(),
       _refreshTokenUrl =
           '${_dio.options.baseUrl}/admin-api/system/auth/refresh-token';

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
      }
    } else {
      logger.d("AuthInterceptor: Request path excluded from auth.");
    }
    // QueuedInterceptorsWrapper 要求在最后调用 super
    return super.onRequest(options, handler);
  }

  // --- onError ---
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 检查 401 且非刷新接口本身
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.endsWith('/refresh-token')) {
      logger.d(
        'AuthInterceptor: Received 401 error for ${err.requestOptions.path}.',
      );

      // 如果不是首次触发刷新
      if (!_isRefreshing) {
        _isRefreshing = true;
        _refreshCompleter = Completer<void>();
        logger.d('AuthInterceptor: Starting token refresh process.');

        try {
          final refreshToken = await _tokenStorageService.getRefreshToken();
          if (refreshToken == null || refreshToken.isEmpty) {
            logger.d('AuthInterceptor: No refresh token. Deleting tokens.');
            await _tokenStorageService.deleteTokens();
            _isRefreshing = false;
            final error = SessionExpiredException(
              'No refresh token available.',
            );
            _refreshCompleter?.completeError(error); // 通知等待者
            // *** 修改点 2: QueuedInterceptorsWrapper 中直接 reject ***
            return handler.reject(
              DioException(
                requestOptions: err.requestOptions,
                error: error,
                response: err.response,
                type: err.type,
              ),
            );
          }

          logger.d('AuthInterceptor: Calling refresh token API.');
          final refreshResponse = await _refreshDio.post(
            _refreshTokenUrl,
            data: {'refreshToken': refreshToken},
          );
          logger.d(
            'AuthInterceptor: Refresh API response received: ${refreshResponse.data}',
          );

          if (refreshResponse.data is Map<String, dynamic>) {
            final loginResponse = LoginResponse.fromJson(refreshResponse.data);
            if (loginResponse.code == 0 && loginResponse.data != null) {
              // 刷新成功
              final newData = loginResponse.data!;
              logger.d('AuthInterceptor: Token refresh successful.');
              await _tokenStorageService.saveTokens(
                accessToken: newData.accessToken,
                refreshToken:
                    newData.refreshToken.isNotEmpty
                        ? newData.refreshToken
                        : refreshToken,
              );
              logger.d('AuthInterceptor: New tokens saved.');
              _isRefreshing = false;
              _refreshCompleter?.complete(); // 通知等待者成功

              // 更新原始请求的 Header
              err.requestOptions.headers['Authorization'] =
                  'Bearer ${newData.accessToken}';
              logger.d(
                'AuthInterceptor: Retrying original request: ${err.requestOptions.path}',
              );

              // 使用主 _dio 实例重试
              try {
                // *** 修改点 3: 使用 dio.fetch 重试并 resolve ***
                final response = await _dio.fetch(err.requestOptions);
                logger.d(
                  'AuthInterceptor: Original request retried successfully.',
                );
                return handler.resolve(response); // 解决并返回重试后的响应
              } on DioException catch (retryError) {
                logger.d(
                  'AuthInterceptor: Error retrying original request: $retryError',
                );
                // 如果重试失败，则将重试错误传递下去
                return handler.reject(retryError);
              }
            } else {
              // 刷新接口返回业务错误
              logger.d(
                'AuthInterceptor: Refresh API error. Code=${loginResponse.code}, Msg=${loginResponse.msg}. Deleting tokens.',
              );
              await _tokenStorageService.deleteTokens();
              _isRefreshing = false;
              final error = SessionExpiredException(
                'Refresh token invalid/expired. API Msg: ${loginResponse.msg}',
              );
              _refreshCompleter?.completeError(error); // 通知等待者
              return handler.reject(
                DioException(
                  requestOptions: err.requestOptions,
                  error: error,
                  response: err.response,
                  type: err.type,
                ),
              );
            }
          } else {
            // 刷新接口格式错误
            logger.d(
              'AuthInterceptor: Invalid refresh API response format. Deleting tokens.',
            );
            await _tokenStorageService.deleteTokens();
            _isRefreshing = false;
            final error = SessionExpiredException(
              'Invalid response format from refresh API.',
            );
            _refreshCompleter?.completeError(error); // 通知等待者
            return handler.reject(
              DioException(
                requestOptions: err.requestOptions,
                error: error,
                response: err.response,
                type: err.type,
              ),
            );
          }
        } catch (e) {
          // 刷新流程中的其他异常
          logger.d(
            'AuthInterceptor: Exception during refresh flow: $e. Deleting tokens.',
          );
          await _tokenStorageService.deleteTokens();
          _isRefreshing = false;
          _refreshCompleter?.completeError(e); // 通知等待者
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: SessionExpiredException('Failed to refresh token: $e'),
              response: err.response,
              type: err.type,
            ),
          );
        } finally {
          // 确保重置状态
          _isRefreshing = false;
        }
      } else if (_isRefreshing) {
        // 如果当前是 401，但已在刷新中，则等待
        logger.d(
          'AuthInterceptor: Another refresh in progress, waiting for retry ${err.requestOptions.path}',
        );
        try {
          await _refreshCompleter?.future;
          logger.d(
            'AuthInterceptor: Refresh completed for waiting request. Retrying ${err.requestOptions.path}',
          );
          // 刷新完成后重试
          final String? newAccessToken =
              await _tokenStorageService.getAccessToken();
          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            err.requestOptions.headers['Authorization'] =
                'Bearer $newAccessToken';
            // *** 修改点 3 (同上): 使用 dio.fetch 重试并 resolve ***
            final response = await _dio.fetch(err.requestOptions);
            logger.d('AuthInterceptor: Waiting request retried successfully.');
            return handler.resolve(response);
          } else {
            logger.d(
              'AuthInterceptor: Refresh completed, but no token for waiting request. Rejecting.',
            );
            return handler.reject(err);
          }
        } catch (e) {
          logger.d(
            'AuthInterceptor: Waiting request failed because refresh failed: $e. Rejecting.',
          );
          return handler.reject(err); // 拒绝原始错误
        }
      }
    }

    // 如果不是需要处理的 401 错误，则继续传递
    return super.onError(err, handler);
  }

  // onResponse 可以保持默认或根据需要添加逻辑
  // @override
  // void onResponse(Response response, ResponseInterceptorHandler handler) {
  //   return super.onResponse(response, handler);
  // }
}
