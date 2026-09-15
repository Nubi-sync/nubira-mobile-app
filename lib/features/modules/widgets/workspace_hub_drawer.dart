import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/module_card_model.dart';
import '../screens/enterprise_workspace_hub_screen.dart';
import '../screens/supervisor_floor_stations_screen.dart';
import '../screens/department_heads_screen.dart';
import '../screens/company_profile_screen.dart';
import '../screens/generic_division_screen.dart';
import '../../admin/screens/admin_shell.dart';
import '../../dashboard/store_dashboard.dart';
import '../../dashboard/mending_dashboard.dart';
import '../../dashboard/qc_dashboard.dart';
import '../../dashboard/dispatch_dashboard.dart';

class WorkspaceHubDrawer extends ConsumerWidget {
  final String activeRoute;

  const WorkspaceHubDrawer({
    super.key,
    this.activeRoute = '/modules',
  });

  bool _canAccessDepartmentHeads(String role, bool isSuperAdmin, bool isHead) {
    final r = role.toUpperCase();
    return isSuperAdmin || isHead || r == 'ADMIN' || r == 'SUPERADMIN' || r == 'PLATFORM_SUPERADMIN';
  }

  bool _canAccessSupervisor(String role, bool isSuperAdmin) {
    final r = role.toUpperCase();
    return isSuperAdmin || r == 'ADMIN' || r == 'SUPERADMIN' || r == 'PRODUCTION_MANAGER' || r == 'SUPERVISOR' || r == 'PLATFORM_SUPERADMIN';
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

  void _showAiAssistantDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF3A3564), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Zigza AI Copilot',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Active Plant Intelligence is monitoring shop-floor execution throughput and trims consumption across authorized divisions.',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // Close Drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
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

    final rawAllowed = tenant?.allowedDivisions.isNotEmpty == true
        ? tenant!.allowedDivisions
        : authState.allowedDivisions;

    final isNubira = (tenant?.companyName ?? '').toLowerCase().contains('nubira') ||
        (tenant?.isLegacyNubira == true) ||
        (authState.cachedUsername ?? '').toLowerCase().contains('nubira') ||
        (authState.cachedUsername ?? '').toLowerCase() == 'admin';

    final allowed = isNubira
        ? (rawAllowed.isNotEmpty && rawAllowed.length <= 2 ? rawAllowed : const ['/stitching-sewing', '/store'])
        : (rawAllowed.isNotEmpty ? rawAllowed : const ['/stitching-sewing', '/store']);

    final visibleModules = allEnterpriseModules
        .where((m) => allowed.contains(m.route) || allowed.any((a) => a.startsWith(m.route) || m.route.startsWith(a)))
        .toList();

    final canHeads = _canAccessDepartmentHeads(role, isSuperAdmin, false);
    final canSupervisor = _canAccessSupervisor(role, isSuperAdmin);

    // User Initials
    final initials = adminDisplayName.trim().isNotEmpty
        ? adminDisplayName.trim().split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() : '').take(2).join()
        : 'Z';

    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // DRAWER HEADER (Matching Image 3)
            // ==========================================
            Container(
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
                                color: const Color(0xFF3A3564),
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
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(14),
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
            ),

            // ==========================================
            // DRAWER NAVIGATION LIST
            // ==========================================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                children: [
                  _buildSectionLabel('WORKSPACE HUB'),
                  const SizedBox(height: 4),

                  // All Modules (Hub Home)
                  _buildNavItem(
                    context: context,
                    icon: Icons.grid_view_rounded,
                    title: 'All Modules',
                    isActive: activeRoute == '/modules',
                    onTap: () {
                      if (activeRoute == '/modules') {
                        Navigator.pop(context);
                      } else {
                        _navigateTo(context, const EnterpriseWorkspaceHubScreen());
                      }
                    },
                  ),

                  // Department Heads (Role-Gated)
                  if (canHeads)
                    _buildNavItem(
                      context: context,
                      icon: Icons.shield_outlined,
                      title: 'Department Heads',
                      isActive: activeRoute == '/access-control',
                      onTap: () => _navigateTo(context, const DepartmentHeadsScreen()),
                    ),

                  // Supervisor Operations (Role-Gated)
                  if (canSupervisor)
                    _buildNavItem(
                      context: context,
                      icon: Icons.build_outlined,
                      title: 'Supervisor Operations',
                      isActive: activeRoute == '/supervisor-desk',
                      onTap: () => _navigateTo(context, const SupervisorFloorStationsScreen()),
                    ),

                  // Company Profile
                  _buildNavItem(
                    context: context,
                    icon: Icons.business_outlined,
                    title: 'Company Profile',
                    isActive: activeRoute == '/profile',
                    onTap: () => _navigateTo(context, const CompanyProfileScreen()),
                  ),

                  // Zigza AI
                  _buildNavItem(
                    context: context,
                    icon: Icons.smart_toy_outlined,
                    title: 'Zigza AI',
                    isActive: false,
                    onTap: () {
                      Navigator.pop(context);
                      _showAiAssistantDialog(context);
                    },
                  ),

                  const SizedBox(height: 16),
                  _buildSectionLabel('AUTHORIZED OPERATING UNITS'),
                  const SizedBox(height: 4),

                  // Dynamic list of authorized division cards
                  ...visibleModules.map((mod) {
                    final isCurrentMod = activeRoute == mod.route;
                    return _buildNavItem(
                      context: context,
                      icon: mod.icon,
                      title: mod.title,
                      isActive: isCurrentMod,
                      onTap: () {
                        if (isCurrentMod) {
                          Navigator.pop(context);
                          return;
                        }

                        Widget dest;
                        switch (mod.id) {
                          case 'stitching-sewing':
                            dest = const AdminShell();
                            break;
                          case 'store':
                            dest = const StoreDashboard();
                            break;
                          case 'alter':
                            dest = const MendingDashboard();
                            break;
                          case 'ready-goods':
                            dest = const QcDashboard();
                            break;
                          case 'dispatch':
                            dest = const DispatchDashboard();
                            break;
                          default:
                            dest = GenericDivisionScreen(module: mod);
                            break;
                        }
                        _navigateTo(context, dest);
                      },
                    );
                  }),
                ],
              ),
            ),

            // ==========================================
            // PINNED FOOTER (#FFFFFF / #FAF7F0 Surface matching Image 3)
            // ==========================================
            Container(
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
                      color: Color(0xFF3A3564),
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
                                color: const Color(0xFF64748B),
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
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.arrow_outward_rounded,
                                    size: 11,
                                    color: Color(0xFF0F172A),
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
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B), size: 20),
                    tooltip: 'Sign Out',
                    onPressed: () => _showSignOutDialog(context, ref),
                  ),
                ],
              ),
            ),
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
        color: isActive ? const Color(0xFFFAF7F0) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            border: isActive
                ? const Border(left: BorderSide(color: Color(0xFF3A3564), width: 3.5))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF3A3564) : const Color(0xFF475569),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.publicSans(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: isActive ? const Color(0xFF3A3564) : const Color(0xFF0F172A),
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
