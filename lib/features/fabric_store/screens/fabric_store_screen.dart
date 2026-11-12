import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../../core/widgets/zigza_section_header.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/fabric_store_models.dart';
import '../providers/fabric_store_provider.dart';
import '../widgets/fabric_store_modals.dart';

class FabricStoreScreen extends ConsumerStatefulWidget {
  const FabricStoreScreen({super.key});

  @override
  ConsumerState<FabricStoreScreen> createState() => _FabricStoreScreenState();
}

class _FabricStoreScreenState extends ConsumerState<FabricStoreScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _numFmt = NumberFormat('#,##,###', 'en_IN');

  static const int _itemsPerPage = 5;

  int _fabricPage = 1;
  int _trimPage = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _fmtCount(num value) {
    if (value == value.roundToDouble()) return _numFmt.format(value.round());
    return value.toStringAsFixed(1);
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: zigzaBodyStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? AppTheme.badgeRoseText : AppTheme.headingObsidian,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildKpiTile({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    Color valueColor = AppTheme.headingObsidian,
    Color iconBg = AppTheme.mintSurface,
    Color iconBorder = AppTheme.badgeMintBorder,
    Color iconColor = const Color(0xFF0F766E),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zigzaBodyStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.bodyInk,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: iconBorder),
                ),
                child: Icon(icon, size: 13.5, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zigzaHeadingStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: zigzaBodyStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.faintInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF14C8B4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF14C8B4) : AppTheme.borderLight,
          ),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: zigzaHeadingStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? AppTheme.headingObsidian : AppTheme.bodyInk,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySectionState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.mintSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.badgeMintBorder),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E), size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: zigzaHeadingStyle(fontSize: 14, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: zigzaBodyStyle(fontSize: 12, color: AppTheme.bodyInk),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFabricCard(FabricAllocationItem fabric, FabricStoreState state) {
    final isAssigned = (fabric.bookedForArticle ?? '').isNotEmpty && fabric.bookedMeters > 0;
    final pct = fabric.allocationPercentage;
    final Color badgeBg = pct >= 100
        ? const Color(0xFFECFDF5)
        : pct > 0
            ? const Color(0xFFEFF6FF)
            : AppTheme.cardSurface;
    final Color badgeBorder = pct >= 100
        ? const Color(0xFFA7F3D0)
        : pct > 0
            ? const Color(0xFFBFDBFE)
            : AppTheme.borderLight;
    final Color badgeFg = pct >= 100
        ? const Color(0xFF065F46)
        : pct > 0
            ? AppTheme.brandRoyalBlue
            : AppTheme.bodyInk;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.badgeMintBorder),
                ),
                child: Center(
                  child: Text(
                    getStoreAvatarInitials(fabric.fabricType),
                    style: zigzaHeadingStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.headingObsidian,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fabric.fabricType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zigzaHeadingStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.headingObsidian,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${fabric.color} • ${_fmtCount(fabric.totalMeters)} m • ${fabric.totalRolls} rolls',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  '$pct%',
                  style: zigzaHeadingStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Nested white metrics box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ASSIGNED ARTICLE',
                        style: zigzaBodyStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.faintInk,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAssigned ? fabric.bookedForArticle! : 'Free Stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: zigzaHeadingStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isAssigned ? AppTheme.headingObsidian : AppTheme.bodyInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'BOOKED / FREE',
                        style: zigzaBodyStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.faintInk,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtCount(fabric.bookedMeters)}m / ${_fmtCount(fabric.availableMeters)}m',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: zigzaBodyStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.headingObsidian,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: () => showFabricStoreDetailSheet(
                      context,
                      fabric: fabric,
                      companyName: state.companyName,
                      onAssignPressed: () => showAssignFabricSheet(
                        context,
                        ref,
                        fabric: fabric,
                        activeArticles: state.activeArticles,
                        onMessage: _showToast,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.headingObsidian,
                      backgroundColor: AppTheme.cardSurface,
                      side: const BorderSide(color: AppTheme.borderLight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(
                      'View More',
                      style: zigzaHeadingStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => showAssignFabricSheet(
                      context,
                      ref,
                      fabric: fabric,
                      activeArticles: state.activeArticles,
                      onMessage: _showToast,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandRoyalBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Assign',
                          style: zigzaHeadingStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 14),
                      ],
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

  Widget _buildTrimCard(TrimAllocationItem trim, FabricStoreState state) {
    final isAssigned = (trim.assignedArticle ?? '').isNotEmpty && trim.assignedQuantity > 0;
    final pct = trim.allocationPercentage;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.badgeMintBorder),
                ),
                child: Center(
                  child: Text(
                    getStoreAvatarInitials(trim.itemName),
                    style: zigzaHeadingStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.headingObsidian,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trim.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zigzaHeadingStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.headingObsidian,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trim.category} • ${_numFmt.format(trim.totalInStore)} ${trim.unit}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: pct >= 100 ? const Color(0xFFECFDF5) : AppTheme.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: pct >= 100 ? const Color(0xFFA7F3D0) : AppTheme.borderLight,
                  ),
                ),
                child: Text(
                  '$pct%',
                  style: zigzaHeadingStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: pct >= 100 ? const Color(0xFF065F46) : AppTheme.bodyInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ASSIGNED ARTICLE',
                        style: zigzaBodyStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.faintInk,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAssigned ? trim.assignedArticle! : 'Free Stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: zigzaHeadingStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isAssigned ? AppTheme.headingObsidian : AppTheme.bodyInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'ASSIGNED / FREE',
                        style: zigzaBodyStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.faintInk,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_numFmt.format(trim.assignedQuantity)} / ${_numFmt.format(trim.freeQuantity)} ${trim.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: zigzaBodyStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.headingObsidian,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: OutlinedButton(
              onPressed: () => showFabricStoreDetailSheet(
                context,
                trim: trim,
                companyName: state.companyName,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.headingObsidian,
                backgroundColor: AppTheme.cardSurface,
                side: const BorderSide(color: AppTheme.borderLight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'View More',
                style: zigzaHeadingStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPager({
    required int currentPage,
    required int totalPages,
    required int totalCount,
    required String noun,
    required ValueChanged<int> onPageChanged,
  }) {
    final start = (currentPage - 1) * _itemsPerPage + 1;
    final end = math.min(currentPage * _itemsPerPage, totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '$start–$end of $totalCount $noun',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk, fontWeight: FontWeight.w600),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '$currentPage / $totalPages',
                  style: zigzaHeadingStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fabricStoreProvider);
    final filteredFabrics = state.filteredFabrics;
    final filteredTrims = state.filteredTrims;

    final totalFabricPages = math.max(1, (filteredFabrics.length / _itemsPerPage).ceil());
    final safeFabricPage = _fabricPage.clamp(1, totalFabricPages);
    final fabricStart = (safeFabricPage - 1) * _itemsPerPage;
    final paginatedFabrics = filteredFabrics.sublist(
      fabricStart,
      math.min(fabricStart + _itemsPerPage, filteredFabrics.length),
    );

    final totalTrimPages = math.max(1, (filteredTrims.length / _itemsPerPage).ceil());
    final safeTrimPage = _trimPage.clamp(1, totalTrimPages);
    final trimStart = (safeTrimPage - 1) * _itemsPerPage;
    final paginatedTrims = filteredTrims.sublist(
      trimStart,
      math.min(trimStart + _itemsPerPage, filteredTrims.length),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bgCanvas,
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: const WorkspaceHubDrawer(activeRoute: '/fabric-store'),
      body: state.isLoading && state.fabrics.isEmpty && state.trims.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.headingObsidian))
          : RefreshIndicator(
              color: AppTheme.brandRoyalBlue,
              backgroundColor: Colors.white,
              onRefresh: () => ref.read(fabricStoreProvider.notifier).fetchHubData(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                children: [
                  // 1. Compact Header + Search Card
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.mintSurface,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: AppTheme.badgeMintBorder),
                              ),
                              child: const Icon(Icons.layers_outlined, color: Color(0xFF0F766E), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      style: zigzaHeadingStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                      children: const [
                                        TextSpan(text: 'Fabric & '),
                                        TextSpan(
                                          text: 'Store',
                                          style: TextStyle(color: AppTheme.brandRoyalBlue),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (state.companyName.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.mintSurface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppTheme.badgeMintBorder),
                                      ),
                                      child: Text(
                                        state.companyName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: zigzaHeadingStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F766E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _fabricPage = 1;
                              _trimPage = 1;
                            });
                            ref.read(fabricStoreProvider.notifier).setSearchQuery(val);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search cloth, color, trim, or article...',
                            hintStyle: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.faintInk),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.faintInk),
                            suffixIcon: state.searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16, color: AppTheme.bodyInk),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _fabricPage = 1;
                                        _trimPage = 1;
                                      });
                                      ref.read(fabricStoreProvider.notifier).setSearchQuery('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppTheme.bgCanvas,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.borderLight),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.borderLight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.headingObsidian, width: 1.3),
                            ),
                          ),
                          style: zigzaBodyStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.headingObsidian,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Store Overview KPI Card
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ZigzaSectionHeader(
                          icon: Icons.analytics_outlined,
                          title: 'Store',
                          accent: 'Overview',
                          badge: '${state.fabrics.length + state.trims.length} Items',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiTile(
                                label: 'CLOTH IN STORE',
                                value: _fmtCount(state.totalClothMeters),
                                unit: 'm',
                                icon: Icons.content_cut_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildKpiTile(
                                label: 'CLOTH ASSIGNED',
                                value: _fmtCount(state.totalClothAssignedMeters),
                                unit: 'm',
                                icon: Icons.layers_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiTile(
                                label: 'TRIMS IN STORE',
                                value: _numFmt.format(state.totalTrimUnitsInStore),
                                unit: 'pcs',
                                icon: Icons.inventory_2_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildKpiTile(
                                label: 'TRIMS ASSIGNED',
                                value: _numFmt.format(state.totalTrimAssignedUnits),
                                unit: 'pcs',
                                icon: Icons.check_circle_outline_rounded,
                                valueColor: const Color(0xFF065F46),
                                iconBg: const Color(0xFFECFDF5),
                                iconBorder: const Color(0xFFA7F3D0),
                                iconColor: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Cloth Left in Store Card
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ZigzaSectionHeader(
                          icon: Icons.content_cut_rounded,
                          title: 'Cloth Left in',
                          accent: 'Store',
                          badge: '${filteredFabrics.length}',
                          action: InkWell(
                            onTap: () => showAddClothSheet(
                              context,
                              ref,
                              activeArticles: state.activeArticles,
                              onMessage: _showToast,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                              decoration: BoxDecoration(
                                color: AppTheme.brandRoyalBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Add Cloth',
                                    style: zigzaHeadingStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                label: 'All Cloth',
                                isActive: state.fabricFilter == 'ALL',
                                onTap: () {
                                  setState(() => _fabricPage = 1);
                                  ref.read(fabricStoreProvider.notifier).setFabricFilter('ALL');
                                },
                              ),
                              const SizedBox(width: 7),
                              _buildFilterChip(
                                label: 'Assigned',
                                isActive: state.fabricFilter == 'ASSIGNED',
                                onTap: () {
                                  setState(() => _fabricPage = 1);
                                  ref.read(fabricStoreProvider.notifier).setFabricFilter('ASSIGNED');
                                },
                              ),
                              const SizedBox(width: 7),
                              _buildFilterChip(
                                label: 'Free Stock',
                                isActive: state.fabricFilter == 'UNASSIGNED',
                                onTap: () {
                                  setState(() => _fabricPage = 1);
                                  ref.read(fabricStoreProvider.notifier).setFabricFilter('UNASSIGNED');
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (paginatedFabrics.isEmpty)
                          _buildEmptySectionState(
                            icon: Icons.content_cut_rounded,
                            title: 'No cloth records in store',
                            subtitle: state.searchQuery.isNotEmpty
                                ? 'No cloth matching "${state.searchQuery}".'
                                : 'Tap "+ Add Cloth" to register fabric rolls.',
                          )
                        else ...[
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: paginatedFabrics.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, idx) => _buildFabricCard(paginatedFabrics[idx], state),
                          ),
                          if (totalFabricPages > 1) ...[
                            const SizedBox(height: 12),
                            _buildPager(
                              currentPage: safeFabricPage,
                              totalPages: totalFabricPages,
                              totalCount: filteredFabrics.length,
                              noun: 'cloth types',
                              onPageChanged: (p) => setState(() => _fabricPage = p),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Required Trims & Accessories Card
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ZigzaSectionHeader(
                          icon: Icons.inventory_2_outlined,
                          title: 'Required',
                          accent: 'Trims',
                          badge: '${filteredTrims.length}',
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: state.trimCategories.map((cat) {
                              final label = cat == 'ALL' ? 'All Trims' : cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: _buildFilterChip(
                                  label: label,
                                  isActive: state.trimCategoryFilter == cat,
                                  onTap: () {
                                    setState(() => _trimPage = 1);
                                    ref.read(fabricStoreProvider.notifier).setTrimCategoryFilter(cat);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (paginatedTrims.isEmpty)
                          _buildEmptySectionState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No trims recorded',
                            subtitle: state.searchQuery.isNotEmpty
                                ? 'No trims matching "${state.searchQuery}".'
                                : 'No required trims recorded for this factory.',
                          )
                        else ...[
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: paginatedTrims.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, idx) => _buildTrimCard(paginatedTrims[idx], state),
                          ),
                          if (totalTrimPages > 1) ...[
                            const SizedBox(height: 12),
                            _buildPager(
                              currentPage: safeTrimPage,
                              totalPages: totalTrimPages,
                              totalCount: filteredTrims.length,
                              noun: 'trim items',
                              onPageChanged: (p) => setState(() => _trimPage = p),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }
}
