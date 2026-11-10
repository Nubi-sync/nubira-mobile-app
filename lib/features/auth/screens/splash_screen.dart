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
          // 1. Center Brand Block: Elevated by -28px for optical center alignment
          Center(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Brand Icon Mark - scaled to 140px to match Android's native launch icon seamlessly
                  Image.asset(
                    'assets/images/zigza_icon.png',
                    height: 140,
                    width: 140,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/icon.png',
                      height: 140,
                      width: 140,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1220),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: const Center(
                          child: Icon(Icons.flash_on_rounded, color: Color(0xFF14C8B4), size: 70),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Worded "ZIGZA" Logo Beneath the Icon
                  Image.asset(
                    'assets/images/z_i_g_z_a.png',
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/zigza_web_logo.png',
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => RichText(
                        text: TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
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

                  const SizedBox(height: 13),

                  // Meaningful Indian Trust Tagline in English letters with italic font style
                  Text(
                    'Aapka Vishwas • Hamara Bharosa',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.0,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Bottom Trust Badge Block (Authentic Indian Enterprise Trust Badge - Much Bigger & Bold)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 44.0, left: 24, right: 24),
              child: Image.asset(
                'assets/images/indian_trust_badge.png',
                height: 68,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 1.8,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'BHARAT TRUSTED • 100% SAFE & VERIFIED',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: 0.8,
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

