import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ZigzaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuPressed;
  final Widget? trailing;
  final bool showMenu;

  const ZigzaAppBar({
    super.key,
    this.onMenuPressed,
    this.trailing,
    this.showMenu = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.cardSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleSpacing: 0,
      centerTitle: true,
      shape: const Border(
        bottom: BorderSide(color: AppTheme.borderLight, width: 0.8),
      ),
      leading: showMenu
          ? Center(
              child: InkWell(
                onTap: () {
                  if (onMenuPressed != null) {
                    onMenuPressed!();
                  } else {
                    Scaffold.of(context).openDrawer();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: const Icon(Icons.menu_rounded, color: AppTheme.headingObsidian, size: 20),
                ),
              ),
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/zigza_web_logo.png',
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/zigza_new_logo.png',
              height: 24,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
      actions: [
        if (trailing != null)
          trailing!
        else
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.badgeMintBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.badgeMintBorder),
              ),
              child: Text(
                'ERP MES',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.badgeMintText,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
