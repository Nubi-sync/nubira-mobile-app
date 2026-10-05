import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/screens/admin_shell.dart';
import '../../design/screens/design_studio_screen.dart';
import '../../merchandising/screens/merchandising_dashboard_screen.dart';
import '../../cutting/screens/cutting_lay_floor_screen.dart';
import '../../printing/screens/printing_studio_screen.dart';
import '../../embroidery/screens/embroidery_studio_screen.dart';
import '../../washing/screens/washing_floor_screen.dart';
import '../../iron/screens/iron_floor_screen.dart';
import '../../store/screens/central_store_godown_screen.dart';
import '../../dashboard/mending_dashboard.dart';
import '../../dashboard/dispatch_dashboard.dart';
import '../../ready_goods/screens/quality_clinic_floor_screen.dart';
import '../models/module_card_model.dart';
import '../widgets/workspace_hub_drawer.dart';
import 'generic_division_screen.dart';

class EnterpriseWorkspaceHubScreen extends ConsumerStatefulWidget {
  const EnterpriseWorkspaceHubScreen({super.key});

  @override
  ConsumerState<EnterpriseWorkspaceHubScreen> createState() => _EnterpriseWorkspaceHubScreenState();
}

class _EnterpriseWorkspaceHubScreenState extends ConsumerState<EnterpriseWorkspaceHubScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String? _launchingId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isModuleAllowed(String modRoute, List<String> allowedDivisions) {
    if (allowedDivisions.isEmpty || allowedDivisions.contains('/modules')) return true;
    if (modRoute == '/ready-goods' && (allowedDivisions.contains('/ready-goods') || allowedDivisions.contains('/alter'))) {
      return true;
    }
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

    await Future.delayed(const Duration(milliseconds: 250));

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
      case 'printing':
        destination = const PrintingStudioScreen();
        break;
      case 'embroidery':
        destination = const EmbroideryStudioScreen();
        break;
      case 'washing':
        destination = const WashingFloorScreen();
        break;
      case 'iron':
        destination = const IronFloorScreen();
        break;
      case 'stitching-sewing':
        destination = const AdminShell();
        break;
      case 'store':
        destination = const CentralStoreGodownScreen();
        break;
      case 'alter':
        destination = const MendingDashboard();
        break;
      case 'ready-goods':
        destination = const QualityClinicFloorScreen();
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;
    final role = authState.userRole ?? 'STAFF';
    final isSuperAdmin = tenant?.isSuperAdmin ?? false;

    // Strict tenant company name resolution
    final rawCompanyName = tenant?.companyName;
    final resolvedCompany = (rawCompanyName != null &&
            rawCompanyName.trim().isNotEmpty &&
            rawCompanyName != 'Account Deactivated')
        ? rawCompanyName.trim()
        : '';

    // Strict multi-tenant division resolution
    final rawAllowed = tenant?.allowedDivisions.isNotEmpty == true
        ? tenant!.allowedDivisions
        : authState.allowedDivisions;

    final isAdminUser = isSuperAdmin ||
        role.toUpperCase() == 'ADMIN' ||
        role.toUpperCase() == 'SUPERADMIN' ||
        role.toUpperCase() == 'PLATFORM_SUPERADMIN' ||
        (authState.cachedUsername ?? '').toLowerCase().contains('admin') ||
        (tenant?.userEmail ?? '').toLowerCase().contains('admin');

    final allowed = rawAllowed.isNotEmpty
        ? rawAllowed
        : (isAdminUser ? allEnterpriseModules.map((m) => m.route).toList() : const ['/stitching-sewing', '/store']);

    final visibleModules = (rawAllowed.isNotEmpty && !rawAllowed.contains('/modules'))
        ? allEnterpriseModules.where((m) => _isModuleAllowed(m.route, allowed)).toList()
        : allEnterpriseModules;

    final operatingUnitsCount = visibleModules.length;

