import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';

class TechPackCatalogScreen extends ConsumerStatefulWidget {
  const TechPackCatalogScreen({super.key});

  @override
  ConsumerState<TechPackCatalogScreen> createState() => _TechPackCatalogScreenState();
}

class _TechPackCatalogScreenState extends ConsumerState<TechPackCatalogScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  String _selectedStatusTab = 'ALL';
  bool _isCompactView = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(designerProvider.notifier).fetchStudioData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(designerProvider);
    final techPacks = state.techPacks;

    final query = _searchController.text.trim().toLowerCase();

    // Filter tech-packs
    final filteredTechPacks = techPacks.where((tp) {
      if (_selectedStatusTab != 'ALL') {
        final st = tp.status.toUpperCase();
        if (_selectedStatusTab == 'APPROVED_BULK') {
          if (st != 'APPROVED_BULK' && st != 'PPS_APPROVED' && st != 'PRODUCTION_READY') return false;
        } else if (_selectedStatusTab == 'PPS_APPROVED') {
          if (st != 'PPS_APPROVED') return false;
        } else if (_selectedStatusTab == 'PPS_SUBMITTED') {
          if (st != 'PPS_SUBMITTED' && st != 'PPS_REVIEW') return false;
        } else if (_selectedStatusTab == 'SAMPLE_DEV') {
          if (st != 'SAMPLE_DEV') return false;
        } else if (_selectedStatusTab == 'REVISE_FIT') {
          if (st != 'REVISE_FIT') return false;
        } else if (_selectedStatusTab == 'DRAFT') {
          if (st != 'DRAFT') return false;
        }
      }

      if (query.isNotEmpty) {
        final matchStyleNo = tp.styleNumber.toLowerCase().contains(query);
        final matchStyleName = tp.styleName.toLowerCase().contains(query);
        final matchBrand = tp.brandName.toLowerCase().contains(query);
        final matchCat = tp.category.toLowerCase().contains(query);
        final matchFab = tp.fabricComposition.toLowerCase().contains(query);
        if (!matchStyleNo && !matchStyleName && !matchBrand && !matchCat && !matchFab) {
          return false;
        }
      }
      return true;
    }).toList();

    // Stats calculations strictly matching web metrics
    final totalSpecs = techPacks.length;
    final bulkApprovedCount = techPacks.where((p) {
      final st = p.status.toUpperCase();
      return st == 'APPROVED_BULK' || st == 'PPS_APPROVED' || st == 'PRODUCTION_READY';
    }).length;
    final samplingCount = techPacks.where((p) {
      final st = p.status.toUpperCase();
      return st == 'SAMPLE_DEV' || st == 'PPS_SUBMITTED' || st == 'PPS_REVIEW';
    }).length;
    final draftsCount = techPacks.where((p) {
      final st = p.status.toUpperCase();
      return st == 'DRAFT' || st == 'REVISE_FIT';
    }).length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: WorkspaceHubDrawer(
        activeRoute: '/design/tech-packs',
        onOpenTeam: () => Navigator.pop(context),
      ),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        color: AppTheme.brandSteel,
        onRefresh: () async {
          await ref.read(designerProvider.notifier).fetchStudioData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // 1. BREADCRUMBS
              // ==========================================
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Design Studio',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('/', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                  const SizedBox(width: 4),
                  Text(
                    'Specifications',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('/', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                  const SizedBox(width: 4),
                  Text(
                    'Tech-Pack Catalog',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ==========================================
              // 2. HERO HEADER CARD (#FAFAF8 matching Web)
              // ==========================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x04000000),
                      blurRadius: 8,
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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF332B6B), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Tech-Pack Master Catalog',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF7F0),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0x26000000)),
                                    ),
                                    child: Text(
                                      '$totalSpecs SPECS',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF332B6B),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Standardized technical packages, CAD vectors, SPI standards & bill of materials',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Action Row (Toggle + Create button)
                    Row(
                      children: [
                        // View Toggle Segment
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _isCompactView = false),
                                borderRadius: BorderRadius.circular(9),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: !_isCompactView ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                    boxShadow: !_isCompactView
                                        ? const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))]
                                        : null,
                                  ),
                                  child: Icon(
                                    Icons.view_agenda_outlined,
                                    size: 16,
                                    color: !_isCompactView ? const Color(0xFF332B6B) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setState(() => _isCompactView = true),
                                borderRadius: BorderRadius.circular(9),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _isCompactView ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                    boxShadow: _isCompactView
                                        ? const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))]
                                        : null,
                                  ),
                                  child: Icon(
                                    Icons.format_list_bulleted_rounded,
                                    size: 16,
                                    color: _isCompactView ? const Color(0xFF332B6B) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Create Tech-Pack Button
                        Expanded(
                          child: InkWell(
                            onTap: () => _openCreateTechPackModal(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF332B6B),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x2A332B6B),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Create Tech-Pack',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
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
              // 3. STATS GRID 2x2 (#FAFAF8 matching Web)
              // ==========================================
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      stage: 'CATALOG',
                      title: 'TOTAL SPECS',
                      count: totalSpecs,
                      icon: Icons.file_copy_outlined,
                      accentColor: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      stage: 'PRODUCTION',
                      title: 'READY FOR MERCH',
                      count: bulkApprovedCount,
                      icon: Icons.check_circle_outline_rounded,
                      accentColor: const Color(0xFF047857),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      stage: 'SAMPLING',
                      title: 'SAMPLE DEV / PPS',
                      count: samplingCount,
                      icon: Icons.access_time_rounded,
                      accentColor: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      stage: 'REVISIONS',
                      title: 'FIT REVISIONS',
                      count: draftsCount,
                      icon: Icons.layers_outlined,
                      accentColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ==========================================
              // 4. SEARCH INPUT
              // ==========================================
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search style or brand...',
                    hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ==========================================
              // 5. HORIZONTAL STATUS FILTER TABS
              // ==========================================
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusChip('ALL', 'All Specs ($totalSpecs)'),
                    const SizedBox(width: 6),
                    _buildStatusChip('APPROVED_BULK', 'Ready for Merchandising ($bulkApprovedCount)'),
                    const SizedBox(width: 6),
                    _buildStatusChip('SAMPLE_DEV', 'Sample Dev ($samplingCount)'),
                    const SizedBox(width: 6),
                    _buildStatusChip('DRAFT', 'Drafts ($draftsCount)'),
                    const SizedBox(width: 6),
                    _buildStatusChip('REVISE_FIT', 'Fit Revisions'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // 6. TECH-PACK SPEC CARDS LIST
              // ==========================================
              if (filteredTechPacks.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: const Icon(Icons.assignment_outlined, size: 26, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No Tech-Packs Match',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try changing your search keywords or filter status above.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredTechPacks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (ctx, idx) {
                    final pack = filteredTechPacks[idx];
                    return _isCompactView
                        ? _buildCompactSpecCard(pack)
                        : _buildDetailedSpecCard(pack);
                  },
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // METRIC CARD BUILDER
  // ==========================================
  Widget _buildMetricCard({
    required String stage,
    required String title,
    required int count,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Text(
                  stage,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF332B6B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count.toString(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STATUS CHIP BUILDER
  // ==========================================
  Widget _buildStatusChip(String value, String label) {
    final isSel = _selectedStatusTab == value;
    return InkWell(
      onTap: () => setState(() => _selectedStatusTab = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF332B6B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSel ? const Color(0xFF332B6B) : const Color(0xFFE2E8F0)),
          boxShadow: isSel
              ? const [BoxShadow(color: Color(0x1A332B6B), blurRadius: 4, offset: Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 12,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
            color: isSel ? const Color(0xFFFAF7F0) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DETAILED TECH-PACK CARD (Matching Web)
  // ==========================================
  Widget _buildDetailedSpecCard(TechPackSummaryModel pack) {
    final status = pack.status.toUpperCase();
    final isReady = status == 'APPROVED_BULK' || status == 'PPS_APPROVED' || status == 'PRODUCTION_READY';
    final isDraft = status == 'DRAFT';
    final isDev = status == 'SAMPLE_DEV' || status == 'PPS_SUBMITTED';

    final badgeBg = isReady
        ? const Color(0xFFE9F7EE)
        : (isDraft
            ? const Color(0xFFFEF3C7)
            : (isDev ? const Color(0xFFFAF7F0) : const Color(0xFFFEE2E2)));
    final badgeText = isReady
        ? const Color(0xFF1B7A43)
        : (isDraft
            ? const Color(0xFFB45309)
            : (isDev ? const Color(0xFF332B6B) : const Color(0xFF991B1B)));
    final badgeBorder = isReady
        ? const Color(0xFFA7F3D0)
        : (isDraft
            ? const Color(0xFFFDE68A)
            : (isDev ? const Color(0x26000000) : const Color(0xFFFECACA)));

    final statusLabel = isReady
        ? 'Ready for merchandising'
        : (isDraft ? 'Draft Spec' : (isDev ? 'Sampling in progress' : 'Fit Revision'));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECECE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              border: Border(bottom: BorderSide(color: Color(0x0F000000))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x26000000)),
                      ),
                      child: Text(
                        pack.styleNumber,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF332B6B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  pack.styleName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Brand: ${pack.brandName} • Category: ${pack.category}',
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Specs Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2-Column Base Size & GSM
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x12000000)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BASE SIZE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pack.baseSize,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x12000000)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TARGET WEIGHT',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pack.targetGsm} GSM',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Fabric Composition
                Text(
                  'FABRIC COMPOSITION',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pack.cleanFabricComposition.isNotEmpty ? pack.cleanFabricComposition : '100% Cotton Single Jersey',
                  style: GoogleFonts.publicSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 10),

                // Embellishment Flow
                Text(
                  'EMBELLISHMENT FLOW',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: Text(
                    pack.embellishmentSequence == 'NONE'
                        ? 'Plain Cut Assembly'
                        : pack.embellishmentSequence.replaceAll('_', ' '),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF332B6B),
                    ),
                  ),
                ),

                // BOM preview if present
                if (pack.bomItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'BILL OF MATERIALS (${pack.bomItems.length} ITEMS)',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: pack.bomItems.take(3).map((b) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0x12000000)),
                        ),
                        child: Text(
                          '${b.componentType}: ${b.itemName}',
                          style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Footer Action Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAF8),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(19)),
              border: Border(top: BorderSide(color: Color(0x0F000000))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      'Cut: ${pack.targetCutDate ?? "14 Days"}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Edit button
                    InkWell(
                      onTap: () => _openEditTechPackModal(context, pack),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF332B6B)),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Delete button (Red tinted #FBE4E4 / #C23838)
                    InkWell(
                      onTap: () => _confirmDeleteTechPack(context, pack),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBE4E4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFC23838)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Diff / Compare button
                    InkWell(
                      onTap: () => _showDiffModal(context, pack),
                      child: Row(
                        children: [
                          const Icon(Icons.compare_arrows_rounded, size: 14, color: Color(0xFF332B6B)),
                          const SizedBox(width: 2),
                          Text(
                            'Diff',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF332B6B),
                            ),
                          ),
                        ],
                      ),
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

  // ==========================================
  // COMPACT SPEC CARD BUILDER
  // ==========================================
  Widget _buildCompactSpecCard(TechPackSummaryModel pack) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECE8)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x1A000000)),
            ),
            child: Text(
              pack.styleNumber,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF332B6B),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.styleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${pack.category} • ${pack.baseSize} • ${pack.targetGsm} GSM',
                  style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF332B6B)),
            onPressed: () => _openEditTechPackModal(context, pack),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFC23838)),
            onPressed: () => _confirmDeleteTechPack(context, pack),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CREATE TECH-PACK MODAL
  // ==========================================
  void _openCreateTechPackModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _TechPackFormModal(isEditing: false),
    );
  }

  // ==========================================
  // EDIT TECH-PACK MODAL
  // ==========================================
  void _openEditTechPackModal(BuildContext context, TechPackSummaryModel pack) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TechPackFormModal(isEditing: true, initialPack: pack),
    );
  }

  // ==========================================
  // DELETE CONFIRMATION DIALOG
  // ==========================================
  void _confirmDeleteTechPack(BuildContext context, TechPackSummaryModel pack) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Tech-Pack',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${pack.styleNumber} (${pack.styleName}) from the master catalog? This action will remove its BOM ledger and CAD records.',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC23838),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              nav.pop();
              final ok = await ref.read(designerProvider.notifier).deleteTechPack(pack.id);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Tech-Pack deleted successfully.' : 'Failed to delete tech-pack.'),
                  backgroundColor: ok ? const Color(0xFF047857) : const Color(0xFFDC2626),
                ),
              );
            },
            child: Text('Delete', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIFF / VERSION INSPECTOR MODAL
  // ==========================================
  void _showDiffModal(BuildContext context, TechPackSummaryModel pack) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x1A000000))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.compare_arrows_rounded, color: Color(0xFF332B6B)),
                      const SizedBox(width: 8),
                      Text(
                        'Specification Diff: ${pack.styleNumber}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: Text(
                      'Comparing Version ${pack.version} (Active Bulk Spec) with Baseline Initial Spec',
                      style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF332B6B)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDiffRow('Base Size', 'M (Standard)', pack.baseSize, false),
                  _buildDiffRow('Fabric Composition', '100% Single Jersey', pack.cleanFabricComposition, pack.cleanFabricComposition != '100% Single Jersey'),
                  _buildDiffRow('Target GSM', '180 GSM', '${pack.targetGsm} GSM', pack.targetGsm != 180),
                  _buildDiffRow('SPI Standards', '10 SPI', '${pack.spi} SPI', pack.spi != 10),
                  _buildDiffRow('Seam Class', 'ISO Class 504', pack.seamClass, false),
                  _buildDiffRow('Embellishment', 'Plain Cut', pack.embellishmentSequence, pack.embellishmentSequence != 'NONE'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiffRow(String field, String original, String current, bool isChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isChanged ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isChanged ? const Color(0xFFA7F3D0) : const Color(0x12000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text('Baseline: $original', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8))),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Current: $current', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: isChanged ? const Color(0xFF047857) : const Color(0xFF0F172A))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TECH-PACK FORM MODAL (CREATE & EDIT)
// =============================================================================
class _TechPackFormModal extends ConsumerStatefulWidget {
  final bool isEditing;
  final TechPackSummaryModel? initialPack;

  const _TechPackFormModal({
    required this.isEditing,
    this.initialPack,
  });

  @override
  ConsumerState<_TechPackFormModal> createState() => _TechPackFormModalState();
}

class _TechPackFormModalState extends ConsumerState<_TechPackFormModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _styleNumberController;
  late TextEditingController _styleNameController;
  late TextEditingController _brandController;
  late TextEditingController _baseSizeController;
  late TextEditingController _fabricController;
  late TextEditingController _gsmController;
  late TextEditingController _spiController;
  late TextEditingController _instructionsController;

  String _selectedCategory = 'T-Shirt';
  String _selectedSizeSystem = 'ALPHA_ADULT';
  String _selectedEmbellishment = 'NONE';
  String _selectedSeamClass = 'ISO 4915 Class 401 (Chainstitch)';
  String _selectedStatus = 'DRAFT';

  List<TechPackBomItemModel> _bomItems = [];

  final List<String> _categories = [
    'T-Shirt',
    'Hoodie',
    'Polo',
    'Pant',
    'Suit',
    'Jogger',
    'Jacket',
    'Kids Romper',
    'Ethnic',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialPack;
    _styleNumberController = TextEditingController(text: p?.styleNumber ?? '');
    _styleNameController = TextEditingController(text: p?.styleName ?? '');
    _brandController = TextEditingController(text: p?.brandName ?? 'DIRECT CLIENT');
    _baseSizeController = TextEditingController(text: p?.baseSize ?? 'M');
    _fabricController = TextEditingController(text: p?.cleanFabricComposition ?? '100% Combed Cotton Single Jersey');
    _gsmController = TextEditingController(text: (p?.targetGsm ?? 180).toString());
    _spiController = TextEditingController(text: (p?.spi ?? 12).toString());
    _instructionsController = TextEditingController(text: p?.cleanInstructions ?? '');

    if (p != null) {
      _selectedCategory = p.category;
      _selectedSizeSystem = p.sizeSystem;
      _selectedEmbellishment = p.embellishmentSequence;
      _selectedSeamClass = p.seamClass;
      _selectedStatus = p.status;
      _bomItems = List.from(p.bomItems);
    }
  }

  @override
  void dispose() {
    _styleNumberController.dispose();
    _styleNameController.dispose();
    _brandController.dispose();
    _baseSizeController.dispose();
    _fabricController.dispose();
    _gsmController.dispose();
    _spiController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(String cat) {
    setState(() {
      _selectedCategory = cat;
      if (cat == 'T-Shirt') {
        _fabricController.text = '100% Combed Cotton Single Jersey';
        _gsmController.text = '180';
        _baseSizeController.text = 'M';
      } else if (cat == 'Hoodie') {
        _fabricController.text = '3-End French Terry 360 GSM Brushed Inside';
        _gsmController.text = '360';
        _baseSizeController.text = 'M';
      } else if (cat == 'Pant') {
        _fabricController.text = '98% Cotton 2% Elastane Twill';
        _gsmController.text = '280';
        _selectedSizeSystem = 'NUMERIC_WAIST';
        _baseSizeController.text = '32';
      } else if (cat == 'Polo') {
        _fabricController.text = '100% Cotton Pique Double Knit';
        _gsmController.text = '220';
        _baseSizeController.text = 'M';
      } else if (cat == 'Suit') {
        _fabricController.text = 'Super 120s Wool Worsted';
        _gsmController.text = '260';
        _baseSizeController.text = 'M';
      }
    });
  }

  void _addBomItem() {
    setState(() {
      _bomItems.add(TechPackBomItemModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        componentType: 'TRIM',
        itemName: 'Button',
        specification: 'Standard',
        consumption: '1',
        placement: 'Main',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(designerProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x1A000000))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF332B6B), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.isEditing ? 'Edit Tech-Pack' : 'Create Tech-Pack Spec',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Body Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Style Number & Brand
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField(
                          label: 'STYLE NUMBER *',
                          controller: _styleNumberController,
                          hint: 'e.g. DEMO-103',
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormField(
                          label: 'BRAND NAME',
                          controller: _brandController,
                          hint: 'DIRECT CLIENT',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Category Dropdown
                  Text(
                    'GARMENT CATEGORY *',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          if (v != null) _onCategoryChanged(v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Base Size & Target GSM
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField(
                          label: 'BASE SIZE *',
                          controller: _baseSizeController,
                          hint: 'M / 32 / 4T',
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormField(
                          label: 'TARGET GSM *',
                          controller: _gsmController,
                          hint: '240',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Fabric Composition
                  _buildFormField(
                    label: 'FABRIC COMPOSITION *',
                    controller: _fabricController,
                    hint: '100% Combed Cotton Single Jersey',
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  // SPI & Seam Class
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField(
                          label: 'SPI (STITCHES/INCH)',
                          controller: _spiController,
                          hint: '12',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SEAM CLASS',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSeamClass,
                                  isExpanded: true,
                                  items: [
                                    'ISO 4915 Class 401 (Chainstitch)',
                                    'ISO 4915 Class 504 (Overlock)',
                                    'ISO 4915 Class 607 (Flatlock)',
                                  ].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11)))).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedSeamClass = v);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Embellishment Sequence
                  Text(
                    'EMBELLISHMENT SEQUENCE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedEmbellishment,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(value: 'NONE', child: Text('No Embellishment (Plain Cut)', style: GoogleFonts.publicSans(fontSize: 12))),
                          DropdownMenuItem(value: 'PRINT_FIRST_THEN_EMBROIDERY', child: Text('Print First, Then Embroidery', style: GoogleFonts.publicSans(fontSize: 12))),
                          DropdownMenuItem(value: 'EMBROIDERY_FIRST_THEN_PRINT', child: Text('Embroidery First, Then Print', style: GoogleFonts.publicSans(fontSize: 12))),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedEmbellishment = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bill of Materials Builder
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BILL OF MATERIALS (BOM)',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                      ),
                      InkWell(
                        onTap: _addBomItem,
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF332B6B)),
                            const SizedBox(width: 4),
                            Text('Add Item', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_bomItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x12000000)),
                      ),
                      child: Text('No BOM components added. Tap "+ Add Item" above.', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8))),
                    )
                  else
                    ..._bomItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(item.componentType, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B))),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(item.itemName, style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFC23838)),
                              onPressed: () {
                                setState(() {
                                  _bomItems.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Footer Submit
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x1A000000))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF332B6B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: state.isSubmitting
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        final stNo = _styleNumberController.text.trim();
                        final gsm = int.tryParse(_gsmController.text.trim()) ?? 240;
                        final spi = int.tryParse(_spiController.text.trim()) ?? 12;

                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);

                        bool ok;
                        if (widget.isEditing && widget.initialPack != null) {
                          ok = await ref.read(designerProvider.notifier).updateTechPack(
                            id: widget.initialPack!.id,
                            styleNumber: stNo,
                            category: _selectedCategory,
                            baseSize: _baseSizeController.text.trim(),
                            fabricComposition: _fabricController.text.trim(),
                            targetGsm: gsm,
                            sizeSystem: _selectedSizeSystem,
                            embellishmentSequence: _selectedEmbellishment,
                            spi: spi,
                            seamClass: _selectedSeamClass,
                            status: _selectedStatus,
                            instructions: _instructionsController.text.trim(),
                            bomItems: _bomItems,
                          );
                        } else {
                          ok = await ref.read(designerProvider.notifier).createTechPack(
                            styleNumber: stNo,
                            brandName: _brandController.text.trim(),
                            category: _selectedCategory,
                            baseSize: _baseSizeController.text.trim(),
                            fabricComposition: _fabricController.text.trim(),
                            targetGsm: gsm,
                            sizeSystem: _selectedSizeSystem,
                            embellishmentSequence: _selectedEmbellishment,
                            spi: spi,
                            seamClass: _selectedSeamClass,
                            instructions: _instructionsController.text.trim(),
                            bomItems: _bomItems,
                            status: _selectedStatus,
                          );
                        }

                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Tech-Pack saved successfully!' : 'Failed to save tech-pack.'),
                            backgroundColor: ok ? const Color(0xFF047857) : const Color(0xFFDC2626),
                          ),
                        );
                      },
                child: state.isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.isEditing ? 'Update Specification' : 'Save & Publish Tech-Pack', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
      ],
    );
  }
}
