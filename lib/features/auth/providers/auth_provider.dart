import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final String? userRole;
  
  AuthState({this.isLoading = false, this.error, this.isAuthenticated = false, this.userRole});
  
  AuthState copyWith({bool? isLoading, String? error, bool? isAuthenticated, String? userRole}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userRole: userRole ?? this.userRole,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _checkToken();
  }

  Future<void> _checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('access_token') != null) {
      state = state.copyWith(
        isAuthenticated: true,
        userRole: prefs.getString('user_role'),
      );
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await DioClient.dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });
      
      final token = response.data['access_token'];
      final role = response.data['user']['role'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      await prefs.setString('user_role', role);
      
      state = state.copyWith(isLoading: false, isAuthenticated: true, userRole: role);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false, 
        error: e.response?.data['message'] ?? 'Network Error',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Unknown Error occurred');
    }
  }
  
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_role');
    state = state.copyWith(isAuthenticated: false);
  }
}
