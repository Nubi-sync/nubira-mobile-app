import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/screens/admin_shell.dart';
import '../../dashboard/store_dashboard.dart';
import '../../dashboard/mending_dashboard.dart';
import '../../dashboard/qc_dashboard.dart';
import '../../dashboard/dispatch_dashboard.dart';
import '../models/module_card_model.dart';
import '../widgets/workspace_hub_drawer.dart';
import 'supervisor_floor_stations_screen.dart';
import 'company_profile_screen.dart';
import 'department_heads_screen.dart';
import 'generic_division_screen.dart';

/// Design System Tokens strictly based on web_admin/docs_logic/design.md
class DesignTokens {
  static const Color brandSteel = Color(0xFF3A3564);
  static const Color brandSteelHover = Color(0xFF2A2649);
  static const Color canvasCream = Color(0xFFFAF7F0);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color foregroundInk = Color(0xFF0F172A);
  static const Color mutedInk = Color(0xFF475569);
  static const Color faintInk = Color(0xFF94A3B8);
  static const Color standardBorder = Color(0x1A000000); // border-black/10
  static const Color subtleDivider = Color(0xFFF1F5F9); // slate-100

  // Badges
  static const Color badgeExecutiveBg = Color(0xFFFEF3C7); // amber-100
  static const Color badgeExecutiveText = Color(0xFFB45309); // amber-700
  static const Color badgeExecutiveBorder = Color(0xFFFDE68A);

  static const Color badgeLiveGreenBg = Color(0xFFECFDF5);
  static const Color badgeLiveGreenText = Color(0xFF047857);
  static const Color badgeLiveGreenBorder = Color(0xFFA7F3D0);
}

class EnterpriseWorkspaceHubScreen extends ConsumerStatefulWidget {
  const EnterpriseWorkspaceHubScreen({super.key});

  @override
  ConsumerState<EnterpriseWorkspaceHubScreen> createState() => _EnterpriseWorkspaceHubScreenState();
}

