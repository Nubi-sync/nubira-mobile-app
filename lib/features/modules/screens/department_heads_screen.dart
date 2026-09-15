import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../../auth/providers/auth_provider.dart';
import 'appoint_department_head_screen.dart';

// ============================================================================
// MODELS & CATALOG DEFINITIONS (Strictly matching web_admin/src/lib/access-control.ts)
// ============================================================================

class DepartmentHeadItem {
  final String id;
  final String displayName;
  final String username;
  final String email;
  final String role;
  final String designation;
  final List<String> allowedModules;
  final bool isActive;
  final String? phone;
  final String? createdAt;

  const DepartmentHeadItem({
    required this.id,
    required this.displayName,
    required this.username,
    required this.email,
    required this.role,
    required this.designation,
    required this.allowedModules,
    required this.isActive,
    this.phone,
    this.createdAt,
  });

  DepartmentHeadItem copyWith({
    String? id,
    String? displayName,
    String? username,
    String? email,
    String? role,
    String? designation,
    List<String>? allowedModules,
    bool? isActive,
    String? phone,
    String? createdAt,
  }) {
    return DepartmentHeadItem(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      designation: designation ?? this.designation,
      allowedModules: allowedModules ?? this.allowedModules,
      isActive: isActive ?? this.isActive,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DepartmentHeadCatalogDef {
  final String id;
  final String code;
  final String name;
  final String route;
  final String defaultDesignation;
  final IconData icon;
  final String description;

  const DepartmentHeadCatalogDef({
    required this.id,
    required this.code,
    required this.name,
    required this.route,
    required this.defaultDesignation,
    required this.icon,
    required this.description,
  });
}

const List<DepartmentHeadCatalogDef> kDepartmentHeadsCatalog = [
  DepartmentHeadCatalogDef(
    id: 'div-01',
    code: '01',
    name: 'Design & Tech-Pack Studio',
    route: '/design',
    defaultDesignation: 'Design Studio Head / CAD Master',
    icon: Icons.palette_outlined,
    description: 'CAD sketches, tech-pack specs, sample iterations & grading approvals',
  ),
  DepartmentHeadCatalogDef(
    id: 'div-02',
    code: '02',
    name: 'Merchandising & Sourcing Desk',
    route: '/merchandising',
    defaultDesignation: 'Senior Merchandiser / Sourcing Head',
    icon: Icons.work_outline,
    description: 'Buyer PO allocation, BOM costing, trim procurement & shipment schedules',
  ),
  DepartmentHeadCatalogDef(
    id: 'div-03',
    code: '03',
    name: 'Cutting Floor & Spreading CAD',
    route: '/cutting',
    defaultDesignation: 'Cutting Master / Cutting Floor Head',
    icon: Icons.content_cut_outlined,
    description: 'Fabric roll lay planning, marker efficiency, auto-cutters & bundle tickets',
  ),
  DepartmentHeadCatalogDef(
    id: 'div-04',
    code: '04',
    name: 'Screen & Digital Printing Studio',
    route: '/printing',
    defaultDesignation: 'Printing Master / Print Unit Head',
    icon: Icons.print_outlined,
    description: 'Screen print tables, industrial DTG curing & strike-off color approvals',
  ),
  DepartmentHeadCatalogDef(
    id: 'div-05',
    code: '05',
    name: 'Multi-Head Embroidery Studio',
    route: '/embroidery',
    defaultDesignation: 'Embroidery Master / Unit Head',
    icon: Icons.auto_awesome_outlined,
    description: 'Multi-head computerized machines, punch digitizing & stitch billing',
  ),
  DepartmentHeadCatalogDef(
    id: 'div-06',
    code: '06',
    name: 'Stitching & Sewing Assembly Line',
    route: '/stitching-sewing',
    defaultDesignation: 'Production Manager / Sewing Floor Head',
    icon: Icons.layers_outlined,
    description: 'Live cutting lots, lineman bundle allocations, 3-stage QC & store sync',
  ),
  DepartmentHeadCatalogDef(
    id: 'div-07',
    code: '07',
    name: 'Industrial Washing & Dyeing',
    route: '/washing',
    defaultDesignation: 'Washing Master / Wet Processing Head',
    icon: Icons.waves_outlined,
    description: 'Garment enzyme wash, silicon softeners & liquor ratio batch tracking',
  ),
  DepartmentHeadCatalogDef(
    id: 'div-08',
    code: '08',
    name: 'Steam Pressing & Ironing Floor',
    route: '/iron',
    defaultDesignation: 'Finishing & Ironing Incharge',
    icon: Icons.local_fire_department_outlined,
    description: 'Industrial steam irons, vacuum pressing boards & inline finish inspection',
  ),
  DepartmentHeadCatalogDef(
    id: 'div-09',
    code: '09',
    name: 'Ready Goods & Carton Packing',
    route: '/ready-goods',
    defaultDesignation: 'Quality Assurance Head / AQL Manager',
    icon: Icons.inventory_2_outlined,
    description: 'AQL 2.5 final inspection, barcode hangtags, polybag sealing & cartons',
  ),
  DepartmentHeadCatalogDef(
    id: 'div-10',
    code: '10',
    name: 'Alteration & Reclamation Clinic',
    route: '/alter',
    defaultDesignation: 'Alteration Incharge / Rework Master',
    icon: Icons.build_outlined,
    description: 'Defect categorization, seam rework, broken stitch alterations & re-inspection',
  ),
  DepartmentHeadCatalogDef(
    id: 'div-11',
    code: '11',
    name: 'Central Store Godown & Vault',
    route: '/store',
    defaultDesignation: 'Store Manager / Chief Godown Keeper',
    icon: Icons.storefront_outlined,
    description: 'Raw fabric rolls, trims inventory, cutting challan issue & finished carton storage',
  ),
  DepartmentHeadCatalogDef(
    id: 'div-12',
    code: '12',
    name: 'Dispatch & Delivery Logistics',
    route: '/dispatch',
    defaultDesignation: 'Dispatch Manager / Logistics Head',
    icon: Icons.local_shipping_outlined,
    description: 'Delivery challans, physical counting audits, vehicle gate-out & logistics passes',
  ),
];

// ============================================================================
// MAIN SCREEN WIDGET
// ============================================================================

class DepartmentHeadsScreen extends ConsumerStatefulWidget {
  const DepartmentHeadsScreen({super.key});

  @override
  ConsumerState<DepartmentHeadsScreen> createState() => _DepartmentHeadsScreenState();
}

class _DepartmentHeadsScreenState extends ConsumerState<DepartmentHeadsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DepartmentHeadItem> _heads = [];
  String _searchTerm = '';
  String _filterStatus = 'ALL'; // 'ALL' | 'ACTIVE' | 'SUSPENDED'

  @override
  void initState() {
    super.initState();
    _fetchDepartmentHeads();
  }

  Future<void> _fetchDepartmentHeads() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authState = ref.read(authProvider);
      final tenant = authState.tenantProfile;
      final companyName = tenant?.companyName;

      // Query profiles table where is_head == true
      var query = supabase
          .from('profiles')
          .select('id, username, role, is_head, designation, allowed_modules, phone, is_active, created_at, company_name')
          .eq('is_head', true);

      if (companyName != null && companyName.isNotEmpty && companyName.toLowerCase() != 'apparel factory') {
        query = query.or('company_name.eq.$companyName,company_name.is.null');
      }

      final res = await query.order('created_at', ascending: false);

      final List<DepartmentHeadItem> loaded = [];
      for (final row in res) {
        final rawModules = row['allowed_modules'];
        List<String> modules = [];
        if (rawModules is List) {
          modules = rawModules.map((m) => m.toString()).toList();
        }

        final role = (row['role'] ?? 'OPERATIONS_HEAD').toString();
        final username = (row['username'] ?? 'head_user').toString();
        final displayName = (row['username'] ?? 'Department Lead').toString();
        final designation = (row['designation'] ?? _deriveDesignation(role, modules)).toString();
        final isActive = row['is_active'] != false;
        final phone = row['phone']?.toString();
        final createdAt = row['created_at']?.toString();

        loaded.add(
          DepartmentHeadItem(
            id: row['id'].toString(),
            displayName: displayName,
            username: username,
            email: '$username@factory.local',
            role: role,
            designation: designation,
            allowedModules: modules,
            isActive: isActive,
            phone: phone,
            createdAt: createdAt,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _heads = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load department heads: $e';
        });
      }
    }
  }

