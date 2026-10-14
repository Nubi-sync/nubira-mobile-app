import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_drawer.dart';
import '../screens/admin_shell.dart';
import 'challan_models.dart';
import 'challan_detail_screen.dart';
import 'widgets/create_job_work_challan_sheet.dart';
import '../../../core/theme/app_theme.dart';

class ChallansDashboardScreen extends ConsumerStatefulWidget {
  const ChallansDashboardScreen({super.key});

  @override
  ConsumerState<ChallansDashboardScreen> createState() => _ChallansDashboardScreenState();
}

class _ChallansDashboardScreenState extends ConsumerState<ChallansDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  String _selectedStatus = 'PENDING'; // 'PENDING' | 'IN_PROGRESS' | 'ALL'
  String _selectedBrand = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(challanGroupedOrdersProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateChallanModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreateJobWorkChallanSheet(),
    );
  }

  void _showTvViewModal(List<ChallanGroupedOrder> challans) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChallansTvViewSheet(challans: challans),
    );
  }

  void _showArticleExplorerSheet(List<ChallanGroupedOrder> challans) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ArticleStylesExplorerSheet(challans: challans),
    );
  }

  Future<void> _handleRecallChallan(ChallanGroupedOrder challan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF0DD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.rotate_left_rounded, color: Color(0xFFA56A17), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Recall Challan?',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'This will recall Challan #${challan.challanNo} back to "Pending Allotment" and reset floor assignments.',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.publicSans(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA56A17),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Recall to Pending', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await unallotChallanDirectlyInSupabase(challan.id);
      if (mounted) {
        if (success) {
          ref.invalidate(challanGroupedOrdersProvider);
          ref.invalidate(adminDashboardProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Challan #${challan.challanNo} recalled to Pending Allotment.'),
              backgroundColor: const Color(0xFF1F8A5A),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to recall challan.')),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteChallan(ChallanGroupedOrder challan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4E6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Challan?',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete Challan #${challan.challanNo}? This will also delete related floor allotments.',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.publicSans(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete Permanently', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await deleteChallanInSupabase(challan.id);
      if (mounted) {
        if (success) {
          ref.invalidate(challanGroupedOrdersProvider);
          ref.invalidate(adminDashboardProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Challan #${challan.challanNo} deleted.'),
              backgroundColor: const Color(0xFFE11D48),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete challan.')),
          );
        }
      }
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw.trim());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd MMM, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUser = supabase.auth.currentUser;
    final companyName = (tenant?.companyName != null && tenant!.companyName.trim().isNotEmpty)
        ? tenant!.companyName.trim()
        : (currentUser?.userMetadata?['company_name'] ??
           currentUser?.userMetadata?['company'] ??
           '').toString().trim();
    final userName = (authState.cachedUsername != null && authState.cachedUsername!.trim().isNotEmpty && !authState.cachedUsername!.contains('@'))
        ? authState.cachedUsername!.trim()
        : (tenant?.adminDisplayName != null && tenant!.adminDisplayName.trim().isNotEmpty && !tenant.adminDisplayName.contains('@')
            ? tenant.adminDisplayName.trim()
            : (currentUser?.userMetadata?['full_name'] ??
               currentUser?.email?.split('@').first ??
               ''));

    final challansAsync = ref.watch(challanGroupedOrdersProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bgCanvas,
      drawer: const AdminDrawer(activeRoute: '/stitching-sewing/production-orders'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(color: AppTheme.borderLight, width: 1),
        ),
        leadingWidth: 56,
        leading: Center(
          child: InkWell(
            onTap: () {
              if (adminScaffoldKey.currentState != null) {
                adminScaffoldKey.currentState!.openDrawer();
              } else if (_scaffoldKey.currentState != null) {
                _scaffoldKey.currentState!.openDrawer();
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: const Icon(Icons.menu_rounded, color: AppTheme.headingObsidian, size: 20),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/zigza_web_logo.png',
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/zigza_new_logo.png',
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
            decoration: BoxDecoration(
              color: AppTheme.mintSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.badgeMintBorder),
            ),
            child: Text(
              (authState.userRole?.toUpperCase() == 'PRODUCTION_MANAGER') ? 'PROD MES' : 'ERP MES',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.headingObsidian,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.bodyInk, size: 20),
            onPressed: () {
              ref.invalidate(challanGroupedOrdersProvider);
              ref.invalidate(adminDashboardProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.brandRoyalBlue,
        backgroundColor: Colors.white,
        onRefresh: () async {
          ref.invalidate(challanGroupedOrdersProvider);
          ref.invalidate(adminDashboardProvider);
        },
        child: challansAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.brandRoyalBlue),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 44, color: Color(0xFFE11D48)),
                  const SizedBox(height: 12),
                  Text(
                    'Error Loading Challans',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.headingObsidian),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$err',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.bodyInk),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(challanGroupedOrdersProvider),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandRoyalBlue, foregroundColor: Colors.white),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (rawList) {
            // 1. Calculate Metrics
            final totalChallans = rawList.length;
            final Set<String> uniqueMasterArticles = {};
            int totalVariantsCount = 0;
            int totalSets = 0;
            int totalPcs = 0;
            int inProductionPcs = 0;
            int readyOutPcs = 0;
            int dispatchedPcs = 0;

            int pendingCount = 0;
            int inProgressCount = 0;

            final Set<String> brandSet = {'ALL'};

            for (var ch in rawList) {
              totalSets += ch.totalSets;
              totalPcs += ch.totalPcs;
              totalVariantsCount += ch.articles.length;

              if (ch.brand.trim().isNotEmpty) brandSet.add(ch.brand.trim().toUpperCase());

              // Status tab counts matching Web ProductionOrdersClient.tsx:
              // PARTIALLY_ALLOTTED stays in pendingCount because it still has unallotted lines to allot
              if (ch.status == 'IN_PROGRESS') {
                inProgressCount++;
              } else {
                pendingCount++;
              }

              for (var art in ch.articles) {
                // Base master article style extraction matching Web:
                // rawArt.replace(/[^0-9].*$/, '').trim() || rawArt
                final rawArt = art.artNo.trim().toUpperCase();
                final base = rawArt.replaceAll(RegExp(r'[^0-9].*$'), '').trim();
                final masterArt = base.isNotEmpty ? base : rawArt;
                if (masterArt.isNotEmpty) uniqueMasterArticles.add(masterArt);

                final isAllotted = art.assignedLinemanId != null &&
                    art.assignedLinemanId!.isNotEmpty &&
                    art.status == 'IN_PROGRESS';
                final lineTotalPcs = art.totalPcs;
                final lineCompletedQty = art.completedQty;

                if (art.status == 'QC_PASSED' || art.status == 'COMPLETED') {
                  readyOutPcs += lineCompletedQty > 0 ? lineCompletedQty : lineTotalPcs;
                } else if (art.status == 'DISPATCHED') {
                  dispatchedPcs += lineTotalPcs;
                } else if (isAllotted) {
                  final remaining = lineTotalPcs - lineCompletedQty;
                  inProductionPcs += remaining > 0 ? remaining : 0;
                }
              }
            }

            final totalReadyAndOut = readyOutPcs + dispatchedPcs;

            // 2. Filter Display List
            final query = _searchController.text.trim().toLowerCase();
            final isSearching = query.isNotEmpty;

            final filtered = rawList.where((ch) {
              // Search filter
              if (isSearching) {
                final matchChNo = ch.challanNo.toLowerCase().contains(query);
                final matchBrand = ch.brand.toLowerCase().contains(query);
                final matchFabric = ch.fabricType?.toLowerCase().contains(query) ?? false;
                final matchArt = ch.articles.any((a) =>
                    a.artNo.toLowerCase().contains(query) ||
                    (a.subArtNo?.toLowerCase().contains(query) ?? false) ||
                    a.colorPattern.toLowerCase().contains(query) ||
                    (a.description?.toLowerCase().contains(query) ?? false));

                if (!matchChNo && !matchBrand && !matchFabric && !matchArt) {
                  return false;
                }
              }

              // Brand filter
              if (_selectedBrand != 'ALL' && ch.brand.toUpperCase() != _selectedBrand.toUpperCase()) {
                return false;
              }

              // Status tab/filter
              if (!isSearching) {
                if (_selectedStatus == 'PENDING') {
                  if (ch.status != 'PENDING' && ch.status != 'PARTIALLY_ALLOTTED') return false;
                } else if (_selectedStatus == 'IN_PROGRESS') {
                  if (ch.status != 'IN_PROGRESS') return false;
                }
              }

              return true;
            }).toList();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Breadcrumbs Row
                        _buildBreadcrumbs(companyName),
                        const SizedBox(height: 10),

                        // 2. Welcome Card
                        _buildWelcomeCard(
                          companyName: companyName,
                          userName: userName,
                          allOrders: rawList,
                        ),
                        const SizedBox(height: 14),

                        // 3. 2x3 KPI Grid
                        _buildKpiGrid(
                          totalChallans: totalChallans,
                          articleStylesCount: uniqueMasterArticles.length,
                          totalVariantsCount: totalVariantsCount,
                          totalSets: totalSets,
                          totalPcs: totalPcs,
                          inProductionPcs: inProductionPcs,
                          readyOutPcs: totalReadyAndOut,
                          onOpenArticleExplorer: () => _showArticleExplorerSheet(rawList),
                        ),
                        const SizedBox(height: 14),

                        // 4. Status Tabs
                        _buildStatusTabs(
                          pendingCount: pendingCount,
                          inProgressCount: inProgressCount,
                        ),
                        const SizedBox(height: 12),

                        // 5. Search Bar & Dropdown Filters
                        _buildSearchAndFilters(
                          brands: brandSet.toList(),
                          pendingCount: pendingCount,
                          inProgressCount: inProgressCount,
                          totalCount: totalChallans,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // 6. Challan Cards or Empty State
                if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.bgCanvas,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, color: AppTheme.faintInk, size: 24),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isSearching
                                ? 'No Challans Matching "$query"'
                                : _selectedStatus == 'PENDING'
                                    ? 'No Pending Allotments'
                                    : 'No Allotted Challans in Production',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.headingObsidian,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSearching
                                ? 'Try searching with another article number or challan ID.'
                                : 'Tap "+ New Delivery Challan" to create or import cutting job sheets.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.bodyInk),
                          ),
                          const SizedBox(height: 14),
                          if (isSearching)
                            OutlinedButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.borderLight),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.bodyInk),
                              label: Text('Clear Search Filter', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.bodyInk)),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _showCreateChallanModal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.brandRoyalBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text('Create Delivery Challan', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final challan = filtered[index];
                          return _buildChallanCard(challan);
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 40),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // 1. BREADCRUMBS ROW
  // ==========================================
  Widget _buildBreadcrumbs(String companyName) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Workspace Hub / Production / Production & Job Work Challans',
            style: GoogleFonts.publicSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.faintInk,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: AppTheme.mintSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.badgeMintBorder),
          ),
          child: Text(
            companyName,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.headingObsidian,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. WELCOME HERO CARD
  // ==========================================
  Widget _buildWelcomeCard({
    required String companyName,
    required String userName,
    required List<ChallanGroupedOrder> allOrders,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.badgeMintBorder),
                ),
                child: const Icon(Icons.layers_rounded, color: Color(0xFF0F766E), size: 22),
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
                            'Production & Job Work Challans',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.headingObsidian,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.mintSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.badgeMintBorder),
                          ),
                          child: Text(
                            'MES Multi-Article',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.headingObsidian,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Real-world job work challans with multi-article size grids, BOM fabrics & lineman allotments.',
                      style: GoogleFonts.publicSans(
                        fontSize: 11.5,
                        color: AppTheme.bodyInk,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCreateChallanModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandRoyalBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    '+ New Delivery Challan',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _showTvViewModal(allOrders),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.borderLight),
                  foregroundColor: AppTheme.headingObsidian,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.tv_rounded, size: 16, color: AppTheme.bodyInk),
                label: Text(
                  'TV View',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. STATS KPI GRID (2 Columns x 3 Rows)
  // ==========================================
  Widget _buildKpiGrid({
    required int totalChallans,
    required int articleStylesCount,
    required int totalVariantsCount,
    required int totalSets,
    required int totalPcs,
    required int inProductionPcs,
    required int readyOutPcs,
    required VoidCallback onOpenArticleExplorer,
  }) {
    return Column(
      children: [
        // Row 1: Challans & Article Styles (Explorer)
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'CHALLANS',
                value: '$totalChallans',
                caption: 'Buyer Job Sheets',
                icon: Icons.description_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildArticleStylesExplorerCard(
                count: articleStylesCount,
                variantsCount: totalVariantsCount,
                onTap: onOpenArticleExplorer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 2: Total Sets & Total Pieces
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'TOTAL SETS',
                value: NumberFormat('#,###').format(totalSets),
                caption: 'Bundle Units',
                icon: Icons.layers_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'TOTAL PIECES',
                value: NumberFormat('#,###').format(totalPcs),
                caption: 'Garment Pieces',
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 3: In Production & Ready / Out
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'IN PRODUCTION',
                value: NumberFormat('#,###').format(inProductionPcs),
                caption: 'Active Sewing (pcs)',
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'READY / OUT',
                value: NumberFormat('#,###').format(readyOutPcs),
                caption: 'QC Passed / Gate Out',
                icon: Icons.local_shipping_outlined,
                iconColor: const Color(0xFF059669),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String caption,
    required IconData icon,
    Color bgColor = AppTheme.cardSurface,
    Color borderColor = AppTheme.borderLight,
    Color textColor = AppTheme.headingObsidian,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.faintInk,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: iconColor ?? AppTheme.faintInk),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.publicSans(
              fontSize: 10.5,
              color: AppTheme.bodyInk,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleStylesExplorerCard({
    required int count,
    required int variantsCount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ARTICLE STYLES',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.faintInk,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.badgeBlueBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.badgeBlueBorder),
                  ),
                  child: Text(
                    'Explorer ↗',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.brandRoyalBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.headingObsidian,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '($variantsCount Variants)',
                    style: GoogleFonts.publicSans(fontSize: 10, color: AppTheme.bodyInk),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  'Ledger →',
                  style: GoogleFonts.publicSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.brandRoyalBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. STATUS TABS (Pending vs Allotted)
  // ==========================================
  Widget _buildStatusTabs({
    required int pendingCount,
    required int inProgressCount,
  }) {
    final isPending = _selectedStatus == 'PENDING';
    final isInProgress = _selectedStatus == 'IN_PROGRESS';

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _selectedStatus = 'PENDING'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
              decoration: BoxDecoration(
                color: isPending ? AppTheme.headingObsidian : AppTheme.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isPending ? AppTheme.headingObsidian : AppTheme.borderLight),
                boxShadow: [
                  if (isPending)
                    BoxShadow(
                      color: AppTheme.headingObsidian.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: isPending ? const Color(0xFFFBBF24) : AppTheme.faintInk,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Pending Allotment',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isPending ? Colors.white : AppTheme.bodyInk,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isPending ? Colors.white.withValues(alpha: 0.18) : AppTheme.bgCanvas,
                      borderRadius: BorderRadius.circular(10),
                      border: isPending ? null : Border.all(color: AppTheme.borderLight),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isPending ? Colors.white : AppTheme.faintInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _selectedStatus = 'IN_PROGRESS'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
              decoration: BoxDecoration(
                color: isInProgress ? AppTheme.headingObsidian : AppTheme.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isInProgress ? AppTheme.headingObsidian : AppTheme.borderLight),
                boxShadow: [
                  if (isInProgress)
                    BoxShadow(
                      color: AppTheme.headingObsidian.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 15,
                    color: isInProgress ? const Color(0xFF38BDF8) : AppTheme.faintInk,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Allotted, In Prod',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isInProgress ? Colors.white : AppTheme.bodyInk,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isInProgress ? Colors.white.withValues(alpha: 0.18) : AppTheme.bgCanvas,
                      borderRadius: BorderRadius.circular(10),
                      border: isInProgress ? null : Border.all(color: AppTheme.borderLight),
                    ),
                    child: Text(
                      '$inProgressCount',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isInProgress ? Colors.white : AppTheme.faintInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 5. SEARCH BAR & 3 STACKED DROPDOWNS
  // ==========================================
  Widget _buildSearchAndFilters({
    required List<String> brands,
    required int pendingCount,
    required int inProgressCount,
    required int totalCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by Article No, Challan #…',
              hintStyle: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.faintInk),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.faintInk),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.faintInk),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.bgCanvas,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.brandRoyalBlue, width: 1.2)),
              isDense: true,
            ),
            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.headingObsidian),
          ),
          const SizedBox(height: 8),

          // Stacked Dropdowns (Brand, Status)
          Row(
            children: [
              // Brand Dropdown
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCanvas,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: brands.contains(_selectedBrand) ? _selectedBrand : 'ALL',
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.faintInk),
                      style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.headingObsidian),
                      items: brands.map((b) {
                        return DropdownMenuItem<String>(
                          value: b,
                          child: Text(
                            b == 'ALL' ? 'Brand: All' : b,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedBrand = val ?? 'ALL'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Status Dropdown
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCanvas,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.faintInk),
                      style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.headingObsidian),
                      items: [
                        DropdownMenuItem(value: 'PENDING', child: Text('Pending ($pendingCount)')),
                        DropdownMenuItem(value: 'IN_PROGRESS', child: Text('Allotted ($inProgressCount)')),
                        DropdownMenuItem(value: 'ALL', child: Text('All ($totalCount)')),
                      ],
                      onChanged: (val) => setState(() => _selectedStatus = val ?? 'PENDING'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. INDIVIDUAL CHALLAN CARD
  // ==========================================
  Widget _buildChallanCard(ChallanGroupedOrder challan) {
    final artNos = Array.fromSet(challan.articles.map((a) => a.artNo.trim()).where((s) => s.isNotEmpty).toSet());
    final isPartiallyAllotted = challan.status == 'PARTIALLY_ALLOTTED';
    final isPending = challan.status == 'PENDING';
    final isInProgress = challan.status == 'IN_PROGRESS';
    final isQcPassed = challan.status == 'QC_PASSED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges Wrap
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.mintSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.badgeMintBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_outlined, size: 12, color: Color(0xFF0F766E)),
                          const SizedBox(width: 4),
                          Text(
                            'Challan ${challan.challanNo}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (artNos.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCanvas,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Text(
                          'Art: ${artNos.join(', ')}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.bodyInk,
                          ),
                        ),
                      ),
                    if (challan.brand.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCanvas,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Text(
                          challan.brand,
                          style: GoogleFonts.publicSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.headingObsidian,
                          ),
                        ),
                      ),
                    if (challan.fabricType != null && challan.fabricType!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCanvas,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Text(
                          challan.fabricType!,
                          style: GoogleFonts.publicSans(
                            fontSize: 9.5,
                            color: AppTheme.faintInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (challan.sampleGiven)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.mintSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.badgeMintBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, size: 10, color: Color(0xFF0F766E)),
                            const SizedBox(width: 3),
                            Text(
                              'Sample Attached',
                              style: GoogleFonts.publicSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Date & Time Line
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Challan Date: ${_formatDate(challan.challanDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.publicSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.bodyInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Created: ${_formatDateTime(challan.createdAt)}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8.5,
                        color: AppTheme.faintInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Summary Line
                Text(
                  '• Art: ${artNos.join(', ')} • ${artNos.length} Master Style${artNos.length > 1 ? 's' : ''} (${challan.articles.length} Variants)',
                  style: GoogleFonts.publicSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.bodyInk,
                  ),
                ),
              ],
            ),
          ),

          // Middle: Batch Total Pill & Status Badge
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.bgCanvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${NumberFormat('#,###').format(challan.totalSets)} Sets | ${NumberFormat('#,###').format(challan.totalPcs)} Pcs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.headingObsidian,
                        ),
                      ),
                      Text(
                        'GRAND BATCH TOTAL',
                        style: GoogleFonts.publicSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.faintInk,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: (isPartiallyAllotted || isPending)
                        ? AppTheme.badgeAmberBg
                        : isInProgress
                            ? AppTheme.badgeBlueBg
                            : isQcPassed
                                ? AppTheme.mintSurface
                                : AppTheme.bgCanvas,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isPartiallyAllotted || isPending)
                          ? AppTheme.badgeAmberBorder
                          : isInProgress
                              ? AppTheme.badgeBlueBorder
                              : isQcPassed
                                  ? AppTheme.badgeMintBorder
                                  : AppTheme.borderLight,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (isPartiallyAllotted || isPending)
                            ? Icons.schedule_rounded
                            : isInProgress
                                ? Icons.bolt_rounded
                                : isQcPassed
                                    ? Icons.check_circle_rounded
                                    : Icons.local_shipping_rounded,
                        size: 11,
                        color: (isPartiallyAllotted || isPending)
                            ? AppTheme.badgeAmberText
                            : isInProgress
                                ? AppTheme.brandRoyalBlue
                                : isQcPassed
                                    ? const Color(0xFF0F766E)
                                    : AppTheme.bodyInk,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPartiallyAllotted
                            ? 'Partially Allotted'
                            : isPending
                                ? 'Pending Allotment'
                                : isInProgress
                                    ? 'In Production'
                                    : isQcPassed
                                        ? 'Ready (QC Passed)'
                                        : 'Dispatched',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: (isPartiallyAllotted || isPending)
                              ? AppTheme.badgeAmberText
                              : isInProgress
                                  ? AppTheme.brandRoyalBlue
                                  : isQcPassed
                                      ? const Color(0xFF0F766E)
                                      : AppTheme.bodyInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action & Drill-down Row
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isInProgress || isPartiallyAllotted)
                      OutlinedButton.icon(
                        onPressed: () => _handleRecallChallan(challan),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.badgeAmberBorder),
                          backgroundColor: AppTheme.badgeAmberBg,
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.rotate_left_rounded, size: 12, color: AppTheme.badgeAmberText),
                        label: Text('Recall', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.badgeAmberText)),
                      ),
                    if (isInProgress || isPartiallyAllotted) const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.faintInk),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 16,
                      onPressed: () => _handleDeleteChallan(challan),
                    ),
                  ],
                ),

                // Trailing Drill-Down Action
                Flexible(
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChallanDetailScreen(challan: challan),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'View Allotment & Color Matrix',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.brandRoyalBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.chevron_right_rounded, size: 15, color: AppTheme.brandRoyalBlue),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper for Array from set
class Array {
  static List<T> fromSet<T>(Set<T> set) => set.toList();
}

