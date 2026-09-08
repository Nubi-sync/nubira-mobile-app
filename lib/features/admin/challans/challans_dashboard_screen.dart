import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_providers.dart';
import 'challan_models.dart';
import 'challan_detail_screen.dart';
import 'widgets/challan_summary_card.dart';
import 'widgets/create_job_work_challan_sheet.dart';

class ChallansDashboardScreen extends ConsumerStatefulWidget {
  const ChallansDashboardScreen({super.key});

  @override
  ConsumerState<ChallansDashboardScreen> createState() => _ChallansDashboardScreenState();
}

class _ChallansDashboardScreenState extends ConsumerState<ChallansDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _activeTab = 'PENDING'; // 'PENDING' | 'ALLOTTED'
  String _selectedBrand = 'ALL';

  final List<String> _brandOptions = [
    'ALL',
    'OLLYPOP',
    'POKEMON',
    'SUPERMAN',
    'DISNEY',
    'ZIGZA',
    'NUBIRA',
  ];

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

  Future<void> _handleRecallChallan(ChallanGroupedOrder challan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recall Challan?'),
        content: Text('This will recall Challan #${challan.challanNo} back to Pending Allotment and reset all floor assignments.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF854F0B), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Recall to Pending'),
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
            SnackBar(content: Text('Challan #${challan.challanNo} recalled to Pending.')),
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
        title: const Text('Delete Challan?'),
        content: Text('Are you sure you want to permanently delete Challan #${challan.challanNo}? This will also delete related floor allotments.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
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
            SnackBar(content: Text('Challan #${challan.challanNo} deleted.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete challan.')),
          );
        }
      }
    }
  }

  void _exportCsvDialog(List<ChallanGroupedOrder> allChallans) {
    showDialog(
      context: context,
      builder: (ctx) {
        final totalPcs = allChallans.fold<int>(0, (sum, c) => sum + c.totalPcs);
        final totalSets = allChallans.fold<int>(0, (sum, c) => sum + c.totalSets);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEAF6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.table_chart_outlined, color: Color(0xFF332B6B), size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Export Job Sheets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate standard production CSV for ${allChallans.length} challans ($totalSets sets / $totalPcs pcs).',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B6A65)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDAD9D3)),
                ),
                child: Column(
                  children: [
                    _buildCsvPreviewRow('Challans Count', '${allChallans.length}'),
                    _buildCsvPreviewRow('Total Garment Pcs', '${totalPcs.toLocaleString()} pcs'),
                    _buildCsvPreviewRow('Total Bundle Sets', '${totalSets.toLocaleString()} sets'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(color: Color(0xFF6B6A65))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF332B6B),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Production job sheets exported successfully!'),
                    backgroundColor: Color(0xFF047857),
                  ),
                );
              },
              child: const Text('Export Data'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCsvPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B6A65))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challansAsync = ref.watch(challanGroupedOrdersProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1C1C1A)),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            const Text(
              'Zigza.',
              style: TextStyle(
                color: Color(0xFF332B6B),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEDEAF6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ERP MES',
                style: TextStyle(
                  color: Color(0xFF332B6B),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B6A65)),
            onPressed: () {
              ref.invalidate(challanGroupedOrdersProvider);
              ref.invalidate(adminDashboardProvider);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFDAD9D3), height: 0.8),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF332B6B),
        onRefresh: () async {
          ref.invalidate(challanGroupedOrdersProvider);
          ref.invalidate(adminDashboardProvider);
        },
        child: challansAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF332B6B))),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Color(0xFFE11D48)),
                const SizedBox(height: 10),
                Text('Error loading challans: $err', style: const TextStyle(color: Color(0xFF6B6A65))),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => ref.invalidate(challanGroupedOrdersProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (rawList) {
            // Compute KPI Metrics across all raw challans
            final totalChallansCount = rawList.length;
            final distinctMasterStyles = rawList.map((c) => c.articles.map((a) => a.artNo)).expand((i) => i).toSet().length;
            final totalSetsAll = rawList.fold<int>(0, (sum, c) => sum + c.totalSets);
            final totalPcsAll = rawList.fold<int>(0, (sum, c) => sum + c.totalPcs);

            final inProductionPcs = rawList
                .where((c) => c.status == 'IN_PROGRESS' || c.status == 'PARTIALLY_ALLOTTED')
                .fold<int>(0, (sum, c) => sum + c.totalPcs);

            final readyOutPcs = rawList
                .where((c) => c.status == 'QC_PASSED' || c.status == 'DISPATCHED')
                .fold<int>(0, (sum, c) => sum + c.totalPcs);

            final pendingCount = rawList.where((c) => c.status == 'PENDING' || c.status == 'PARTIALLY_ALLOTTED').length;
            final allottedCount = rawList.where((c) => c.status != 'PENDING' && c.status != 'PARTIALLY_ALLOTTED').length;

            // Filter for current view: Partially allotted challans remain in Pending tab until 100% allotted
            var displayList = rawList;
            if (_activeTab == 'PENDING') {
              displayList = displayList.where((c) => c.status == 'PENDING' || c.status == 'PARTIALLY_ALLOTTED').toList();
            } else {
              displayList = displayList.where((c) => c.status != 'PENDING' && c.status != 'PARTIALLY_ALLOTTED').toList();
            }

            if (_selectedBrand != 'ALL') {
              displayList = displayList.where((c) => c.brand.toUpperCase() == _selectedBrand.toUpperCase()).toList();
            }

            if (_searchController.text.trim().isNotEmpty) {
              final q = _searchController.text.trim().toLowerCase();
              displayList = displayList.where((c) {
                return c.challanNo.toLowerCase().contains(q) ||
                    c.brand.toLowerCase().contains(q) ||
                    (c.fabricType?.toLowerCase().contains(q) ?? false) ||
                    c.articles.any((a) => a.artNo.toLowerCase().contains(q) || a.colorPattern.toLowerCase().contains(q));
              }).toList();
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title & Subtitle
                        const Text(
                          'Production and job work challans',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1C1C1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Multi-article challan batches with automated line distribution',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B6A65)),
                        ),
                        const SizedBox(height: 14),

                        // Action Buttons Row
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF332B6B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('+ New Challan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: _showCreateChallanModal,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFDAD9D3)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.download_outlined, size: 16, color: Color(0xFF1C1C1A)),
                              label: const Text('Export CSV', style: TextStyle(color: Color(0xFF1C1C1A), fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => _exportCsvDialog(rawList),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 2x3 STATS KPI GRID
                        _buildKpiGrid(
                          totalChallans: totalChallansCount,
                          articleStyles: distinctMasterStyles,
                          totalSets: totalSetsAll,
                          totalPcs: totalPcsAll,
                          inProductionPcs: inProductionPcs,
                          readyOutPcs: readyOutPcs,
                        ),
                        const SizedBox(height: 16),

                        // 2-TAB SEGMENTED FILTER
                        _buildSegmentedTabs(pendingCount: pendingCount, allottedCount: allottedCount),
                        const SizedBox(height: 14),

                        // SEARCH BAR & BRAND FILTER
                        _buildSearchAndFilters(),
                      ],
                    ),
                  ),
                ),

                // CHALLAN LIST OR EMPTY STATE
                if (displayList.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAF8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF9B9A94)),
                          const SizedBox(height: 10),
                          Text(
                            _activeTab == 'PENDING'
                                ? 'No pending challans found.'
                                : 'No active production challans found.',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B6A65)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap "+ New Challan" to create a multi-article batch.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF9B9A94)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final challan = displayList[index];
                        return ChallanSummaryCard(
                          challan: challan,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChallanDetailScreen(challan: challan),
                              ),
                            );
                          },
                          onRecall: () => _handleRecallChallan(challan),
                          onDelete: () => _handleDeleteChallan(challan),
                        );
                      },
                      childCount: displayList.length,
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

  Widget _buildKpiGrid({
    required int totalChallans,
    required int articleStyles,
    required int totalSets,
    required int totalPcs,
    required int inProductionPcs,
    required int readyOutPcs,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildKpiCard('Challans', '$totalChallans', 'Buyer job sheets')),
            const SizedBox(width: 8),
            Expanded(child: _buildKpiCard('Article styles', '$articleStyles', 'Master articles')),
            const SizedBox(width: 8),
            Expanded(child: _buildKpiCard('Total sets', totalSets.toLocaleString(), 'Bundle units')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildKpiCard('Total pieces', totalPcs.toLocaleString(), 'Garment pieces')),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                'In production',
                inProductionPcs.toLocaleString(),
                'Active sewing pcs',
                valueColor: const Color(0xFF854F0B),
                bgColor: const Color(0xFFFAEEDA),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                'Ready / out',
                readyOutPcs.toLocaleString(),
                'QC passed / gate out',
                valueColor: const Color(0xFF047857),
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, String subtext, {Color? valueColor, Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor ?? const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: bgColor != null ? (valueColor?.withValues(alpha: 0.3) ?? const Color(0xFFDAD9D3)) : const Color(0xFFDAD9D3),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor ?? const Color(0xFF1C1C1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtext,
            style: const TextStyle(fontSize: 9, color: Color(0xFF6B6A65)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs({required int pendingCount, required int allottedCount}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 'PENDING'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == 'PENDING' ? const Color(0xFF332B6B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pending allotment ($pendingCount)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _activeTab == 'PENDING' ? Colors.white : const Color(0xFF6B6A65),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 'ALLOTTED'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == 'ALLOTTED' ? const Color(0xFF332B6B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Allotted, in production ($allottedCount)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _activeTab == 'ALLOTTED' ? Colors.white : const Color(0xFF6B6A65),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Search bar
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1A)),
            decoration: InputDecoration(
              hintText: 'Search by challan #, brand, art #, fabric...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9B9A94)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF6B6A65)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF6B6A65)),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 10),

        // Brand Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _brandOptions.map((brand) {
              final isSelected = _selectedBrand.toUpperCase() == brand.toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(
                    brand == 'ALL' ? 'All Brands' : brand,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF1C1C1A),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF332B6B),
                  backgroundColor: const Color(0xFFFAFAF8),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF332B6B) : const Color(0xFFDAD9D3),
                    width: 0.8,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  onSelected: (val) {
                    setState(() {
                      _selectedBrand = brand;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
