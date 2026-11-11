import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../../core/widgets/zigza_section_header.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/buyers_vendors_models.dart';
import '../providers/buyers_vendors_provider.dart';
import '../widgets/buyers_vendors_modals.dart';

class BuyersVendorsScreen extends ConsumerStatefulWidget {
  const BuyersVendorsScreen({super.key});

  @override
  ConsumerState<BuyersVendorsScreen> createState() => _BuyersVendorsScreenState();
}

class _BuyersVendorsScreenState extends ConsumerState<BuyersVendorsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _numFmt = NumberFormat('#,##,###', 'en_IN');

  static const int _buyersPerPage = 5;
  static const int _articlesPerPage = 5;

  final Set<String> _expandedBuyers = <String>{};
  final Set<String> _expandedModules = <String>{};
  final Map<String, int> _buyerArticlePages = <String, int>{};

  int _buyerCurrentPage = 1;
  String? _deletingModuleRoute;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _dialPhone(String rawPhone) async {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final clean = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    final uri = Uri(scheme: 'tel', path: '+91$clean');
    try {
      await launchUrl(uri);
    } catch (_) {
      _showToast('Could not open phone dialer', isError: true);
    }
  }

  void _toggleBuyerExpand(String buyerId) {
    setState(() {
      if (_expandedBuyers.contains(buyerId)) {
        _expandedBuyers.remove(buyerId);
      } else {
        _expandedBuyers.add(buyerId);
      }
    });
  }

  void _toggleModuleExpand(String moduleRoute) {
    setState(() {
      if (_expandedModules.contains(moduleRoute)) {
        _expandedModules.remove(moduleRoute);
      } else {
        _expandedModules.add(moduleRoute);
      }
    });
  }

  Future<void> _confirmAndDeleteCustomModule(ModuleVendorItem mod) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Custom Module',
          style: zigzaHeadingStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to delete "${mod.moduleName}"?',
          style: zigzaBodyStyle(fontSize: 13, color: AppTheme.bodyInk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text('Cancel', style: zigzaBodyStyle(color: AppTheme.bodyInk)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.badgeRoseText,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deletingModuleRoute = mod.moduleRoute);
    final res = await ref.read(buyersVendorsProvider.notifier).deleteCustomModule(mod.moduleRoute);
    if (!mounted) return;
    setState(() => _deletingModuleRoute = null);

    if (res.success) {
      _expandedModules.remove(mod.moduleRoute);
      _showToast('Custom module "${mod.moduleName}" removed');
    } else {
      _showToast(res.error ?? 'Failed to delete custom module', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(buyersVendorsProvider);
    final filteredBuyers = state.filteredBuyers;
    final filteredModules = state.filteredModules;

    final totalBuyerPages = math.max(1, (filteredBuyers.length / _buyersPerPage).ceil());
    final safeBuyerPage = _buyerCurrentPage.clamp(1, totalBuyerPages);
    final startIdx = (safeBuyerPage - 1) * _buyersPerPage;
    final endIdx = math.min(filteredBuyers.length, startIdx + _buyersPerPage);
    final paginatedBuyers =
        filteredBuyers.isEmpty ? <BuyerItem>[] : filteredBuyers.sublist(startIdx, endIdx);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bgCanvas,
      drawer: const WorkspaceHubDrawer(activeRoute: '/buyers-vendors'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        color: AppTheme.brandRoyalBlue,
        backgroundColor: Colors.white,
        onRefresh: () => ref.read(buyersVendorsProvider.notifier).fetchHubData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. HERO + GLOBAL SEARCH CARD
              _buildHeroCard(state),
              const SizedBox(height: 14),

              // 2. KPI SUMMARY GRID (2x2)
              _buildKpiGrid(state),
              const SizedBox(height: 14),

              if (state.isLoading && state.buyers.isEmpty && state.moduleVendors.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.headingObsidian),
                  ),
                )
              else if (state.error != null && state.buyers.isEmpty && state.moduleVendors.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 36, color: AppTheme.badgeRoseText),
                      const SizedBox(height: 10),
                      Text(
                        state.error!,
                        textAlign: TextAlign.center,
                        style: zigzaBodyStyle(fontSize: 13, color: AppTheme.bodyInk),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandRoyalBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        onPressed: () => ref.read(buyersVendorsProvider.notifier).fetchHubData(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else ...[
                // 3. SECTION 1: BUYERS & CONTRACT HISTORY (Header Inside Card)
                _buildBuyersSectionCard(
                  state: state,
                  filteredBuyers: filteredBuyers,
                  paginatedBuyers: paginatedBuyers,
                  safeBuyerPage: safeBuyerPage,
                  totalBuyerPages: totalBuyerPages,
                  startIdx: startIdx,
                  endIdx: endIdx,
                ),
                const SizedBox(height: 14),

                // 4. SECTION 2: SUBSCRIBED MODULES — VENDOR ASSIGNMENT (Header Inside Card)
                _buildModulesSectionCard(
                  state: state,
                  filteredModules: filteredModules,
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuyersVendorsState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
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
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppTheme.badgeMintBorder),
                ),
                child: const Icon(
                  Icons.store_mall_directory_outlined,
                  color: Color(0xFF0F766E),
                  size: 20,
                ),
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
                          TextSpan(text: 'Buyers & '),
                          TextSpan(
                            text: 'Vendors Hub',
                            style: TextStyle(color: AppTheme.brandRoyalBlue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.mintSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.badgeMintBorder),
                      ),
                      child: Text(
                        state.companyName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: zigzaHeadingStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => ref.read(buyersVendorsProvider.notifier).fetchHubData(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: state.isSyncing
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandRoyalBlue),
                        )
                      : const Icon(Icons.refresh_rounded, color: AppTheme.headingObsidian, size: 19),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Global Search Box
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() => _buyerCurrentPage = 1);
              ref.read(buyersVendorsProvider.notifier).setSearchQuery(val);
            },
            style: zigzaBodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.headingObsidian,
            ),
            decoration: InputDecoration(
              hintText: 'Search buyer, phone, article code, or vendor...',
              hintStyle: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.faintInk),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.faintInk),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.bodyInk),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _buyerCurrentPage = 1);
                        ref.read(buyersVendorsProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.bgCanvas,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(BuyersVendorsState state) {
    final modTotal = state.moduleVendors.isNotEmpty ? state.moduleVendors.length : 12;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.68,
      children: [
        _buildKpiTile(
          label: 'TOTAL BUYERS',
          value: _numFmt.format(state.totalBuyers),
          icon: Icons.business_rounded,
        ),
        _buildKpiTile(
          label: 'ARTICLES CONTRACTED',
          value: _numFmt.format(state.totalArticles),
          icon: Icons.content_cut_rounded,
        ),
        _buildKpiTile(
          label: 'PIECES DELIVERED',
          value: '${_numFmt.format(state.totalDeliveredPieces)} / ${_numFmt.format(state.totalAssignedPieces)}',
          icon: Icons.inventory_2_outlined,
          valueColor: state.totalDeliveredPieces > 0
              ? AppTheme.badgeEmeraldText
              : AppTheme.headingObsidian,
        ),
        _buildKpiTile(
          label: 'VENDOR MODULES',
          value: '${state.assignedModulesCount} / $modTotal',
          icon: Icons.layers_outlined,
        ),
      ],
    );
  }

  Widget _buildKpiTile({
    required String label,
    required String value,
    required IconData icon,
    Color valueColor = AppTheme.headingObsidian,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zigzaBodyStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.faintInk,
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: zigzaHeadingStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: valueColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.mintSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.badgeMintBorder),
            ),
            child: Icon(icon, size: 17, color: AppTheme.headingObsidian),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionActionBar({
    required String primaryLabel,
    required VoidCallback onPrimaryTap,
    required VoidCallback onExpandAll,
    required VoidCallback onCollapseAll,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandRoyalBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            onPressed: onPrimaryTap,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: Text(
              primaryLabel,
              style: zigzaBodyStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.headingObsidian,
              side: const BorderSide(color: AppTheme.borderLight),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            onPressed: onExpandAll,
            child: Text(
              'Expand All',
              style: zigzaBodyStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.headingObsidian,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.headingObsidian,
              side: const BorderSide(color: AppTheme.borderLight),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            onPressed: onCollapseAll,
            child: Text(
              'Collapse All',
              style: zigzaBodyStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.headingObsidian,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyersSectionCard({
    required BuyersVendorsState state,
    required List<BuyerItem> filteredBuyers,
    required List<BuyerItem> paginatedBuyers,
    required int safeBuyerPage,
    required int totalBuyerPages,
    required int startIdx,
    required int endIdx,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZigzaSectionHeader(
            icon: Icons.people_outline_rounded,
            title: 'Buyers &',
            accent: 'Contracts',
            badge: '${filteredBuyers.length} Buyers',
          ),
          const SizedBox(height: 12),

          _buildSectionActionBar(
            primaryLabel: 'Add Buyer',
            onPrimaryTap: () async {
              final ok = await showAddEditBuyerSheet(context);
              if (ok == true) _showToast('Buyer profile saved');
            },
            onExpandAll: () => setState(() {
              _expandedBuyers.addAll(state.buyers.map((b) => b.id));
            }),
            onCollapseAll: () => setState(() => _expandedBuyers.clear()),
          ),
          const SizedBox(height: 12),

          if (filteredBuyers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.bgCanvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                children: [
                  const Icon(Icons.business_outlined, size: 36, color: AppTheme.faintInk),
                  const SizedBox(height: 8),
                  Text(
                    state.searchQuery.isNotEmpty ? 'No Matching Buyers' : 'No Buyers Registered',
                    style: zigzaHeadingStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.searchQuery.isNotEmpty
                        ? 'No buyer, brand, or contract matched "${state.searchQuery}".'
                        : 'Add your first buyer or link contracts from Merchandising.',
                    textAlign: TextAlign.center,
                    style: zigzaBodyStyle(fontSize: 12, color: AppTheme.faintInk),
                  ),
                  if (state.searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandRoyalBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _buyerCurrentPage = 1);
                        ref.read(buyersVendorsProvider.notifier).setSearchQuery('');
                      },
                      child: const Text('Clear Search Filter'),
                    ),
                  ],
                ],
              ),
            )
          else
            ...paginatedBuyers.map(_buildBuyerCard),

          if (totalBuyerPages > 1) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgCanvas,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Showing ${startIdx + 1}–$endIdx of ${filteredBuyers.length} buyers',
                      style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk),
                    ),
                  ),
                  Row(
                    children: [
                      _buildPageIconBtn(
                        icon: Icons.chevron_left_rounded,
                        enabled: safeBuyerPage > 1,
                        onTap: () => setState(() => _buyerCurrentPage = math.max(1, safeBuyerPage - 1)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$safeBuyerPage / $totalBuyerPages',
                        style: zigzaHeadingStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      _buildPageIconBtn(
                        icon: Icons.chevron_right_rounded,
                        enabled: safeBuyerPage < totalBuyerPages,
                        onTap: () => setState(
                            () => _buyerCurrentPage = math.min(totalBuyerPages, safeBuyerPage + 1)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBuyerCard(BuyerItem buyer) {
    final isExpanded = _expandedBuyers.contains(buyer.id);
    final articles = buyer.articles;
    final artPage = _buyerArticlePages[buyer.id] ?? 1;
    final totalArtPages = math.max(1, (articles.length / _articlesPerPage).ceil());
    final safeArtPage = artPage.clamp(1, totalArtPages);
    final aStart = (safeArtPage - 1) * _articlesPerPage;
    final aEnd = math.min(articles.length, aStart + _articlesPerPage);
    final paginatedArticles =
        articles.isEmpty ? <BuyerArticleHistory>[] : articles.sublist(aStart, aEnd);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded ? AppTheme.brandRoyalBlue.withValues(alpha: 0.45) : AppTheme.borderLight,
          width: isExpanded ? 1.3 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleBuyerExpand(buyer.id),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.mintSurface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppTheme.badgeMintBorder),
                    ),
                    child: Center(
                      child: Text(
                        getBuyerAvatarInitials(buyer.brandName),
                        style: zigzaHeadingStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                buyer.brandName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: zigzaHeadingStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (buyer.gstin.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.badgeAmberBg,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: AppTheme.badgeAmberBorder),
                                ),
                                child: Text(
                                  'GST',
                                  style: zigzaHeadingStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.badgeAmberText,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${buyer.totalContractsCount} ${buyer.totalContractsCount == 1 ? 'Contract' : 'Contracts'} • ${buyer.totalArticlesCount} Articles • ${_numFmt.format(buyer.totalAssignedPieces)} pcs',
                          style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.faintInk),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: buyer.deliveryPercentage >= 100
                          ? AppTheme.badgeEmeraldBg
                          : AppTheme.subtleDivider,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: buyer.deliveryPercentage >= 100
                            ? AppTheme.badgeEmeraldBorder
                            : AppTheme.borderLight,
                      ),
                    ),
                    child: Text(
                      '${buyer.deliveryPercentage}%',
                      style: zigzaHeadingStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: buyer.deliveryPercentage >= 100
                            ? AppTheme.badgeEmeraldText
                            : AppTheme.headingObsidian,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.bodyInk,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded)
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.bgCanvas,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                border: Border(top: BorderSide(color: AppTheme.borderLight)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Contact summary strip when available
                  if (buyer.contactPerson.isNotEmpty ||
                      buyer.phone.isNotEmpty ||
                      buyer.city.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (buyer.contactPerson.isNotEmpty)
                          _buildInfoChip(Icons.person_outline_rounded, buyer.contactPerson),
                        if (buyer.phone.isNotEmpty)
                          InkWell(
                            onTap: () => _dialPhone(buyer.phone),
                            borderRadius: BorderRadius.circular(8),
                            child: _buildInfoChip(
                              Icons.phone_outlined,
                              '+91 ${buyer.phone}',
                              textColor: AppTheme.brandRoyalBlue,
                            ),
                          ),
                        if (buyer.city.isNotEmpty)
                          _buildInfoChip(Icons.location_on_outlined, buyer.city),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Roster header + Edit Buyer
                  Row(
                    children: [
                      const Icon(Icons.content_cut_rounded, size: 15, color: Color(0xFF0F766E)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Contracted Articles (${articles.length})',
                          style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          final ok = await showAddEditBuyerSheet(context, buyer: buyer);
                          if (ok == true) _showToast('Buyer profile updated');
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_outlined, size: 13, color: AppTheme.bodyInk),
                              const SizedBox(width: 4),
                              Text(
                                'Edit Buyer',
                                style: zigzaBodyStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.headingObsidian,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (articles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Text(
                        'No active contract lines recorded for this buyer yet.',
                        textAlign: TextAlign.center,
                        style: zigzaBodyStyle(fontSize: 12, color: AppTheme.faintInk),
                      ),
                    )
                  else ...[
                    ...paginatedArticles.map((art) => _buildArticleItemCard(art, buyer)),
                    if (totalArtPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Page $safeArtPage of $totalArtPages',
                              style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk),
                            ),
                            const SizedBox(width: 8),
                            _buildPageIconBtn(
                              icon: Icons.chevron_left_rounded,
                              enabled: safeArtPage > 1,
                              onTap: () => setState(() {
                                _buyerArticlePages[buyer.id] = math.max(1, safeArtPage - 1);
                              }),
                            ),
                            const SizedBox(width: 4),
                            _buildPageIconBtn(
                              icon: Icons.chevron_right_rounded,
                              enabled: safeArtPage < totalArtPages,
                              onTap: () => setState(() {
                                _buyerArticlePages[buyer.id] =
                                    math.min(totalArtPages, safeArtPage + 1);
                              }),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArticleItemCard(BuyerArticleHistory art, BuyerItem buyer) {
    final isDelivered = art.status == 'DELIVERED' || art.status == 'DISPATCHED';
    final isInProd = art.status == 'IN_PRODUCTION';
    final isQc = art.status == 'QC_PASSED';

    final statusBg = isDelivered
        ? AppTheme.badgeEmeraldBg
        : (isInProd
            ? AppTheme.badgeBlueBg
            : (isQc ? AppTheme.mintSurface : AppTheme.badgeAmberBg));
    final statusText = isDelivered
        ? AppTheme.badgeEmeraldText
        : (isInProd
            ? AppTheme.badgeBlueText
            : (isQc ? const Color(0xFF0F766E) : AppTheme.badgeAmberText));
    final statusBorder = isDelivered
        ? AppTheme.badgeEmeraldBorder
        : (isInProd
            ? AppTheme.badgeBlueBorder
            : (isQc ? AppTheme.badgeMintBorder : AppTheme.badgeAmberBorder));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.mintSurface,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppTheme.badgeMintBorder),
                      ),
                      child: Text(
                        art.artNo,
                        style: zigzaHeadingStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${art.sourceType == 'MERCHANDISING_PO' ? 'PO' : 'CH'} #${art.challanNo}',
                      style: zigzaHeadingStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.bodyInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.subtleDivider,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Text(
                        '${_numFmt.format(art.assignedQty)} pcs',
                        style: zigzaHeadingStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusBorder),
                      ),
                      child: Text(
                        '• ${art.status.replaceAll('_', ' ')}',
                        style: zigzaBodyStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => showArticleContractDetailSheet(
              context,
              article: art,
              buyerName: buyer.brandName,
              buyerContact: buyer.contactPerson,
              buyerPhone: buyer.phone,
            ),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.mintSurface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppTheme.badgeMintBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_outlined, size: 14, color: AppTheme.brandRoyalBlue),
                  const SizedBox(width: 4),
                  Text(
                    'View',
                    style: zigzaBodyStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.headingObsidian,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulesSectionCard({
    required BuyersVendorsState state,
    required List<ModuleVendorItem> filteredModules,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZigzaSectionHeader(
            icon: Icons.layers_outlined,
            title: 'Vendor',
            accent: 'Assignments',
            badge: '${filteredModules.length} Modules',
          ),
          const SizedBox(height: 12),

          _buildSectionActionBar(
            primaryLabel: 'Add Custom Module',
            onPrimaryTap: () async {
              final created = await showAddCustomModuleSheet(context);
              if (created != null && created.isNotEmpty) {
                _showToast('Custom module "$created" created');
              }
            },
            onExpandAll: () => setState(() {
              _expandedModules.addAll(state.moduleVendors.map((m) => m.moduleRoute));
            }),
            onCollapseAll: () => setState(() => _expandedModules.clear()),
          ),
          const SizedBox(height: 12),

          if (filteredModules.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.bgCanvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Text(
                'No subscribed modules match your search filter.',
                textAlign: TextAlign.center,
                style: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.faintInk),
              ),
            )
          else
            ...filteredModules.map(_buildModuleCard),
        ],
      ),
    );
  }

  Widget _buildModuleCard(ModuleVendorItem mod) {
    final isExpanded = _expandedModules.contains(mod.moduleRoute);
    final vendor = mod.assignedVendor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded ? AppTheme.brandRoyalBlue.withValues(alpha: 0.45) : AppTheme.borderLight,
          width: isExpanded ? 1.3 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleModuleExpand(mod.moduleRoute),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(13),
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
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: AppTheme.badgeMintBorder),
                        ),
                        child: Icon(
                          iconDataForModuleIconName(mod.iconName),
                          size: 19,
                          color: AppTheme.headingObsidian,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    mod.moduleName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: zigzaHeadingStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (mod.isCustom) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.badgeAmberBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.badgeAmberBorder),
                                    ),
                                    child: Text(
                                      'Custom',
                                      style: zigzaBodyStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.badgeAmberText,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mod.defaultDesignation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.faintInk),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: vendor != null ? AppTheme.badgeEmeraldBg : AppTheme.subtleDivider,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: vendor != null ? AppTheme.badgeEmeraldBorder : AppTheme.borderLight,
                          ),
                        ),
                        child: Text(
                          vendor != null ? 'Assigned' : 'Open',
                          style: zigzaBodyStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: vendor != null ? AppTheme.badgeEmeraldText : AppTheme.bodyInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.bodyInk,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  const Divider(height: 1, color: AppTheme.subtleDivider),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Vendor: ',
                                style: zigzaBodyStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.faintInk,
                                ),
                              ),
                              TextSpan(
                                text: vendor != null ? vendor.companyName : 'Not Assigned',
                                style: zigzaHeadingStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: vendor != null
                                      ? AppTheme.headingObsidian
                                      : AppTheme.bodyInk,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (vendor != null && vendor.phone.isNotEmpty)
                        Text(
                          '+91 ${vendor.phone}',
                          style: zigzaHeadingStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.bodyInk,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded)
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.bgCanvas,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                border: Border(top: BorderSide(color: AppTheme.borderLight)),
              ),
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${mod.moduleName} — Vendor Details',
                      style: zigzaHeadingStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mod.description,
                      style: zigzaBodyStyle(fontSize: 12, color: AppTheme.faintInk, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (mod.isCustom)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.badgeRoseText,
                              backgroundColor: AppTheme.badgeRoseBg,
                              side: const BorderSide(color: AppTheme.badgeRoseBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _deletingModuleRoute == mod.moduleRoute
                                ? null
                                : () => _confirmAndDeleteCustomModule(mod),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: Text(
                              'Delete Module',
                              style: zigzaBodyStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.badgeRoseText,
                              ),
                            ),
                          ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandRoyalBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final outcome = await showAssignVendorSheet(context, moduleItem: mod);
                            if (outcome == 'assigned') {
                              _showToast('Vendor assigned to ${mod.moduleName}');
                            } else if (outcome == 'removed') {
                              _showToast('Vendor removed from ${mod.moduleName}');
                            }
                          },
                          icon: Icon(vendor != null ? Icons.edit_outlined : Icons.add_rounded, size: 16),
                          label: Text(
                            vendor != null ? 'Edit Vendor' : 'Assign Vendor',
                            style: zigzaBodyStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (vendor != null) ...[
                      _buildVendorFieldTile('COMPANY NAME', vendor.companyName, 'Active Partner'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildVendorFieldTile(
                              'CONTACT PERSON',
                              vendor.contactPerson,
                              'Unit Representative',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _dialPhone(vendor.phone),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgCanvas,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderLight),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'MOBILE',
                                      style: zigzaBodyStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.faintInk,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '+91 ${vendor.phone}',
                                      style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Call Vendor →',
                                      style: zigzaBodyStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.brandRoyalBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (vendor.notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.badgeAmberBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.badgeAmberBorder),
                          ),
                          child: Text(
                            'Scope / Notes: ${vendor.notes}',
                            style: zigzaBodyStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.badgeAmberText,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ] else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCanvas,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 22, color: AppTheme.faintInk),
                            const SizedBox(height: 4),
                            Text(
                              'No External Vendor Assigned',
                              style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Handled in-house. Tap Assign Vendor anytime.',
                              textAlign: TextAlign.center,
                              style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.faintInk),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVendorFieldTile(String label, String value, String sublabel) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: zigzaBodyStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.faintInk),
          ),
          const SizedBox(height: 3),
          Text(
            value.isNotEmpty ? value : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: zigzaBodyStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.faintInk),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color textColor = AppTheme.headingObsidian}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.bodyInk),
          const SizedBox(width: 5),
          Text(
            label,
            style: zigzaBodyStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIconBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : AppTheme.subtleDivider,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppTheme.headingObsidian : AppTheme.faintInk,
        ),
      ),
    );
  }
}