    // Search filter
    final query = _searchQuery.toLowerCase().trim();
    final filteredModules = query.isEmpty
        ? visibleModules
        : visibleModules.where((m) {
            return m.title.toLowerCase().contains(query) ||
                m.subtitle.toLowerCase().contains(query) ||
                m.badge.toLowerCase().contains(query) ||
                m.statusText.toLowerCase().contains(query) ||
                m.features.any((f) => f.toLowerCase().contains(query));
          }).toList();

    final headingSubtitle = resolvedCompany.isNotEmpty
        ? 'Central manufacturing execution and floor operations hub for $resolvedCompany'
        : 'Central manufacturing execution hub across ${visibleModules.length == allEnterpriseModules.length ? 'all 11 apparel production divisions' : 'your authorized division modules'}';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const WorkspaceHubDrawer(activeRoute: '/modules'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // 1. PAGE HEADER CARD (Matching Web Admin)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      // 44x44 Icon Box with #F0FDFA bg and subtle border
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x26000000)),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.grid_view_rounded,
                            color: Color(0xFF0B1220),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: resolvedCompany.isNotEmpty ? 'Welcome, ' : 'Enterprise ',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0B1220),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  TextSpan(
                                    text: resolvedCompany.isNotEmpty ? resolvedCompany : 'Workspace Hub',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1D4ED8),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDFA),
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(color: const Color(0x26000000)),
                              ),
                              child: Text(
                                '$operatingUnitsCount OPERATING UNITS',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0B1220),
                                  letterSpacing: 0.6,
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
                    headingSubtitle,
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search Bar
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.search,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            style: GoogleFonts.publicSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0B1220),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search modules & divisions...',
                              hintStyle: GoogleFonts.publicSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          InkWell(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ==========================================
            // 2. EQUALIZED MODULE CARDS GRID
            // ==========================================
            if (filteredModules.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x26000000)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.search,
                          size: 24,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No modules found',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No operating unit matched "$_searchQuery". Try a different search keyword.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.publicSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D4ED8),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x331D4ED8),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Clear Search',
                          style: GoogleFonts.publicSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...filteredModules.map((mod) {
                final isLaunching = _launchingId == mod.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isLaunching ? const Color(0xFFF0FDFA).withValues(alpha: 0.4) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLaunching ? const Color(0xFF0B1220) : const Color(0xFFE2E8F0),
                      width: isLaunching ? 1.5 : 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Bare Outline Icon (left) + Category Tag (right)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDFA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0x26000000)),
                              ),
                              child: Center(
                                child: Icon(
                                  mod.icon,
                                  color: const Color(0xFF0B1220),
                                  size: 22,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isLaunching ? const Color(0xFF0B1220) : const Color(0xFFF0FDFA),
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(
                                  color: isLaunching ? const Color(0xFF0B1220) : const Color(0x26000000),
                                ),
                              ),
                              child: Text(
                                isLaunching ? 'OPENING...' : mod.badge,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isLaunching ? Colors.white : const Color(0xFF0B1220),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Module Title (Bold Plus Jakarta Sans)
                        Text(
                          mod.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B1220),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Subtitle
                        Text(
                          mod.subtitle,
                          style: GoogleFonts.publicSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2 Feature Bullets
                        Column(
                          children: mod.features.take(2).map((feat) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0B1220).withValues(alpha: 0.6),
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
                        const SizedBox(height: 14),

                        // Launch Button (Royal Blue full width)
                        InkWell(
                          onTap: isLaunching ? null : () => _handleLaunch(mod),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D4ED8),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x2E1D4ED8),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isLaunching) ...[
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Opening...',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    'Launch',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],

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
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF0B1220), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Zigza AI Copilot',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Active Plant Intelligence is monitoring shop-floor execution throughput and trims consumption across authorized divisions.',
                style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Close',
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
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
                  const Icon(Icons.smart_toy_outlined, color: Color(0xFFFAF7F0), size: 18),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 7,
                      height: 7,
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
                  fontSize: 13,
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
