import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_brand_logo.dart';
import '../../../core/widgets/zigza_dual_ring_spinner.dart';
import '../providers/auth_provider.dart';
import '../services/register_service.dart';
import 'login_screen.dart';
import '../../modules/screens/enterprise_workspace_hub_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Stepper State (1: Account Setup, 2: Choose Modules, 3: Activated)
  int _currentStep = 1;

  // Step 1 Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus nodes
  final _emailFocusNode = FocusNode();

  // Obscure toggles
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  // Step 1 Validation & Status States
  String? _errorMsg;
  String? _phoneErrorMsg;
  String? _emailErrorMsg;
  String _phoneStatus = 'idle'; // idle | checking | available | error
  String _emailStatus = 'idle'; // idle | checking | available | error

  // Phone OTP States
  bool _isPhoneVerified = false;
  bool _isOtpBoxOpen = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  String? _otpError;
  int _otpCountdown = 0;
  Timer? _countdownTimer;
  String? _verificationToken;

  // 6 Individual OTP controllers & focus nodes
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  // Step 2 Module Selection: Pre-select all 11 modules
  late List<String> _selectedDivisions;

  // Step 3 Activated Details
  bool _isSubmitting = false;
  String _createdCompany = '';
  String _trialExpiresAt = '';

  @override
  void initState() {
    super.initState();
    _selectedDivisions = allTrialModules.map((m) => m.route).toList();

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _triggerEmailCheck();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // PHONE LOGIC
  // ----------------------------------------------------------------------
  void _onPhoneChanged(String val) {
    final raw = val.replaceAll(RegExp(r'\D'), '');
    final phone10 = raw.length > 10 ? raw.substring(0, 10) : raw;

    if (phone10 != _phoneController.text) {
      _phoneController.value = TextEditingValue(
        text: phone10,
        selection: TextSelection.collapsed(offset: phone10.length),
      );
    }

    if (_isPhoneVerified || _isOtpBoxOpen) {
      setState(() {
        _isPhoneVerified = false;
        _isOtpBoxOpen = false;
        _otpError = null;
        _verificationToken = null;
        for (final c in _otpControllers) {
          c.clear();
        }
      });
    }

    if (phone10.length < 10) {
      setState(() {
        _phoneStatus = 'idle';
        _phoneErrorMsg = null;
        _errorMsg = null;
      });
    } else if (phone10.length == 10) {
      _triggerPhoneCheck(phone10);
    }
  }

  Future<void> _triggerPhoneCheck(String phone10) async {
    setState(() {
      _phoneStatus = 'checking';
      _phoneErrorMsg = null;
      _errorMsg = null;
    });

    final res = await RegisterService.checkPhoneAvailability(phone10);
    if (!mounted) return;

    if (res.available) {
      setState(() {
        _phoneStatus = 'available';
        _phoneErrorMsg = null;
      });
    } else {
      setState(() {
        _phoneStatus = 'error';
        _phoneErrorMsg = res.error ?? 'Mobile number already registered to a workspace. Please sign in.';
      });
    }
  }

  Future<void> _handleSendOtp() async {
    final phone10 = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone10.length != 10 || _isSendingOtp) return;

    setState(() {
      _isSendingOtp = true;
      _otpError = null;
      _errorMsg = null;
    });

    final res = await RegisterService.sendPhoneOtp(phone10);
    if (!mounted) return;

    setState(() {
      _isSendingOtp = false;
    });

    if (res.success) {
      setState(() {
        _verificationToken = res.verificationToken;
        _isOtpBoxOpen = true;
        _otpCountdown = 30;
        for (final c in _otpControllers) {
          c.clear();
        }
      });

      _startOtpCountdown();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code sent to +91 $phone10'),
          backgroundColor: const Color(0xFF1D4ED8),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Focus first OTP field
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _otpFocusNodes[0].requestFocus();
        }
      });
    } else {
      setState(() {
        _otpError = res.error ?? 'Failed to deliver OTP. Please try again.';
      });
    }
  }

  void _startOtpCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpCountdown <= 1) {
        timer.cancel();
        setState(() => _otpCountdown = 0);
      } else {
        setState(() => _otpCountdown--);
      }
    });
  }

  void _handleOtpDigitChange(int index, String val) {
    final digit = val.replaceAll(RegExp(r'\D'), '');
    if (digit.isNotEmpty) {
      _otpControllers[index].text = digit.substring(digit.length - 1);
      _otpControllers[index].selection =
          TextSelection.collapsed(offset: _otpControllers[index].text.length);

      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        // Auto-verify on 6th digit
        _handleVerifyOtp();
      }
    }
    setState(() => _otpError = null);
  }

  Future<void> _handleVerifyOtp() async {
    final fullCode = _otpControllers.map((c) => c.text).join();
    if (fullCode.length != 6) {
      setState(() => _otpError = 'Please enter the complete 6-digit OTP.');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _otpError = null;
    });

    final phone10 = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final res = RegisterService.verifyPhoneOtp(
      rawPhone: phone10,
      userOtp: fullCode,
      verificationToken: _verificationToken,
    );

    if (!mounted) return;

    setState(() {
      _isVerifyingOtp = false;
    });

    if (res.success) {
      setState(() {
        _isPhoneVerified = true;
        _isOtpBoxOpen = false;
        _otpError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mobile number verified successfully!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _otpError = res.error ?? 'Incorrect OTP code. Please check and re-enter.';
      });
    }
  }

  // ----------------------------------------------------------------------
  // EMAIL LOGIC
  // ----------------------------------------------------------------------
  Future<void> _triggerEmailCheck() async {
    final cleanEmail = _emailController.text.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      setState(() {
        _emailStatus = 'idle';
        _emailErrorMsg = null;
      });
      return;
    }

    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      setState(() {
        _emailStatus = 'error';
        _emailErrorMsg = 'Enter a valid email address.';
      });
      return;
    }

    setState(() {
      _emailStatus = 'checking';
      _emailErrorMsg = null;
    });

    final res = await RegisterService.checkEmailAvailability(cleanEmail);
    if (!mounted) return;

    if (res.available) {
      setState(() {
        _emailStatus = 'available';
        _emailErrorMsg = null;
      });
    } else {
      setState(() {
        _emailStatus = 'error';
        _emailErrorMsg = res.error ?? 'Email already registered. Please sign in.';
      });
    }
  }

  // ----------------------------------------------------------------------
  // PASSWORD STRENGTH & MATCH LOGIC
  // ----------------------------------------------------------------------
  int _calculateStrengthScore(String pass) {
    if (pass.isEmpty) return 0;
    if (pass.length < 6) return 1;

    final hasUpper = RegExp(r'[A-Z]').hasMatch(pass);
    final hasLower = RegExp(r'[a-z]').hasMatch(pass);
    final hasNumber = RegExp(r'[0-9]').hasMatch(pass);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(pass);

    final count = (hasUpper ? 1 : 0) + (hasLower ? 1 : 0) + (hasNumber ? 1 : 0) + (hasSymbol ? 1 : 0);
    if (count <= 1) return 1;
    if (count == 2) return 2;
    if (count == 3) return 3;
    return 4;
  }

  String _get5WordRecommendation(String pass) {
    if (pass.isEmpty) return 'Use at least 6 characters';
    if (pass.length < 6) return 'Needs at least 6 characters';
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pass);
    final hasNumber = RegExp(r'[0-9]').hasMatch(pass);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(pass);

    if (!hasUpper && !hasNumber && !hasSymbol) return 'Add uppercase, numbers, and symbols';
    if (!hasUpper && !hasNumber) return 'Add uppercase letters and numbers';
    if (!hasUpper && !hasSymbol) return 'Add uppercase letters and symbols';
    if (!hasNumber && !hasSymbol) return 'Add numbers and special symbols';
    if (!hasUpper) return 'Add uppercase letters to strengthen';
    if (!hasNumber) return 'Add numbers to improve strength';
    if (!hasSymbol) return 'Add symbols to improve strength';
    return 'Great! Your password is secure';
  }

  // ----------------------------------------------------------------------
  // STEP 1 -> STEP 2 NAVIGATION
  // ----------------------------------------------------------------------
  Future<void> _handleStep1Next() async {
    setState(() => _errorMsg = null);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.length < 2) {
      setState(() => _errorMsg = 'Please enter your full contact person name.');
      return;
    }

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMsg = 'Please enter a valid work email address.');
      return;
    }

    if (phone.length != 10) {
      setState(() => _errorMsg = 'Please enter a valid 10-digit Indian mobile number.');
      return;
    }

    if (_phoneStatus == 'error') {
      setState(() => _errorMsg = _phoneErrorMsg ?? 'Please use a different mobile number.');
      return;
    }

    if (!_isPhoneVerified) {
      setState(() => _errorMsg = 'Please verify your mobile number with OTP before continuing.');
      if (!_isOtpBoxOpen && _phoneStatus == 'available') {
        _handleSendOtp();
      }
      return;
    }

    if (pass.length < 6) {
      setState(() => _errorMsg = 'Password must be at least 6 characters long.');
      return;
    }

    if (pass != confirm) {
      setState(() => _errorMsg = 'Passwords do not match. Please re-enter to confirm.');
      return;
    }

    if (_emailStatus == 'error') {
      setState(() => _errorMsg = _emailErrorMsg ?? 'Please use a different work email.');
      return;
    }

    // Double check email availability if not yet verified
    if (_emailStatus != 'available') {
      final emailRes = await RegisterService.checkEmailAvailability(email);
      if (!emailRes.available) {
        setState(() {
          _emailStatus = 'error';
          _emailErrorMsg = emailRes.error;
          _errorMsg = emailRes.error;
        });
        return;
      }
      setState(() => _emailStatus = 'available');
    }

    setState(() {
      _currentStep = 2;
      _errorMsg = null;
    });
  }

  // ----------------------------------------------------------------------
  // STEP 2 -> STEP 3 FINAL SUBMIT
  // ----------------------------------------------------------------------
  Future<void> _handleFinalSubmit() async {
    if (_selectedDivisions.isEmpty) {
      setState(() => _errorMsg = 'Please select at least 1 production module to test.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });

    final payload = FreeTrialRegistrationPayload(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      phone: _phoneController.text.replaceAll(RegExp(r'\D'), ''),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      selectedDivisions: _selectedDivisions,
    );

    final res = await RegisterService.registerFreeTrial(payload);
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (res.success) {
      setState(() {
        _createdCompany = res.companyName ?? RegisterService.deriveCompanyName(_nameController.text);
        _trialExpiresAt = res.expiresAt ?? '';
        _currentStep = 3;
      });

      // Auto-authenticate into local Riverpod auth session
      ref.read(authProvider.notifier).login(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text,
        rememberMe: true,
      );
    } else {
      setState(() {
        _errorMsg = res.error ?? 'Registration failed. Please check your details and retry.';
      });
    }
  }

  // ----------------------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final derivedCompany = RegisterService.deriveCompanyName(_nameController.text);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Watermark Background Fixed to Screen Bounds (Identical to LoginScreen)
          Positioned(
            top: 0,
            left: 0,
            width: screenSize.width,
            height: screenSize.height,
            child: RepaintBoundary(
              child: Opacity(
                opacity: 0.10,
                child: Image.asset(
                  'assets/images/factory_bg_tinted_sketch.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // 2. Main Scrollable Content with Welcome Back Screen Alignment & Font
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: isKeyboardOpen ? 8.0 : 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row: Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (_currentStep == 2) {
                            setState(() => _currentStep = 1);
                          } else if (_currentStep == 1) {
                            Navigator.pop(context);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF0F172A), width: 1.2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0C000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isKeyboardOpen ? 4 : 10),

                  // Official Zigza Brand Logo (Exact matching LoginScreen)
                  Center(
                    child: ZigzaBrandLogo(
                      iconHeight: isKeyboardOpen ? 28 : 36,
                      logoHeight: isKeyboardOpen ? 22 : 28,
                      spacing: 9,
                    ),
                  ),
                  SizedBox(height: isKeyboardOpen ? 12 : 20),

                  // Stepper Pill & Progress Bar (Matching Welcome Back style)
                  _buildStepperHeader(),
                  SizedBox(height: isKeyboardOpen ? 12 : 18),

                  // Clean Hero Header
                  Center(
                    child: Text(
                      _currentStep == 1
                          ? 'Create Factory Account'
                          : (_currentStep == 2 ? 'Choose Modules' : 'Trial Activated'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isKeyboardOpen ? 22 : 25,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Center(
                    child: Text(
                      _currentStep == 1
                          ? 'Enter your details to begin your 7-day free trial'
                          : (_currentStep == 2
                              ? 'All 11 enterprise units are pre-selected for your trial'
                              : 'Your enterprise apparel MES account is now active'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.publicSans(
                        fontSize: isKeyboardOpen ? 12.5 : 13.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: isKeyboardOpen ? 14 : 22),

                  // Error Banner if any
                  if (_errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFE11D48)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMsg!,
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
                    const SizedBox(height: 16),
                  ],

                  // Form Content (Matches Welcome Back Input Style exactly)
                  if (_currentStep == 1)
                    _buildStep1AccountSetup(isKeyboardOpen)
                  else if (_currentStep == 2)
                    _buildStep2ChooseModules(derivedCompany)
                  else
                    _buildStep3Activated(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // STEPPER PROGRESS WIDGET
  // ----------------------------------------------------------------------
  Widget _buildStepperHeader() {
    String stepLabel = 'Account Setup';
    if (_currentStep == 2) stepLabel = 'Choose Modules';
    if (_currentStep == 3) stepLabel = 'Trial Ready';

    final progressFactor = _currentStep == 1 ? 0.333 : (_currentStep == 2 ? 0.667 : 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STEP $_currentStep OF 3',
              style: GoogleFonts.publicSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D4ED8),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              stepLabel,
              style: GoogleFonts.publicSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Animated Royal Blue Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 4,
            width: double.infinity,
            color: const Color(0xFFE2E8F0),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressFactor,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------------
  // STEP 1: ACCOUNT SETUP (Exact Welcome Back Styling)
  // ----------------------------------------------------------------------
  Widget _buildStep1AccountSetup(bool isKeyboardOpen) {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final strengthScore = _calculateStrengthScore(password);
    final recommendationTip = _get5WordRecommendation(password);
    final passwordsMatch = confirmPassword.isNotEmpty && password == confirmPassword;

    Color strengthColor = const Color(0xFFE11D48);
    String strengthText = 'Too Short';
    if (strengthScore == 2) {
      strengthColor = const Color(0xFFD97706);
      strengthText = 'Fair';
    } else if (strengthScore == 3) {
      strengthColor = const Color(0xFF2563EB);
      strengthText = 'Good';
    } else if (strengthScore == 4) {
      strengthColor = const Color(0xFF059669);
      strengthText = 'Strong';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. CONTACT PERSON NAME
        Text(
          'Contact Person Name',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 19, color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (_) {
              if (_errorMsg != null) setState(() => _errorMsg = null);
            },
          ),
        ),
        SizedBox(height: isKeyboardOpen ? 10 : 16),

        // 2. MOBILE NUMBER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mobile Number',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            if (_isPhoneVerified)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: GoogleFonts.publicSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              )
            else if (_phoneStatus == 'checking')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Checking...',
                    style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                ],
              )
            else if (_phoneStatus == 'available')
              Text(
                'Available',
                style: GoogleFonts.publicSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF059669),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _phoneStatus == 'error'
                  ? const Color(0xFFE11D48)
                  : (_isPhoneVerified
                      ? const Color(0xFF10B981)
                      : const Color(0xFFCBD5E1)),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // +91 Flag Strip matching LoginScreen
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(13)),
                  border: Border(right: BorderSide(color: Color(0xFFCBD5E1))),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      '+91',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                  ],
                ),
              ),

              // Phone Number Input
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  enabled: !_isPhoneVerified,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter 10-digit number',
                    hintStyle: GoogleFonts.publicSans(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  onChanged: _onPhoneChanged,
                ),
              ),

              // Right Button: Send OTP / Verified
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _isPhoneVerified
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, size: 14, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: GoogleFonts.publicSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: (_phoneController.text.length == 10 &&
                                  _phoneStatus == 'available' &&
                                  !_isSendingOtp)
                              ? _handleSendOtp
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFF1F5F9),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSendingOtp
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _isOtpBoxOpen ? 'Resend' : 'Send OTP',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
              ),
            ],
          ),
        ),

        // Live Phone Error Message (matching website red error)
        if (_phoneStatus == 'error' && _phoneErrorMsg != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.close_rounded, size: 14, color: Color(0xFFE11D48)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _phoneErrorMsg!,
                  style: GoogleFonts.publicSans(
                    fontSize: 11.5,
                    color: const Color(0xFFE11D48),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Verified Change Link
        if (_isPhoneVerified) ...[
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Phone authenticated with SMS OTP',
                style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF059669)),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isPhoneVerified = false;
                    _phoneController.clear();
                    _phoneStatus = 'idle';
                  });
                },
                child: Text(
                  'Change',
                  style: GoogleFonts.publicSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D4ED8),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],

        // --- INLINE 6-DIGIT OTP VERIFICATION BOX ---
        if (_isOtpBoxOpen && !_isPhoneVerified) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vpn_key_rounded, size: 16, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 6),
                        Text(
                          'Enter 6-Digit Code',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0B1220),
                          ),
                        ),
                      ],
                    ),
                    if (_otpCountdown > 0)
                      Text(
                        'Resend in ${_otpCountdown}s',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _handleSendOtp,
                        child: Text(
                          'Resend OTP',
                          style: GoogleFonts.publicSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D4ED8),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'SMS OTP sent to +91 ${_phoneController.text}',
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),

                // 6 Individual Digit Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (idx) {
                    return SizedBox(
                      width: 44,
                      height: 48,
                      child: TextField(
                        controller: _otpControllers[idx],
                        focusNode: _otpFocusNodes[idx],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0B1220),
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.8),
                          ),
                        ),
                        onChanged: (val) => _handleOtpDigitChange(idx, val),
                      ),
                    );
                  }),
                ),

                if (_otpError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _otpError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.publicSans(
                      fontSize: 11.5,
                      color: const Color(0xFFE11D48),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Verify Button
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _isVerifyingOtp ? null : _handleVerifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isVerifyingOtp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Verify OTP',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: isKeyboardOpen ? 10 : 16),

        // 3. WORK EMAIL
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Work Email',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            if (_emailStatus == 'checking')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Checking...',
                    style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                ],
              )
            else if (_emailStatus == 'available')
              Text(
                'Available',
                style: GoogleFonts.publicSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF059669),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _emailStatus == 'error'
                  ? const Color(0xFFE11D48)
                  : (_emailStatus == 'available'
                      ? const Color(0xFF10B981)
                      : const Color(0xFFCBD5E1)),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'name@company.com',
              hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.alternate_email_rounded, size: 19, color: Color(0xFF64748B)),
              suffixIcon: _emailStatus == 'available'
                  ? const Icon(Icons.check_circle_rounded, size: 19, color: Color(0xFF059669))
                  : (_emailStatus == 'error'
                      ? const Icon(Icons.error_outline_rounded, size: 19, color: Color(0xFFE11D48))
                      : null),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (_) {
              if (_emailStatus != 'idle') setState(() => _emailStatus = 'idle');
              if (_errorMsg != null) setState(() => _errorMsg = null);
            },
          ),
        ),
        if (_emailStatus == 'error' && _emailErrorMsg != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.close_rounded, size: 14, color: Color(0xFFE11D48)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _emailErrorMsg!,
                  style: GoogleFonts.publicSans(
                    fontSize: 11.5,
                    color: const Color(0xFFE11D48),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: isKeyboardOpen ? 10 : 16),

        // 4. PASSWORD
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            if (password.isNotEmpty)
              Text(
                strengthText,
                style: GoogleFonts.publicSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: strengthColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Min 6 characters',
              hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19, color: Color(0xFF64748B)),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 19,
                  color: const Color(0xFF64748B),
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // 4-Segment Strength Meter
        if (password.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: List.generate(4, (idx) {
              final active = strengthScore >= (idx + 1);
              return Expanded(
                child: Container(
                  height: 3.5,
                  margin: EdgeInsets.only(right: idx < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: active ? strengthColor : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                recommendationTip,
                style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
              Text(
                '${password.length} chars (min 6)',
                style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
        SizedBox(height: isKeyboardOpen ? 10 : 16),

        // 5. CONFIRM PASSWORD
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Confirm Password',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            if (confirmPassword.isNotEmpty)
              Text(
                passwordsMatch ? '✓ Match' : '✗ No match',
                style: GoogleFonts.publicSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: passwordsMatch ? const Color(0xFF059669) : const Color(0xFFE11D48),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: confirmPassword.isNotEmpty
                  ? (passwordsMatch ? const Color(0xFF10B981) : const Color(0xFFE11D48))
                  : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Re-enter password',
              hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.vpn_key_outlined, size: 19, color: Color(0xFF64748B)),
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 19,
                  color: const Color(0xFF64748B),
                ),
                onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(height: isKeyboardOpen ? 16 : 24),

        // Primary Button: Next: Choose Modules
        Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x381D4ED8),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _handleStep1Next,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next: Choose Modules',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Already have an account? Sign in
        Center(
          child: GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Already have an account? ',
                    style: GoogleFonts.publicSans(
                      fontSize: 13.5,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: 'Sign in',
                    style: GoogleFonts.publicSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------------
  // STEP 2: CHOOSE MODULES (Matches Welcome Back Theme)
  // ----------------------------------------------------------------------
  Widget _buildStep2ChooseModules(String derivedCompany) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Factory Workspace Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.business_rounded, size: 18, color: Color(0xFF0B1220)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$derivedCompany (Auto-Assigned)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedDivisions.length} of ${allTrialModules.length} Active',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDivisions = allTrialModules.map((m) => m.route).toList();
                          });
                        },
                        child: Text(
                          'Select All',
                          style: GoogleFonts.publicSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDivisions = [];
                          });
                        },
                        child: Text(
                          'Clear',
                          style: GoogleFonts.publicSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 11 Modules List
        ...allTrialModules.map((mod) {
          final isSelected = _selectedDivisions.contains(mod.route);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDivisions.remove(mod.route);
                  } else {
                    _selectedDivisions.add(mod.route);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0B1220) : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.2 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1D4ED8) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      mod.code,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? const Color(0xFF0B1220) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mod.name,
                        style: GoogleFonts.publicSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),

        // Action Buttons: Back + Continue
        Row(
          children: [
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.publicSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x381D4ED8),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleFinalSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ZigzaDualRingSpinner(
                              size: 19,
                              strokeWidth: 2.2,
                              outerColor: Colors.white,
                              innerColor: Color(0xFF67E8F9),
                            ),
                            SizedBox(width: 10),
                            Text('Activating 7-Day Trial...'),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Start 7-Day Trial',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------------------------
  // STEP 3: ACTIVATED & READY
  // ----------------------------------------------------------------------
  Widget _buildStep3Activated() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.4), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1014C8B4),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 36,
              color: Color(0xFF14C8B4),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Text(
              '7 DAYS ACTIVATED',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF059669),
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Welcome, ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B1220),
                ),
              ),
              TextSpan(
                text: _createdCompany,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
              TextSpan(
                text: '!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B1220),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your enterprise apparel MES account is now active with full access to your selected divisions.',
          textAlign: TextAlign.center,
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: const Color(0xFF64748B),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),

        // Confirmation Slip
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSlipRow('Admin Email', _emailController.text.trim().toLowerCase()),
              const Divider(color: Color(0xFFF1F5F9), height: 20),
              _buildSlipRow('Active Divisions', '${_selectedDivisions.length} of ${allTrialModules.length} Units Live'),
              const Divider(color: Color(0xFFF1F5F9), height: 20),
              _buildSlipRow('Trial Validity', '7 Days Remaining', highlightGreen: true),
              const Divider(color: Color(0xFFF1F5F9), height: 20),
              _buildSlipRow('Access Role', 'Super Admin (Full Plant AI)'),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Primary: Launch Floor Workspace
        Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x381D4ED8),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Launch Floor Workspace',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary: Sign in with Credentials
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Sign in with Credentials',
              style: GoogleFonts.publicSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlipRow(String label, String value, {bool highlightGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: highlightGreen ? const Color(0xFF059669) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