class _EnterpriseWorkspaceHubScreenState extends ConsumerState<EnterpriseWorkspaceHubScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _launchingId;

  bool _isModuleAllowed(String modRoute, List<String> allowedDivisions) {
    if (allowedDivisions.isEmpty || allowedDivisions.contains('/modules')) return true;
    final r = modRoute.replaceAll(RegExp(r'/+$'), '');
    return allowedDivisions.any((allowed) {
      final a = allowed.replaceAll(RegExp(r'/+$'), '');
      return a == r || r.startsWith('$a/') || a.startsWith('$r/');
    });
  }

  bool _canAccessDepartmentHeads(String role, bool isSuperAdmin) {
    final r = role.toUpperCase();
    return isSuperAdmin || r == 'ADMIN' || r == 'SUPERADMIN' || r == 'PLATFORM_SUPERADMIN';
  }

  bool _canAccessSupervisor(String role, bool isSuperAdmin) {
    final r = role.toUpperCase();
    return isSuperAdmin || r == 'ADMIN' || r == 'SUPERADMIN' || r == 'PRODUCTION_MANAGER' || r == 'SUPERVISOR' || r == 'PLATFORM_SUPERADMIN';
  }

  void _handleLaunch(ModuleCardData mod) async {
    if (_launchingId != null) return;

    setState(() {
      _launchingId = mod.id;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    Widget destination;
    switch (mod.id) {
      case 'stitching-sewing':
        destination = const AdminShell();
        break;
      case 'store':
        destination = const StoreDashboard();
        break;
      case 'alter':
        destination = const MendingDashboard();
        break;
      case 'ready-goods':
        destination = const QcDashboard();
        break;
      case 'dispatch':
        destination = const DispatchDashboard();
        break;
      default:
        destination = GenericDivisionScreen(module: mod);
        break;
    }

    setState(() {
      _launchingId = null;
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  void _showSignOutConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DesignTokens.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: DesignTokens.foregroundInk,
          ),
        ),
        content: Text(
          'Are you sure you want to end your current session and sign out of Zigza MES?',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: DesignTokens.mutedInk,
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
                color: DesignTokens.mutedInk,
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;
    final role = authState.userRole ?? 'STAFF';
    final isSuperAdmin = tenant?.isSuperAdmin ?? false;

    final allowed = authState.allowedDivisions;
    final visibleModules = (allowed.isNotEmpty && !allowed.contains('/modules'))
        ? allEnterpriseModules.where((m) => _isModuleAllowed(m.route, allowed)).toList()
        : allEnterpriseModules;

    final operatingUnitsCount = visibleModules.length;
    final canHeads = _canAccessDepartmentHeads(role, isSuperAdmin);
    final canSupervisor = _canAccessSupervisor(role, isSuperAdmin);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: DesignTokens.canvasCream, // Warm Canvas Background (#FAF7F0)
      drawer: const WorkspaceHubDrawer(activeRoute: '/modules'),
      appBar: AppBar(
        backgroundColor: DesignTokens.cardWhite,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: DesignTokens.foregroundInk, size: 24),
          tooltip: 'Open Menu',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Text(
              'Zigza.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DesignTokens.brandSteel,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: DesignTokens.canvasCream,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: DesignTokens.standardBorder),
              ),
              child: Text(
                'ERP MES',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: DesignTokens.brandSteel,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: DesignTokens.badgeLiveGreenBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DesignTokens.badgeLiveGreenBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Live sync',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.badgeLiveGreenText,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.sync_rounded, color: Color(0xFF10B981), size: 12),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // LAYER 2: ENCAPSULATED TOP HEADER CARD
            // ==========================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: DesignTokens.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DesignTokens.standardBorder, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 44x44px Icon Container with #FAF7F0 bg
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: DesignTokens.canvasCream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DesignTokens.standardBorder),
                        ),
                        child: const Center(
                          child: Icon(Icons.grid_view_rounded, color: DesignTokens.brandSteel, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enterprise Workspace Hub',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: DesignTokens.foregroundInk,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: DesignTokens.canvasCream,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: DesignTokens.standardBorder),
                              ),
                              child: Text(
                                '$operatingUnitsCount OPERATING UNITS',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: DesignTokens.brandSteel,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Central manufacturing execution hub across your authorized division modules',
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      color: DesignTokens.mutedInk,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Button Row: Primary filled "Department heads" (role-gated) + Outline "Company profile"
                  Row(
                    children: [
                      if (canHeads) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesignTokens.brandSteel,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              minimumSize: const Size(0, 38),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DepartmentHeadsScreen()),
                              );
                            },
                            icon: const Icon(Icons.verified_user_outlined, size: 15),
                            label: Text(
                              'Department Heads',
                              style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: DesignTokens.canvasCream,
                            foregroundColor: DesignTokens.brandSteel,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size(0, 38),
                            side: const BorderSide(color: DesignTokens.standardBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
                            );
                          },
                          icon: const Icon(Icons.business_outlined, size: 15),
                          label: Text(
                            'Company Profile',
                            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Full-width muted-outline button: Sign out
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: DesignTokens.cardWhite,
                      foregroundColor: DesignTokens.mutedInk,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      minimumSize: const Size.fromHeight(38),
                      side: const BorderSide(color: DesignTokens.standardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showSignOutConfirmDialog,
                    icon: const Icon(Icons.logout_rounded, size: 15, color: Color(0xFFE11D48)),
                    label: Text(
                      'Sign Out',
                      style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFE11D48)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ==========================================
            // LAYER 3: FLOOR SUPERVISOR OPERATIONS HUB CARD (Role-Gated)
            // ==========================================
            if (canSupervisor) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: DesignTokens.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DesignTokens.standardBorder, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: DesignTokens.canvasCream,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DesignTokens.standardBorder),
                          ),
                          child: const Center(
                            child: Icon(Icons.build_rounded, color: DesignTokens.brandSteel, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Floor Supervisor Operations & Absentee Override Hub',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: DesignTokens.foregroundInk,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: DesignTokens.badgeExecutiveBg, // Amber badge
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: DesignTokens.badgeExecutiveBorder),
                                ),
                                child: Text(
                                  'EXECUTIVE CONTROL',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: DesignTokens.badgeExecutiveText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Direct access to Lineman lines, Mending verification, QC inspection, Store issuance, and Dispatch gates.',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        color: DesignTokens.mutedInk,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.brandSteel,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SupervisorFloorStationsScreen()),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Open Floor Stations',
                            style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 15),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ==========================================
            // LAYER 4: EQUALIZED MODULAR DIVISION CARDS
            // ==========================================
            ...visibleModules.map((mod) {
              final isLaunching = _launchingId == mod.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isLaunching ? DesignTokens.canvasCream : DesignTokens.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLaunching ? DesignTokens.brandSteel : DesignTokens.standardBorder,
                    width: isLaunching ? 1.8 : 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Module Icon (left) + Category Badge (right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isLaunching ? DesignTokens.brandSteel : DesignTokens.canvasCream,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DesignTokens.standardBorder),
                          ),
                          child: Icon(
                            mod.icon,
                            color: isLaunching ? Colors.white : DesignTokens.brandSteel,
                            size: 22,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isLaunching ? DesignTokens.brandSteel : DesignTokens.canvasCream,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: DesignTokens.standardBorder),
                          ),
                          child: Text(
                            isLaunching ? 'OPENING...' : mod.badge,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isLaunching ? Colors.white : DesignTokens.mutedInk,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Module Title (Bold)
                    Text(
                      mod.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: isLaunching ? DesignTokens.brandSteel : DesignTokens.foregroundInk,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // One-line Plain Description
                    Text(
                      mod.subtitle,
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        color: DesignTokens.mutedInk,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2-3 Bullet Highlights
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: DesignTokens.subtleDivider, width: 1)),
                      ),
                      child: Column(
                        children: mod.features.map((feat) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 5.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    feat,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: DesignTokens.foregroundInk,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bottom Row: Status Tag + Launch Button
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: DesignTokens.subtleDivider, width: 1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            mod.statusText,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: DesignTokens.faintInk,
                              letterSpacing: 0.5,
                            ),
                          ),
                          InkWell(
                            onTap: isLaunching ? null : () => _handleLaunch(mod),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isLaunching ? DesignTokens.brandSteel : DesignTokens.canvasCream,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: DesignTokens.standardBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isLaunching ? 'Opening…' : 'Launch',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isLaunching ? Colors.white : DesignTokens.foregroundInk,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: isLaunching ? Colors.white : DesignTokens.foregroundInk,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
