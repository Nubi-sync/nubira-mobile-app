import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleSpacing: 0,
      centerTitle: true,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.menu_rounded, color: Color(0xFF475569), size: 20),
                ),
              ),
            )
          : null,
      title: Image.asset(
        'assets/images/z_i_g_z_a.png',
        height: 34,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/zigza_logo.png',
          height: 34,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/zigza_main_logo.png',
            height: 34,
            fit: BoxFit.contain,
          ),
        ),
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
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x26000000)),
              ),
              child: Text(
                'ERP MES',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3A3564),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
