import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../screens/enterprise_workspace_hub_screen.dart';
import '../screens/supervisor_floor_stations_screen.dart';
import '../screens/department_heads_screen.dart';
import '../screens/company_profile_screen.dart';
import '../../design/screens/design_studio_screen.dart';
import '../../design/screens/design_team_management_screen.dart';
import '../../design/screens/ph_settings_screen.dart';
import '../../design/screens/tech_pack_catalog_screen.dart';
import '../../design/screens/sa_design_approvals_screen.dart';
import '../../merchandising/screens/merchandising_dashboard_screen.dart';
import '../../merchandising/screens/active_buyers_screen.dart';
import '../../merchandising/screens/buyer_purchase_orders_screen.dart';
import '../../merchandising/screens/tna_planner_screen.dart';
import '../../cutting/screens/cutting_lay_floor_screen.dart';
import '../../cutting/screens/cutting_notifications_screen.dart';
import '../../cutting/screens/cutting_rolls_store_screen.dart';
import '../../cutting/screens/cutting_lay_sheets_screen.dart';
import '../../cutting/screens/cutting_cad_markers_screen.dart';
import '../../cutting/screens/cutting_orders_queue_screen.dart';
import '../../cutting/screens/cutting_bundle_tickets_screen.dart';
import '../../cutting/screens/cutting_zigza_ai_screen.dart';
import '../../printing/screens/printing_studio_screen.dart';
import '../../printing/screens/printing_notifications_screen.dart';
import '../../printing/screens/printing_store_screen.dart';
import '../../printing/screens/printing_zigza_ai_screen.dart';

class WorkspaceHubDrawer extends ConsumerWidget {
  final String activeRoute;
  final VoidCallback? onOpenTechPacks;
  final VoidCallback? onOpenTeam;
  final VoidCallback? onOpenSettings;

  const WorkspaceHubDrawer({
    super.key,
    this.activeRoute = '/modules',
    this.onOpenTechPacks,
    this.onOpenTeam,
    this.onOpenSettings,
  });

  bool _canAccessDepartmentHeads(String role, bool isSuperAdmin, bool isHead) {
    final r = role.toUpperCase();
    return isSuperAdmin || isHead || r == 'ADMIN' || r == 'SUPERADMIN' || r == 'PLATFORM_SUPERADMIN';
  }

  bool _canAccessSupervisor(String role, bool isSuperAdmin) {
    final r = role.toUpperCase();
    return isSuperAdmin || r == 'ADMIN' || r == 'SUPERADMIN' || r == 'PRODUCTION_MANAGER' || r == 'SUPERVISOR' || r == 'PLATFORM_SUPERADMIN';
  }

