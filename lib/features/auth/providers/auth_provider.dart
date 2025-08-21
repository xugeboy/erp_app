import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/interceptors/auth_interceptor.dart';
import '../../../core/providers/storage_provider.dart';
import '../../../core/providers/token_manager_provider.dart';
import '../data/datasources/auth_remote_data_source.dart';
import '../data/datasources/auth_remote_data_source_impl.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/login_usecase.dart';
import '../presentation/notifiers/login_notifier.dart';
import '../presentation/state/login_state.dart';
import 'auth_state.dart';
import 'auth_state_notifier.dart';

// 提供 AuthRemoteDataSource 实例
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
      (ref) => AuthRemoteDataSourceImpl(ref.read(dioProvider)),
);

// 提供 AuthRepository 实例
final authRepositoryProvider = Provider<AuthRepository>(
      (ref) => AuthRepositoryImpl(
    ref.read(authRemoteDataSourceProvider),
    ref.read(tokenStorageProvider), // <--- 将 tokenStorageProvider 传入
  ),
);

// 提供 LoginUseCase 实例
final loginUseCaseProvider = Provider<LoginUseCase>(
      (ref) => LoginUseCase(ref.read(authRepositoryProvider)),
);

// 提供 LoginNotifier 实例 (状态管理)
final loginNotifierProvider = StateNotifierProvider<LoginNotifier, LoginState>(
      (ref) => LoginNotifier(ref.read(loginUseCaseProvider),ref),
);

// 定义一个 StateProvider 来持有可空的 User 对象
final userProvider = StateProvider<User?>((ref) {
  // 初始状态为 null，表示未登录
  return null;
});

// 提供 Dio 实例
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();

  // 添加 Base URL (如果所有 API 都有相同的前缀)
  dio.options.baseUrl = "https://erp.xiangleratchetstrap.com";

  // 添加我们的认证拦截器，并传入会话过期回调
  final tokenStorage = ref.read(tokenStorageProvider); // 获取 TokenStorageService
  dio.interceptors.add(AuthInterceptor(
    tokenStorage, 
    dio,
    onSessionExpired: () {
      // 当会话过期时，通知认证状态变更
      ref.read(authStateProvider.notifier).setUnauthenticated();
    },
  ));
  return dio;
});

// Provider for AuthStateNotifier
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthStatus>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider); // 使用 watch 确保服务可用
  return AuthStateNotifier(tokenStorage, ref);
});

// 新增：提供TokenManager的启动/停止控制
final tokenManagementControllerProvider = Provider<TokenManagementController>((ref) {
  return TokenManagementController(ref);
});

// 新增：TokenManagementController类
class TokenManagementController {
  final Ref _ref;
  
  TokenManagementController(this._ref);
  
  // 启动token管理
  void startTokenManagement() {
    _ref.read(tokenManagementProvider.notifier).startManagement();
  }
  
  // 停止token管理
  void stopTokenManagement() {
    _ref.read(tokenManagementProvider.notifier).stopManagement();
  }
  
  // 手动刷新token
  Future<bool> manualRefreshToken() async {
    final tokenManager = _ref.read(tokenManagerProvider);
    return await tokenManager.manualRefreshToken();
  }
  
  // 获取token状态
  Future<Map<String, dynamic>> getTokenStatus() async {
    final tokenManager = _ref.read(tokenManagerProvider);
    return await tokenManager.getTokenStatus();
  }
}
