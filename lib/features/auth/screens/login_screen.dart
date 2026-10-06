import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../main.dart';
import '../providers/auth_provider.dart';
import '../../dashboard/lineman_dashboard.dart';
import '../../dashboard/qc_dashboard.dart';
import '../../dashboard/store_dashboard.dart';
import '../../dashboard/dispatch_dashboard.dart';
import '../../dashboard/production_manager_dashboard.dart';
import '../../dashboard/mending_dashboard.dart';
import '../../design/screens/designer_dashboard_screen.dart';
import '../../modules/screens/enterprise_workspace_hub_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _inputController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPhoneMode = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  // Field validation states
  String? _inputError;
  String? _passwordError;

  // Lockout countdown timer
  Timer? _lockoutTimer;
  int _remainingLockoutSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOperatorId = prefs.getString('remembered_operator_id');
    if (savedOperatorId != null && savedOperatorId.trim().isNotEmpty) {
      final text = savedOperatorId.trim();
      final isDigits = RegExp(r'^[0-9]+$').hasMatch(text);
      if (mounted) {
        setState(() {
          _isPhoneMode = isDigits && text.length == 10;
          _inputController.text = text;
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
    _inputController.dispose();
    _passwordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _handleSubmit() {
    final rawInput = _inputController.text.trim();
    final password = _passwordController.text;

    setState(() {
      if (rawInput.isEmpty) {
        _inputError = _isPhoneMode ? "Mobile number can't be empty" : "Email can't be empty";
      } else if (_isPhoneMode && rawInput.replaceAll(RegExp(r'\D'), '').length != 10) {
        _inputError = "Enter a valid 10-digit mobile number";
      } else {
        _inputError = null;
      }
      _passwordError = password.isEmpty ? "Password can't be empty" : null;
    });

    if (_inputError != null || _passwordError != null) return;

    ref.read(authProvider.notifier).login(
      rawInput,
      password,
      rememberMe: _rememberMe,
    );
  }

  void _showForgotPasswordModal() {
    int currentStep = 1;
    final emailCtrl = TextEditingController(text: !_isPhoneMode ? _inputController.text.trim() : '');
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String? modalError;
    String? modalStatus;
    bool isPending = false;
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final bottomInset = MediaQuery.of(modalCtx).viewInsets.bottom;

            Future<void> sendOtp() async {
              final em = emailCtrl.text.trim();
              if (em.isEmpty || !em.contains('@')) {
                setModalState(() => modalError = 'Please enter a valid registered email.');
                return;
              }
              setModalState(() {
                isPending = true;
                modalError = null;
                modalStatus = null;
              });

              try {
                await supabase.auth.resetPasswordForEmail(em);
                setModalState(() {
                  isPending = false;
                  modalStatus = '6-digit OTP sent to your registered email.';
                  currentStep = 2;
                });
              } catch (e) {
                setModalState(() {
                  isPending = false;
                  modalError = 'Unable to send OTP. Please check email or contact Admin.';
                });
              }
            }

            Future<void> verifyOtp() async {
              final em = emailCtrl.text.trim();
              final token = otpCtrl.text.trim();
              if (token.length < 6) {
                setModalState(() => modalError = 'Please enter the 6-digit code.');
                return;
              }
              setModalState(() {
                isPending = true;
                modalError = null;
              });

              try {
                await supabase.auth.verifyOTP(
                  email: em,
                  token: token,
                  type: OtpType.recovery,
                );
                setModalState(() {
                  isPending = false;
                  currentStep = 3;
                });
              } catch (e) {
                setModalState(() {
                  isPending = false;
                  modalError = 'Invalid or expired OTP token. Please retry.';
                });
              }
            }

            Future<void> setNewPassword() async {
              final np = newPassCtrl.text;
              final cp = confirmPassCtrl.text;
              if (np.length < 6) {
                setModalState(() => modalError = 'Password must be at least 6 characters.');
                return;
              }
              if (np != cp) {
                setModalState(() => modalError = 'Passwords do not match.');
                return;
              }
              setModalState(() {
                isPending = true;
                modalError = null;
              });

              try {
                await supabase.auth.updateUser(UserAttributes(password: np));
                setModalState(() {
                  isPending = false;
                  isSuccess = true;
                });
                Future.delayed(const Duration(milliseconds: 1400), () {
                  if (mounted && Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password updated successfully! Please sign in.'),
                          backgroundColor: Color(0xFF0F766E),
                        ),
                      );
                    }
                  }
                });
              } catch (e) {
                setModalState(() {
                  isPending = false;
                  modalError = 'Failed to update password. Please try again.';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: bottomInset + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                          ),
                          child: Icon(
                            currentStep == 1
                                ? Icons.vpn_key_outlined
                                : (currentStep == 2 ? Icons.shield_outlined : Icons.lock_outline_rounded),
                            color: const Color(0xFF0B1220),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentStep == 1
                                    ? 'Reset Password'
                                    : (currentStep == 2 ? 'Verify Security Code' : 'Set New Password'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0B1220),
                                ),
                              ),
                              Text(
                                'Step $currentStep of 3 · Factory Security Verification',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (modalStatus != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                modalStatus!,
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  color: const Color(0xFF065F46),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (modalError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                modalError!,
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  color: const Color(0xFFBE123C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (isSuccess) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF14C8B4), size: 48),
                            SizedBox(height: 10),
                            Text(
                              'Password Updated!',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ] else if (currentStep == 1) ...[
                      Text(
                        'REGISTERED EMAIL',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.publicSans(fontSize: 13.5, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Enter your email',
                          hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.mail_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: isPending ? null : sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 46),
                          elevation: 0,
                        ),
                        child: isPending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Send Verification OTP',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ] else if (currentStep == 2) ...[
                      Text(
                        '6-DIGIT VERIFICATION CODE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: otpCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '123456',
                          hintStyle: GoogleFonts.jetBrainsMono(fontSize: 18, letterSpacing: 4, color: const Color(0xFFCBD5E1)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: isPending ? null : verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 46),
                          elevation: 0,
                        ),
                        child: isPending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Verify Security Code',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ] else if (currentStep == 3) ...[
                      Text(
                        'NEW PASSWORD',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: newPassCtrl,
                        obscureText: true,
                        style: GoogleFonts.publicSans(fontSize: 13.5, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'At least 6 characters',
                          hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'CONFIRM NEW PASSWORD',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: confirmPassCtrl,
                        obscureText: true,
                        style: GoogleFonts.publicSans(fontSize: 13.5, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Re-enter new password',
                          hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.lock_reset_rounded, size: 18, color: Color(0xFF94A3B8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: isPending ? null : setNewPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 46),
                          elevation: 0,
                        ),
                        child: isPending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Save New Password',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAdminContactDialog();
                        },
                        child: Text(
                          'Need admin help instead? Contact Admin',
                          style: GoogleFonts.publicSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAdminContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF0F766E), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Plant Admin Reset',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B1220),
              ),
            ),
          ],
        ),
        content: Text(
          'Shop floor operator accounts are provisioned and managed by factory administration.\n\nPlease contact your Plant Admin or Line Supervisor to reset your password.',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: const Color(0xFF5B6478),
            height: 1.45,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showLegalDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF5B6478), height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFreeTrialSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF1D4ED8), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start 7-Day Free Trial',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                          Text(
                            'Set up your garment factory workspace in 2 minutes.',
                            style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTrialFeature('Full Access to 8 Factory Production Modules'),
                      const SizedBox(height: 6),
                      _buildTrialFeature('Unlimited Linemen & Tailor Real-time Tablets'),
                      const SizedBox(height: 6),
                      _buildTrialFeature('Automatic Multi-tenant Data Isolation'),
                      const SizedBox(height: 6),
                      _buildTrialFeature('Zero Credit Card Required to Start'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please visit zigza.in on your desktop browser to register your factory.'),
                        backgroundColor: Color(0xFF1D4ED8),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Register Factory Account →',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrialFeature(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for Auth Changes & Route to Dashboards
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && next.userRole != null) {
        final roleUpper = next.userRole!.toUpperCase();
        Widget destination;

        switch (roleUpper) {
          case 'STORE':
          case 'STORE_SUPERVISOR':
          case 'GODOWN':
            destination = const StoreDashboard();
            break;
          case 'DISPATCH':
          case 'LOGISTICS':
            destination = const DispatchDashboard();
            break;
          case 'PRODUCTION_MANAGER':
            destination = const ProductionManagerDashboard();
            break;
          case 'PRODUCTION':
          case 'QC':
          case 'AQL_INSPECTOR':
            destination = const QcDashboard();
            break;
          case 'MENDING':
          case 'ALTERATION':
          case 'REPAIR_TAILOR':
            destination = const MendingDashboard();
            break;
          case 'DESIGNER':
            destination = const DesignerDashboardScreen();
            break;
          case 'LINEMAN':
          case 'STITCHING_SUPERVISOR':
          case 'STITCHING':
            destination = const LinemanDashboard();
            break;
          default:
            if (next.isMultiDivisionUser ||
                roleUpper == 'ADMIN' ||
                roleUpper == 'SUPERADMIN' ||
                roleUpper == 'PLATFORM_SUPERADMIN' ||
                roleUpper == 'DEPARTMENT_HEAD') {
              destination = const EnterpriseWorkspaceHubScreen();
            } else {
              destination = const LinemanDashboard();
            }
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
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          // ==========================================
          // 1. FULL PAGE WALLPAPER BACKGROUND (ISOMETRIC SKETCH)
          // ==========================================
          Positioned.fill(
            child: Opacity(
              opacity: 0.28,
              child: Image.asset(
                'assets/images/factory_bg_tinted_sketch.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // ==========================================
          // 2. MAIN SCROLLABLE CONTENT
          // ==========================================
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- TOP HEADER: BRAND LOGO (CLEAN & CENTERED/LEFT) ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/images/icon.png',
                            height: 32,
                            width: 32,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          Image.asset(
                            'assets/images/z_i_g_z_a.png',
                            height: 18,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Text(
                              'ZIGZA',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // --- CENTERED WHITE CARD (CONTAINING FACTORY PHOTO & FORM) ---
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.85)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Factory Photo Banner inside Card (Indian Garment Manufacturing Floor)
                          Container(
                            height: 165,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/images/factory_handshake_art.jpg',
                              fit: BoxFit.cover,
                              alignment: const Alignment(0.0, 0.36),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Staff Portal Heading
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Staff ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0B1220),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Portal',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1D4ED8),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Access your factory floor allotments and live logs.',
                            style: GoogleFonts.publicSans(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3. Work Email / Mobile (+91) Toggle Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _isPhoneMode ? '10-DIGIT MOBILE' : 'WORK EMAIL',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF475569),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isPhoneMode = !_isPhoneMode;
                                    _inputError = null;
                                    _inputController.clear();
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!_isPhoneMode) ...[
                                        const Text('🇮🇳', style: TextStyle(fontSize: 13)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Use Mobile (+91)',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0B1220),
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ] else ...[
                                        const Icon(Icons.mail_outline_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Use Email',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0B1220),
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // 4. Input Field (Email or Phone +91 prefix)
                          if (_isPhoneMode)
                            Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _inputError != null ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF0FDFA),
                                      borderRadius: BorderRadius.horizontal(left: Radius.circular(11)),
                                      border: Border(
                                        right: BorderSide(color: Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('🇮🇳', style: TextStyle(fontSize: 13)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+91',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0B1220),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _inputController,
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      onChanged: (_) {
                                        if (_inputError != null) setState(() => _inputError = null);
                                      },
                                      decoration: InputDecoration(
                                        counterText: '',
                                        hintText: 'Enter 10-digit mobile number',
                                        hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _inputError != null ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: TextField(
                                controller: _inputController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.publicSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                                onChanged: (_) {
                                  if (_inputError != null) setState(() => _inputError = null);
                                },
                                decoration: InputDecoration(
                                  hintText: 'Enter your email',
                                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                                  prefixIcon: const Icon(Icons.mail_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),

                          if (_inputError != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _inputError!,
                              style: GoogleFonts.publicSans(
                                fontSize: 11,
                                color: const Color(0xFFE11D48),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // 5. Password Field
                          Text(
                            'PASSWORD',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF475569),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _passwordError != null ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: GoogleFonts.publicSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                              onChanged: (_) {
                                if (_passwordError != null) setState(() => _passwordError = null);
                              },
                              onSubmitted: (_) => _handleSubmit(),
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  onPressed: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),

                          if (_passwordError != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _passwordError!,
                              style: GoogleFonts.publicSans(
                                fontSize: 11,
                                color: const Color(0xFFE11D48),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),

                          // 6. Remember Me & Forgot Password Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          activeColor: const Color(0xFF0B1220),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (val) => setState(() => _rememberMe = val ?? true),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Keep me signed in',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 12.5,
                                          color: const Color(0xFF475569),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _showForgotPasswordModal,
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0B1220),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 7. Error Banner
                          if (authState.error != null && !authState.isLoading) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFECDD3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      authState.error!,
                                      style: GoogleFonts.publicSans(
                                        fontSize: 11.5,
                                        color: const Color(0xFFBE123C),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 8. Submit Button: "Sign In to Dashboard →"
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: (authState.isLoading || isLocked) ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D4ED8),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFF1D4ED8).withValues(alpha: 0.6),
                                elevation: 1,
                                shadowColor: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                          'Signing in...',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          isLocked ? 'Locked ($lockoutTimeString)' : 'Sign In to Dashboard',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
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
                          const SizedBox(height: 14),

                          // 9. Free Trial Link
                          Center(
                            child: GestureDetector(
                              onTap: _showFreeTrialSheet,
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'New to Zigza? ',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Start 7-Day Free Trial →',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 12,
                                        color: const Color(0xFF1D4ED8),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- FOOTER SECTION (OUTSIDE CARD, ON TOP OF BACKGROUND PATTERN) ---
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Proudly Made in India',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 14.5,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0B1220),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('🇮🇳', style: TextStyle(fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _showLegalDialog(
                                'Privacy Policy',
                                'Zigza strictly isolates all factory tenant records, worker allotments, production logs, and designs. Zero third-party telemetry is shared.',
                              ),
                              child: Text(
                                'Privacy',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _showLegalDialog(
                                'Terms of Service',
                                'Standard enterprise service level agreement for real-time garment production execution and multi-division management.',
                              ),
                              child: Text(
                                'Terms',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _showLegalDialog(
                                'Enterprise Security',
                                'End-to-end encrypted session tokens, Supabase Row-Level Security (RLS) enforcement, and strict multi-tenant authorization barriers.',
                              ),
                              child: Text(
                                'Security',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '© 2026 Zigza. All rights reserved.',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
