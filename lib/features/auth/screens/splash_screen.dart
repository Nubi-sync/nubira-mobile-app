import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../main.dart';

/// The official Zigza splash screen displaying the brand icon mark,
/// the "ZIGZA" wordmark beneath it, and an enterprise trust badge at the bottom.
class SplashScreen extends ConsumerStatefulWidget {
  final Duration minimumDuration;
  final Widget? destination;

  const SplashScreen({
    super.key,
    this.minimumDuration = const Duration(milliseconds: 2200),
    this.destination,
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _minTimeElapsed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();

    // Ensure splash is visible for at least minimumDuration
    Timer(widget.minimumDuration, () {
      if (mounted) {
        setState(() {
          _minTimeElapsed = true;
        });
        _checkAndNavigate();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _checkAndNavigate() {
    if (_navigated || !mounted) return;

    final authState = ref.read(authProvider);
    if (_minTimeElapsed && !authState.isLoading) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => widget.destination ?? const AuthGate(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth changes so we navigate as soon as both auth finishes & timer has elapsed
    ref.listen<AuthState>(authProvider, (_, nextState) {
      if (_minTimeElapsed && !nextState.isLoading) {
        _checkAndNavigate();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: const SplashScreenView(),
          ),
        ),
      ),
    );
  }
}

/// Standalone presentation view for the Zigza Splash Screen
class SplashScreenView extends StatelessWidget {
  const SplashScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Stack(
        children: [
          // 1. Center Brand Block: Icon + Worded Logo Below
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Brand Icon Mark
                Image.asset(
                  'assets/images/zigza_icon.png',
                  height: 84,
                  width: 84,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/icon.png',
                    height: 84,
                    width: 84,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1220),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Center(
                        child: Icon(Icons.flash_on_rounded, color: Color(0xFF14C8B4), size: 44),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Worded "ZIGZA" Logo Beneath the Icon
                Image.asset(
                  'assets/images/z_i_g_z_a.png',
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/zigza_web_logo.png',
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => RichText(
                      text: TextSpan(
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                        ),
                        children: const [
                          TextSpan(text: 'ZIG', style: TextStyle(color: Color(0xFF0B1220))),
                          TextSpan(text: 'ZA', style: TextStyle(color: Color(0xFF14C8B4))),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Clean Mono Product Identifier
                Text(
                  'SMART FACTORY MES',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // 2. Bottom Trust Badge Block (Solid Presence, Mono-Colored, Rounded Green Outline)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 34.0, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Primary Trust Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Solid Green Tick
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        // Mono-Colored Bold Status Text
                        Text(
                          '100% SAFE & SECURE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Enterprise Security Subtitle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'ENTERPRISE CLOUD SYNC • 256-BIT ENCRYPTION',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

