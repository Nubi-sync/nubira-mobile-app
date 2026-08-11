import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioClient {
  static final Dio dio = Dio(BaseOptions(
    // NOTE: Change this to your PC's local IP address (e.g., 192.168.1.100:3000) for a physical device
    // Or 10.0.2.2:3000 for Android Emulator
    baseUrl: 'http://10.0.2.2:3000', 
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
}
