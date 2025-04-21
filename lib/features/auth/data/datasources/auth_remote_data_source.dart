// lib/features/auth/data/datasources/auth_remote_data_source.dart
import '../models/login_request.dart';
import '../models/login_response.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponse> performLogin(LoginRequest loginRequest);
  Future<void> performLogout();
  Future<Map<String, dynamic>> getUserProfile();
}