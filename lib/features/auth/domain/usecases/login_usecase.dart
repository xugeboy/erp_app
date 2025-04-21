import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _authRepository;

  LoginUseCase(this._authRepository);

  Future<User> execute(String username, String password, bool rememberMe) async {
    return _authRepository.login(username: username,
        password: password,
        rememberMe: rememberMe);
  }
}