// ==========================================
// 7. ARTICLE STYLES EXPLORER MODAL SHEET
// ==========================================
class _ArticleStylesExplorerSheet extends StatefulWidget {
  final List<ChallanGroupedOrder> challans;

  const _ArticleStylesExplorerSheet({required this.challans});

  @override
  State<_ArticleStylesExplorerSheet> createState() => _ArticleStylesExplorerSheetState();
}

class _ArticleStylesExplorerSheetState extends State<_ArticleStylesExplorerSheet> {
  final TextEditingController _artSearchController = TextEditingController();

  @override
  void dispose() {
    _artSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Group all challans by Master Article
    final Map<String, _MasterArticleStat> map = {};

    for (var ch in widget.challans) {
      for (var art in ch.articles) {
        final clean = art.artNo.trim().toUpperCase();
        if (clean.isEmpty) continue;

        if (!map.containsKey(clean)) {
          map[clean] = _MasterArticleStat(
            artNo: clean,
            description: art.description ?? '',
            stitchingRate: art.stitchingRate,
          );
        }

        final stat = map[clean]!;
        stat.totalPcs += art.totalPcs;
        stat.totalSets += art.sets;
        stat.challanNos.add(ch.challanNo);
        stat.colors.add(art.colorPattern);
        stat.sizes.add(art.sizeRange);
      }
    }

    final query = _artSearchController.text.trim().toLowerCase();
    final articlesList = map.values.where((a) {
      if (query.isEmpty) return true;
      return a.artNo.toLowerCase().contains(query) || a.description.toLowerCase().contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.badgeBlueBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.sell_outlined, color: AppTheme.brandRoyalBlue, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Master Article Styles Explorer',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.headingObsidian,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.faintInk),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _artSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search style / article number…',
                hintStyle: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.faintInk),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.faintInk),
                filled: true,
                fillColor: AppTheme.cardSurface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.brandRoyalBlue, width: 1.2)),
                isDense: true,
              ),
              style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.headingObsidian),
            ),
          ),

          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: articlesList.length,
              itemBuilder: (ctx, i) {
                final art = articlesList[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.headingObsidian,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          art.artNo.isNotEmpty ? art.artNo.substring(0, art.artNo.length >= 2 ? 2 : 1) : 'A',
                          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Article ${art.artNo}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.headingObsidian,
                              ),
                            ),
                            if (art.description.isNotEmpty)
                              Text(
                                art.description,
                                style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.bodyInk),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              'In Challans: ${art.challanNos.join(', ')}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: AppTheme.faintInk),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${NumberFormat('#,###').format(art.totalPcs)} pcs',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.brandRoyalBlue,
                            ),
                          ),
                          Text(
                            '${art.totalSets} sets',
                            style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.faintInk),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MasterArticleStat {
  final String artNo;
  final String description;
  final double stitchingRate;
  int totalPcs = 0;
  int totalSets = 0;
  final Set<String> challanNos = {};
  final Set<String> colors = {};
  final Set<String> sizes = {};

  _MasterArticleStat({
    required this.artNo,
    required this.description,
    required this.stitchingRate,
  });
}

// ==========================================
// 8. TV VIEW MODAL SHEET
// ==========================================
class _ChallansTvViewSheet extends StatelessWidget {
  final List<ChallanGroupedOrder> challans;

  const _ChallansTvViewSheet({required this.challans});

  @override
  Widget build(BuildContext context) {
    final totalPcs = challans.fold<int>(0, (sum, c) => sum + c.totalPcs);
    final inProdPcs = challans
        .where((c) => c.status == 'IN_PROGRESS' || c.status == 'PARTIALLY_ALLOTTED')
        .fold<int>(0, (sum, c) => sum + c.totalPcs);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tv_rounded, color: Color(0xFF14C8B4), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Live Factory Floor TV View',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL ORDERED', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white54)),
                        Text('${NumberFormat('#,###').format(totalPcs)} pcs', style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IN PRODUCTION', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white54)),
                        Text('${NumberFormat('#,###').format(inProdPcs)} pcs', style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF14C8B4))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: challans.length,
              itemBuilder: (ctx, i) {
                final ch = challans[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Challan #${ch.challanNo}', style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(ch.brand, style: GoogleFonts.publicSans(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${NumberFormat('#,###').format(ch.totalPcs)} pcs', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF14C8B4), fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(ch.status, style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 9.5)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
