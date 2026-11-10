import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/core/widgets/zigza_brand_logo.dart';
import 'package:mobile_app/core/widgets/live_date_time_header.dart';
import 'package:mobile_app/features/modules/screens/department_heads_screen.dart';
import 'package:mobile_app/features/design/screens/sa_design_approvals_screen.dart';
import 'package:mobile_app/features/cutting/screens/cutting_lay_floor_screen.dart';
import 'package:mobile_app/features/dashboard/lineman_dashboard.dart';
import 'package:mobile_app/features/modules/screens/company_profile_screen.dart';
import 'package:mobile_app/features/admin/screens/profile_screen.dart';
import 'package:mobile_app/features/cutting/screens/cutting_notifications_screen.dart';

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
      titleSpacing: 8,
      centerTitle: false,
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
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu_rounded, color: Color(0xFF0B1220), size: 20),
                ),
              ),
            )
          : null,
      title: const LiveDateTimeHeader(),
      actions: [
        if (trailing != null)
          trailing!
        else ...[
          // 1. + ⌵ Quick Actions Dropdown Button
          _buildQuickActionsButton(context),
          const SizedBox(width: 8),

          // 2. Notification Bell
          _buildNotificationButton(context),
          const SizedBox(width: 8),

          // 3. User Avatar
          _buildUserButton(context),
          const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _buildQuickActionsButton(BuildContext context) {
    return Center(
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: PopupMenuButton<String>(
          offset: const Offset(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
          color: Colors.white,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          padding: EdgeInsets.zero,
          tooltip: 'Quick Actions',
          onSelected: (value) {
            switch (value) {
              case 'appoint_head':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DepartmentHeadsScreen()),
                );
                break;
              case 'design_approvals':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SADesignApprovalsScreen()),
                );
                break;
              case 'cutting_floor':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CuttingLayFloorScreen()),
                );
                break;
              case 'sewing_dashboard':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LinemanDashboard()),
                );
                break;
              case 'company_profile':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CompanyProfileScreen()),
                );
                break;
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem<String>(
              enabled: false,
              height: 32,
              child: Text(
                'QUICK ACTIONS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'appoint_head',
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.people_alt_rounded, size: 16, color: Color(0xFF059669)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Appoint Department Head',
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'design_approvals',
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Review Design Approvals',
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'cutting_floor',
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.content_cut_rounded, size: 16, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Open Cutting Floor',
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'sewing_dashboard',
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.layers_rounded, size: 16, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Open Sewing Dashboard',
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem<String>(
              value: 'company_profile',
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.apartment_rounded, size: 16, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Company Profile & Units',
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white, size: 17),
                SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CuttingNotificationsScreen()),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.35)),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF0B1220),
            size: 19,
          ),
        ),
      ),
    );
  }

  Widget _buildUserButton(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfileScreen()),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.35)),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: Color(0xFF0B1220),
            size: 19,
          ),
        ),
      ),
    );
  }
}
