import 'package:dio/dio.dart';
import '../domain/user.dart';
import '../../../core/storage/secure_storage.dart';

class AuthRepository {
  final Dio dio;
  final SecureStorage secureStorage;

  AuthRepository({required this.dio, required this.secureStorage});

  Future<User> register({
    required String fullName,
    required String email,
    required String password,
    String baseCurrency = "IDR",
  }) async {
    try {
      final response = await dio.post('/api/v1/auth/register', data: {
        "full_name": fullName,
        "email": email,
        "password": password,
        "base_currency": baseCurrency,
      });

      final data = response.data['data'];
      final tokens = data['tokens'];
      
      await secureStorage.saveTokens(
        accessToken: tokens['access_token'],
        refreshToken: tokens['refresh_token'],
      );

      return User.fromJson(data['user']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Registration failed');
    }
  }

  Future<User> login({required String email, required String password}) async {
    try {
      final response = await dio.post('/api/v1/auth/login', data: {
        "email": email,
        "password": password,
      });

      final data = response.data['data'];
      final tokens = data['tokens'];
      
      await secureStorage.saveTokens(
        accessToken: tokens['access_token'],
        refreshToken: tokens['refresh_token'],
      );

      return User.fromJson(data['user']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Login failed');
    }
  }

  Future<void> logout() async {
    await secureStorage.clearTokens();
  }

  Future<User?> checkAuth() async {
    final token = await secureStorage.getAccessToken();
    if (token == null) return null;

    try {
      final response = await dio.get('/api/v1/auth/me');
      return User.fromJson(response.data['data']['user']);
    } catch (_) {
      return null;
    }
  }
}
