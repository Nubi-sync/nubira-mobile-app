import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../../dashboard/lineman_dashboard.dart';
import '../../dashboard/qc_dashboard.dart';
import '../../dashboard/store_dashboard.dart';
import '../../dashboard/dispatch_dashboard.dart';
import '../../dashboard/production_manager_dashboard.dart';
import '../../dashboard/mending_dashboard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/connectivity_indicator.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;

  // Field validation states
  String? _usernameError;
  String? _passwordError;

  // App version tag
  String _appVersion = 'v1.0.0';

  // Lockout countdown timer
  Timer? _lockoutTimer;
  int _remainingLockoutSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version}';
        });
      }
    } catch (_) {}

    // Pre-fill remembered username directly from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedOperatorId = prefs.getString('remembered_operator_id');
    if (savedOperatorId != null && savedOperatorId.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _usernameController.text = savedOperatorId.trim();
          _rememberMe = true;
        });
      }
    }

    _checkLockoutTimer();
  }

  void _checkLockoutTimer() {
    final authState = ref.read(authProvider);
    if (authState.isLockedOut) {
      _remainingLockoutSeconds = authState.remainingLockoutSeconds;
      _lockoutTimer?.cancel();
      _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingLockoutSeconds <= 1) {
          timer.cancel();
          setState(() {
            _remainingLockoutSeconds = 0;
          });
        } else {
          setState(() {
            _remainingLockoutSeconds--;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _handleSubmit() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _usernameError = username.isEmpty ? "Operator ID can't be empty" : null;
      _passwordError = password.isEmpty ? "Password can't be empty" : null;
    });

    if (username.isEmpty || password.isEmpty) return;

    ref.read(authProvider.notifier).login(
      username,
      password,
      rememberMe: _rememberMe,
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.steelMist,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_reset_rounded, color: AppTheme.steel, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Password Recovery',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.ink,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Shop floor operator accounts are provisioned and managed by factory administration.\n\nPlease contact your Plant Admin or Line Supervisor to reset your password.',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: AppTheme.inkSoft,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.steel,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              minimumSize: const Size(100, 40),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Understood',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for Auth Changes & Route to Dashboards
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && next.userRole != null) {
        Widget destination;
        switch (next.userRole) {
          case 'DISPATCH':
            destination = const DispatchDashboard();
            break;
          case 'STORE':
            destination = const StoreDashboard();
            break;
          case 'PRODUCTION_MANAGER':
          case 'PRODUCTION':
            destination = const ProductionManagerDashboard();
            break;
          case 'QC':
            destination = const QcDashboard();
            break;
          case 'MENDING':
            destination = const MendingDashboard();
            break;
          case 'LINEMAN':
          default:
            destination = const LinemanDashboard();
            break;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
      }

      if (next.isLockedOut && (previous == null || !previous.isLockedOut)) {
        _checkLockoutTimer();
      }
    });

    final isLocked = authState.isLockedOut || _remainingLockoutSeconds > 0;
    final lockoutMin = _remainingLockoutSeconds ~/ 60;
    final lockoutSec = _remainingLockoutSeconds % 60;
    final lockoutTimeString = '${lockoutMin.toString().padLeft(2, '0')}:${lockoutSec.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Factory Line Art Sketch with warm brand overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.30,
              child: Image.asset(
                'assets/images/factory_bg_sketch.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      
                      // ==========================================
                      // 1. BRAND HEADER
                      // ==========================================
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.border, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.steel.withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                  // 1. Single Brand Header Line
                  Text(
                    'Zigza',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Connectivity Banner
                  const ConnectivityIndicator(showLabel: true),
                  const SizedBox(height: 14),

                  // ==========================================
                  // 2. MAIN FORM CONTAINER (NO WHITE BG, ROUNDED)
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        
                        // Operator ID Field
                        Text(
                          'OPERATOR ID',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppTheme.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _usernameController,
                          enabled: !authState.isLoading && !isLocked,
                          scrollPadding: const EdgeInsets.only(bottom: 220),
                          textInputAction: TextInputAction.next,
                          style: GoogleFonts.publicSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink,
                          ),
                          onChanged: (val) {
                            if (_usernameError != null) {
                              setState(() => _usernameError = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter your Operator ID',
                            filled: true,
                            fillColor: _usernameError != null ? AppTheme.redMist : Colors.white,
                            prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.steel, size: 20),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: _usernameError != null ? AppTheme.red : AppTheme.border,
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppTheme.steel,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                        if (_usernameError != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 13, color: AppTheme.red),
                              const SizedBox(width: 4),
                              Text(
                                _usernameError!,
                                style: GoogleFonts.publicSans(
                                  fontSize: 11,
                                  color: AppTheme.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Password Field
                        Text(
                          'PASSWORD',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppTheme.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enabled: !authState.isLoading && !isLocked,
                          scrollPadding: const EdgeInsets.only(bottom: 180),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleSubmit(),
                          style: GoogleFonts.publicSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink,
                          ),
                          onChanged: (val) {
                            if (_passwordError != null) {
                              setState(() => _passwordError = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            filled: true,
                            fillColor: _passwordError != null ? AppTheme.redMist : Colors.white,
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.steel, size: 20),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: _passwordError != null ? AppTheme.red : AppTheme.border,
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppTheme.steel,
                                width: 1.8,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppTheme.inkFaint,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        if (_passwordError != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 13, color: AppTheme.red),
                              const SizedBox(width: 4),
                              Text(
                                _passwordError!,
                                style: GoogleFonts.publicSans(
                                  fontSize: 10.5,
                                  color: AppTheme.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Remember Me & Forgot Password Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Remember Me Checkbox
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _rememberMe = !_rememberMe;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: AppTheme.steel,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        onChanged: (val) {
                                          setState(() {
                                            _rememberMe = val ?? true;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Remember ID',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 12,
                                        color: AppTheme.inkSoft,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Forgot Password Link
                            GestureDetector(
                              onTap: _showForgotPasswordDialog,
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.steel,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ==========================================
                        // 4. LOGIN BUTTON (IDLE / LOADING / LOCKOUT)
                        // ==========================================
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (authState.isLoading || isLocked) ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.steel,
                              disabledBackgroundColor: AppTheme.steel.withValues(alpha: 0.55),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: authState.isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Signing in…',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isLocked ? 'Locked ($lockoutTimeString)' : 'Login to Dashboard',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (!isLocked) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                                      ],
                                    ],
                                  ),
                          ),
                        ),

                        // Verifying with server caption
                        if (authState.isLoading) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Verifying with server…',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              color: AppTheme.inkFaint,
                            ),
                          ),
                        ],

                        // ==========================================
                        // 5. ERROR STATE & ATTEMPT TRACKING
                        // ==========================================
                        if (authState.error != null && !authState.isLoading) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.redMist,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: AppTheme.red.withValues(alpha: 0.3), width: 1),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        authState.isNetworkError
                                            ? "Couldn't reach server"
                                            : isLocked
                                                ? "Too many failed attempts"
                                                : "Incorrect ID or password",
                                        style: GoogleFonts.publicSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.red,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        authState.isNetworkError
                                            ? "Please check your Wi-Fi or mobile data."
                                            : isLocked
                                                ? "Try again in $lockoutTimeString, or contact your admin."
                                                : "Double-check with your admin if you're not sure.",
                                        style: GoogleFonts.publicSans(
                                          fontSize: 11,
                                          color: AppTheme.red.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLocked && authState.failedAttempts > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${authState.failedAttempts} of 5 attempts used',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                color: AppTheme.inkFaint,
                              ),
                            ),
                          ],
                        ],

                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ==========================================
                  // 6. VERSION FOOTER
                  // ==========================================
                  Text(
                    'ZIGZA · $_appVersion',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.inkFaint,
                      letterSpacing: 1.2,
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
  }
}

