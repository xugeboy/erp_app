
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/login_usecase.dart';
import '../../providers/auth_provider.dart';
import '../state/login_state.dart';

class LoginNotifier extends StateNotifier<LoginState> {
  final LoginUseCase _loginUseCase;
  final Ref ref; // 通过 Provider 获取 ref，或者直接传入 ref

  // 修改构造函数以接收 Ref (如果你的 Provider 是这样创建的)
  // 或者 LoginNotifier 的 Provider 直接 read authStateProvider.notifier
  LoginNotifier(this._loginUseCase, this.ref) : super(const LoginState());

  Future<void> login(String username, String password, bool rememberMe) async {
    state = state.copyWith(status: LoginStatus.loading, errorMessage: null);
    try {
      final user = await _loginUseCase.execute(username, password, rememberMe);
      state = state.copyWith(status: LoginStatus.success, user: user);

      ref.read(userProvider.notifier).state = user;
      ref.read(authStateProvider.notifier).setAuthenticated();
    } catch (e) {
      state = state.copyWith(status: LoginStatus.failure, errorMessage: e.toString());
      // 登录失败不需要改变 AuthStatus，它应该还是 unauthenticated
    }
  }
}