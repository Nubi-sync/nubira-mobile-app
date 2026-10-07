import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../screens/admin_shell.dart';
import '../screens/employees_screen.dart';
import '../screens/articles_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/profile_screen.dart';
import '../challans/challans_dashboard_screen.dart';
import '../../dashboard/store_dashboard.dart';
import '../../dashboard/lineman_dashboard.dart';
import '../../dashboard/mending_dashboard.dart';
import '../../dashboard/qc_dashboard.dart';
import '../../modules/screens/enterprise_workspace_hub_screen.dart';
import '../../modules/screens/supervisor_floor_stations_screen.dart';

class AdminDrawer extends ConsumerWidget {
  final int activeIndex;
  final Function(int)? onTabSelected;
  final String? activeRoute;

  const AdminDrawer({
    super.key,
    this.activeIndex = -1,
    this.onTabSelected,
    this.activeRoute,
  });

  String _getUserInitials(String email, String? username) {
    if (username != null && username.trim().isNotEmpty) {
      final parts = username.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return username.trim().substring(0, username.trim().length >= 2 ? 2 : 1).toUpperCase();
    }
    if (email.isNotEmpty) {
      final prefix = email.split('@').first;
      if (prefix.toLowerCase() == 'aj') return 'AJ';
      if (prefix.length >= 2) return prefix.substring(0, 2).toUpperCase();
      return prefix.toUpperCase();
    }
    return 'AJ';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;
    final userEmail = tenant?.userEmail ?? authState.cachedUsername ?? 'aj@nubiracreation.com';
    final userInitials = _getUserInitials(userEmail, authState.cachedUsername);
    final userRoleRaw = (tenant?.role != null && tenant!.role.isNotEmpty)
        ? tenant.role
        : (authState.userRole ?? '');
    final roleUpper = userRoleRaw.toUpperCase();
    final emailLower = userEmail.toLowerCase();

    // 100% Web Parity Role Detection
    final isAdmin = emailLower == 'admin@zigza.in' ||
        emailLower == 'team.anga9@gmail.com' ||
        emailLower == 'aj@nubiracreation.com' ||
        roleUpper == 'ADMIN' ||
        roleUpper == 'SUPERADMIN' ||
        roleUpper == 'PLATFORM_SUPERADMIN' ||
        roleUpper == 'ADMINISTRATOR';

    final isStoreUser = roleUpper == 'STORE' ||
        roleUpper == 'STORE_SUPERVISOR' ||
        roleUpper == 'GODOWN' ||
        emailLower.startsWith('store@') ||
        emailLower.startsWith('store') ||
        emailLower.contains('store');

    final isLineman = roleUpper == 'LINEMAN' ||
        roleUpper == 'STITCHING' ||
        roleUpper == 'STITCHING_SUPERVISOR';

    final isMending = roleUpper == 'MENDING' ||
        roleUpper == 'ALTERATION' ||
        roleUpper == 'REPAIR_TAILOR';

    final isQc = roleUpper == 'QC' ||
        roleUpper == 'PRODUCTION_QC' ||
        roleUpper == 'AQL_INSPECTOR';

    final isProductionManager = roleUpper == 'PRODUCTION_MANAGER' ||
        roleUpper == 'PROD_MANAGER' ||
        roleUpper == 'PRODUCTION_SUPERVISOR' ||
        emailLower.contains('@pm.') ||
        emailLower.startsWith('pm@');

    // Determine Top Header Badge
    final String badgeText;
    if (isAdmin) {
      badgeText = 'ERP MES';
    } else if (isStoreUser) {
      badgeText = 'STORE MES';
    } else if (isLineman) {
      badgeText = 'STITCHING MES';
    } else if (isMending) {
      badgeText = 'MENDING MES';
    } else if (isQc) {
      badgeText = 'QC MES';
    } else if (isProductionManager) {
      badgeText = 'PROD MES';
    } else {
      badgeText = '${roleUpper.isNotEmpty ? roleUpper : "ERP"} MES';
    }

    // Determine Footer Role Label
    final String roleLabel;
    if (isAdmin) {
      roleLabel = 'Super Admin';
    } else if (isProductionManager) {
      roleLabel = 'Production Manager';
    } else if (isStoreUser) {
      roleLabel = 'Store (Inventory)';
    } else if (isLineman) {
      roleLabel = 'Lineman (Stitching)';
    } else if (isMending) {
      roleLabel = 'Mending (Matrix Counting)';
    } else if (isQc) {
      roleLabel = 'QC (Inspection & Packing)';
    } else if (roleUpper.isNotEmpty) {
      roleLabel = roleUpper.replaceAll('_', ' ');
    } else {
      roleLabel = 'Employee';
    }

    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            // ========================================================
            // 1. TOP HEADER (100% Web Parity)
            // ========================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/icon.png',
                        height: 28,
                        width: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/new_icon.png',
                          height: 28,
                          width: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Image.asset(
                        'assets/images/z_i_g_z_a.png',
                        height: 20,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/zigza_new_logo.png',
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Text(
                            'ZIGZA',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0B1220),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B1220),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ========================================================
            // 2. NAVIGATION ITEMS LIST (Role-Based Web Parity)
            // ========================================================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                children: [
                  if (isAdmin) ...[
                    // SUPER ADMIN NAVIGATION
                    _buildSectionHeader('WORKSPACE HUB'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.grid_view_outlined,
                      title: 'All Modules',
                      isSelected: activeRoute == '/modules',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/modules') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 8),
                    _buildSectionHeader('6. SEWING OPERATIONS'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.dashboard_outlined,
                      title: 'Floor Dashboard',
                      isSelected: activeRoute == '/stitching-sewing/dashboard' || activeIndex == 0,
                      onTap: () {
                        Navigator.pop(context);
                        if (onTabSelected != null) {
                          onTabSelected!(0);
                        } else if (activeRoute != '/stitching-sewing/dashboard') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminShell()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.store_mall_directory_outlined,
                      title: 'Store Dashboard',
                      isSelected: activeRoute == '/stitching-sewing/store',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/store') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const StoreDashboard()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.notifications_none_rounded,
                      title: 'Notification',
                      isSelected: activeRoute == '/stitching-sewing/notifications',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No new stitching floor alerts')),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.assignment_ind_outlined,
                      title: 'Supervisor Desk',
                      isSelected: activeRoute == '/stitching-sewing/supervisor-desk',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/supervisor-desk') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SupervisorFloorStationsScreen()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.smart_toy_outlined,
                      title: 'Zigza AI',
                      isSelected: activeRoute == '/stitching-sewing/zigza-ai',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Zigza AI Sewing Copilot is active on the floor')),
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    _buildSectionHeader('MANAGE'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.apartment_outlined,
                      title: 'Brands & Vendors',
                      isSelected: activeRoute == '/stitching-sewing/vendors',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Brands & Vendors directory')),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.people_outline_rounded,
                      title: 'Employees',
                      isSelected: activeRoute == '/stitching-sewing/employees',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/employees') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EmployeesScreen()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.sell_outlined,
                      title: 'Articles',
                      isSelected: activeRoute == '/stitching-sewing/articles',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/articles') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ArticlesScreen()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.description_outlined,
                      title: 'Reports & Analytics',
                      isSelected: activeRoute == '/stitching-sewing/reports',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/reports') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ReportsScreen()),
                          );
                        }
                      },
                    ),
                  ] else if (isStoreUser) ...[
                    // STORE / GODOWN EMPLOYEE NAVIGATION
                    _buildSectionHeader('GODOWN SHIFT'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.store_mall_directory_outlined,
                      title: 'Store Dashboard',
                      isSelected: activeRoute == '/stitching-sewing/store',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/store') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const StoreDashboard()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.notifications_none_rounded,
                      title: 'Notification',
                      isSelected: activeRoute == '/stitching-sewing/notifications',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No new store inventory alerts')),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.smart_toy_outlined,
                      title: 'Zigza AI',
                      isSelected: activeRoute == '/stitching-sewing/zigza-ai',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Zigza AI Store Assistant is ready')),
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    _buildSectionHeader('ACCOUNT'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      isSelected: activeRoute == '/stitching-sewing/profile',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/profile') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        }
                      },
                    ),
                  ] else if (isLineman) ...[
                    // LINEMAN NAVIGATION
                    _buildSectionHeader('STITCHING LINE'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.precision_manufacturing_outlined,
                      title: 'Lineman Dashboard',
                      isSelected: activeRoute == '/stitching-sewing/lineman',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/lineman') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const LinemanDashboard()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.notifications_none_rounded,
                      title: 'Notification',
                      isSelected: activeRoute == '/stitching-sewing/notifications',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No new stitching line alerts')),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.smart_toy_outlined,
                      title: 'Zigza AI',
                      isSelected: activeRoute == '/stitching-sewing/zigza-ai',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Zigza AI Stitching Copilot is active')),
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    _buildSectionHeader('ACCOUNT'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      isSelected: activeRoute == '/stitching-sewing/profile',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/profile') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        }
                      },
                    ),
                  ] else if (isMending) ...[
                    // MENDING & COUNTING NAVIGATION
                    _buildSectionHeader('MENDING & PACKING'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.auto_fix_high_outlined,
                      title: 'Mending & Counting',
                      isSelected: activeRoute == '/stitching-sewing/mending',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/mending') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const MendingDashboard()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.notifications_none_rounded,
                      title: 'Notification',
                      isSelected: activeRoute == '/stitching-sewing/notifications',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No new mending alerts')),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.smart_toy_outlined,
                      title: 'Zigza AI',
                      isSelected: activeRoute == '/stitching-sewing/zigza-ai',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Zigza AI Quality Assistant active')),
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    _buildSectionHeader('ACCOUNT'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      isSelected: activeRoute == '/stitching-sewing/profile',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/profile') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        }
                      },
                    ),
                  ] else if (isQc) ...[
                    // QC INSPECTION NAVIGATION
                    _buildSectionHeader('QUALITY CONTROL'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.fact_check_outlined,
                      title: 'QC Inspection',
                      isSelected: activeRoute == '/stitching-sewing/qc',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/qc') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const QcDashboard()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.notifications_none_rounded,
                      title: 'Notification',
                      isSelected: activeRoute == '/stitching-sewing/notifications',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No new QC alerts')),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.smart_toy_outlined,
                      title: 'Zigza AI',
                      isSelected: activeRoute == '/stitching-sewing/zigza-ai',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Zigza AI Inspection Copilot active')),
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    _buildSectionHeader('ACCOUNT'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      isSelected: activeRoute == '/stitching-sewing/profile',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/profile') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        }
                      },
                    ),
                  ] else if (isProductionManager) ...[
                    // PRODUCTION MANAGER NAVIGATION
                    _buildSectionHeader('PRODUCTION OPERATIONS'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.layers_outlined,
                      title: 'Production Orders',
                      isSelected: activeRoute == '/stitching-sewing/production-orders',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/production-orders') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChallansDashboardScreen()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.store_mall_directory_outlined,
                      title: 'Store Dashboard',
                      isSelected: activeRoute == '/stitching-sewing/store',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/store') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const StoreDashboard()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.assignment_ind_outlined,
                      title: 'Supervisor Desk',
                      isSelected: activeRoute == '/stitching-sewing/supervisor-desk',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/supervisor-desk') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SupervisorFloorStationsScreen()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.notifications_none_rounded,
                      title: 'Notification',
                      isSelected: activeRoute == '/stitching-sewing/notifications',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No new floor alerts')),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.smart_toy_outlined,
                      title: 'Zigza AI',
                      isSelected: activeRoute == '/stitching-sewing/zigza-ai',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Zigza AI Copilot is active')),
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    _buildSectionHeader('ACCOUNT'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      isSelected: activeRoute == '/stitching-sewing/profile',
                      onTap: () {
                        Navigator.pop(context);
                        if (activeRoute != '/stitching-sewing/profile') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        }
                      },
                    ),
                  ] else ...[
                    // DEFAULT GENERIC FALLBACK
                    _buildSectionHeader('SEWING OPERATIONS'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.dashboard_outlined,
                      title: 'Floor Dashboard',
                      isSelected: activeRoute == '/stitching-sewing/dashboard' || activeIndex == 0,
                      onTap: () {
                        Navigator.pop(context);
                        if (onTabSelected != null) {
                          onTabSelected!(0);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminShell()),
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.notifications_none_rounded,
                      title: 'Notification',
                      isSelected: activeRoute == '/stitching-sewing/notifications',
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),

                    const SizedBox(height: 8),
                    _buildSectionHeader('ACCOUNT'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      isSelected: activeRoute == '/stitching-sewing/profile',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // ========================================================
            // 3. BOTTOM USER PROFILE BLOCK & LOGOUT (100% Web Parity)
            // ========================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAF8),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0B1220),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        userInitials,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (isAdmin && onTabSelected != null) {
                          onTabSelected!(3);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Text(
                                roleLabel,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 10, bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0FDFA) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 9,
                  bottom: 9,
                  child: Container(
                    width: 3.5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B1220),
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 19,
                      color: isSelected ? const Color(0xFF0B1220) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.publicSans(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF0B1220) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
