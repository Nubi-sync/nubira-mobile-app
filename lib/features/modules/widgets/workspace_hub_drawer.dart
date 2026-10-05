import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../screens/enterprise_workspace_hub_screen.dart';
import '../screens/supervisor_floor_stations_screen.dart';
import '../screens/department_heads_screen.dart';
import '../screens/company_profile_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/lineman_dashboard.dart';
import '../../design/screens/design_studio_screen.dart';
import '../../design/screens/design_team_management_screen.dart';
import '../../design/screens/ph_settings_screen.dart';
import '../../design/screens/tech_pack_catalog_screen.dart';
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
import '../../embroidery/screens/embroidery_studio_screen.dart';
import '../../embroidery/screens/embroidery_notifications_screen.dart';
import '../../embroidery/screens/embroidery_store_screen.dart';
import '../../embroidery/screens/embroidery_zigza_ai_screen.dart';
import '../../washing/screens/washing_floor_screen.dart';
import '../../washing/screens/washing_notifications_screen.dart';
import '../../washing/screens/washing_zigza_ai_screen.dart';
import '../../iron/screens/iron_floor_screen.dart';
import '../../iron/screens/iron_notifications_screen.dart';
import '../../iron/screens/iron_zigza_ai_screen.dart';
import '../../ready_goods/screens/quality_clinic_floor_screen.dart';
import '../../store/screens/central_store_godown_screen.dart';
import '../../dispatch/screens/dispatch_logistics_hub_screen.dart';
import '../../admin/screens/admin_shell.dart';
import '../../admin/screens/employees_screen.dart';
import '../../admin/screens/articles_screen.dart';
import '../../admin/screens/reports_screen.dart';
import '../../admin/screens/dispatch_screen.dart';
import '../../dashboard/store_dashboard.dart';

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
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderLight, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icon.png',
                height: 30,
                width: 30,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/new_icon.png',
                  height: 30,
                  width: 30,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/images/z_i_g_z_a.png',
                height: 22,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/zigza_new_logo.png',
                  height: 22,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    'ZIGZA',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.headingObsidian,
                      letterSpacing: 0.5,
                    ),
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
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: const Icon(Icons.close_rounded, color: AppTheme.bodyInk, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerFooter(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _navigateTo(context, const CompanyProfileScreen()),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.business_rounded, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 14),
                  Text(
                    'Company Profile & Settings',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => _navigateTo(context, const CuttingNotificationsScreen()),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 14),
                  Text(
                    'Floor Notifications',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: () => _showSignOutDialog(context, ref),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFE11D48)),
                  const SizedBox(width: 14),
                  Text(
                    'Sign Out',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ),
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

    // Check if inside Design Studio, Merchandising, Cutting, or Printing
    final isDesignStudio = activeRoute.startsWith('/design') && activeRoute != '/design/sa-approvals';
    final isMerchandising = activeRoute.startsWith('/merchandising');
    final isCutting = activeRoute.startsWith('/cutting');
    final isPrinting = activeRoute.startsWith('/printing');
    final isEmbroidery = activeRoute.startsWith('/embroidery');
    final isStitching = activeRoute.startsWith('/stitching') || activeRoute.startsWith('/sewing') || activeRoute.startsWith('/admin');
    final isWashing = activeRoute.startsWith('/washing');
    final isIron = activeRoute.startsWith('/iron');
    final isReadyGoods = activeRoute.startsWith('/ready-goods');
    final isStore = activeRoute.startsWith('/store');
    final isDispatch = activeRoute.startsWith('/dispatch');

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
    } else if (isEmbroidery) {
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
        _buildSectionLabel('5. EMBROIDERY DIVISION'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.auto_awesome_outlined,
          title: 'Floor Dashboard',
          isActive: activeRoute == '/embroidery',
          onTap: () {
            if (activeRoute == '/embroidery') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const EmbroideryStudioScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.notifications_none_rounded,
          title: 'Notification',
          isActive: activeRoute == '/embroidery/notifications',
          onTap: () {
            if (activeRoute == '/embroidery/notifications') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const EmbroideryNotificationsScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.storefront_outlined,
          title: 'Floor Store (Panels)',
          isActive: activeRoute == '/embroidery/store',
          onTap: () {
            if (activeRoute == '/embroidery/store') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const EmbroideryStoreScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.smart_toy_outlined,
          title: 'Zigza AI',
          isActive: activeRoute == '/embroidery/zigza-ai',
          onTap: () {
            if (activeRoute == '/embroidery/zigza-ai') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const EmbroideryZigzaAiScreen());
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
          isActive: activeRoute == '/embroidery/profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    } else if (isStitching) {
      final isCustom = tenant?.isCustomStitching ?? true;
      if (isCustom) {
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
          _buildSectionLabel('6. SEWING FLOOR OPERATIONS'),
          const SizedBox(height: 4),
          _buildNavItem(
            context: context,
            icon: Icons.dashboard_outlined,
            title: 'Master Floor Dashboard',
            isActive: activeRoute == '/stitching-sewing/dashboard' || activeRoute == '/stitching-sewing' || activeRoute == '/admin',
            onTap: () {
              if (activeRoute == '/stitching-sewing/dashboard' || activeRoute == '/stitching-sewing' || activeRoute == '/admin') {
                Navigator.pop(context);
              } else {
                _navigateTo(context, const AdminShell());
              }
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.notifications_none_rounded,
            title: 'Notifications & Alerts',
            isActive: activeRoute == '/stitching-sewing/notifications',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new stitching floor alerts')),
              );
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.assignment_ind_outlined,
            title: 'Supervisor Desk',
            isActive: activeRoute == '/stitching-sewing/supervisor-desk',
            onTap: () {
              if (activeRoute == '/stitching-sewing/supervisor-desk') {
                Navigator.pop(context);
              } else {
                _navigateTo(context, const SupervisorFloorStationsScreen());
              }
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.storefront_outlined,
            title: 'Store Dashboard',
            isActive: activeRoute == '/stitching-sewing/store',
            onTap: () {
              if (activeRoute == '/stitching-sewing/store') {
                Navigator.pop(context);
              } else {
                _navigateTo(context, const StoreDashboard());
              }
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.smart_toy_outlined,
            title: 'Zigza AI Floor Copilot',
            isActive: activeRoute == '/stitching-sewing/zigza-ai',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Zigza AI Sewing Copilot is active on the floor')),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('PRODUCTION EXECUTION'),
          const SizedBox(height: 4),
          _buildNavItem(
            context: context,
            icon: Icons.layers_outlined,
            title: 'Production Chart & Orders',
            isActive: activeRoute == '/stitching-sewing/production-orders',
            onTap: () {
              _navigateTo(context, const AdminShell());
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.assignment_outlined,
            title: 'Target Allotments',
            isActive: activeRoute == '/stitching-sewing/allotments',
            onTap: () {
              _navigateTo(context, const AdminShell());
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.warehouse_outlined,
            title: 'Godown & Inventory',
            isActive: activeRoute == '/stitching-sewing/inventory',
            onTap: () {
              _navigateTo(context, const AdminShell());
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.local_shipping_outlined,
            title: 'Dispatch & Challans',
            isActive: activeRoute == '/dispatch',
            onTap: () {
              _navigateTo(context, const DispatchScreen());
            },
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('FACTORY MANAGEMENT'),
          const SizedBox(height: 4),
          _buildNavItem(
            context: context,
            icon: Icons.badge_outlined,
            title: 'Division Profile',
            isActive: activeRoute == '/stitching-sewing/profile',
            onTap: () => _navigateTo(context, const CompanyProfileScreen()),
          ),
          _buildNavItem(
            context: context,
            icon: Icons.store_outlined,
            title: 'Brands & Vendors',
            isActive: activeRoute == '/stitching-sewing/vendors',
            onTap: () => _navigateTo(context, const CompanyProfileScreen()),
          ),
          _buildNavItem(
            context: context,
            icon: Icons.people_outline,
            title: 'Employee Roster & Wages',
            isActive: activeRoute == '/stitching-sewing/employees',
            onTap: () => _navigateTo(context, const EmployeesScreen()),
          ),
          _buildNavItem(
            context: context,
            icon: Icons.style_outlined,
            title: 'Articles & Style Tech Packs',
            isActive: activeRoute == '/stitching-sewing/articles',
            onTap: () => _navigateTo(context, const ArticlesScreen()),
          ),
          _buildNavItem(
            context: context,
            icon: Icons.analytics_outlined,
            title: 'Reports & Analytics',
            isActive: activeRoute == '/stitching-sewing/reports',
            onTap: () => _navigateTo(context, const ReportsScreen()),
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
            isActive: false,
            onTap: () {
              _navigateTo(context, const EnterpriseWorkspaceHubScreen());
            },
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('6. SEWING OPERATIONS'),
          const SizedBox(height: 4),
          _buildNavItem(
            context: context,
            icon: Icons.dashboard_outlined,
            title: 'Floor Dashboard',
            isActive: activeRoute == '/stitching-sewing/dashboard' || activeRoute == '/stitching-sewing',
            onTap: () {
              if (activeRoute == '/stitching-sewing/dashboard' || activeRoute == '/stitching-sewing') {
                Navigator.pop(context);
              } else {
                _navigateTo(context, const AdminShell());
              }
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.notifications_none_rounded,
            title: 'Notification',
            isActive: activeRoute == '/stitching-sewing/notifications',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.storefront_outlined,
            title: 'Floor Store (Bundles)',
            isActive: activeRoute == '/stitching-sewing/store',
            onTap: () {
              _navigateTo(context, const StoreDashboard());
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.smart_toy_outlined,
            title: 'Zigza AI Copilot',
            isActive: activeRoute == '/stitching-sewing/zigza-ai',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Zigza AI Sewing Copilot is active')),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('ACCOUNT'),
          const SizedBox(height: 4),
          _buildNavItem(
            context: context,
            icon: Icons.person_outline_rounded,
            title: 'Division Profile',
            isActive: activeRoute == '/stitching-sewing/profile',
            onTap: () => _navigateTo(context, const CompanyProfileScreen()),
          ),
        ];
      }
    } else if (isWashing) {
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
        _buildSectionLabel('7. INDUSTRIAL WASHING'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.waves_outlined,
          title: 'Floor Dashboard',
          isActive: activeRoute == '/washing',
          onTap: () {
            if (activeRoute == '/washing') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const WashingFloorScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.notifications_none_rounded,
          title: 'Notification',
          isActive: activeRoute == '/washing/notifications',
          onTap: () {
            if (activeRoute == '/washing/notifications') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const WashingNotificationsScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.smart_toy_outlined,
          title: 'Zigza AI',
          isActive: activeRoute == '/washing/zigza-ai',
          onTap: () {
            if (activeRoute == '/washing/zigza-ai') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const WashingZigzaAiScreen());
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
          isActive: activeRoute == '/washing/profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    } else if (isIron) {
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
        _buildSectionLabel('8. STEAM FINISHING & IRONING'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.air_rounded,
          title: 'Floor Dashboard',
          isActive: activeRoute == '/iron',
          onTap: () {
            if (activeRoute == '/iron') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const IronFloorScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.notifications_none_rounded,
          title: 'Notification',
          isActive: activeRoute == '/iron/notifications',
          onTap: () {
            if (activeRoute == '/iron/notifications') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const IronNotificationsScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.smart_toy_outlined,
          title: 'Zigza AI',
          isActive: activeRoute == '/iron/zigza-ai',
          onTap: () {
            if (activeRoute == '/iron/zigza-ai') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const IronZigzaAiScreen());
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
          isActive: activeRoute == '/iron/profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    } else if (isReadyGoods) {
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
        _buildSectionLabel('09. READY GOODS CLINIC'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.verified_outlined,
          title: 'Floor Dashboard',
          isActive: activeRoute == '/ready-goods',
          onTap: () {
            if (activeRoute == '/ready-goods') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const QualityClinicFloorScreen());
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
          isActive: activeRoute == '/ready-goods/profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    } else if (isStore) {
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
        _buildSectionLabel('10. CENTRAL STORE & GODOWN'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.store_mall_directory_outlined,
          title: 'Central Hub (Cloth Stock)',
          isActive: activeRoute == '/store',
          onTap: () {
            if (activeRoute == '/store') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const CentralStoreGodownScreen());
            }
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.business_center_outlined,
          title: 'Merchandise Store',
          isActive: activeRoute == '/store/merchandise',
          onTap: () {
            _navigateTo(context, const CentralStoreGodownScreen());
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.content_cut_outlined,
          title: 'Cutting Floor Store',
          isActive: activeRoute == '/store/cutting',
          onTap: () {
            _navigateTo(context, const CuttingRollsStoreScreen());
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.print_outlined,
          title: 'Printing Floor Store',
          isActive: activeRoute == '/store/printing',
          onTap: () {
            _navigateTo(context, const PrintingStoreScreen());
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.auto_awesome_outlined,
          title: 'Embroidery Floor Store',
          isActive: activeRoute == '/store/embroidery',
          onTap: () {
            _navigateTo(context, const EmbroideryStoreScreen());
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.layers_outlined,
          title: 'Sewing Floor Store',
          isActive: activeRoute == '/store/sewing',
          onTap: () {
            _navigateTo(context, const CentralStoreGodownScreen());
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.waves_outlined,
          title: 'Washing Floor Store',
          isActive: activeRoute == '/store/washing',
          onTap: () {
            _navigateTo(context, const WashingFloorScreen());
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.air_rounded,
          title: 'Ironing Floor Store',
          isActive: activeRoute == '/store/iron',
          onTap: () {
            _navigateTo(context, const IronFloorScreen());
          },
        ),
        _buildNavItem(
          context: context,
          icon: Icons.smart_toy_outlined,
          title: 'Zigza AI Copilot',
          isActive: activeRoute == '/store/zigza-ai',
          onTap: () {
            _navigateTo(context, const CuttingZigzaAiScreen());
          },
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('ACCOUNT'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.person_outline_rounded,
          title: 'Division Profile',
          isActive: activeRoute == '/store/profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    } else if (isDispatch) {
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
        _buildSectionLabel('12. DISPATCH & LOGISTICS HUB'),
        const SizedBox(height: 4),
        _buildNavItem(
          context: context,
          icon: Icons.local_shipping_outlined,
          title: 'Floor Dashboard',
          isActive: activeRoute == '/dispatch',
          onTap: () {
            if (activeRoute == '/dispatch') {
              Navigator.pop(context);
            } else {
              _navigateTo(context, const DispatchLogisticsHubScreen());
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
          isActive: activeRoute == '/dispatch/profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    } else {
      navChildren = [
        _buildWorkspaceCard(tenant, isSuperAdmin, role),
        const SizedBox(height: 10),
        _buildSectionLabel('MAIN NAVIGATION'),
        const SizedBox(height: 6),
        _buildNavItem(
          context: context,
          icon: Icons.dashboard_outlined,
          title: 'Dashboard',
          isActive: activeRoute == '/dashboard' || activeRoute == '/stitching-sewing/dashboard',
          onTap: () => _navigateTo(context, const LinemanDashboard()),
        ),
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
        _buildNavItem(
          context: context,
          icon: Icons.store_mall_directory_outlined,
          title: 'Buyers & Vendors',
          isActive: activeRoute == '/merchandising/buyers' || activeRoute == '/vendors',
          onTap: () => _navigateTo(context, const ActiveBuyersScreen()),
        ),
        _buildNavItem(
          context: context,
          icon: Icons.people_outline_rounded,
          title: 'Supervisor & Workers',
          isActive: activeRoute == '/access-control' || activeRoute == '/department-heads' || activeRoute == '/modules/access-control',
          onTap: () => _navigateTo(context, const DepartmentHeadsScreen()),
        ),
        _buildNavItem(
          context: context,
          icon: Icons.checkroom_outlined,
          title: 'All Designs',
          isActive: activeRoute == '/design' || activeRoute == '/all-designs',
          onTap: () => _navigateTo(context, const DesignStudioScreen()),
        ),
        _buildNavItem(
          context: context,
          icon: Icons.layers_outlined,
          title: 'Fabric & Store',
          isActive: activeRoute == '/store' || activeRoute == '/stitching-sewing/store',
          onTap: () => _navigateTo(context, const CentralStoreGodownScreen()),
        ),
        _buildNavItem(
          context: context,
          icon: Icons.auto_awesome_outlined,
          title: 'Zigza AI',
          isActive: activeRoute == '/cutting/zigza-ai',
          onTap: () => _navigateTo(context, const CuttingZigzaAiScreen()),
        ),
        _buildNavItem(
          context: context,
          icon: Icons.description_outlined,
          title: 'Reports',
          isActive: activeRoute == '/reports',
          onTap: () => _navigateTo(context, const ReportsScreen()),
        ),
        _buildNavItem(
          context: context,
          icon: Icons.badge_outlined,
          title: 'Company Profile',
          isActive: activeRoute == '/profile' || activeRoute == '/company-profile',
          onTap: () => _navigateTo(context, const CompanyProfileScreen()),
        ),
      ];
    }

    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.84,
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(context),

            // DRAWER NAVIGATION LIST
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                children: navChildren,
              ),
            ),

            _buildDrawerFooter(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceCard(dynamic tenant, bool isSuperAdmin, String role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA), // Light Mint Tint
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'WORKSPACE',
                  style: GoogleFonts.publicSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tenant?.companyName ?? 'Nubira Creation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0B1220),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.4)),
            ),
            child: Text(
              isSuperAdmin ? 'SUPERADMIN' : (role == 'ADMIN' ? 'ADMIN' : role),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F766E),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 6, bottom: 4),
      child: Text(
        label,
        style: GoogleFonts.publicSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.1,
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
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF0FDFA) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.45), width: 1.2)
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // Rounded Icon Container Box
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: isActive ? Colors.white : const Color(0xFF475569),
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: isActive ? const Color(0xFF0B1220) : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isActive ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

