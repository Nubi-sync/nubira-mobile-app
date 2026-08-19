import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart'; // To access the global supabase client

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final String? userRole;
  
  AuthState({
    this.isLoading = false, 
    this.error, 
    this.isAuthenticated = false, 
    this.userRole
  });
  
  AuthState copyWith({
    bool? isLoading, 
    String? error, 
    bool? isAuthenticated, 
    String? userRole
  }) {
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
    _initAuthListener();
  }

  void _initAuthListener() {
    // Listen to Supabase auth state changes (automatically handles secure storage)
    supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        // Fetch role from profiles table
        try {
          final res = await supabase
            .from('profiles')
            .select('role')
            .eq('id', session.user.id)
            .single();
          
          final role = res['role'] as String?;
          state = state.copyWith(
            isAuthenticated: true,
            userRole: role,
            isLoading: false,
          );
        } catch (e) {
          state = state.copyWith(
            isAuthenticated: false,
            error: 'Failed to fetch user role.',
            isLoading: false,
          );
        }
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          userRole: null,
          isLoading: false,
        );
      }
    });
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // In Supabase we use email for login. We generate the faux email from username.
      final email = username.contains('@') ? username : '$username@nubira.local';
      
      await supabase.auth.signInWithPassword(
        email: email.toLowerCase(),
        password: password,
      );
      
      // onAuthStateChange listener will automatically update the state once signed in
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false, 
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false, 
        error: 'An unknown error occurred.',
      );
    }
  }
  
  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}
