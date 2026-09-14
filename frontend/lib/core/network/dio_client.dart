import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class DioClient {
  final Dio dio;
  final SecureStorage secureStorage;

  DioClient({required String baseUrl, required this.secureStorage})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await secureStorage.getAccessToken();
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            // Attempt to refresh token
            final refreshToken = await secureStorage.getRefreshToken();
            if (refreshToken != null) {
              try {
                // Call refresh endpoint directly using a new Dio instance to avoid interceptor loop
                final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
                final response = await refreshDio.post('/api/v1/auth/refresh', data: {
                  'refresh_token': refreshToken,
                });
                
                if (response.statusCode == 200) {
                  final newAccessToken = response.data['data']['access_token'];
                  
                  // We update only the access token here, assuming refresh token remains valid
                  await secureStorage.saveTokens(
                    accessToken: newAccessToken,
                    refreshToken: refreshToken,
                  );
                  
                  // Retry the original request
                  final opts = error.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $newAccessToken';
                  final cloneReq = await dio.fetch(opts);
                  return handler.resolve(cloneReq);
                }
              } catch (e) {
                // Refresh failed, clear tokens
                await secureStorage.clearTokens();
              }
            } else {
              // No refresh token available
              await secureStorage.clearTokens();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}