  bool _canAccessSAApprovals(String role, bool isSuperAdmin) {
    final r = role.toUpperCase();
    return isSuperAdmin || r == 'ADMIN' || r == 'SUPERADMIN' || r == 'PLATFORM_SUPERADMIN';
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to end your current session and sign out of Zigza MES?',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: const Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              'Sign Out',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // Close Drawer
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1A000000), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/z_i_g_z_a.png',
                  height: 30,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/zigza_logo.png',
                    height: 30,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      'Zigza.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF332B6B),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF6E9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x26000000)),
                ),
                child: Text(
                  'ERP MES',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF332B6B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: const Icon(Icons.close_rounded, color: Color(0xFF475569), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerFooter(BuildContext context, WidgetRef ref, String initials, String userEmail, bool isSuperAdmin, String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x1A000000), width: 1)),
      ),
      child: Row(
        children: [
          // User Avatar Circle
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF332B6B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // User Info & Profile Link
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.publicSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      isSuperAdmin ? 'Super Admin' : (role == 'ADMIN' ? 'Admin' : 'Operator'),
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        color: const Color(0xFF6B6A65),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _navigateTo(context, const CompanyProfileScreen()),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Profile',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF332B6B),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_outward_rounded,
                            size: 11,
                            color: Color(0xFF332B6B),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Logout Icon Button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF6B6A65), size: 20),
            tooltip: 'Sign Out',
            onPressed: () => _showSignOutDialog(context, ref),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;
    final role = authState.userRole ?? 'STAFF';
    final isSuperAdmin = tenant?.isSuperAdmin ?? false;
    final userEmail = tenant?.userEmail ?? authState.cachedUsername ?? 'staff@factory.local';
    final adminDisplayName = tenant?.adminDisplayName ?? authState.cachedUsername ?? 'User';

    final canHeads = _canAccessDepartmentHeads(role, isSuperAdmin, false);
    final canSupervisor = _canAccessSupervisor(role, isSuperAdmin);
    final canSAApprovals = _canAccessSAApprovals(role, isSuperAdmin);

    // User Initials
    final initials = adminDisplayName.trim().isNotEmpty
        ? adminDisplayName.trim().split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() : '').take(2).join()
        : 'Z';

    // Check if inside Design Studio, Merchandising, Cutting, or Printing
    final isDesignStudio = activeRoute.startsWith('/design') && activeRoute != '/design/sa-approvals';
    final isMerchandising = activeRoute.startsWith('/merchandising');
    final isCutting = activeRoute.startsWith('/cutting');
    final isPrinting = activeRoute.startsWith('/printing');

    List<Widget> navChildren;

    if (isDesignStudio) {
      navChildren = [
        _buildSectionLabel('WORKSPACE HUB'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.grid_view_rounded,
          title: 'All Modules',
          isActive: false,
          onTap: () {
            _navigateTo(context, const EnterpriseWorkspaceHubScreen());
          },
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('1. DESIGN STUDIO'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.palette_outlined,
          title: 'Studio Dashboard',
          isActive: activeRoute == '/design',
          onTap: () {
            if (activeRoute == '/design') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const DesignStudioScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.description_outlined,
          title: 'Tech-Pack Catalog',
          isActive: activeRoute == '/design/tech-packs',
          onTap: () {
            if (activeRoute == '/design/tech-packs') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const TechPackCatalogScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.people_outline_rounded,
          title: 'Team Management',
          isActive: activeRoute == '/design/team',
          onTap: () {
            if (activeRoute == '/design/team') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const DesignTeamManagementScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.settings_outlined,
          title: 'PH Settings',
          isActive: activeRoute == '/design/settings',
          onTap: () {
            if (activeRoute == '/design/settings') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const PHSettingsScreen());
            }
          },
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('ACCOUNT'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.person_outline_rounded,
          title: 'Studio Profile',
          isActive: activeRoute == '/design/profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    } else if (isMerchandising) {
      navChildren = [
        _buildSectionLabel('WORKSPACE HUB'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.grid_view_rounded,
          title: 'All Modules',
          isActive: false,
          onTap: () {
            _navigateTo(context, const EnterpriseWorkspaceHubScreen());
          },
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('2. MERCHANDISING'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.business_center_outlined,
          title: 'Desk Dashboard',
          isActive: activeRoute == '/merchandising',
          onTap: () {
            if (activeRoute == '/merchandising') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const MerchandisingDashboardScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.people_outline_rounded,
          title: 'Active Buyers',
          isActive: activeRoute == '/merchandising/buyers',
          onTap: () {
            if (activeRoute == '/merchandising/buyers') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const ActiveBuyersScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.fact_check_outlined,
          title: 'Buyer Purchase Orders',
          isActive: activeRoute == '/merchandising/orders',
          onTap: () {
            if (activeRoute == '/merchandising/orders') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const BuyerPurchaseOrdersScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.calendar_month_outlined,
          title: 'Time & Action (T&A) Planner',
          isActive: activeRoute == '/merchandising/tna-calendar',
          onTap: () {
            if (activeRoute == '/merchandising/tna-calendar') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const TnaPlannerScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.smart_toy_outlined,
          title: 'Zigza AI',
          isActive: activeRoute == '/merchandising/zigza-ai',
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Zigza AI Merchandising Assistant active on desk')),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('ACCOUNT'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.person_outline_rounded,
          title: 'Desk Profile',
          isActive: activeRoute == '/merchandising/profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    } else if (isCutting) {
      navChildren = [
        _buildSectionLabel('WORKSPACE HUB'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.grid_view_rounded,
          title: 'All Modules',
          isActive: false,
          onTap: () {
            _navigateTo(context, const EnterpriseWorkspaceHubScreen());
          },
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('3. CUTTING FLOOR'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.content_cut_rounded,
          title: 'Floor Dashboard',
          isActive: activeRoute == '/cutting',
          onTap: () {
            if (activeRoute == '/cutting') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const CuttingLayFloorScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.notifications_none_rounded,
          title: 'Notification',
          isActive: activeRoute == '/cutting/notifications',
          onTap: () {
            if (activeRoute == '/cutting/notifications') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const CuttingNotificationsScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.storefront_outlined,
          title: 'Floor Store (Rolls)',
          isActive: activeRoute == '/cutting/store',
          onTap: () {
            if (activeRoute == '/cutting/store') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const CuttingRollsStoreScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.layers_outlined,
          title: 'Spreading & Lay Plans',
          isActive: activeRoute == '/cutting/lay-sheets',
          onTap: () {
            if (activeRoute == '/cutting/lay-sheets') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const CuttingLaySheetsScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.open_in_full_rounded,
          title: 'CAD Markers & Nesting',
          isActive: activeRoute == '/cutting/markers',
          onTap: () {
            if (activeRoute == '/cutting/markers') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const CuttingCadMarkersScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.memory_rounded,
          title: 'Cutting Orders & Queue',
          isActive: activeRoute == '/cutting/orders',
          onTap: () {
            if (activeRoute == '/cutting/orders') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const CuttingOrdersQueueScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.qr_code_2_rounded,
          title: 'Bundle Tickets & Barcodes',
          isActive: activeRoute == '/cutting/bundles',
          onTap: () {
            if (activeRoute == '/cutting/bundles') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const CuttingBundleTicketsScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.smart_toy_outlined,
          title: 'Zigza AI',
          isActive: activeRoute == '/cutting/zigza-ai',
          onTap: () {
            if (activeRoute == '/cutting/zigza-ai') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const CuttingZigzaAiScreen());
            }
          },
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('ACCOUNT'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.person_outline_rounded,
          title: 'Division Profile',
          isActive: activeRoute == '/cutting/profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    } else if (isPrinting) {
      navChildren = [
        _buildSectionLabel('WORKSPACE HUB'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.grid_view_rounded,
          title: 'All Modules',
          isActive: false,
          onTap: () {
            _navigateTo(context, const EnterpriseWorkspaceHubScreen());
          },
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('4. PRINTING DIVISION'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.print_outlined,
          title: 'Floor Dashboard',
          isActive: activeRoute == '/printing',
          onTap: () {
            if (activeRoute == '/printing') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const PrintingStudioScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.notifications_none_rounded,
          title: 'Notification',
          isActive: activeRoute == '/printing/notifications',
          onTap: () {
            if (activeRoute == '/printing/notifications') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const PrintingNotificationsScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.storefront_outlined,
          title: 'Floor Store (Panels)',
          isActive: activeRoute == '/printing/store',
          onTap: () {
            if (activeRoute == '/printing/store') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const PrintingStoreScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.smart_toy_outlined,
          title: 'Zigza AI',
          isActive: activeRoute == '/printing/zigza-ai',
          onTap: () {
            if (activeRoute == '/printing/zigza-ai') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const PrintingZigzaAiScreen());
            }
          },
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('ACCOUNT'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.person_outline_rounded,
          title: 'Division Profile',
          isActive: activeRoute == '/printing/profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    } else {
      navChildren = [
        _buildSectionLabel('WORKSPACE HUB'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.grid_view_rounded,
          title: 'All Modules',
          isActive: activeRoute == '/modules' || activeRoute == '/workspace-hub',
          onTap: () {
            if (activeRoute == '/modules' || activeRoute == '/workspace-hub') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const EnterpriseWorkspaceHubScreen());
            }
          },
        ),
        if (canHeads)
          _buildNavItem(
            context: context,
            icon: Icons.shield_outlined,
            title: 'Department Heads',
            isActive: activeRoute == '/access-control' ||
                activeRoute == '/department-heads' ||
                activeRoute == '/modules/access-control',
            onTap: () => _navigateTo(context, const DepartmentHeadsScreen()),
          ),
        if (canSupervisor)
          _buildNavItem(
            context: context,
            icon: Icons.build_outlined,
            title: 'Supervisor Operations',
            isActive: activeRoute == '/supervisor-desk' ||
                activeRoute == '/supervisor-hub' ||
                activeRoute == '/modules/supervisor-desk',
            onTap: () => _navigateTo(context, const SupervisorFloorStationsScreen()),
          ),
        if (canSAApprovals)
          _buildNavItem(
            context: context,
            icon: Icons.verified_user_outlined,
            title: 'SA Design Approvals',
            isActive: activeRoute == '/design/sa-approvals' || activeRoute == '/sa-approvals',
            onTap: () => _navigateTo(context, const SADesignApprovalsScreen()),
          ),
        _buildNavItem(
          context: context,
          icon: Icons.business_outlined,
          title: 'Company Profile',
          isActive: activeRoute == '/profile' ||
              activeRoute == '/company-profile' ||
              activeRoute == '/modules/profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    }

    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(context),

            // DRAWER NAVIGATION LIST
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                children: navChildren,
              ),
            ),

            _buildDrawerFooter(context, ref, initials, userEmail, isSuperAdmin, role),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFAF6E9) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            border: isActive
                ? const Border(left: BorderSide(color: Color(0xFF332B6B), width: 3.0))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF332B6B) : const Color(0xFF6B6A65),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.publicSans(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: isActive ? const Color(0xFF332B6B) : const Color(0xFF3C3A35),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
