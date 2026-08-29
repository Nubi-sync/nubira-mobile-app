import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../main.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isNetworkError;
  final bool isAuthenticated;
  final String? userRole;
  final String? cachedUsername;
  final int failedAttempts;
  final DateTime? lockoutUntil;
  final bool isOfflineSession;

  AuthState({
    this.isLoading = false,
    this.error,
    this.isNetworkError = false,
    this.isAuthenticated = false,
    this.userRole,
    this.cachedUsername,
    this.failedAttempts = 0,
    this.lockoutUntil,
    this.isOfflineSession = false,
  });

  bool get isLockedOut {
    if (lockoutUntil == null) return false;
    return DateTime.now().isBefore(lockoutUntil!);
  }

  int get remainingLockoutSeconds {
    if (lockoutUntil == null) return 0;
    final diff = lockoutUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isNetworkError,
    bool? isAuthenticated,
    String? userRole,
    String? cachedUsername,
    int? failedAttempts,
    DateTime? lockoutUntil,
    bool? isOfflineSession,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isNetworkError: isNetworkError ?? this.isNetworkError,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userRole: userRole ?? this.userRole,
      cachedUsername: cachedUsername ?? this.cachedUsername,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutUntil: lockoutUntil ?? this.lockoutUntil,
      isOfflineSession: isOfflineSession ?? this.isOfflineSession,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const _storage = FlutterSecureStorage();
  static const _maxAttempts = 5;
  static const _lockoutMinutes = 15;

  AuthNotifier() : super(AuthState(isAuthenticated: false)) {
    _initAuth();
  }

  Future<void> _initAuth() async {
    final prefs = await SharedPreferences.getInstance();

    // Check Lockout Status
    final lockoutMillis = prefs.getInt('login_lockout_until');
    DateTime? lockoutDate;
    if (lockoutMillis != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(lockoutMillis);
      if (DateTime.now().isBefore(dt)) {
        lockoutDate = dt;
      } else {
        await prefs.remove('login_lockout_until');
        await prefs.setInt('login_failed_attempts', 0);
      }
    }

    final attempts = prefs.getInt('login_failed_attempts') ?? 0;
    final savedUsername = prefs.getString('remembered_operator_id');

    state = state.copyWith(
      failedAttempts: attempts,
      lockoutUntil: lockoutDate,
      cachedUsername: savedUsername,
      isAuthenticated: false, // NO AUTO LOGIN: Operator must tap Login to Dashboard
    );
  }

  Future<void> login(String username, String password, {bool rememberMe = true}) async {
    if (state.isLockedOut) {
      state = state.copyWith(
        error: 'Account locked due to too many attempts. Please wait or contact your admin.',
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null, isNetworkError: false);

    final prefs = await SharedPreferences.getInstance();

    // Persist or clear Remember ID
    if (rememberMe) {
      await prefs.setString('remembered_operator_id', username.trim());
      state = state.copyWith(cachedUsername: username.trim());
    } else {
      await prefs.remove('remembered_operator_id');
      state = state.copyWith(cachedUsername: null);
    }

    // Check Connectivity
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.isEmpty || connectivity.every((r) => r == ConnectivityResult.none);

    if (isOffline) {
      // Offline Login via Cached Credentials
      final cachedUserId = await _storage.read(key: 'cached_user_id');
      final cachedRole = await _storage.read(key: 'cached_user_role');

      if (cachedUserId != null && cachedRole != null) {
        state = state.copyWith(
          isAuthenticated: true,
          userRole: cachedRole,
          isOfflineSession: true,
          isLoading: false,
        );
        return;
      } else {
        state = state.copyWith(
          isLoading: false,
          isNetworkError: true,
          error: "Couldn't reach the server — check your connection.",
        );
        return;
      }
    }

    try {
      final email = username.contains('@') ? username : '${username.trim()}@nubira.local';

      final authRes = await supabase.auth.signInWithPassword(
        email: email.toLowerCase(),
        password: password,
      );

      final session = authRes.session;
      final user = authRes.user;

      if (user != null) {
        String role = 'LINEMAN';
        try {
          final res = await supabase
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .single();
          if (res['role'] != null) {
            role = res['role'] as String;
          }
        } catch (_) {}

        if (session != null) {
          await _cacheSessionForOffline(session, role);
        }

        // Reset attempts on successful sign-in
        await prefs.setInt('login_failed_attempts', 0);
        await prefs.remove('login_lockout_until');

        state = state.copyWith(
          isAuthenticated: true,
          userRole: role,
          isLoading: false,
          failedAttempts: 0,
          lockoutUntil: null,
        );
      }
    } on AuthException catch (e) {
      final newAttempts = state.failedAttempts + 1;
      await prefs.setInt('login_failed_attempts', newAttempts);

      DateTime? lockout;
      if (newAttempts >= _maxAttempts) {
        lockout = DateTime.now().add(const Duration(minutes: _lockoutMinutes));
        await prefs.setInt('login_lockout_until', lockout.millisecondsSinceEpoch);
      }

      state = state.copyWith(
        isLoading: false,
        failedAttempts: newAttempts,
        lockoutUntil: lockout,
        isNetworkError: false,
        error: e.message.contains('Invalid login credentials')
            ? 'Incorrect ID or password.'
            : e.message,
      );
    } catch (e) {
      final isNetwork = e.toString().contains('SocketException') || e.toString().contains('ClientException');
      state = state.copyWith(
        isLoading: false,
        isNetworkError: isNetwork,
        error: isNetwork
            ? "Couldn't reach the server — check your connection."
            : 'An unexpected authentication error occurred.',
      );
    }
  }

  Future<void> _cacheSessionForOffline(Session session, String? role) async {
    try {
      await _storage.write(key: 'cached_access_token', value: session.accessToken);
      await _storage.write(key: 'cached_refresh_token', value: session.refreshToken);
      await _storage.write(key: 'cached_user_id', value: session.user.id);
      if (role != null) {
        await _storage.write(key: 'cached_user_role', value: role);
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
      await _storage.deleteAll();
      state = state.copyWith(
        isAuthenticated: false,
        userRole: null,
        isOfflineSession: false,
      );
    } catch (_) {}
  }
}