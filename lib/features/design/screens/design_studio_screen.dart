import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';

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

    // Filter briefs based on tab & search
    final filteredBriefs = briefs.where((b) {
      if (_activeTab == 'IN_REVIEW') {
        final st = b.status.toUpperCase();
        if (st != 'SUBMITTED' && st != 'IN_REVIEW' && st != 'PENDING_REVIEW') return false;
      } else if (_activeTab == 'PH_APPROVED') {
        final st = b.status.toUpperCase();
        if (st != 'PH_APPROVED' && st != 'APPROVED_BY_PH' && st != 'PENDING_SA') return false;
      } else if (_activeTab == 'ALLOCATED') {
        final st = b.status.toUpperCase();
        if (st != 'ALLOCATED' && st != 'DRAFT') return false;
      } else if (_activeTab == 'REVISIONS') {
        final st = b.status.toUpperCase();
        if (!st.contains('REVIS') && !st.contains('REJECT')) return false;
      } else if (_activeTab == 'TECHPACK_CREATED') {
        final st = b.status.toUpperCase();
        if (!st.contains('TECHPACK') && !st.contains('COMPLETED')) return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchGarment = b.garmentType.toLowerCase().contains(q);
        final matchCategory = b.category.toLowerCase().contains(q);
        final matchDesigner = (b.designerName ?? '').toLowerCase().contains(q);
        final matchInstructions = (b.instructions ?? '').toLowerCase().contains(q);
        final matchCode = b.briefCode.toLowerCase().contains(q);
        if (!matchGarment && !matchCategory && !matchDesigner && !matchInstructions && !matchCode) {
          return false;
        }
      }
      return true;
    }).toList();

    // Stats calculations
    final activeBriefsCount = briefs.where((b) => !b.status.toUpperCase().contains('COMPLETED') && !b.status.toUpperCase().contains('CANCELLED')).length;
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
      drawer: const WorkspaceHubDrawer(activeRoute: '/design'),
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
                    'Design studio',
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
                    'Provisional head desk',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brandSteel,
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
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
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
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x18000000)),
                          ),
                          child: const Icon(Icons.palette_rounded, color: AppTheme.brandSteel, size: 24),
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
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0x14000000)),
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
                      'Provisional Head desk — Review concepts, allocate briefs, create tech-packs & route to SA.',
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
                            icon: Icons.inventory_2_outlined,
                            label: 'Tech-packs',
                            count: techPacksCount > 0 ? '$techPacksCount' : null,
                            onTap: () => _openTechPacksModal(context, techPacks),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildHeaderActionButton(
                            icon: Icons.group_outlined,
                            label: 'Team',
                            count: teamMembers.isNotEmpty ? '${teamMembers.length}' : null,
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
                            label: 'PH settings',
                            onTap: () => _openSettingsModal(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _openNewBriefModal(context, teamMembers),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.brandSteel,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x2A3A3564),
                                    blurRadius: 6,
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
                                    '+ New brief',
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
              const SizedBox(height: 16),

              // ==========================================
              // 3. 2x2 STATS KPI GRID
              // ==========================================
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      tag: 'Stage 01',
                      title: 'Active briefs',
                      value: '$activeBriefsCount',
                      icon: Icons.pending_actions_rounded,
                      accentColor: const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKpiCard(
                      tag: 'Stage 02',
                      title: 'Pending PH review',
                      value: '$pendingPhReviewCount',
                      icon: Icons.rate_review_outlined,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      tag: 'Stage 03',
                      title: 'Forwarded to SA',
                      value: '$forwardedSaCount',
                      icon: Icons.send_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKpiCard(
                      tag: 'Catalog',
                      title: 'Tech-packs ready',
                      value: '$techPacksCount',
                      icon: Icons.check_circle_outline_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ==========================================
              // 4. HORIZONTAL QUEUE FILTER TABS
              // ==========================================
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildQueueTab('ALL', 'All queue', briefs.length),
                    _buildQueueTab('IN_REVIEW', 'In review', pendingPhReviewCount),
                    _buildQueueTab('PH_APPROVED', 'PH approved', forwardedSaCount),
                    _buildQueueTab(
                      'ALLOCATED',
                      'Allocated',
                      briefs.where((b) => b.status.toUpperCase() == 'ALLOCATED').length,
                    ),
                    _buildQueueTab(
                      'REVISIONS',
                      'Revisions needed',
                      briefs.where((b) => b.status.toUpperCase().contains('REVIS')).length,
                    ),
                    _buildQueueTab('TECHPACK_CREATED', 'Tech-pack created', techPacksCount),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // 5. SEARCH FIELD
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: GoogleFonts.publicSans(fontSize: 13.5, color: const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search concepts or designers...',
                    hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // 6. BRIEFS QUEUE LIST
              // ==========================================
              if (state.isLoading && briefs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: AppTheme.brandSteel),
                  ),
                )
              else if (filteredBriefs.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredBriefs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final brief = filteredBriefs[index];
                    return _buildBriefCard(brief);
                  },
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
    String? count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF475569), size: 17),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String tag,
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
              Text(
                tag.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, color: accentColor.withValues(alpha: 0.8), size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.publicSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTab(String tabKey, String label, int count) {
    final isSelected = _activeTab == tabKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = tabKey;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.brandSteel : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.brandSteel : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x223A3564),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBriefCard(DesignBriefModel brief) {
    final statusBg = _getStatusBg(brief.status);
    final statusFg = _getStatusFg(brief.status);
    final colors = brief.safeColorways;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Header: Brief ID Chip & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x18000000)),
                    ),
                    child: Text(
                      brief.briefCode,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brandSteel,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${brief.safeTargetDesigns} Concept${brief.safeTargetDesigns > 1 ? 's' : ''}',
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatStatus(brief.status),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Category
          Text(
            '${brief.garmentType} • ${brief.category}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          if (brief.instructions != null && brief.instructions!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              brief.cleanInstructions,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.publicSans(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Detail Strip: Designer left, Color dots right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFFFAF7F0),
                    child: Text(
                      (brief.designerName?.isNotEmpty == true ? brief.designerName![0] : 'D').toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brandSteel,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    brief.designerName ?? 'Unassigned',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              if (colors.isNotEmpty)
                Row(
                  children: colors.take(5).map((c) {
                    final hex = _parseColor(c);
                    return Container(
                      margin: const EdgeInsets.only(left: 4),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: hex,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x33000000), width: 0.5),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Row: View & Review + Delete
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openReviewModal(context, brief),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text('View & review (${brief.briefCode})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandSteel,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _confirmDeleteBrief(context, brief),
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                tooltip: 'Delete brief',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF2F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppTheme.brandSteel, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'No design briefs found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search keywords'
                : 'Create your first design brief using the "+ New brief" button above.',
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MODALS & DIALOGS
  // ==========================================================================

  // 1. CONCEPT REVIEW MODAL (Tabbed artwork viewer + Verdicts)
  void _openReviewModal(BuildContext context, DesignBriefModel brief) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConceptReviewSheet(brief: brief),
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

  // 3. TECH-PACKS CATALOG MODAL
  void _openTechPacksModal(BuildContext context, List<TechPackSummaryModel> techPacks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TechPacksCatalogSheet(techPacks: techPacks),
    );
  }

  // 4. TEAM MANAGEMENT MODAL
  void _openTeamModal(BuildContext context, List<DesignTeamMemberModel> team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TeamManagementSheet(teamMembers: team),
    );
  }

  // 5. PH SETTINGS MODAL
  void _openSettingsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.tune_rounded, color: AppTheme.brandSteel, size: 22),
            const SizedBox(width: 8),
            Text(
              'PH Studio Settings',
              style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workflow Configuration',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: true,
              onChanged: (_) {},
              activeColor: AppTheme.brandSteel,
              title: Text('Auto-notify designers on assignment', style: GoogleFonts.publicSans(fontSize: 12.5)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: true,
              onChanged: (_) {},
              activeColor: AppTheme.brandSteel,
              title: Text('Require both Front & Back views', style: GoogleFonts.publicSans(fontSize: 12.5)),
            ),
            const SizedBox(height: 10),
            Text(
              'Max active concepts per designer: 10',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppTheme.brandSteel)),
          ),
        ],
      ),
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
  // HELPERS
  // ==========================================================================

  Color _getStatusBg(String status) {
    switch (status.toUpperCase()) {
      case 'SUBMITTED':
      case 'IN_REVIEW':
      case 'PENDING_REVIEW':
        return const Color(0xFFFEF3C7);
      case 'PH_APPROVED':
      case 'APPROVED_BY_PH':
      case 'PENDING_SA':
        return const Color(0xFFEDE9FE);
      case 'ALLOCATED':
        return const Color(0xFFE0F2FE);
      case 'TECHPACK_CREATED':
      case 'COMPLETED':
        return const Color(0xFFD1FAE5);
      case 'REVISION_REQUESTED':
      case 'REJECTED':
      case 'PH_REJECTED':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusFg(String status) {
    switch (status.toUpperCase()) {
      case 'SUBMITTED':
      case 'IN_REVIEW':
      case 'PENDING_REVIEW':
        return const Color(0xFFD97706);
      case 'PH_APPROVED':
      case 'APPROVED_BY_PH':
      case 'PENDING_SA':
        return const Color(0xFF7C3AED);
      case 'ALLOCATED':
        return const Color(0xFF0284C7);
      case 'TECHPACK_CREATED':
      case 'COMPLETED':
        return const Color(0xFF059669);
      case 'REVISION_REQUESTED':
      case 'REJECTED':
      case 'PH_REJECTED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF475569);
    }
  }

  String _formatStatus(String status) {
    switch (status.toUpperCase()) {
      case 'SUBMITTED':
        return 'Pending PH';
      case 'IN_REVIEW':
        return 'In Review';
      case 'PH_APPROVED':
        return 'PH Approved';
      case 'ALLOCATED':
        return 'Allocated';
      case 'TECHPACK_CREATED':
        return 'Tech-Pack Ready';
      case 'REVISION_REQUESTED':
        return 'Revisions';
      case 'PH_REJECTED':
        return 'Rejected';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Color _parseColor(String colorStr) {
    final clean = colorStr.trim().toLowerCase();
    switch (clean) {
      case 'black':
      case '#000000':
        return Colors.black;
      case 'white':
      case '#ffffff':
        return Colors.white;
      case 'navy':
      case '#000080':
        return const Color(0xFF000080);
      case 'royal blue':
      case '#4169e1':
        return const Color(0xFF4169E1);
      case 'red':
      case '#ff0000':
        return Colors.red;
      case 'maroon':
      case '#800000':
        return const Color(0xFF800000);
      case 'bottle green':
      case '#006a4e':
        return const Color(0xFF006A4E);
      case 'olive':
      case '#808000':
        return const Color(0xFF808000);
      case 'grey':
      case 'gray':
      case '#808080':
        return Colors.grey;
      case 'charcoal':
      case '#36454f':
        return const Color(0xFF36454F);
      case 'beige':
      case '#f5f5dc':
        return const Color(0xFFF5F5DC);
      case 'yellow':
      case '#ffff00':
        return Colors.yellow;
      case 'orange':
      case '#ffa500':
        return Colors.orange;
      case 'pink':
      case '#ffc0cb':
        return Colors.pink;
      case 'purple':
      case '#800080':
        return Colors.purple;
      default:
        if (clean.startsWith('#') && clean.length == 7) {
          try {
            return Color(int.parse('0xFF${clean.substring(1)}'));
          } catch (_) {}
        }
        return const Color(0xFF94A3B8);
    }
  }
}

// ============================================================================
// SHEET 1: CONCEPT REVIEW & ARTWORK LIGHTBOX
// ============================================================================

class _ConceptReviewSheet extends ConsumerStatefulWidget {
  final DesignBriefModel brief;

  const _ConceptReviewSheet({required this.brief});

  @override
  ConsumerState<_ConceptReviewSheet> createState() => _ConceptReviewSheetState();
}

class _ConceptReviewSheetState extends ConsumerState<_ConceptReviewSheet> {
  int _selectedConceptIndex = 0;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brief = widget.brief;
    final submissions = brief.submissions;
    final latestSubmission = submissions.isNotEmpty ? submissions.first : null;
    final concepts = latestSubmission?.safeConcepts ?? [];

    final targetDesigns = brief.safeTargetDesigns;
    final totalTabs = concepts.isNotEmpty ? concepts.length : (targetDesigns > 0 ? targetDesigns : 1);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Concept Review • ${brief.briefCode}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${brief.garmentType} • ${brief.category}',
                      style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Concept selection tabs (Concept 1, 2, 3...)
          if (totalTabs > 1)
            Container(
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAF8),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: totalTabs,
                itemBuilder: (ctx, i) {
                  final isSelected = _selectedConceptIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Concept #${i + 1}'),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedConceptIndex = i),
                      selectedColor: AppTheme.brandSteel,
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Scrollable Concept Artworks & Notes
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Designer info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x18000000)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, color: AppTheme.brandSteel, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              brief.designerName ?? 'Assigned Designer',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        if (latestSubmission != null)
                          Text(
                            DateFormat('dd MMM yyyy').format(DateTime.parse(latestSubmission.submittedAt)),
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Concept Artwork Preview (Front & Back Views)
                  if (concepts.isNotEmpty && _selectedConceptIndex < concepts.length) ...[
                    _buildConceptArtworkSection(concepts[_selectedConceptIndex]),
                  ] else if (latestSubmission != null && (latestSubmission.photoUrl1.isNotEmpty || latestSubmission.photoUrl2 != null)) ...[
                    _buildLegacyArtworkSection(latestSubmission),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.pending_actions_rounded, color: Color(0xFF94A3B8), size: 36),
                          const SizedBox(height: 10),
                          Text(
                            'No artwork submitted yet for Concept #${_selectedConceptIndex + 1}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Instructions Recap
                  if (brief.instructions != null && brief.instructions!.isNotEmpty) ...[
                    Text(
                      'Brief Instructions',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        brief.cleanInstructions,
                        style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // Action Buttons: Approve & Forward to SA / Request Revisions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openRevisionsDialog(context, brief, latestSubmission?.id ?? ''),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Request revisions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveBrief(context, brief, latestSubmission?.id ?? ''),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Approve & SA ->'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
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

  Widget _buildConceptArtworkSection(DesignConceptItemModel concept) {
    final colorways = concept.safeColorways;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (concept.title.isNotEmpty)
          Text(
            concept.title,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        const SizedBox(height: 10),
        for (final cw in colorways) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppTheme.brandSteel,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Colorway: ${cw.colorwayName}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (cw.photoFront != null && cw.photoFront!.isNotEmpty)
                      Expanded(
                        child: _buildArtworkTile(
                          title: 'Front View',
                          photoUrl: cw.photoFront!,
                        ),
                      ),
                    if (cw.photoBack != null && cw.photoBack!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildArtworkTile(
                          title: 'Back View',
                          photoUrl: cw.photoBack!,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLegacyArtworkSection(DesignSubmissionModel sub) {
    return Row(
      children: [
        if (sub.photoUrl1.isNotEmpty)
          Expanded(
            child: _buildArtworkTile(title: 'Front View', photoUrl: sub.photoUrl1),
          ),
        if (sub.photoUrl2 != null && sub.photoUrl2!.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _buildArtworkTile(title: 'Back View', photoUrl: sub.photoUrl2!),
          ),
        ],
      ],
    );
  }

  Widget _buildArtworkTile({required String title, required String photoUrl}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _openImageLightbox(context, photoUrl),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 28),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openImageLightbox(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _approveBrief(BuildContext context, DesignBriefModel brief, String submissionId) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Approve & Forward to SA?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text(
          'This will approve ${brief.briefCode} and forward it to SuperAdmin for final production approval.',
          style: GoogleFonts.publicSans(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(designerProvider.notifier).reviewBriefVerdict(
            briefId: brief.id,
            submissionId: submissionId,
            verdict: 'APPROVED',
          );
      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: success ? const Color(0xFF059669) : const Color(0xFFDC2626),
            content: Text(success ? 'Approved and forwarded to SA!' : 'Failed to approve'),
          ),
        );
      }
    }
  }

  void _openRevisionsDialog(BuildContext context, DesignBriefModel brief, String submissionId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Request Revisions', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify changes or corrections required from the designer:', style: GoogleFonts.publicSans(fontSize: 12.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g. Adjust neckline proportions, refine rear artwork colors...',
                hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final fb = _feedbackController.text.trim();
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              final success = await ref.read(designerProvider.notifier).reviewBriefVerdict(
                    briefId: brief.id,
                    submissionId: submissionId,
                    verdict: 'REJECTED',
                    feedback: fb.isNotEmpty ? fb : null,
                  );
              if (mounted) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: success ? const Color(0xFFDC2626) : const Color(0xFFDC2626),
                    content: Text(success ? 'Revision feedback sent to designer' : 'Failed to request revisions'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Send Revisions', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
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

// ============================================================================
// SHEET 3: TECH-PACKS CATALOG
// ============================================================================

class _TechPacksCatalogSheet extends StatelessWidget {
  final List<TechPackSummaryModel> techPacks;

  const _TechPacksCatalogSheet({required this.techPacks});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: AppTheme.brandSteel, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Tech-Packs Ready (${techPacks.length})',
                      style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: techPacks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.layers_clear_outlined, size: 40, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 10),
                        Text('No tech-packs generated yet', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: techPacks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final tp = techPacks[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAF8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tp.techPackCode,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.brandSteel),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Status: ${tp.status}',
                                  style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF059669), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('PRODUCTION READY', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF065F46))),
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

// ============================================================================
// SHEET 4: TEAM MANAGEMENT & ONBOARDING
// ============================================================================

class _TeamManagementSheet extends ConsumerStatefulWidget {
  final List<DesignTeamMemberModel> teamMembers;

  const _TeamManagementSheet({required this.teamMembers});

  @override
  ConsumerState<_TeamManagementSheet> createState() => _TeamManagementSheetState();
}

class _TeamManagementSheetState extends ConsumerState<_TeamManagementSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showOnboardForm = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                Row(
                  children: [
                    const Icon(Icons.group_outlined, color: AppTheme.brandSteel, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Design Team Roster (${widget.teamMembers.length})',
                      style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // "+ Onboard Designer" Toggle
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _showOnboardForm = !_showOnboardForm),
                    icon: Icon(_showOnboardForm ? Icons.close_rounded : Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(_showOnboardForm ? 'Hide Form' : '+ Onboard Designer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandSteel,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (_showOnboardForm) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x18000000)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Onboard New Creative Designer', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Full Name *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailCtrl,
                            decoration: InputDecoration(
                              labelText: 'Email or Mobile *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Access Password *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveNewDesigner,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Save & Authorize Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Active Designers', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  if (widget.teamMembers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No designers onboarded yet')),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.teamMembers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final m = widget.teamMembers[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFFAF7F0),
                                child: Text(m.designerName.isNotEmpty ? m.designerName[0].toUpperCase() : 'D', style: const TextStyle(color: AppTheme.brandSteel, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.designerName, style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                    Text(m.designerEmail ?? m.phoneNumber ?? 'Active Designer', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('ACTIVE', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF065F46))),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveNewDesigner() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    final success = await ref.read(designerProvider.notifier).onboardDesigner(
          name: name,
          emailOrPhone: email,
          password: pass,
        );

    if (mounted) {
      if (success) {
        _nameCtrl.clear();
        _emailCtrl.clear();
        _passCtrl.clear();
        setState(() => _showOnboardForm = false);
        messenger.showSnackBar(const SnackBar(backgroundColor: Color(0xFF059669), content: Text('Designer onboarded successfully!')));
      } else {
        messenger.showSnackBar(const SnackBar(backgroundColor: Color(0xFFDC2626), content: Text('Failed to onboard designer')));
      }
    }
  }
}
