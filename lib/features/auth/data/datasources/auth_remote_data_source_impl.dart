import 'package:dio/dio.dart';
import '../../../../core/utils/logger.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import 'auth_remote_data_source.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  final String loginUrl = 'https://erp.xiangleratchetstrap.com/admin-api/system/auth/login';
  final String logoutUrl = 'https://erp.xiangleratchetstrap.com/admin-api/system/auth/logout';
  final String profileUrl = 'https://erp.xiangleratchetstrap.com/admin-api/system/user/profile/get';

  AuthRemoteDataSourceImpl(this.dio);

  @override
  Future<LoginResponse> performLogin(LoginRequest loginRequest) async {
    try {
      final response = await dio.post(
        loginUrl,
        // 使用 LoginRequest 的 toJson 方法生成请求体
        data: loginRequest.toJson(),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      // 检查响应数据是否为 Map 类型
      if (response.data is Map<String, dynamic>) {
        // 使用 LoginResponse 的 fromJson 工厂方法解析响应
        return LoginResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Invalid response format received from server.');
      }
    } on DioException catch (e) {
      // 可以选择在这里处理 DioException，或者重新抛出让 Repository 处理
      logger.d("DioException in DataSource: ${e.response?.data ?? e.message}");
      // 尝试从 Dio 错误响应中解析 LoginResponse（如果后端在错误时也返回相同结构）
      if (e.response?.data is Map<String, dynamic>) {
        try {
          return LoginResponse.fromJson(e.response!.data as Map<String, dynamic>);
        } catch (_) {
          // 如果解析失败，则抛出原始 DioException 或通用错误
          rethrow; // 或者抛出自定义错误
        }
      }
      rethrow; // 重新抛出原始 DioException
    } catch (e) {
      logger.d("Unexpected error in DataSource: $e");
      throw Exception('Data source error: $e');
    }
  }

  @override
  Future<void> performLogout() async {
    try {
      // 注意：登出请求通常也需要带上有效的 Access Token
      await dio.post(logoutUrl); // 或 delete, 根据后端设计
      logger.d("Logout successful on backend.");
    } on DioException catch (e) {
      // 处理登出接口可能发生的错误，但通常不影响客户端强制登出
      logger.d("Error calling backend logout: ${e.message}");
    }
  }

  // 实现获取 Profile 的方法
  @override
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      // 注意：这个请求会自动被 AuthInterceptor 拦截并添加 Authorization Header
      logger.d("DataSource: Getting user profile from $profileUrl");
      final response = await dio.get(profileUrl); // 使用 GET 请求

      if (response.data is Map<String, dynamic>) {
        logger.d("DataSource: Profile response received: ${response.data}");
        return response.data as Map<String, dynamic>;
      } else {
        logger.e("DataSource: Invalid profile response format. Expected Map, got ${response.data?.runtimeType}");
        throw Exception('Invalid profile response format received.');
      }
    } on DioException catch (e) { // 使用 DioException
      // 让 Repository 处理错误细节
      logger.e("DataSource: DioException getting profile", error: e);
      rethrow;
    } catch (e, stackTrace) {
      logger.e("DataSource: Unexpected error getting profile", error: e, stackTrace: stackTrace);
      throw Exception('Failed to get user profile: $e');
    }
  }
}