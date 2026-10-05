import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../providers/plant_operations_provider.dart';
import '../challans/challans_dashboard_screen.dart';
import '../widgets/plant_stage_drilldown_sheet.dart';
import 'admin_shell.dart';
import 'reports_screen.dart';
import '../../auth/providers/auth_provider.dart';

class PlantOperationsScreen extends ConsumerStatefulWidget {
  const PlantOperationsScreen({super.key});

  @override
  ConsumerState<PlantOperationsScreen> createState() => _PlantOperationsScreenState();
}

class _PlantOperationsScreenState extends ConsumerState<PlantOperationsScreen> {
  bool _isManualSyncing = false;
  String _trendMode = 'Monthly'; // 'Monthly' or 'Weekly'
  final String _selectedMonthPeriod = 'All-Time Period';

  void _triggerManualSync() async {
    setState(() => _isManualSyncing = true);
    ref.invalidate(plantOperationsProvider);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isManualSyncing = false);
    }
  }

  void _showArticlePicker(BuildContext context, PlantOperationsData data, PlantOperationsFilterState filterState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = data.articles.where((a) {
              if (query.trim().isEmpty) return true;
              final q = query.toLowerCase();
              return a.artNo.toLowerCase().contains(q) || (a.description ?? '').toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Article Style',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0B1220),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) {
                      setModalState(() => query = val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search styles & articles...',
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          dense: true,
                          title: Text(
                            'All Article Styles (${data.articles.length} styles)',
                            style: GoogleFonts.publicSans(
                              fontWeight: filterState.selectedArticleId == 'ALL' ? FontWeight.bold : FontWeight.normal,
                              color: filterState.selectedArticleId == 'ALL' ? const Color(0xFF1D4ED8) : const Color(0xFF0B1220),
                            ),
                          ),
                          trailing: filterState.selectedArticleId == 'ALL'
                              ? const Icon(Icons.check, color: Color(0xFF1D4ED8), size: 18)
                              : null,
                          onTap: () {
                            ref.read(plantOperationsFilterProvider.notifier).update(
                              (s) => s.copyWith(selectedArticleId: 'ALL'),
                            );
                            Navigator.pop(ctx);
                          },
                        ),
                        const Divider(height: 1),
                        ...filtered.map((art) {
                          final isSelected = filterState.selectedArticleId == art.id;
                          return ListTile(
                            dense: true,
                            title: Text(
                              art.artNo,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0B1220),
                              ),
                            ),
                            subtitle: art.description != null && art.description!.isNotEmpty
                                ? Text(
                                    cleanDesc(art.description),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                                  )
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check, color: Color(0xFF1D4ED8), size: 18)
                                : null,
                            onTap: () {
                              ref.read(plantOperationsFilterProvider.notifier).update(
                                (s) => s.copyWith(selectedArticleId: art.id),
                              );
                              Navigator.pop(ctx);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final plantDataAsync = ref.watch(plantOperationsProvider);
    final filterState = ref.watch(plantOperationsFilterProvider);
    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;
    final companyName = (tenant?.companyName != null && tenant!.companyName.trim().isNotEmpty)
        ? tenant.companyName.trim()
        : 'Nubira Creation';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        leadingWidth: 56,
        leading: Center(
          child: InkWell(
            onTap: () => adminScaffoldKey.currentState?.openDrawer(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.menu_rounded, color: Color(0xFF0B1220), size: 20),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/icon.png',
              height: 28,
              width: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/new_icon.png',
                height: 28,
                width: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/z_i_g_z_a.png',
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/zigza_new_logo.png',
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  'ZIGZA',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0B1220),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x26000000)),
              ),
              child: Text(
                'ERP MES',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B1220),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF1D4ED8),
        backgroundColor: Colors.white,
        onRefresh: () async {
          ref.invalidate(plantOperationsProvider);
        },
        child: plantDataAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF1D4ED8)),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Color(0xFFBE123C), size: 48),
                  const SizedBox(height: 14),
                  Text(
                    'Failed to sync floor operations',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => ref.invalidate(plantOperationsProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry Connection'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) => _buildDashboardContent(context, ref, data, filterState, companyName),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    PlantOperationsData data,
    PlantOperationsFilterState filterState,
    String companyName,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Title Header Card
          _buildHeaderCard(context, companyName),
          const SizedBox(height: 14),

          // 2. Filter Section
          _buildFiltersSection(context, ref, data, filterState),
          const SizedBox(height: 14),

          // 3. Six-Stage Stats Grid (2 columns x 3 rows)
          _buildSixStageGrid(context, data),
          const SizedBox(height: 16),

          // 4. Live Factory Conversion Flow (Vertical Stack)
          _buildConversionFlowSection(data),
          const SizedBox(height: 16),

          // 5. Production Trend Card
          _buildProductionTrendCard(data),
          const SizedBox(height: 16),

          // 6. Order Status Card
          _buildOrderStatusCard(data),
          const SizedBox(height: 16),

          // 7. Production by Category Card
          _buildCategoryCard(data),
          const SizedBox(height: 16),

          // 8. Top Running Styles Card
          _buildTopRunningStylesCard(data),
          const SizedBox(height: 16),

          // 9. Recent Activities Card
          _buildRecentActivitiesCard(context, data),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // 1. TITLE HEADER CARD (100% Web Parity)
  // ==========================================
  Widget _buildHeaderCard(BuildContext context, String companyName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
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
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Color(0xFF14C8B4),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Stitching & ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                              letterSpacing: -0.4,
                            ),
                          ),
                          TextSpan(
                            text: 'Sewing\nFloor',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1D4ED8),
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'FLOOR OPS LIVE',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            companyName,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
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
          const SizedBox(height: 10),
          Text(
            'Real-time 6-stage garment manufacturing floor throughput and inventory lifecycle',
            style: GoogleFonts.publicSans(
              fontSize: 12.5,
              color: const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('TV View mode activated for production display monitors.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tv_rounded, size: 16, color: Color(0xFF0B1220)),
                  label: Text(
                    'TV View',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(
                          'Sign Out',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        content: Text(
                          'Are you sure you want to sign out of the floor operations session?',
                          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBE123C),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              ref.read(authProvider.notifier).logout();
                            },
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF64748B)),
                  label: Text(
                    'Sign Out',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
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
  // 2. FILTERS SECTION (100% Web Parity)
  // ==========================================
  Widget _buildFiltersSection(
    BuildContext context,
    WidgetRef ref,
    PlantOperationsData data,
    PlantOperationsFilterState filterState,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BRAND: All Orders | Direct Floor Lots
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'BRAND:',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildBrandTab(
                        label: 'All Orders',
                        isSelected: filterState.selectedBrand == 'ALL',
                        onTap: () {
                          ref.read(plantOperationsFilterProvider.notifier).update(
                            (s) => s.copyWith(selectedBrand: 'ALL'),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildBrandTab(
                        label: 'Direct Floor Lots',
                        isSelected: filterState.selectedBrand == 'DIRECT',
                        onTap: () {
                          ref.read(plantOperationsFilterProvider.notifier).update(
                            (s) => s.copyWith(selectedBrand: 'DIRECT'),
                          );
                        },
                      ),
                      ...data.brandTabs.where((b) => b != 'ALL' && b != 'DIRECT').map((b) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _buildBrandTab(
                            label: b,
                            isSelected: filterState.selectedBrand.toUpperCase() == b.toUpperCase(),
                            onTap: () {
                              ref.read(plantOperationsFilterProvider.notifier).update(
                                (s) => s.copyWith(selectedBrand: b),
                              );
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Article Style Dropdown Box
          InkWell(
            onTap: () => _showArticlePicker(context, data, filterState),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filterState.selectedArticleId == 'ALL'
                          ? 'All Article Styles (${data.articles.length} styles)'
                          : (data.articles.where((a) => a.id == filterState.selectedArticleId).firstOrNull?.artNo ?? 'Selected Style'),
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0B1220),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // All-Time Period Dropdown
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedMonthPeriod,
                  style: GoogleFonts.publicSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0B1220),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Date Range Container
          Container(
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x26000000)),
            ),
            child: Row(
              children: [
                _buildDateChip(
                  label: 'Today',
                  isSelected: filterState.dateFilter == PlantDateFilter.today,
                  onTap: () => ref.read(plantOperationsFilterProvider.notifier).update((s) => s.copyWith(dateFilter: PlantDateFilter.today)),
                ),
                _buildDateChip(
                  label: 'This Week',
                  isSelected: filterState.dateFilter == PlantDateFilter.week,
                  onTap: () => ref.read(plantOperationsFilterProvider.notifier).update((s) => s.copyWith(dateFilter: PlantDateFilter.week)),
                ),
                _buildDateChip(
                  label: 'This Month',
                  isSelected: filterState.dateFilter == PlantDateFilter.month,
                  onTap: () => ref.read(plantOperationsFilterProvider.notifier).update((s) => s.copyWith(dateFilter: PlantDateFilter.month)),
                ),
                _buildDateChip(
                  label: 'All Time',
                  isSelected: filterState.dateFilter == PlantDateFilter.all,
                  onTap: () => ref.read(plantOperationsFilterProvider.notifier).update((s) => s.copyWith(dateFilter: PlantDateFilter.all)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Refresh circular button
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: _isManualSyncing ? null : _triggerManualSync,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                ),
                child: _isManualSyncing
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF14C8B4),
                          ),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF0B1220)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandTab({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0B1220) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0B1220) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF0B1220),
          ),
        ),
      ),
    );
  }

  Widget _buildDateChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? const Color(0xFF0B1220) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. SIX-STAGE STATS GRID (100% Web Parity)
  // ==========================================
  Widget _buildSixStageGrid(BuildContext context, PlantOperationsData data) {
    final m = data.metrics;
    final formatter = NumberFormat('#,###');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                context: context,
                stageBadge: 'STAGE 01',
                title: '1. TOTAL STOCKS',
                subtitle: 'Pending Allotment Ba...',
                value: formatter.format(m.unallottedStocks),
                badgeText: 'UNALLOTTED',
                extraRightText: '${formatter.format(m.totalStocks)} total',
                icon: Icons.warehouse_outlined,
                onTap: () {
                  PlantStageDrilldownSheet.show(context, PlantStageType.totalStocks);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                context: context,
                stageBadge: 'STAGE 02',
                title: '2. GOODS IN LINE',
                subtitle: 'Sewing Machines WIP',
                value: formatter.format(m.goodsInLine),
                badgeText: 'ON FLOOR',
                icon: Icons.show_chart_rounded,
                onTap: () {
                  PlantStageDrilldownSheet.show(context, PlantStageType.goodsInLine);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                context: context,
                stageBadge: 'STAGE 03',
                title: '3. MENDING & C...',
                subtitle: 'QC Inspection & Repai...',
                value: formatter.format(m.mendingChecking),
                badgeText: 'FINISHING TABLE',
                icon: Icons.warning_amber_rounded,
                onTap: () {
                  PlantStageDrilldownSheet.show(context, PlantStageType.mendingChecking);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                context: context,
                stageBadge: 'STAGE 04',
                title: '4. READY GOODS',
                subtitle: 'QC Passed & Packed',
                value: formatter.format(m.readyGoods),
                badgeText: 'IN GODOWN',
                icon: Icons.inventory_2_outlined,
                onTap: () {
                  PlantStageDrilldownSheet.show(context, PlantStageType.readyGoods);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                context: context,
                stageBadge: 'STAGE 05',
                title: '5. RTO & REJECTI...',
                subtitle: 'Return to Origin',
                value: formatter.format(m.rto),
                badgeText: 'DEFECT / REJECT',
                icon: Icons.replay_rounded,
                onTap: () {
                  PlantStageDrilldownSheet.show(context, PlantStageType.rto);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                context: context,
                stageBadge: 'STAGE 06',
                title: '6. READY FOR DE...',
                subtitle: 'Gate Pass & Dispatched',
                value: formatter.format(m.readyDelivery),
                badgeText: 'DISPATCHED PCS',
                icon: Icons.local_shipping_outlined,
                onTap: () {
                  PlantStageDrilldownSheet.show(context, PlantStageType.readyDelivery);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required String stageBadge,
    required String title,
    required String subtitle,
    required String value,
    required String badgeText,
    String? extraRightText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF0B1220)),
                ),
                Row(
                  children: [
                    Text(
                      stageBadge,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_outward_rounded, size: 12, color: Color(0xFF94A3B8)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B1220),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.publicSans(
                fontSize: 10.5,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0B1220),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x26000000)),
                    ),
                    child: Text(
                      badgeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                  ),
                ),
                if (extraRightText != null) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      extraRightText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8.5,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. LIVE FACTORY CONVERSION FLOW (Vertical Stack 100% Web Parity)
  // ==========================================
  Widget _buildConversionFlowSection(PlantOperationsData data) {
    final m = data.metrics;
    final formatter = NumberFormat('#,###');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.trending_up_rounded, size: 18, color: Color(0xFF14C8B4)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Factory Conversion Flow',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                    Text(
                      'Order to gate delivery progression',
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Total Target: ${formatter.format(m.totalOrderPipeline)} pcs',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0B1220),
            ),
          ),
          const SizedBox(height: 14),

          // 1. SEWING IN-LINE
          _buildFlowStepCard(
            stepNum: '1.',
            title: 'SEWING IN-LINE',
            pctText: '${m.inLinePct}%',
            pcsText: '${formatter.format(m.goodsInLine)} pcs',
            statusText: 'On Machines',
            accentColor: const Color(0xFF1D4ED8),
            badgeBg: const Color(0xFFEFF6FF),
            badgeColor: const Color(0xFF1D4ED8),
            progress: (m.inLinePct / 100).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 10),

          // 2. MENDING & CHECKING
          _buildFlowStepCard(
            stepNum: '2.',
            title: 'MENDING & CHECKING',
            pctText: '${m.mendingPct}%',
            pcsText: '${formatter.format(m.mendingChecking)} pcs',
            statusText: 'QC Table',
            accentColor: const Color(0xFFF59E0B),
            badgeBg: const Color(0xFFFEF3C7),
            badgeColor: const Color(0xFFD97706),
            progress: (m.mendingPct / 100).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 10),

          // 3. READY IN GODOWN
          _buildFlowStepCard(
            stepNum: '3.',
            title: 'READY IN GODOWN',
            pctText: '${m.readyPct}%',
            pcsText: '${formatter.format(m.readyGoods)} pcs',
            statusText: '100% Packed',
            accentColor: const Color(0xFF14C8B4),
            badgeBg: const Color(0xFFF0FDFA),
            badgeColor: const Color(0xFF0D9488),
            progress: (m.readyPct / 100).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 10),

          // 4. DISPATCHED OUT
          _buildFlowStepCard(
            stepNum: '4.',
            title: 'DISPATCHED OUT',
            pctText: '${m.deliveryPct}%',
            pcsText: '${formatter.format(m.readyDelivery)} pcs',
            statusText: 'Gate Pass',
            accentColor: const Color(0xFF0B1220),
            badgeBg: const Color(0xFFF1F5F9),
            badgeColor: const Color(0xFF334155),
            progress: (m.deliveryPct / 100).clamp(0.0, 1.0),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStepCard({
    required String stepNum,
    required String title,
    required String pctText,
    required String pcsText,
    required String statusText,
    required Color accentColor,
    required Color badgeBg,
    required Color badgeColor,
    required double progress,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 14, top: 12, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$stepNum $title',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pctText,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      pcsText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                    Text(
                      statusText,
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. PRODUCTION TREND CARD (100% Web Parity)
  // ==========================================
  Widget _buildProductionTrendCard(PlantOperationsData data) {
    final trendList = _trendMode == 'Monthly' ? data.monthlyTrend : data.weeklyTrend;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
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
              Row(
                children: [
                  const Icon(Icons.trending_up, size: 18, color: Color(0xFF0B1220)),
                  const SizedBox(width: 6),
                  Text(
                    'Production Trend',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                ],
              ),
              Container(
                height: 30,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildTrendToggleBtn('Monthly', _trendMode == 'Monthly'),
                    _buildTrendToggleBtn('Weekly', _trendMode == 'Weekly'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Monthly vs planned vs delivered',
            style: GoogleFonts.publicSans(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            children: [
              _buildLegendDot(const Color(0xFF0B1220), 'Planned'),
              const SizedBox(width: 14),
              _buildLegendDot(const Color(0xFF14C8B4), 'Production'),
              const SizedBox(width: 14),
              _buildLegendDot(const Color(0xFFF59E0B), 'Delivered'),
            ],
          ),
          const SizedBox(height: 16),

          // Chart Display
          Container(
            height: 130,
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: trendList.isEmpty
                ? Center(
                    child: Text(
                      'No past production trends recorded',
                      style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: trendList.map((item) {
                      final maxVal = math.max(1, math.max(item.planned, math.max(item.production, item.delivered)));
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildBar(item.planned, maxVal, const Color(0xFF0B1220)),
                              const SizedBox(width: 3),
                              _buildBar(item.production, maxVal, const Color(0xFF14C8B4)),
                              const SizedBox(width: 3),
                              _buildBar(item.delivered, maxVal, const Color(0xFFF59E0B)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 6),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 14),

          // Bottom Output Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Period Production Output',
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x26000000)),
                ),
                child: Text(
                  '${data.metrics.totalProduced} pcs produced',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendToggleBtn(String label, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _trendMode = label),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 2)] : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF0B1220) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildBar(int value, int maxVal, Color color) {
    final double height = ((value / maxVal) * 75).clamp(4.0, 75.0);
    return Container(
      width: 10,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }

  // ==========================================
  // 6. ORDER STATUS CARD (Donut Chart 100% Web Parity)
  // ==========================================
  Widget _buildOrderStatusCard(PlantOperationsData data) {
    final formatter = NumberFormat('#,###');
    final segs = data.orderStatusSegments;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
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
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF0B1220)),
                  const SizedBox(width: 6),
                  Text(
                    'Order Status',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Live',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Current lifecycle status breakdown',
            style: GoogleFonts.publicSans(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),

          // Donut Chart Graphic
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: DonutChartPainter(segments: segs),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.metrics.totalStocks >= 1000
                            ? '${(data.metrics.totalStocks / 1000).toStringAsFixed(0)}k'
                            : '${data.metrics.totalStocks}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0B1220),
                        ),
                      ),
                      Text(
                        'TOTAL PCS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2-Column Legend Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: segs.map((seg) {
              return Container(
                width: (MediaQuery.of(context).size.width - 72) / 2,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(seg.colorHex),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        seg.label,
                        style: GoogleFonts.publicSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${seg.pct}%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // In Pipeline Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'In Pipeline',
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                '${formatter.format(data.metrics.totalStocks)} pcs',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B1220),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. PRODUCTION BY CATEGORY (100% Web Parity)
  // ==========================================
  Widget _buildCategoryCard(PlantOperationsData data) {
    final cats = data.categoryProduction;
    final maxCount = math.max(1, cats.fold<int>(0, (m, c) => math.max(m, c.count)));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
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
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF0B1220)),
                  const SizedBox(width: 6),
                  Text(
                    'Production by Category',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'All Time',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Volume across product segments',
            style: GoogleFonts.publicSans(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),

          // Vertical Bar Chart Container
          Container(
            height: 140,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: cats.isEmpty
                ? Center(
                    child: Text(
                      'No category data available',
                      style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: cats.map((c) {
                      final countStr = c.count >= 1000
                          ? '${(c.count / 1000).toStringAsFixed(0)}k'
                          : '${c.count}';
                      final double barHeight = ((c.count / maxCount) * 65).clamp(8.0, 65.0);

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            countStr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 32,
                            height: 70,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 32,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: Color(c.colorHex),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.label,
                            style: GoogleFonts.publicSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 14),

          // Primary Segment Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Primary Segment',
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                data.primarySegmentText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B1220),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 8. TOP RUNNING STYLES CARD (100% Web Parity)
  // ==========================================
  Widget _buildTopRunningStylesCard(PlantOperationsData data) {
    final styles = data.topRunningStyles;
    final formatter = NumberFormat('#,###');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
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
              Row(
                children: [
                  const Icon(Icons.sell_outlined, size: 18, color: Color(0xFF0B1220)),
                  const SizedBox(width: 6),
                  Text(
                    'Top Running Styles',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChallansDashboardScreen()),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: Color(0xFF0B1220)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Styles with highest production volume and progress',
            style: GoogleFonts.publicSans(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '#',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'STYLE / ART NO.',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                SizedBox(
                  width: 75,
                  child: Text(
                    'ORDER QTY',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                SizedBox(
                  width: 65,
                  child: Text(
                    'PRODUCED',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Rows
          if (styles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No active running styles',
                  style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...styles.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final s = entry.value;
              final numStr = idx < 10 ? '0$idx' : '$idx';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        numStr,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Art: ${s.artNo}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                          if (s.description.isNotEmpty)
                            Text(
                              s.description.toUpperCase(),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 75,
                      child: Text(
                        formatter.format(s.orderQty),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0B1220),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 65,
                      child: Text(
                        '${s.producedQty}',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Footer Link
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChallansDashboardScreen()),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tracking active production runs',
                  style: GoogleFonts.publicSans(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Floor Line Allotments',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: Color(0xFF0B1220)),
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
  // 9. RECENT ACTIVITIES CARD (100% Web Parity)
  // ==========================================
  Widget _buildRecentActivitiesCard(BuildContext context, PlantOperationsData data) {
    final activities = data.activities;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
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
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF0B1220)),
                  const SizedBox(width: 6),
                  Text(
                    'Recent Activities',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: Color(0xFF0B1220)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Real-time factory floor log events',
            style: GoogleFonts.publicSans(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Activity Tiles
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No recent factory floor activity logged',
                  style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...activities.take(5).map((act) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x26000000)),
                      ),
                      child: const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF0B1220)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  act.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0B1220),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                formatRelativeTime(act.timestamp),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            act.details,
                            style: GoogleFonts.publicSans(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 6),

          // Full Factory Audit Logs Button
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x26000000)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.description_outlined, size: 16, color: Color(0xFF0B1220)),
                  const SizedBox(width: 8),
                  Text(
                    'Full Factory Audit Logs (${activities.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B1220),
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
}

// Custom Painter for Donut Chart
class DonutChartPainter extends CustomPainter {
  final List<OrderStatusSegment> segments;

  DonutChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 14.0;

    final total = segments.fold<int>(0, (s, e) => s + e.count);
    if (total == 0) {
      final paint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (var seg in segments) {
      final sweepAngle = (seg.count / total) * 2 * math.pi;
      if (sweepAngle > 0) {
        final paint = Paint()
          ..color = Color(seg.colorHex)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
      }
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
