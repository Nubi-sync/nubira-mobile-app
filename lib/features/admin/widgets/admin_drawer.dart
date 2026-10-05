import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../screens/employees_screen.dart';
import '../screens/articles_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/dispatch_screen.dart';
import '../../dashboard/store_dashboard.dart';
import '../../modules/screens/enterprise_workspace_hub_screen.dart';
import '../../modules/screens/supervisor_floor_stations_screen.dart';

class AdminDrawer extends ConsumerWidget {
  final int activeIndex;
  final Function(int) onTabSelected;

  const AdminDrawer({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;
    final isCustom = tenant?.isCustomStitching ?? true;

    return Drawer(
      backgroundColor: AppTheme.bg,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: const BoxDecoration(
                color: AppTheme.card,
                border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/icon.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/new_icon.png',
                      width: 38,
                      height: 38,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/images/z_i_g_z_a.png',
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Text(
                            'ZIGZA',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.ink,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppTheme.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                authState.cachedUsername ?? (isCustom ? 'Nubira Custom Suite' : 'Standard Sewing'),
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.publicSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                children: isCustom
                    ? _buildCustomNavItems(context)
                    : _buildBasicNavItems(context),
              ),
            ),

            // Logout Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.card,
                border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
              ),
              child: InkWell(
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: AppTheme.red, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Sign Out',
                        style: GoogleFonts.publicSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.red,
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
    );
  }

  List<Widget> _buildCustomNavItems(BuildContext context) {
    return [
      _buildSectionHeader('WORKSPACE HUB'),
      _buildDrawerItem(
        context: context,
        icon: Icons.grid_view_rounded,
        activeIcon: Icons.grid_view_rounded,
        title: 'All Modules',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
          );
        },
      ),

      const SizedBox(height: 12),
      _buildSectionHeader('6. SEWING OPERATIONS'),
      _buildDrawerItem(
        context: context,
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        title: 'Floor Dashboard',
        isSelected: activeIndex == 0,
        onTap: () {
          Navigator.pop(context);
          onTabSelected(0);
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.notifications_none_rounded,
        activeIcon: Icons.notifications,
        title: 'Notification',
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
        activeIcon: Icons.assignment_ind,
        title: 'Supervisor Desk',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupervisorFloorStationsScreen()),
          );
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront,
        title: 'Store Dashboard',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoreDashboard()),
          );
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.smart_toy_outlined,
        activeIcon: Icons.smart_toy,
        title: 'Zigza AI Copilot',
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zigza AI Sewing Copilot is active on the floor')),
          );
        },
      ),

      const SizedBox(height: 14),
      _buildSectionHeader('PRODUCTION EXECUTION'),
      _buildDrawerItem(
        context: context,
        icon: Icons.layers_outlined,
        activeIcon: Icons.layers,
        title: 'Production Chart & Orders',
        isSelected: activeIndex == 1,
        onTap: () {
          Navigator.pop(context);
          onTabSelected(1);
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        title: 'Target Allotments',
        isSelected: activeIndex == 2,
        onTap: () {
          Navigator.pop(context);
          onTabSelected(2);
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.warehouse_outlined,
        activeIcon: Icons.warehouse,
        title: 'Godown & Inventory',
        isSelected: activeIndex == 3,
        onTap: () {
          Navigator.pop(context);
          onTabSelected(3);
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping,
        title: 'Dispatch & Challans',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DispatchScreen()),
          );
        },
      ),

      const SizedBox(height: 14),
      _buildSectionHeader('FACTORY MANAGEMENT'),
      _buildDrawerItem(
        context: context,
        icon: Icons.badge_outlined,
        activeIcon: Icons.badge,
        title: 'Division Profile',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.store_outlined,
        activeIcon: Icons.store,
        title: 'Brands & Vendors',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        title: 'Employee Roster & Wages',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EmployeesScreen()),
          );
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.style_outlined,
        activeIcon: Icons.style,
        title: 'Articles & Style Tech Packs',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArticlesScreen()),
          );
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics,
        title: 'Reports & Analytics',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsScreen()),
          );
        },
      ),
    ];
  }

  List<Widget> _buildBasicNavItems(BuildContext context) {
    return [
      _buildSectionHeader('WORKSPACE HUB'),
      _buildDrawerItem(
        context: context,
        icon: Icons.grid_view_rounded,
        activeIcon: Icons.grid_view_rounded,
        title: 'All Modules',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
          );
        },
      ),

      const SizedBox(height: 12),
      _buildSectionHeader('6. SEWING OPERATIONS'),
      _buildDrawerItem(
        context: context,
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        title: 'Floor Dashboard',
        isSelected: activeIndex == 0,
        onTap: () {
          Navigator.pop(context);
          onTabSelected(0);
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.notifications_none_rounded,
        activeIcon: Icons.notifications,
        title: 'Notification',
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No new notifications')),
          );
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront,
        title: 'Floor Store (Bundles)',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoreDashboard()),
          );
        },
      ),
      _buildDrawerItem(
        context: context,
        icon: Icons.smart_toy_outlined,
        activeIcon: Icons.smart_toy,
        title: 'Zigza AI Copilot',
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zigza AI Sewing Copilot is active')),
          );
        },
      ),

      const SizedBox(height: 14),
      _buildSectionHeader('ACCOUNT'),
      _buildDrawerItem(
        context: context,
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        title: 'Division Profile',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
      ),
    ];
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.publicSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.inkFaint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.steelMist : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? AppTheme.steel : AppTheme.inkSoft,
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.publicSans(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.steel : AppTheme.ink,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.steel,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
