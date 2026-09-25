import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../admin/screens/admin_shell.dart';
import '../../design/screens/design_studio_screen.dart';
import '../../merchandising/screens/merchandising_dashboard_screen.dart';
import '../../cutting/screens/cutting_lay_floor_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  bool _isModuleAllowed(String modRoute, List<String> allowedDivisions) {
    if (allowedDivisions.isEmpty) return false;
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
      case 'design':
        destination = const DesignStudioScreen();
        break;
      case 'merchandising':
        destination = const MerchandisingDashboardScreen();
        break;
      case 'cutting':
        destination = const CuttingLayFloorScreen();
        break;
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
              final nav = Navigator.of(context);
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                nav.pushAndRemoveUntil(
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;
    final role = authState.userRole ?? 'STAFF';
    final isSuperAdmin = tenant?.isSuperAdmin ?? false;

    // Strict multi-tenant division resolution
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

    final visibleModules = allEnterpriseModules.where((m) => _isModuleAllowed(m.route, allowed)).toList();

    final operatingUnitsCount = visibleModules.length;
    final canHeads = _canAccessDepartmentHeads(role, isSuperAdmin);
    final canSupervisor = _canAccessSupervisor(role, isSuperAdmin);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: DesignTokens.canvasCream, // Warm Canvas Background (#FAF7F0)
      drawer: const WorkspaceHubDrawer(activeRoute: '/modules'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DesignTokens.cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: DesignTokens.standardBorder, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 48x48px Icon Container with #FAF7F0 bg
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: DesignTokens.canvasCream,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x14000000)),
                        ),
                        child: const Center(
                          child: Icon(Icons.grid_view_rounded, color: DesignTokens.brandSteel, size: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enterprise Workspace\nHub',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: DesignTokens.foregroundInk,
                                height: 1.18,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: DesignTokens.canvasCream,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0x14000000)),
                              ),
                              child: Text(
                                '$operatingUnitsCount OPERATING UNITS',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: DesignTokens.brandSteel,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Central manufacturing execution hub across your authorized division modules',
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: DesignTokens.mutedInk,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Button Row: Primary filled "Department heads" (role-gated) + Outline "Company profile"
                  Row(
                    children: [
                      if (canHeads) ...[
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DepartmentHeadsScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: DesignTokens.brandSteel,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_user_outlined, size: 15, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'Department Heads',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: DesignTokens.canvasCream,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x18000000)),
                          ),
                          child: Text(
                            'Company Profile',
                            style: GoogleFonts.publicSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: DesignTokens.brandSteel,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Standalone Sign out button matching Web screenshot
                  Row(
                    children: [
                      InkWell(
                        onTap: _showSignOutConfirmDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x22000000)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.logout_rounded, size: 15, color: Color(0xFF0F172A)),
                              const SizedBox(width: 8),
                              Text(
                                'Sign Out',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // LAYER 3: FLOOR SUPERVISOR OPERATIONS HUB CARD (Role-Gated)
            // ==========================================
            if (canSupervisor) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: DesignTokens.cardWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DesignTokens.standardBorder, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
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
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: DesignTokens.canvasCream,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x14000000)),
                          ),
                          child: const Center(
                            child: Icon(Icons.build_rounded, color: DesignTokens.brandSteel, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Floor Supervisor Operations &\nAbsentee Override Hub',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: DesignTokens.foregroundInk,
                                  height: 1.25,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: DesignTokens.badgeExecutiveBg, // Amber badge
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: DesignTokens.badgeExecutiveBorder),
                                ),
                                child: Text(
                                  'EXECUTIVE CONTROL',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: DesignTokens.badgeExecutiveText,
                                    letterSpacing: 0.6,
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
                        fontWeight: FontWeight.w400,
                        color: DesignTokens.mutedInk,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SupervisorFloorStationsScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: DesignTokens.brandSteel,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Open Floor Stations',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ==========================================
            // LAYER 4: EQUALIZED MODULAR DIVISION CARDS
            // ==========================================
            ...visibleModules.map((mod) {
              final isLaunching = _launchingId == mod.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isLaunching ? const Color(0xFFFAF7F0) : DesignTokens.cardWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isLaunching ? DesignTokens.brandSteel : DesignTokens.standardBorder,
                    width: isLaunching ? 1.8 : 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isLaunching ? null : () => _handleLaunch(mod),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Module Icon (left) + Category Badge (right)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isLaunching ? DesignTokens.brandSteel : DesignTokens.canvasCream,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0x14000000)),
                                ),
                                child: Icon(
                                  mod.icon,
                                  color: isLaunching ? Colors.white : DesignTokens.brandSteel,
                                  size: 22,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isLaunching ? DesignTokens.brandSteel : DesignTokens.canvasCream,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0x14000000)),
                                ),
                                child: Text(
                                  isLaunching ? 'OPENING...' : mod.badge,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: isLaunching ? Colors.white : DesignTokens.mutedInk,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Module Title (Bold Plus Jakarta Sans)
                          Text(
                            mod.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isLaunching ? DesignTokens.brandSteel : DesignTokens.foregroundInk,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // One-line Plain Description
                          Text(
                            mod.subtitle,
                            style: GoogleFonts.publicSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              color: DesignTokens.mutedInk,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Bullet Highlights
                          Column(
                            children: mod.features.map((feat) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF94A3B8),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        feat,
                                        style: GoogleFonts.publicSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 60),
          ],
        ),
      ),
      floatingActionButton: InkWell(
        onTap: () {
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
                      color: DesignTokens.canvasCream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: DesignTokens.standardBorder),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: DesignTokens.brandSteel, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Zigza AI Copilot',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: DesignTokens.foregroundInk,
                    ),
                  ),
                ],
              ),
              content: Text(
                'Active Plant Intelligence is monitoring shop-floor execution throughput and trims consumption across authorized divisions.',
                style: GoogleFonts.publicSans(fontSize: 13, color: DesignTokens.mutedInk, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Close',
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: DesignTokens.brandSteel,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: DesignTokens.brandSteel,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x403A3564),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.smart_toy_outlined, color: Color(0xFFFAF7F0), size: 20),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                'Zigza AI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
