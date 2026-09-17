import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';
import 'create_production_tech_pack_wizard.dart';

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
      final st = tp.status.toUpperCase();
      final isFitRevision = st == 'REVISE_FIT' || st == 'REVISE';
      final isSampleDev = st == 'SAMPLE_DEV' || st == 'PPS_SUBMITTED' || st == 'PPS_REVIEW';
      final isReady = !isFitRevision && !isSampleDev;

      if (_selectedStatusTab != 'ALL') {
        if (_selectedStatusTab == 'APPROVED_BULK') {
          if (!isReady) return false;
        } else if (_selectedStatusTab == 'PPS_APPROVED') {
          if (st != 'PPS_APPROVED' && st != 'APPROVED_BULK') return false;
        } else if (_selectedStatusTab == 'PPS_SUBMITTED') {
          if (st != 'PPS_SUBMITTED') return false;
        } else if (_selectedStatusTab == 'SAMPLE_DEV') {
          if (!isSampleDev && st != 'SAMPLE_DEV') return false;
        } else if (_selectedStatusTab == 'REVISE_FIT') {
          if (!isFitRevision) return false;
        } else if (_selectedStatusTab == 'DRAFT') {
          if (st != 'DRAFT') return false;
        }
      }

      if (query.isNotEmpty) {
        final matchStyleNo = tp.styleNumber.toLowerCase().contains(query);
        final matchStyleName = tp.styleName.toLowerCase().contains(query);
        final matchBrand = tp.brandName.toLowerCase().contains(query);
        final matchCat = tp.category.toLowerCase().contains(query);
        final matchFab = tp.cleanFabricComposition.toLowerCase().contains(query);
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
      return st != 'REVISE_FIT' && st != 'SAMPLE_DEV' && st != 'PPS_SUBMITTED' && st != 'PPS_REVIEW';
    }).length;
    final samplingCount = techPacks.where((p) {
      final st = p.status.toUpperCase();
      return st == 'SAMPLE_DEV' || st == 'PPS_SUBMITTED' || st == 'PPS_REVIEW';
    }).length;
    final draftsCount = techPacks.where((p) {
      final st = p.status.toUpperCase();
      return st == 'REVISE_FIT' || st == 'REVISE';
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
                    hintText: 'Search style or article #...',
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
                    _buildStatusChip('ALL', 'All Specs'),
                    const SizedBox(width: 6),
                    _buildStatusChip('APPROVED_BULK', 'Ready for Merchandising'),
                    const SizedBox(width: 6),
                    _buildStatusChip('PPS_APPROVED', 'PPS Approved'),
                    const SizedBox(width: 6),
                    _buildStatusChip('PPS_SUBMITTED', 'PPS Submitted'),
                    const SizedBox(width: 6),
                    _buildStatusChip('SAMPLE_DEV', 'Sample Dev'),
                    const SizedBox(width: 6),
                    _buildStatusChip('REVISE_FIT', 'Fit Revisions'),
                    const SizedBox(width: 6),
                    _buildStatusChip('DRAFT', 'Draft Spec'),
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
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 1),
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Text(
                  stage,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF332B6B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Icon(icon, size: 14, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STATUS FILTER CHIP
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
  // EMBELLISHMENT FLOW HELPER
  // ==========================================
  String _formatEmbellishmentFlow(String seq) {
    final s = seq.trim().toUpperCase();
    if (s == 'NONE' || s.isEmpty || s == 'NO_EMBELLISHMENT') {
      return 'No Embroidery, No Printing';
    }
    if (s == 'ONLY_PRINTING' || s == 'PRINT_ONLY' || s == 'PRINTING_ONLY') {
      return 'Only Printing';
    }
    if (s == 'ONLY_EMBROIDERY' || s == 'EMB_ONLY' || s == 'EMBROIDERY_ONLY') {
      return 'Only Embroidery';
    }
    if (s == 'EMBROIDERY_FIRST_THEN_PRINT' || s == 'EMB_FIRST_THEN_PRINT' || s == 'EMB_THEN_PRINT') {
      return 'Embroidery First, Then Printing';
    }
    if (s == 'PRINT_FIRST_THEN_EMBROIDERY' || s == 'PRINTING_FIRST' || s == 'PRINT_THEN_EMB') {
      return 'Printing First, Then Embroidery';
    }
    if (s.contains('PRINT') && s.contains('EMB')) {
      if (s.indexOf('PRINT') < s.indexOf('EMB')) {
        return 'Printing First, Then Embroidery';
      } else {
        return 'Embroidery First, Then Printing';
      }
    }
    return seq.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // ==========================================
  // DETAILED TECH-PACK CARD (Pixel-Perfect to Web)
  // ==========================================
  Widget _buildDetailedSpecCard(TechPackSummaryModel pack) {
    final status = pack.status.toUpperCase();
    final bool isFitRevision = status == 'REVISE_FIT' || status == 'REVISE';
    final bool isSampleDev = status == 'SAMPLE_DEV' || status == 'PPS_SUBMITTED' || status == 'PPS_REVIEW';
    final bool isReady = !isFitRevision && !isSampleDev;

    final Color badgeBg = isReady
        ? const Color(0xFFE9F7EE)
        : (isSampleDev ? const Color(0xFFFAF7F0) : const Color(0xFFFEE2E2));
    final Color badgeText = isReady
        ? const Color(0xFF16A34A)
        : (isSampleDev ? const Color(0xFF332B6B) : const Color(0xFF991B1B));
    final Color badgeBorder = isReady
        ? const Color(0xFFA7F3D0)
        : (isSampleDev ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA));

    final String statusLabel = isReady
        ? 'Ready for Merchandising'
        : (isSampleDev ? 'Sample Dev' : 'Fit Revision');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        pack.styleNumber,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: badgeText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  pack.styleName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Category: ${pack.category}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Specs Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2-Column Base Size & GSM
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Base Size',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pack.baseSize,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target Weight',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${pack.targetGsm} GSM',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
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
                const SizedBox(height: 14),

                // Fabric Composition
                Text(
                  'Fabric Composition',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pack.cleanFabricComposition.isNotEmpty ? pack.cleanFabricComposition : '98% Cotton 2% Elastane Twill',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 14),

                // Embellishment Flow
                Text(
                  'Embellishment Flow',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9EE),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    _formatEmbellishmentFlow(pack.embellishmentSequence),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer Action Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Cut: ${pack.targetCutDate ?? "2026-09-30"}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
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
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF334155)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Delete button (Red tinted #FEE2E2 / #DC2626)
                    InkWell(
                      onTap: () => _confirmDeleteTechPack(context, pack),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Diff / Compare button
                    InkWell(
                      onTap: () => _showDiffModal(context, pack),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.compare_arrows_rounded, size: 16, color: Color(0xFF334155)),
                            const SizedBox(width: 3),
                            Text(
                              'Diff',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
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
        ],
      ),
    );
  }

  // ==========================================
  // COMPACT SPEC CARD BUILDER
  // ==========================================
  Widget _buildCompactSpecCard(TechPackSummaryModel pack) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              pack.styleNumber,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.styleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pack.category} • ${pack.baseSize} • ${pack.targetGsm} GSM',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _openEditTechPackModal(context, pack),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _confirmDeleteTechPack(context, pack),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CREATE TECH-PACK MODAL (2-STEP WIZARD)
  // ==========================================
  void _openCreateTechPackModal(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const CreateProductionTechPackWizard(isEditing: false),
    );
    if (result == true && mounted) {
      ref.read(designerProvider.notifier).fetchStudioData();
    }
  }

  // ==========================================
  // EDIT TECH-PACK MODAL (2-STEP WIZARD)
  // ==========================================
  void _openEditTechPackModal(BuildContext context, TechPackSummaryModel pack) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CreateProductionTechPackWizard(
        isEditing: true,
        initialPack: pack,
      ),
    );
    if (result == true && mounted) {
      ref.read(designerProvider.notifier).fetchStudioData();
    }
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
