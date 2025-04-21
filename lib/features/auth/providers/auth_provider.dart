import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/interceptors/auth_interceptor.dart';
import '../../../core/providers/storage_provider.dart';
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
  dio.options.baseUrl = "https://erp.xiangletools.store:30443";

  // 添加日志拦截器 (可选, 用于调试)
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    requestHeader: true,
  ));

  // 添加我们的认证拦截器
  final tokenStorage = ref.read(tokenStorageProvider); // 获取 TokenStorageService
  dio.interceptors.add(AuthInterceptor(tokenStorage, dio /*, refreshDio: ... */));

  // 可以设置超时等其他 Dio 选项
  // dio.options.connectTimeout = Duration(seconds: 5);
  // dio.options.receiveTimeout = Duration(seconds: 3);

  return dio;
});

// Provider for AuthStateNotifier
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthStatus>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider); // 使用 watch 确保服务可用
  return AuthStateNotifier(tokenStorage);
});
