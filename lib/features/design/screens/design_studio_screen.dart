import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';
import 'concept_review_screen.dart';
import 'design_team_management_screen.dart';
import 'ph_settings_screen.dart';
import 'tech_pack_catalog_screen.dart';

class ConceptCardData {
  final String rowKey;
  final DesignBriefModel brief;
  final int conceptNumber;
  final String artNumber;
  final String garmentType;
  final String categoryStyle;
  final List<String> colors;
  final String status;

  const ConceptCardData({
    required this.rowKey,
    required this.brief,
    required this.conceptNumber,
    required this.artNumber,
    required this.garmentType,
    required this.categoryStyle,
    required this.colors,
    required this.status,
  });
}

class DesignStudioScreen extends ConsumerStatefulWidget {
  const DesignStudioScreen({super.key});

  @override
  ConsumerState<DesignStudioScreen> createState() => _DesignStudioScreenState();
}

class _DesignStudioScreenState extends ConsumerState<DesignStudioScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _activeTab = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final briefs = state.briefs;
    final teamMembers = state.teamMembers;
    final techPacks = state.techPacks;

    // Flatten briefs into concept rows (identical to web Admin DesignDashboardClient lines 473-539 & 661-719)
    final List<ConceptCardData> allConceptRows = [];
    for (final brief in briefs) {
      if (brief.safeDesignConceptsBrief.isNotEmpty) {
        for (final req in brief.safeDesignConceptsBrief) {
          final artNo = req.artNumber?.trim().isNotEmpty == true
              ? req.artNumber!.trim()
              : (req.notes != null && RegExp(r'Art No:\s*([^|]+)', caseSensitive: false).hasMatch(req.notes!)
                  ? RegExp(r'Art No:\s*([^|]+)', caseSensitive: false).firstMatch(req.notes!)!.group(1)!.trim()
                  : '#${brief.id.replaceAll('-', '').substring(0, 6).toUpperCase()}-${req.conceptNumber}');

          final garment = (req.notes != null && RegExp(r'Garment:\s*([^|]+)', caseSensitive: false).hasMatch(req.notes!)
              ? RegExp(r'Garment:\s*([^|]+)', caseSensitive: false).firstMatch(req.notes!)!.group(1)!.trim()
              : brief.garmentType);

          final cat = req.categoryStyle?.trim().isNotEmpty == true ? req.categoryStyle!.trim() : brief.category;
          final cols = req.colors.isNotEmpty ? req.colors : brief.safeColorways;

          allConceptRows.add(ConceptCardData(
            rowKey: '${brief.id}-${req.conceptNumber}',
            brief: brief,
            conceptNumber: req.conceptNumber,
            artNumber: artNo,
            garmentType: garment,
            categoryStyle: cat,
            colors: cols,
            status: brief.status,
          ));
        }
      } else {
        final artNo = '#${brief.id.replaceAll('-', '').substring(0, 6).toUpperCase()}';
        allConceptRows.add(ConceptCardData(
          rowKey: brief.id,
          brief: brief,
          conceptNumber: 1,
          artNumber: artNo,
          garmentType: brief.garmentType,
          categoryStyle: brief.category,
          colors: brief.safeColorways,
          status: brief.status,
        ));
      }
    }

    // Filter concept rows based on tab & search
    final filteredConceptRows = allConceptRows.where((row) {
      if (_activeTab == 'SUBMITTED') {
        final st = row.status.toUpperCase();
        if (st != 'SUBMITTED' && st != 'IN_REVIEW' && st != 'PENDING_REVIEW') return false;
      } else if (_activeTab == 'PH_APPROVED') {
        final st = row.status.toUpperCase();
        if (st != 'PH_APPROVED' && st != 'APPROVED_BY_PH' && st != 'SA_APPROVED' && st != 'SA_SAVED_FOR_LATER' && st != 'PENDING_SA') return false;
      } else if (_activeTab == 'ALLOCATED') {
        final st = row.status.toUpperCase();
        if (st != 'ALLOCATED' && st != 'DRAFT') return false;
      } else if (_activeTab == 'PH_REJECTED') {
        final st = row.status.toUpperCase();
        if (!st.contains('REVIS') && !st.contains('REJECT')) return false;
      } else if (_activeTab == 'TECH_PACK_CREATED') {
        final st = row.status.toUpperCase();
        if (!st.contains('TECHPACK') && !st.contains('TECH_PACK') && !st.contains('COMPLETED')) return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchGarment = row.garmentType.toLowerCase().contains(q);
        final matchCat = row.categoryStyle.toLowerCase().contains(q);
        final matchArt = row.artNumber.toLowerCase().contains(q);
        final matchDesigner = (row.brief.designerName ?? '').toLowerCase().contains(q);
        final matchInst = (row.brief.instructions ?? '').toLowerCase().contains(q);
        if (!matchGarment && !matchCat && !matchArt && !matchDesigner && !matchInst) {
          return false;
        }
      }
      return true;
    }).toList();

    // Stats calculations strictly matching web metrics
    final activeBriefsCount = briefs.where((b) {
      final st = b.status.toUpperCase();
      return st == 'ALLOCATED' || st == 'SUBMITTED';
    }).length;

    final pendingPhReviewCount = briefs.where((b) {
      final st = b.status.toUpperCase();
      return st == 'SUBMITTED' || st == 'IN_REVIEW' || st == 'PENDING_REVIEW';
    }).length;

    final forwardedSaCount = briefs.where((b) {
      final st = b.status.toUpperCase();
      return st == 'PH_APPROVED' || st == 'PENDING_SA' || st == 'APPROVED_BY_PH';
    }).length;

    final techPacksCount = techPacks.length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAFAF8),
      drawer: WorkspaceHubDrawer(
        activeRoute: '/design',
        onOpenTechPacks: () => _openTechPacksModal(context, techPacks),
        onOpenTeam: () => _openTeamModal(context, teamMembers),
        onOpenSettings: () => _openSettingsModal(context),
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
                  Text(
                    'Design Studio',
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
                    'Workspaces',
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
                    'Provisional Head Desk',
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
              // 2. HERO HEADER CARD WITH 2x2 ACTIONS
              // ==========================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: const Icon(Icons.palette_outlined, color: AppTheme.brandSteel, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Design & Tech-Pack Studio',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  height: 1.15,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F0),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0x26000000)),
                                ),
                                child: Text(
                                  '$activeBriefsCount ACTIVE BRIEFS',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.brandSteel,
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
                      'Creative pipeline, multi-concept studio deck, and tech-pack generation',
                      style: GoogleFonts.publicSans(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2x2 Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildHeaderActionButton(
                            icon: Icons.assignment_turned_in_outlined,
                            label: 'Tech-Packs',
                            onTap: () => _openTechPacksModal(context, techPacks),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildHeaderActionButton(
                            icon: Icons.group_outlined,
                            label: 'Team',
                            onTap: () => _openTeamModal(context, teamMembers),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildHeaderActionButton(
                            icon: Icons.tune_rounded,
                            label: 'PH Settings',
                            onTap: () => _openSettingsModal(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _openNewBriefModal(context, teamMembers),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.brandSteel,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x2A3A3564),
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
                                    'New Brief',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
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
              const SizedBox(height: 16),

              // ==========================================
              // 3. 2x2 STATS KPI GRID (Exact Match to Image 4 on Web)
              // ==========================================
              Row(
                children: [
                  Expanded(
                    child: _buildWebKpiCard(
                      tag: 'STAGE 01',
                      title: 'ACTIVE BRIEFS',
                      value: '$activeBriefsCount',
                      icon: Icons.assignment_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildWebKpiCard(
                      tag: 'STAGE 02',
                      title: 'PENDING PH REVIEW',
                      value: '$pendingPhReviewCount',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildWebKpiCard(
                      tag: 'STAGE 03',
                      title: 'FORWARDED TO SA',
                      value: '$forwardedSaCount',
                      icon: Icons.shield_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildWebKpiCard(
                      tag: 'CATALOG',
                      title: 'TECH-PACKS READY',
                      value: '$techPacksCount',
                      icon: Icons.description_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ==========================================
              // 4. QUEUE SECTION CONTAINER WITH TABS & SEARCH
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Filter Tabs Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildQueueTab('ALL', 'All Queue'),
                            _buildQueueTab('SUBMITTED', 'In Review'),
                            _buildQueueTab('PH_APPROVED', 'PH Approved'),
                            _buildQueueTab('ALLOCATED', 'Allocated'),
                            _buildQueueTab('PH_REJECTED', 'Revisions Needed'),
                            _buildQueueTab('TECH_PACK_CREATED', 'Tech-Pack Created'),
                          ],
                        ),
                      ),
                    ),

                    // Search Field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Container(
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
                          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Search concepts or designers...',
                            hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 19),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Card List
                    if (state.isLoading && briefs.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(color: AppTheme.brandSteel),
                        ),
                      )
                    else if (filteredConceptRows.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(14),
                        itemCount: filteredConceptRows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, index) {
                          final row = filteredConceptRows[index];
                          return _buildWebConceptCard(row);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // WIDGET BUILDERS
  // ==========================================================================

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1A000000)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.brandSteel, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Exact Match to Web KPI Cards in Image 4
  Widget _buildWebKpiCard({
    required String tag,
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0x14000000)),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x14000000)),
                ),
                child: Icon(icon, color: AppTheme.brandSteel, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTab(String tabKey, String label) {
    final isSelected = _activeTab == tabKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = tabKey;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.brandSteel : const Color(0xFFFAF7F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.brandSteel : const Color(0x1A000000),
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x1E3A3564),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  // Exact Match to Web Concept Cards in Image 1
  Widget _buildWebConceptCard(ConceptCardData row) {
    final stInfo = _getStatusBadgeInfo(row.status);
    final brief = row.brief;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Row: Article Number on Left + Status Badge on Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.artNumber,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: stInfo.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: stInfo.border),
                ),
                child: Text(
                  stInfo.label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: stInfo.fg,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 2. Garment Title
          Text(
            row.garmentType,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),

          // 3. Subtitle (Category Style • #1 • #24f895)
          Text(
            '${row.categoryStyle} Style • #${row.conceptNumber} • #${brief.id.replaceAll('-', '').substring(0, 6).toLowerCase()}',
            style: GoogleFonts.publicSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Beige Stats Box: DESIGNER | COLORS Selected (Exact Match to Web)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x12000000)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DESIGNER',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      brief.designerName ?? 'Unassigned',
                      style: GoogleFonts.publicSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'COLORS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${row.colors.length} Selected',
                      style: GoogleFonts.publicSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brandSteel,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 5. Action Row: View & Review (DEMO-101) > + Trash Button
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _openReviewModal(context, brief, row.conceptNumber),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.brandSteel,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F3A3564),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.visibility_outlined, color: Colors.white, size: 16),
                        const SizedBox(width: 7),
                        Text(
                          'View & Review (${row.artNumber})',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _confirmDeleteBrief(context, brief),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.palette_outlined, color: AppTheme.brandSteel, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty ? 'No matching concepts' : 'No active design concepts',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'Adjust your filter tabs or search query.'
                : 'Allocate your first design brief using "+ New Brief" above.',
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MODALS & DIALOGS
  // ==========================================================================

  // 1. CONCEPT REVIEW MODAL (Full per-colorway review flow)
  void _openReviewModal(BuildContext context, DesignBriefModel brief, int initialTab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConceptReviewScreen(
          brief: brief,
          initialConceptNumber: initialTab,
        ),
      ),
    );
  }

  // 2. NEW BRIEF MODAL
  void _openNewBriefModal(BuildContext context, List<DesignTeamMemberModel> team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewBriefCreationSheet(teamMembers: team),
    );
  }

  // 3. TECH-PACKS MASTER CATALOG (Full Screen Navigation)
  void _openTechPacksModal(BuildContext context, List<TechPackSummaryModel> techPacks) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TechPackCatalogScreen()),
    );
  }

  // 4. TEAM MANAGEMENT (Full Screen Navigation)
  void _openTeamModal(BuildContext context, List<DesignTeamMemberModel> team) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DesignTeamManagementScreen()),
    );
  }

  // 5. PH SETTINGS (Full Screen Navigation)
  void _openSettingsModal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PHSettingsScreen()),
    );
  }

  // 6. CONFIRM DELETE BRIEF
  void _confirmDeleteBrief(BuildContext context, DesignBriefModel brief) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete Brief ${brief.briefCode}?',
          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
        ),
        content: Text(
          'Are you sure you want to delete this brief and all its associated submissions? This action cannot be undone.',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final success = await ref.read(designerProvider.notifier).deleteBrief(brief.id);
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: success ? AppTheme.brandSteel : const Color(0xFFDC2626),
                    content: Text(success ? 'Brief deleted successfully' : 'Failed to delete brief'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STATUS BADGE CONFIGURATION (Matching Web STATUS_CONFIG)
  // ==========================================================================

  _StatusBadgeInfo _getStatusBadgeInfo(String status) {
    switch (status.toUpperCase()) {
      case 'SA_APPROVED':
        return const _StatusBadgeInfo(
          label: 'SA GREENLIT',
          bg: Color(0xFFECFDF5),
          fg: Color(0xFF047857),
          border: Color(0xFFA7F3D0),
        );
      case 'SUBMITTED':
      case 'IN_REVIEW':
      case 'PENDING_REVIEW':
        return const _StatusBadgeInfo(
          label: 'IN REVIEW',
          bg: Color(0xFFFEF3C7),
          fg: Color(0xFFB45309),
          border: Color(0xFFFDE68A),
        );
      case 'PH_APPROVED':
      case 'APPROVED_BY_PH':
      case 'SA_SAVED_FOR_LATER':
      case 'PENDING_SA':
        return const _StatusBadgeInfo(
          label: 'PH APPROVED',
          bg: Color(0xFFF0F9FF),
          fg: Color(0xFF0369A1),
          border: Color(0xFFBAE6FD),
        );
      case 'ALLOCATED':
      case 'DRAFT':
        return const _StatusBadgeInfo(
          label: 'ALLOCATED',
          bg: Color(0xFFF1F5F9),
          fg: Color(0xFF334155),
          border: Color(0xFFE2E8F0),
        );
      case 'PH_REJECTED':
      case 'REVISION_REQUESTED':
      case 'REJECTED':
        return const _StatusBadgeInfo(
          label: 'REVISIONS NEEDED',
          bg: Color(0xFFFFF1F2),
          fg: Color(0xFFBE123C),
          border: Color(0xFFFECDD3),
        );
      case 'TECH_PACK_CREATED':
      case 'COMPLETED':
        return const _StatusBadgeInfo(
          label: 'TECH-PACK CREATED',
          bg: Color(0xFFFAF7F0),
          fg: Color(0xFF0F172A),
          border: Color(0x26000000),
        );
      default:
        return _StatusBadgeInfo(
          label: status.replaceAll('_', ' ').toUpperCase(),
          bg: const Color(0xFFF1F5F9),
          fg: const Color(0xFF475569),
          border: const Color(0xFFE2E8F0),
        );
    }
  }
}

class _StatusBadgeInfo {
  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  const _StatusBadgeInfo({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });
}

// ============================================================================
// SHEET 2: + NEW BRIEF CREATION
// ============================================================================

class _NewBriefCreationSheet extends ConsumerStatefulWidget {
  final List<DesignTeamMemberModel> teamMembers;

  const _NewBriefCreationSheet({required this.teamMembers});

  @override
  ConsumerState<_NewBriefCreationSheet> createState() => _NewBriefCreationSheetState();
}

class _NewBriefCreationSheetState extends ConsumerState<_NewBriefCreationSheet> {
  final _formKey = GlobalKey<FormState>();
  String _garmentType = 'Oversized T-Shirt';
  String _category = 'Men';
  int _targetDesigns = 3;
  int _maxColors = 4;
  String? _selectedDesignerId;
  final TextEditingController _instructionsController = TextEditingController();
  final List<String> _selectedColors = ['Black', 'Navy', 'White'];

  final List<String> _garmentTypes = [
    'Oversized T-Shirt',
    'Classic T-Shirt',
    'Hoodie / Pullover',
    'Polo Shirt',
    'Trackpants / Joggers',
    'Denim Jacket',
    'Dress / Kurti',
    'Cargo Pants',
  ];

  final List<String> _categories = ['Men', 'Women', 'Unisex', 'Kids'];
  final List<String> _colorOptions = ['Black', 'White', 'Navy', 'Royal Blue', 'Red', 'Maroon', 'Bottle Green', 'Olive', 'Grey', 'Beige'];

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create Design Brief',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Garment Type
                    Text('Garment Type *', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _garmentType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _garmentTypes.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (val) => setState(() => _garmentType = val ?? _garmentType),
                    ),
                    const SizedBox(height: 14),

                    // Category
                    Text('Category *', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: _categories.map((c) {
                        final isSel = _category == c;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Center(child: Text(c)),
                              selected: isSel,
                              onSelected: (_) => setState(() => _category = c),
                              selectedColor: AppTheme.brandSteel,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : const Color(0xFF334155),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Target Designs (1 to 10) & Max Colors
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Target Designs (1-10)', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                value: _targetDesigns,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: List.generate(10, (i) => i + 1)
                                    .map((count) => DropdownMenuItem(value: count, child: Text('$count Concept${count > 1 ? 's' : ''}')))
                                    .toList(),
                                onChanged: (val) => setState(() => _targetDesigns = val ?? _targetDesigns),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Max Colors (1-8)', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                value: _maxColors,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: List.generate(8, (i) => i + 1)
                                    .map((count) => DropdownMenuItem(value: count, child: Text('$count Color${count > 1 ? 's' : ''}')))
                                    .toList(),
                                onChanged: (val) => setState(() => _maxColors = val ?? _maxColors),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Colorway Palette Selection
                    Text('Colorway Palette Options', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _colorOptions.map((c) {
                        final isSel = _selectedColors.contains(c);
                        return FilterChip(
                          label: Text(c),
                          selected: isSel,
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _selectedColors.add(c);
                              } else {
                                _selectedColors.remove(c);
                              }
                            });
                          },
                          selectedColor: AppTheme.brandSteel.withValues(alpha: 0.15),
                          checkmarkColor: AppTheme.brandSteel,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Allocate Designer
                    Text('Allocate Designer', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedDesignerId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        hintText: 'Select team member (Optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Auto / Unassigned')),
                        ...widget.teamMembers.map((m) => DropdownMenuItem(value: m.id, child: Text(m.designerName))),
                      ],
                      onChanged: (val) => setState(() => _selectedDesignerId = val),
                    ),
                    const SizedBox(height: 14),

                    // Instructions
                    Text('Concept Guidelines & Instructions', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _instructionsController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'e.g. Vintage typography on chest, minimal back branding, relaxed boxy fit...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _submitBrief,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandSteel,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Create & Dispatch Brief', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitBrief() async {
    if (_formKey.currentState?.validate() != true) return;

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final success = await ref.read(designerProvider.notifier).createDesignBrief(
          garmentType: _garmentType,
          category: _category,
          targetDesigns: _targetDesigns,
          maxColors: _maxColors,
          targetColors: _selectedColors,
          designerMemberId: _selectedDesignerId,
          instructions: _instructionsController.text.trim(),
        );

    if (mounted) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: success ? AppTheme.brandSteel : const Color(0xFFDC2626),
          content: Text(success ? 'Design brief created successfully!' : 'Failed to create design brief'),
        ),
      );
    }
  }
}



