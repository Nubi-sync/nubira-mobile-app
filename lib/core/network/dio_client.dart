import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DioClient {
  static final Dio dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000'), 
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          const storage = FlutterSecureStorage();
          await storage.delete(key: 'access_token');
          await storage.delete(key: 'user_role');
          // Since we use Riverpod, the authProvider state manages UI, 
          // but we can clear storage so next app reload drops them to login.
          // In a full app, we'd trigger a logout event.
        }
        return handler.next(e);
      }
    ));
}
