import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/screens/admin_shell.dart';
import '../../dashboard/store_dashboard.dart';
import '../../dashboard/mending_dashboard.dart';
import '../../dashboard/qc_dashboard.dart';
import '../../dashboard/dispatch_dashboard.dart';
import '../models/module_card_model.dart';
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
  String? _launchingId;

  bool _isModuleAllowed(String modRoute, List<String> allowedDivisions) {
    if (allowedDivisions.isEmpty || allowedDivisions.contains('/modules')) return true;
    final r = modRoute.replaceAll(RegExp(r'/+$'), '');
    return allowedDivisions.any((allowed) {
      final a = allowed.replaceAll(RegExp(r'/+$'), '');
      return a == r || r.startsWith('$a/') || a.startsWith('$r/');
    });
  }

  void _handleLaunch(ModuleCardData mod) async {
    if (_launchingId != null) return;

    setState(() {
      _launchingId = mod.id;
    });

    await Future.delayed(const Duration(milliseconds: 350));

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

  void _showAiAssistantDialog() {
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
                color: const Color(0xFF3A3564),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Zigza AI Copilot',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Intelligent Garment Manufacturing Execution Copilot is active and continuously monitoring production line throughput, mending rates, and inventory buffers across authorized units.',
              style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft, height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Floor Analytics: All units running at normal throughput.',
                      style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.steel),
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
    final allowed = authState.allowedDivisions;

    final visibleModules = (allowed.isNotEmpty && !allowed.contains('/modules'))
        ? allEnterpriseModules.where((m) => _isModuleAllowed(m.route, allowed)).toList()
        : allEnterpriseModules;

    final operatingUnitsCount = visibleModules.length;
    final companyName = tenant?.companyName ?? 'Zigza Enterprise';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        leadingWidth: 48,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14.0),
          child: Center(
            child: Image.asset(
              'assets/images/icon.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.apps_rounded, color: AppTheme.steel, size: 28),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              'Zigza.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.steel,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.steelMist,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ERP MES',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.steel,
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
              color: AppTheme.greenMist,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
            ),
            child: Row(
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
                Text(
                  'Live sync',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.green,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.sync_rounded, color: AppTheme.green, size: 12),
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
            // 1. PAGE HEADER CARD (Enterprise Workspace Hub)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Center(
                          child: Icon(Icons.grid_view_rounded, color: AppTheme.steel, size: 22),
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
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.bg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(
                                '$operatingUnitsCount OPERATING UNITS',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.steel,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Central manufacturing execution hub across $companyName authorized divisions',
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      color: AppTheme.inkSoft,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Action Buttons Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Department Heads RBAC Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.steel,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: const Size(0, 36),
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

                      // Company Profile Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppTheme.bg,
                          foregroundColor: AppTheme.steel,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: const Size(0, 36),
                          side: const BorderSide(color: AppTheme.border),
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

                      // Sign Out Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.inkSoft,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 36),
                          side: const BorderSide(color: AppTheme.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 15, color: AppTheme.red),
                        label: Text(
                          'Sign Out',
                          style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // 2. FLOOR SUPERVISOR & OPERATIONS HUB BANNER
            // ==========================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Center(
                          child: Icon(Icons.build_rounded, color: AppTheme.steel, size: 20),
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
                                color: AppTheme.ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.bg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(
                                'EXECUTIVE CONTROL',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.steel,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Direct access to Lineman lines, Mending verification, QC inspection, Store issuance, and Dispatch gates.',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      color: AppTheme.inkSoft,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.steel,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      minimumSize: const Size.fromHeight(40),
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
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ==========================================
            // 3. EQUALIZED ENTERPRISE MODULE CARDS LIST
            // ==========================================
            ...visibleModules.map((mod) {
              final isLaunching = _launchingId == mod.id;
              final isOtherLaunching = _launchingId != null && _launchingId != mod.id;

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isOtherLaunching ? 0.5 : 1.0,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isLaunching ? AppTheme.bg : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLaunching ? AppTheme.steel : AppTheme.border,
                      width: isLaunching ? 2.0 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: isOtherLaunching ? null : () => _handleLaunch(mod),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Icon + Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: isLaunching ? AppTheme.steel : AppTheme.bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Center(
                                  child: isLaunching
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Icon(
                                          mod.icon,
                                          color: AppTheme.steel,
                                          size: 22,
                                        ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isLaunching ? AppTheme.steel : AppTheme.bg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  isLaunching ? 'OPENING...' : mod.badge,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isLaunching ? Colors.white : AppTheme.inkSoft,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Title
                          Text(
                            mod.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isLaunching ? AppTheme.steel : AppTheme.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 5),

                          // Subtitle
                          Text(
                            mod.subtitle,
                            style: GoogleFonts.publicSans(
                              fontSize: 12.5,
                              color: AppTheme.inkSoft,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Feature Bullet Points
                          Container(
                            padding: const EdgeInsets.only(top: 10),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppTheme.border, width: 0.8)),
                            ),
                            child: Column(
                              children: mod.features.map((feat) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 5.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: isLaunching ? AppTheme.steel : AppTheme.inkFaint,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          feat,
                                          style: GoogleFonts.publicSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Bottom Row: Status Tag + Launch Button
                          Container(
                            padding: const EdgeInsets.only(top: 10),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppTheme.border, width: 0.8)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  mod.statusText,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.inkFaint,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                                  decoration: BoxDecoration(
                                    color: isLaunching ? AppTheme.steel : AppTheme.bg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.border, width: 1.1),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        isLaunching ? 'Opening...' : 'Launch',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isLaunching ? Colors.white : AppTheme.ink,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 13,
                                        color: isLaunching ? Colors.white : AppTheme.ink,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAiAssistantDialog,
        backgroundColor: const Color(0xFF3A3564),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.smart_toy_rounded, size: 20),
        label: Text(
          'Zigza AI',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
