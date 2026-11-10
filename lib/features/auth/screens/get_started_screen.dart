import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_brand_logo.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Get Started / Landing Screen presented on sign out and initial launch.
/// Displays a full-screen factory visual with an expanded bottom sheet
/// featuring official Zigza brand mark, Welcome headline, and website-aligned action buttons.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Screen Background Image with Contrast Gradients
          Image.asset(
            'assets/images/zigza_launch_bg_cabin.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/zigza_launch_bg_official_logo.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/factory_handshake_art.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ),

          // Gradient scrim to ensure top status bar and bottom sheet contrast
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000), // Top shade for status bar
                  Colors.transparent,
                  Color(0x33000000),
                  Color(0xE60B1220), // Bottom blend into sheet
                ],
                stops: [0.0, 0.25, 0.60, 1.0],
              ),
            ),
          ),

          // 2. Expanded Bottom Sheet with Top-Left Brand Logo, Welcome Text, and Web-Styled Buttons
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 24,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Centered Top Sheet Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. Official Zigza Icon + Wordmark Logo (Top-Left)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: ZigzaBrandLogo(
                        iconHeight: 32,
                        logoHeight: 24,
                        spacing: 9,
                        mainAxisAlignment: MainAxisAlignment.start,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title & Tagline
                    Text(
                      'Welcome to Zigza',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Aapka Vishwas • Hamara Bharosa',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Primary Button: Login (Website Royal Electric Blue #1D4ED8)
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already a user? Log In',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Secondary Button: Get Started (Website Brand Mint & Teal Tint #F0FDFA / #14C8B4)
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF0FDFA),
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(
                            color: Color(0xFF14C8B4),
                            width: 1.5,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'New here? Get Started',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0B1220),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
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
