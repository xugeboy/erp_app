import 'package:dio/dio.dart';

import '../../../../core/storage/token_storage_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final TokenStorageService _tokenStorageService;
  final String _tenantName = "芋道源码";

  AuthRepositoryImpl(this._remoteDataSource,this._tokenStorageService);

  @override
  Future<User> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    // 1. 创建 LoginRequest 对象
    final loginRequest = LoginRequest(
      tenantName: _tenantName,
      username: username,
      password: password,
      rememberMe: rememberMe,
    );

    LoginResponseData? loginData; // 用于存储登录成功后的 token 数据

    try {
      // --- Step 1: 执行登录获取 Token ---
      logger.d("Repository: Attempting login for user '$username'");
      final LoginResponse loginResponse = await _remoteDataSource.performLogin(loginRequest);

      if (loginResponse.code == 0 && loginResponse.data != null) {
        loginData = loginResponse.data!;
        logger.i("Repository: Login successful. Got tokens.");

        // --- Step 2: 立刻保存 Token ---
        // 必须先保存 Token，后续的 Profile 请求才能通过拦截器认证
        await _tokenStorageService.saveTokens(
          accessToken: loginData.accessToken,
          refreshToken: loginData.refreshToken,
        );
        logger.i("Repository: Tokens saved securely.");

        // --- Step 3: 获取用户 Profile 信息 ---
        logger.d("Repository: Fetching user profile...");
        final Map<String, dynamic> profileApiResponse = await _remoteDataSource.getUserProfile();
        final int profileCode = profileApiResponse['code'] as int? ?? -1;
        final String profileMsg = profileApiResponse['msg'] as String? ?? 'Failed to parse profile message';

        if (profileCode == 0 && profileApiResponse['data'] != null) {
          logger.i("Repository: User profile fetched successfully.");
          final Map<String, dynamic> profileData = profileApiResponse['data'] as Map<String, dynamic>;
          // final Map<String, dynamic>? userData = profileData['user'] as Map<String, dynamic>?;
          final List<dynamic>? rolesData = profileData['roles'] as List<dynamic>?;
          final Map<String, dynamic>? deptData = profileData['dept'] as Map<String, dynamic>?;

          if (profileData != null) {
            // --- Step 4: 构建完整的 User 实体 ---
            final user = User(
              id: (profileData['id'] as int? ?? loginData.userId).toString(), // 优先用 profile 的 id， fallback 到 login 的
              username: username, // 使用登录用户名
              nickname: profileData['nickname'] as String,
              deptId: deptData?['id'] as int,
              // 将 List<dynamic> 转换为 List<String>
              roles: rolesData?.map((role) => role.toString()).toList() ?? [],
            );
            logger.i("Repository: Complete User object created: ${user.toString()}");
            await _tokenStorageService.saveUser(user);
            return user; // 返回完整的 User 对象
          } else {
            logger.e("Repository: Profile API success (code 0), but 'user' data is missing.");
            throw Exception('Login partially failed: Could not retrieve user profile details.');
          }
        } else {
          // Profile 获取失败 (code != 0)
          logger.e("Repository: Failed to fetch user profile. Code: $profileCode, Msg: $profileMsg");
          // 即使 Profile 失败，Token 可能已保存。是否回滚？
          // 决定：认为获取 Profile 是登录成功的必要条件，抛出错误。
          await _tokenStorageService.deleteTokens(); // 清除刚保存的 token
          throw Exception('Login partially failed: Could not retrieve user profile ($profileMsg)');
        }
      } else {
        // 登录本身就失败了 (code != 0)
        logger.w("Repository: Login API failed. Code: ${loginResponse.code}, Msg: ${loginResponse.msg}");
        throw Exception('Login failed: ${loginResponse.msg} (Code: ${loginResponse.code})');
      }
    } on DioException catch (e) { // 使用 DioException
      logger.e("Repository: Network error during login/profile fetch", error: e);
      // 如果是因为 Profile 获取失败导致的 DioException，Token 可能已保存，需要清除吗？
      // 暂时不清除，让上层决定重试或登出。但如果错误是 401，拦截器会处理。
      throw Exception('Network error during login. Please check connection.');
    } catch (e, stackTrace) {
      logger.e("Repository: Unexpected error during login flow", error: e, stackTrace: stackTrace);
      // 发生未知错误时，最好也尝试清除可能已保存的 token
      if (loginData != null) { // 只有登录成功后才可能保存过
        await _tokenStorageService.deleteTokens();
      }
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    try {
      // 1. (可选) 调用后端登出接口
      await _remoteDataSource.performLogout();
    } catch (e) {
      // 记录错误，但继续执行本地登出
      logger.d("Error during backend logout, proceeding with local logout: $e");
    } finally {
      // 2. 无论后端是否成功，都必须清除本地 Token
      await _tokenStorageService.deleteTokens();
      await _tokenStorageService.deleteUser();
    }
  }

}