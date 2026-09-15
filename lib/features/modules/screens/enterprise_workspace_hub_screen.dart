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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1C1C1A),
          ),
        ),
        content: Text(
          'Are you sure you want to end your current session and sign out of Zigza MES?',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: const Color(0xFF6B6A65),
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
                color: const Color(0xFF6B6A65),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      backgroundColor: Colors.white,
      drawer: const WorkspaceHubDrawer(activeRoute: '/modules'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF1C1C1A), size: 24),
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
                color: const Color(0xFF332B6B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F2EE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ERP MES',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6B6A65),
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
              color: const Color(0xFFE9F7EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2FAE66).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B7A43),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Live sync',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B7A43),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.sync_rounded, color: Color(0xFF1B7A43), size: 12),
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
            // 1. TOP PROMINENT CARD (Enterprise Workspace Hub)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFECECE8), width: 1),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFECECE8)),
                        ),
                        child: const Center(
                          child: Icon(Icons.grid_view_rounded, color: Color(0xFF332B6B), size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enterprise workspace hub',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1C1C1A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F2EE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$operatingUnitsCount operating units',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF6B6A65),
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
                      color: const Color(0xFF6B6A65),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Button Row: Primary filled "Department heads" (role-gated) + Outline "Company profile"
                  Row(
                    children: [
                      if (canHeads) ...[
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF332B6B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              minimumSize: const Size(0, 38),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DepartmentHeadsScreen()),
                              );
                            },
                            child: Text(
                              'Department heads',
                              style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1C1C1A),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size(0, 38),
                            side: const BorderSide(color: Color(0xFFECECE8)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
                            );
                          },
                          child: Text(
                            'Company profile',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Full-width muted-outline button: Sign out
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF6B6A65),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size.fromHeight(38),
                      side: const BorderSide(color: Color(0xFFECECE8)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _showSignOutConfirmDialog,
                    child: Text(
                      'Sign out',
                      style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // 2. FLOOR SUPERVISOR OPERATIONS HUB CARD (Role-Gated)
            // ==========================================
            if (canSupervisor) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFECECE8), width: 1),
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
                            color: const Color(0xFFFAFAF8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFECECE8)),
                          ),
                          child: const Center(
                            child: Icon(Icons.build_rounded, color: Color(0xFF332B6B), size: 20),
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
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1C1C1A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDF0DC), // Amber badge bg
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Executive control',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF8A6D2F), // Amber text
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
                        color: const Color(0xFF6B6A65),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF332B6B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            'Open floor stations',
                            style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ==========================================
            // 3. EQUALIZED MODULAR DIVISION CARDS
            // ==========================================
            ...visibleModules.map((mod) {
              final isLaunching = _launchingId == mod.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFECECE8), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Module Icon (left) + Category Badge (right, neutral gray)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFECECE8)),
                          ),
                          child: Icon(
                            mod.icon,
                            color: const Color(0xFF332B6B),
                            size: 22,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F2EE), // Neutral gray badge
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            mod.badge,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6B6A65),
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
                        color: const Color(0xFF1C1C1A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // One-line Plain Description
                    Text(
                      mod.subtitle,
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        color: const Color(0xFF6B6A65),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2-3 Bullet Highlights (Small dot + Short label)
                    Column(
                      children: mod.features.map((feat) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5.0),
                          child: Row(
                            children: [
                              Container(
                                width: 4.5,
                                height: 4.5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF9B9A94),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feat,
                                  style: GoogleFonts.publicSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF6B6A65),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Full-width Primary Button: "Launch ->"
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF332B6B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isLaunching ? null : () => _handleLaunch(mod),
                      child: isLaunching
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Opening…',
                                  style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Launch',
                                  style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, size: 15),
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
