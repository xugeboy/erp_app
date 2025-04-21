import '../entities/user.dart';

abstract class AuthRepository {
  Future<User> login({
    required String username,
    required String password,
    required bool rememberMe,
  });

  Future<void> logout();
}