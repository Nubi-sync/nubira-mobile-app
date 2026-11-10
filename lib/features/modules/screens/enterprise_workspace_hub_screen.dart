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

/// Subtle, pleasing blinking live indicator dot for floor telemetry
class _PulsingGreenDot extends StatefulWidget {
  const _PulsingGreenDot();

  @override
  State<_PulsingGreenDot> createState() => _PulsingGreenDotState();
}

class _PulsingGreenDotState extends State<_PulsingGreenDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, _) {
        final val = _opacityAnimation.value;
        return Container(
          width: 7.5,
          height: 7.5,
          decoration: BoxDecoration(
            color: Color(0xFF10B981).withValues(alpha: val),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0xFF10B981).withValues(alpha: val * 0.5),
                blurRadius: 4.5,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
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
                m.displayTitle.toLowerCase().contains(query) ||
                m.displaySubtitle.toLowerCase().contains(query) ||
                m.displayNumber.toLowerCase().contains(query) ||
                m.features.any((f) => f.toLowerCase().contains(query));
          }).toList();


    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawerScrimColor: const Color(0x66000000),
      drawerEdgeDragWidth: 32,
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
            // 1. PAGE HEADER CARD (Minimalist: 3 elements)
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
                  // 1. Prominent Welcome Title
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: resolvedCompany.isNotEmpty ? 'Welcome, ' : 'Enterprise ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B1220),
                            letterSpacing: -0.4,
                          ),
                        ),
                        TextSpan(
                          text: resolvedCompany.isNotEmpty ? resolvedCompany : 'Hub',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1D4ED8),
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Search Bar
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
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
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        filled: false,
                        fillColor: Colors.transparent,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12, right: 8),
                          child: Icon(
                            Icons.search,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 40),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? InkWell(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              )
                            : null,
                        hintText: 'Search modules...',
                        hintStyle: GoogleFonts.publicSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  // 3. Operating Units Count (Below Search Bar - Moved down with subtle blinking live indicator)
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const _PulsingGreenDot(),
                      const SizedBox(width: 7),
                      Text(
                        _searchQuery.isNotEmpty
                            ? '${filteredModules.length} of $operatingUnitsCount Operating Units'
                            : '$operatingUnitsCount Operating Units Active',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
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

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isLaunching ? null : () => _handleLaunch(mod),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        decoration: BoxDecoration(
                          color: isLaunching ? const Color(0xFFF0FDFA).withValues(alpha: 0.6) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLaunching ? const Color(0xFF0B1220) : const Color(0xFFE2E8F0),
                            width: isLaunching ? 1.5 : 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Serious & Prominent Icon Box
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDFA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0x1F000000)),
                              ),
                              child: Center(
                                child: isLaunching
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Color(0xFF0B1220),
                                        ),
                                      )
                                    : Icon(
                                        mod.icon,
                                        color: const Color(0xFF0B1220),
                                        size: 23,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Number + Title + Clean Subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          mod.displayNumber,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          mod.displayTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0B1220),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mod.displaySubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),

                            // Right Arrow / Opening State
                            if (isLaunching)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'OPENING...',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1D4ED8),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
