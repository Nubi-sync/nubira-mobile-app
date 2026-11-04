import 'package:flutter/material.dart';

/// Reusable Zigza Brand Logo displaying the official brand icon mark
/// alongside the crisp "ZIGZA" wordmark, exactly matching the web app.
class ZigzaBrandLogo extends StatelessWidget {
  final double iconHeight;
  final double logoHeight;
  final double spacing;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;

  const ZigzaBrandLogo({
    super.key,
    this.iconHeight = 28,
    this.logoHeight = 22,
    this.spacing = 8,
    this.mainAxisSize = MainAxisSize.min,
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: mainAxisSize,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/zigza_icon.png',
          height: iconHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/icon.png',
            height: iconHeight,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        SizedBox(width: spacing),
        Image.asset(
          'assets/images/zigza_web_logo.png',
          height: logoHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/zigza_new_logo.png',
            height: logoHeight,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