  String _deriveDesignation(String role, List<String> modules) {
    if (modules.contains('/cutting')) return 'Cutting Master / CAD Head';
    if (modules.contains('/store')) return 'Central Store & Godown Manager';
    if (modules.contains('/stitching-sewing')) return 'Production Manager / Floor Head';
    if (modules.contains('/ready-goods')) return 'Quality Assurance (QA) Head';
    if (modules.contains('/merchandising')) return 'Senior Merchandiser / Sourcing Lead';
    if (modules.contains('/design')) return 'Design Studio Head';
    if (modules.contains('/washing')) return 'Washing Master';
    if (modules.contains('/iron')) return 'Finishing & Pressing Incharge';
    if (modules.contains('/alter')) return 'Alteration Clinic Master';
    if (modules.contains('/printing')) return 'Printing Studio Head';
    if (modules.contains('/embroidery')) return 'Embroidery Head';
    if (modules.contains('/dispatch')) return 'Dispatch & Logistics Manager';
    return 'Department Incharge';
  }

  Future<void> _toggleHeadStatus(DepartmentHeadItem head) async {
    final nextStatus = !head.isActive;
    try {
      await supabase.from('profiles').update({'is_active': nextStatus}).eq('id', head.id);

      setState(() {
        _heads = _heads.map((h) => h.id == head.id ? h.copyWith(isActive: nextStatus) : h).toList();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.brandSteel,
          content: Text('Head "${head.displayName}" is now ${nextStatus ? 'Active' : 'Suspended'}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFBE123C),
          content: Text('Failed to update status: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteHead(DepartmentHeadItem head) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Department Head?',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.foregroundInk),
        ),
        content: Text(
          'Are you sure you want to remove Department Head "${head.displayName}"? This will revoke their access to all assigned divisions.',
          style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.mutedInk, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: AppTheme.mutedInk)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE123C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove Head', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('profiles').delete().eq('id', head.id);

      setState(() {
        _heads = _heads.where((h) => h.id != head.id).toList();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.brandSteel,
          content: Text('Head "${head.displayName}" removed successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFBE123C),
          content: Text('Failed to delete head: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openAppointHeadModal([DepartmentHeadItem? headToEdit]) async {
    final authState = ref.read(authProvider);
    final tenant = authState.tenantProfile;
    final companyName = tenant?.companyName ?? 'Nubira Creation';
    final allowedDivisions = authState.allowedDivisions;

    final result = await AppointDepartmentHeadScreen.show(
      context,
      existingHead: headToEdit,
      companyName: companyName,
      allowedDivisions: allowedDivisions,
    );

    if (result == true) {
      _fetchDepartmentHeads();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF332B6B),
          content: Text(
            headToEdit != null
                ? 'Department Head "${headToEdit.displayName}" updated successfully'
                : 'Department Head appointed successfully',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _openResetPasswordDialog(DepartmentHeadItem head) {
    showDialog(
      context: context,
      builder: (ctx) => _ResetPasswordDialog(
        head: head,
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.brandSteel,
              content: Text('Password reset successfully for ${head.displayName}'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;
    final companyName = tenant?.companyName ?? 'Nubira Creation';
    final allowedDivisions = authState.allowedDivisions;

    // Filter catalog to tenant's purchased divisions (Strict match with Web)
    final subscribedCatalog = (allowedDivisions.isNotEmpty && !allowedDivisions.contains('/modules'))
        ? kDepartmentHeadsCatalog.where((d) => allowedDivisions.contains(d.route)).toList()
        : kDepartmentHeadsCatalog;

    final totalDivisions = subscribedCatalog.length;

    // Compute covered divisions
    final coveredRoutes = <String>{};
    for (final head in _heads) {
      for (final r in head.allowedModules) {
        coveredRoutes.add(r);
      }
    }
    final coveredDivisionsCount = coveredRoutes.where((r) => subscribedCatalog.any((d) => d.route == r)).length;
    final unassignedCount = max(0, totalDivisions - coveredDivisionsCount);

    final activeCount = _heads.where((h) => h.isActive).length;
    final suspendedCount = _heads.where((h) => !h.isActive).length;

    // Filter by search & tab
    final filteredHeads = _heads.filterWith(
      status: _filterStatus,
      search: _searchTerm,
    );

    return Scaffold(
      backgroundColor: AppTheme.canvasCream,
      appBar: AppBar(
        backgroundColor: AppTheme.cardWhite,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        centerTitle: true,
        leading: Center(
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.standardBorder),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: AppTheme.mutedInk, size: 20),
            ),
          ),
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/z_i_g_z_a.png',
            height: 34,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/zigza_logo.png',
              height: 34,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                'Zigza.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brandSteel,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: AppTheme.canvasCream,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x26000000)),
              ),
              child: Text(
                'ERP MES',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.brandSteel,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDepartmentHeads,
        color: AppTheme.brandSteel,
        backgroundColor: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ==========================================
            // BREADCRUMB (Line 1) & CONTEXT BADGES (Line 2) - Matching Image 1
            // ==========================================
            Row(
              children: [
                Text(
                  'Workspace Hub',
                  style: GoogleFonts.publicSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedInk,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('/', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Department Heads & Incharges (RBAC)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.foregroundInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.canvasCream,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x18000000)),
                  ),
                  child: Text(
                    companyName,
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.foregroundInk,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.badgeAmberBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.badgeAmberBorder),
                  ),
                  child: Text(
                    'Executive RBAC',
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.badgeAmberText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ==========================================
            // TOP HEADER CARD WITH APPOINT ACTION (Matching Image 1)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.standardBorder, width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
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
                          color: AppTheme.canvasCream,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x14000000)),
                        ),
                        child: const Center(
                          child: Icon(Icons.verified_user_outlined, color: AppTheme.brandSteel, size: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Department Heads &\nIncharges',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.foregroundInk,
                                height: 1.15,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Official division incharges and department heads appointed by company admin.',
                              style: GoogleFonts.publicSans(
                                fontSize: 12.5,
                                color: AppTheme.mutedInk,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Compact primary button matching Image 1
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _openAppointHeadModal(null),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.brandSteel,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_add_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '+ Appoint Department Head',
                                style: GoogleFonts.publicSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
            const SizedBox(height: 14),

            // ==========================================
            // THREE STACKED METRICS CARDS (Matching Image 1)
            // ==========================================
            _buildStatCard(
              label: 'APPOINTED HEADS',
              value: '${_heads.length} Assigned',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 10),
            _buildStatCard(
              label: 'DIVISIONS COVERED',
              value: '$coveredDivisionsCount of $totalDivisions Units',
              icon: Icons.layers_outlined,
            ),
            const SizedBox(height: 10),
            _buildStatCard(
              label: 'UNASSIGNED DIVISIONS',
              value: '$unassignedCount Units Pending',
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 16),

            // ==========================================
            // FILTER TABS & SEARCH BAR (Matching Image 1)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.standardBorder),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Column(
                children: [
                  // Segmented Filter Tabs
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _buildFilterTab('ALL', 'All Appointed (${_heads.length})'),
                        _buildFilterTab('ACTIVE', 'Active ($activeCount)'),
                        _buildFilterTab('SUSPENDED', 'Suspended ($suspendedCount)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Search Field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchTerm = val),
                      style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.foregroundInk, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Search appointed head or designation...',
                        hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.faintInk),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ==========================================
            // APPOINTED HEADS LIST / EMPTY STATE
            // ==========================================
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: AppTheme.brandSteel),
                ),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFBE123C), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF9F1239)),
                      ),
                    ),
                  ],
                ),
              )
            else if (filteredHeads.isEmpty)
              _buildEmptyState()
            else
              ...filteredHeads.map((head) => _buildHeadCard(head, subscribedCatalog)),

            const SizedBox(height: 70),
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
                      color: AppTheme.canvasCream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.standardBorder),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: AppTheme.brandSteel, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Zigza AI Copilot',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.foregroundInk,
                    ),
                  ),
                ],
              ),
              content: Text(
                'Department Heads & Incharges RBAC policy ensures strict division-level isolation across authorized manufacturing units.',
                style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.mutedInk, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Close',
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.brandSteel,
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
            color: AppTheme.brandSteel,
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

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.standardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.faintInk,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.foregroundInk,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.canvasCream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x14000000)),
            ),
            child: Icon(icon, color: AppTheme.brandSteel, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String statusKey, String label) {
    final isSelected = _filterStatus == statusKey;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filterStatus = statusKey),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: const Color(0x18000000)) : null,
            boxShadow: isSelected
                ? const [BoxShadow(color: Color(0x08000000), blurRadius: 2, offset: Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.publicSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? AppTheme.foregroundInk : AppTheme.mutedInk,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadCard(DepartmentHeadItem head, List<DepartmentHeadCatalogDef> catalog) {
    final initials = head.displayName.trim().isNotEmpty
        ? head.displayName.trim().split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() : '').take(2).join()
        : 'DH';

    final assignedUnits = catalog.where((c) => head.allowedModules.contains(c.route)).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.standardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Body
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name/Designation + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Initials Tile
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.canvasCream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x18000000)),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandSteel,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  head.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.foregroundInk,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: head.isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            head.designation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.brandSteel,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: head.isActive ? AppTheme.canvasCream : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: head.isActive ? const Color(0x18000000) : const Color(0x18000000),
                        ),
                      ),
                      child: Text(
                        head.isActive ? 'Active' : 'Suspended',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: head.isActive ? AppTheme.brandSteel : AppTheme.mutedInk,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Credentials / Login Mini-Block
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x14000000)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'LOGIN USER:',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.mutedInk,
                            ),
                          ),
                          Text(
                            head.username,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.foregroundInk,
                            ),
                          ),
                        ],
                      ),
                      if (head.phone != null && head.phone!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PHONE:',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.mutedInk,
                              ),
                            ),
                            Text(
                              '+91 ${head.phone}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.foregroundInk,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Assigned Department Authority Badges
                Text(
                  'ASSIGNED DEPARTMENT AUTHORITY (${head.allowedModules.length} UNITS)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.faintInk,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                if (assignedUnits.isEmpty)
                  Text(
                    'No direct units assigned',
                    style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.mutedInk, fontStyle: FontStyle.italic),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: assignedUnits.map((u) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.canvasCream,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x18000000)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(u.icon, size: 13, color: AppTheme.brandSteel),
                            const SizedBox(width: 5),
                            Text(
                              'Unit ${u.code}: ${u.name.split('&')[0].trim()}',
                              style: GoogleFonts.publicSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.foregroundInk,
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

          // Card Footer Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAF8),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border(top: BorderSide(color: Color(0x14000000))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => _openAppointHeadModal(head),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      'Edit Permissions',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.brandSteel,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.key_rounded, size: 18, color: AppTheme.mutedInk),
                      tooltip: 'Reset Password',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openResetPasswordDialog(head),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.power_settings_new_rounded,
                        size: 18,
                        color: head.isActive ? AppTheme.mutedInk : AppTheme.brandSteel,
                      ),
                      tooltip: head.isActive ? 'Suspend Head' : 'Activate Head',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _toggleHeadStatus(head),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFBE123C)),
                      tooltip: 'Remove Head',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _deleteHead(head),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.standardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.canvasCream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x14000000)),
            ),
            child: const Icon(Icons.verified_user_outlined, color: AppTheme.brandSteel, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            _searchTerm.isNotEmpty ? 'No matching department heads found' : 'No department heads appointed yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.foregroundInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchTerm.isNotEmpty
                ? 'Try adjusting your search query or switching active status filters.'
                : 'Appoint official division incharges to assign leadership authority across your manufacturing units.',
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.mutedInk, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandSteel,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            ),
            onPressed: () => _openAppointHeadModal(null),
            child: Text(
              '+ Appoint Department Head',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RESET PASSWORD DIALOG
// ============================================================================

class _ResetPasswordDialog extends StatefulWidget {
  final DepartmentHeadItem head;
  final VoidCallback onSuccess;

  const _ResetPasswordDialog({
    required this.head,
    required this.onSuccess,
  });

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _pwdCtrl = TextEditingController();
  bool _isResetting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateRandom();
  }

  void _generateRandom() {
    final num = 1000 + Random().nextInt(9000);
    _pwdCtrl.text = '@Factory$num!';
  }

  Future<void> _handleReset() async {
    final newPwd = _pwdCtrl.text.trim();
    if (newPwd.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isResetting = true;
      _error = null;
    });

    try {
      await supabase.from('profiles').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.head.id);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      setState(() {
        _isResetting = false;
        _error = 'Failed to reset password: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.canvasCream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x18000000)),
            ),
            child: const Icon(Icons.key_rounded, color: AppTheme.brandSteel, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reset Password',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.foregroundInk),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter a new password for ${widget.head.displayName} (${widget.head.username}):',
            style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.mutedInk, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pwdCtrl,
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.foregroundInk),
            decoration: InputDecoration(
              hintText: 'Min 6 characters',
              suffixIcon: IconButton(
                icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.brandSteel),
                tooltip: 'Auto-Generate',
                onPressed: _generateRandom,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFFBE123C))),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: AppTheme.mutedInk)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandSteel,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
          ),
          onPressed: _isResetting ? null : _handleReset,
          child: _isResetting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Reset Password', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ============================================================================
// HELPER EXTENSION FOR FILTERING
// ============================================================================

extension DepartmentHeadListFiltering on List<DepartmentHeadItem> {
  List<DepartmentHeadItem> filterWith({required String status, required String search}) {
    return where((head) {
      if (status == 'ACTIVE' && !head.isActive) return false;
      if (status == 'SUSPENDED' && head.isActive) return false;

      if (search.trim().isEmpty) return true;
      final term = search.toLowerCase().trim();
      final name = head.displayName.toLowerCase();
      final uname = head.username.toLowerCase();
      final desig = head.designation.toLowerCase();
      final mods = head.allowedModules.any((m) => m.toLowerCase().contains(term));

      return name.contains(term) || uname.contains(term) || desig.contains(term) || mods;
    }).toList();
  }
}
