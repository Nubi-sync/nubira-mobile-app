import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../providers/printing_store_provider.dart';

class PrintingStoreScreen extends ConsumerStatefulWidget {
  const PrintingStoreScreen({super.key});

  @override
  ConsumerState<PrintingStoreScreen> createState() => _PrintingStoreScreenState();
}

class _PrintingStoreScreenState extends ConsumerState<PrintingStoreScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  int _selectedTabIndex = 0; // 0: Receipts, 1: Issues, 2: Pending
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openIssueChallanModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _IssueChallanModal(),
    );
  }

  void _openAcknowledgeModal(MaterialIssueItem issue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AcknowledgeReceiptModal(pendingIssue: issue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeState = ref.watch(printingStoreProvider);

    final filteredReceipts = storeState.receipts.where((r) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final challan = (r.issue?.issueChallanNo ?? 'MANUAL-REC').toLowerCase();
      final from = (r.issue?.fromDivision ?? 'STORE').toLowerCase();
      final article = (r.issue?.articleNo ?? '').toLowerCase();
      final fabric = (r.issue?.fabricType ?? '').toLowerCase();
      final rack = (r.rackLocation ?? '').toLowerCase();
      return challan.contains(q) || from.contains(q) || article.contains(q) || fabric.contains(q) || rack.contains(q);
    }).toList();

    final filteredIssues = storeState.issues.where((i) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final challan = i.issueChallanNo.toLowerCase();
      final to = i.toDivision.toLowerCase();
      final article = (i.articleNo ?? '').toLowerCase();
      final fabric = (i.fabricType ?? '').toLowerCase();
      return challan.contains(q) || to.contains(q) || article.contains(q) || fabric.contains(q);
    }).toList();

    final filteredPending = storeState.pendingIssues.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final challan = p.issueChallanNo.toLowerCase();
      final from = p.fromDivision.toLowerCase();
      final article = (p.articleNo ?? '').toLowerCase();
      return challan.contains(q) || from.contains(q) || article.contains(q);
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/printing/store'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF3A3564),
        onRefresh: () => ref.read(printingStoreProvider.notifier).fetchStoreData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_back, size: 13, color: Color(0xFF3A3564)),
                              const SizedBox(width: 4),
                              Text(
                                'Printing Studio',
                                style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ Floor Store',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF64748B)),
                    onPressed: () => ref.read(printingStoreProvider.notifier).fetchStoreData(),
                    tooltip: 'Refresh Store Data',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Header Card matching Web Admin ModuleStoreDashboard
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
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
                            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                          ),
                          child: const Icon(Icons.storefront_outlined, color: Color(0xFF3A3564), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Printing Division Store',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF7F0),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                                    ),
                                    child: Text(
                                      'DIV 04',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Material receipts from preceding stage and handoff issues to next line',
                                style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3A3564),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _openIssueChallanModal,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              '+ Issue Challan',
                              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Executive KPI Metric Cards (2x2 Grid)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'TOTAL RECEIVED',
                      tag: 'INWARD',
                      subtitle: 'Inward logged',
                      value: NumberFormat('#,###').format(storeState.totalReceivedQty),
                      badge: '${storeState.receipts.length} LOTS',
                      icon: Icons.arrow_downward_rounded,
                      iconColor: const Color(0xFF3A3564),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'TOTAL ISSUED',
                      tag: 'OUTWARD',
                      subtitle: 'Next line handoff',
                      value: NumberFormat('#,###').format(storeState.totalIssuedQty),
                      badge: '${storeState.issues.length} CHALLANS',
                      icon: Icons.arrow_upward_rounded,
                      iconColor: const Color(0xFF3A3564),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'PENDING INWARDS',
                      tag: 'PENDING',
                      subtitle: 'Awaiting receipt',
                      value: '${storeState.pendingInwardsCount}',
                      badge: 'IN TRANSIT',
                      icon: Icons.schedule_rounded,
                      iconColor: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'LOGGED VARIANCE',
                      tag: 'SHORTAGE',
                      subtitle: 'Logged discrepancy',
                      value: '${storeState.totalShortageQty}',
                      badge: 'UNITS',
                      icon: Icons.error_outline_rounded,
                      iconColor: const Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tabbed Container & Search Toolbar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tabs & Search Header
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildTabButton(0, 'Inwards Received (${storeState.receipts.length})'),
                                const SizedBox(width: 8),
                                _buildTabButton(1, 'Outward Issues (${storeState.issues.length})'),
                                const SizedBox(width: 8),
                                _buildTabButton(2, 'Pending Inward (${storeState.pendingIssues.length})'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Search Input
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                            style: GoogleFonts.publicSans(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Search challan, article, division...',
                              hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                              ),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Tab Body
                    if (_selectedTabIndex == 0)
                      _buildReceiptsList(filteredReceipts)
                    else if (_selectedTabIndex == 1)
                      _buildIssuesList(filteredIssues)
                    else
                      _buildPendingList(filteredPending),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String tag,
    required String subtitle,
    required String value,
    required String badge,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
          ),
          Text(
            subtitle,
            style: GoogleFonts.publicSans(fontSize: 10, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsList(List<MaterialReceiptItem> receipts) {
    if (receipts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No material receipts recorded yet.',
            style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: receipts.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, idx) {
        final r = receipts[idx];
        final challanNo = r.issue?.issueChallanNo ?? 'MANUAL-REC';
        final fromDiv = r.issue?.fromDivision ?? 'CUTTING';
        final article = r.issue?.articleNo != null ? 'Art #${r.issue!.articleNo}' : 'General Stock';
        final details = '${r.issue?.fabricType ?? ''} ${r.issue?.color != null ? '• ${r.issue!.color}' : ''}'.trim();
        final dateStr = r.receivedAt != null
            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(r.receivedAt!))
            : '20/09/2026';

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Challan Ref & From Division
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    challanNo,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      fromDiv,
                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Row 2: Article & Material Details
              Text(
                article,
                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  details,
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 10),

              // Row 3: Metrics & Meta details
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RECEIVED QTY', style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          '${NumberFormat('#,###').format(r.receivedQuantity)} ${r.unit}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RACK', style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          r.rackLocation ?? 'PRINT-INTAKE-01',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: const Color(0xFF334155), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RECEIVER', style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          r.receivedBy ?? 'Kamal',
                          style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF334155), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('DATE', style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIssuesList(List<MaterialIssueItem> issues) {
    if (issues.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No outward issues dispatched yet.',
            style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: issues.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, idx) {
        final i = issues[idx];
        final article = i.articleNo != null ? 'Art #${i.articleNo}' : 'General Stock';
        final details = '${i.fabricType ?? ''} ${i.color != null ? '• ${i.color}' : ''}'.trim();
        final dateStr = i.issueDate ?? '21/09/2026';

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Challan Ref + To Division + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    i.issueChallanNo,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          i.toDivision,
                          style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: i.status == 'RECEIVED' ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: i.status == 'RECEIVED' ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Text(
                          i.status,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: i.status == 'RECEIVED' ? const Color(0xFF047857) : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Row 2: Article & Material Details
              Text(
                article,
                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  details,
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 10),

              // Row 3: Metrics & Meta details
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DISPATCHED QTY', style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          '${NumberFormat('#,###').format(i.quantity)} ${i.unit}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ISSUER', style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          i.issuedBy ?? 'Store Supervisor',
                          style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF334155), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('ISSUE DATE', style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingList(List<MaterialIssueItem> pending) {
    if (pending.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No pending inwards. All dispatched lots have been acknowledged.',
            style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pending.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, idx) {
        final p = pending[idx];
        final article = p.articleNo != null ? 'Art #${p.articleNo}' : 'General Stock';
        final details = '${p.fabricType ?? ''} ${p.color != null ? '• ${p.color}' : ''}'.trim();

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    p.issueChallanNo,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Text(
                      'FROM: ${p.fromDivision}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                article,
                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  details,
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dispatched: ${NumberFormat('#,###').format(p.quantity)} ${p.unit}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3564),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _openAcknowledgeModal(p),
                    child: Text(
                      'Receive & Acknowledge',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Issue Challan Bottom Sheet Modal (1:1 with Web Admin ModuleStoreDashboard)
// ============================================================================

class _IssueChallanModal extends ConsumerStatefulWidget {
  const _IssueChallanModal();

  @override
  ConsumerState<_IssueChallanModal> createState() => _IssueChallanModalState();
}

class _IssueChallanModalState extends ConsumerState<_IssueChallanModal> {
  final _formKey = GlobalKey<FormState>();
  final _articleCtrl = TextEditingController();
  final _buyerCtrl = TextEditingController();
  final _fabricCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _rollsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _targetDivision = 'SEWING';
  String _unit = 'meters';
  bool _isSubmitting = false;

  final List<Map<String, String>> _divisions = [
    {'code': 'CUTTING', 'label': 'Cutting Floor'},
    {'code': 'PRINTING', 'label': 'Printing Division'},
    {'code': 'EMBROIDERY', 'label': 'Embroidery Division'},
    {'code': 'SEWING', 'label': 'Sewing Floor'},
    {'code': 'WASHING', 'label': 'Washing Operations'},
    {'code': 'IRONING', 'label': 'Ironing Operations'},
    {'code': 'PACKING', 'label': 'Ready Goods & Packing'},
  ];

  final List<Map<String, String>> _units = [
    {'code': 'meters', 'label': 'Meters'},
    {'code': 'pcs', 'label': 'Pieces'},
    {'code': 'kg', 'label': 'Kilograms'},
    {'code': 'rolls', 'label': 'Rolls'},
  ];

  @override
  void dispose() {
    _articleCtrl.dispose();
    _buyerCtrl.dispose();
    _fabricCtrl.dispose();
    _colorCtrl.dispose();
    _qtyCtrl.dispose();
    _rollsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final rolls = int.tryParse(_rollsCtrl.text.trim()) ?? 0;

    final success = await ref.read(printingStoreProvider.notifier).createIssueChallan(
      toDivision: _targetDivision,
      articleNo: _articleCtrl.text.trim().isEmpty ? null : _articleCtrl.text.trim(),
      buyerName: _buyerCtrl.text.trim().isEmpty ? null : _buyerCtrl.text.trim(),
      fabricType: _fabricCtrl.text.trim().isEmpty ? null : _fabricCtrl.text.trim(),
      color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
      quantity: qty,
      unit: _unit,
      rollsCount: rolls,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Material Challan generated successfully.' : 'Failed to generate challan.'),
          backgroundColor: success ? const Color(0xFF047857) : const Color(0xFFE11D48),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        margin: const EdgeInsets.only(top: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Web Style Top Header with Cream BG & DIV 04 OUTWARD Badge
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F0),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                            ),
                            child: Text(
                              'DIV 04 OUTWARD',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3A3564),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Issue Material Challan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Destination & Article Number (2 Columns)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('DESTINATION', isRequired: true),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _targetDivision,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 18),
                                      items: _divisions.map((d) {
                                        return DropdownMenuItem<String>(
                                          value: d['code'],
                                          child: Text(
                                            d['label']!,
                                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _targetDivision = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('ARTICLE NUMBER'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _articleCtrl,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                                  decoration: _inputDecoration('E.G. 9437'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 2: Buyer Name & Color / Shade (2 Columns)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('BUYER NAME'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _buyerCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
                                  decoration: _inputDecoration('e.g. Zara / HM'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('COLOR / SHADE'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _colorCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
                                  decoration: _inputDecoration('e.g. Navy Blue'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 3: Fabric / Item Type (Full Width)
                      _buildLabel('FABRIC / ITEM TYPE'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _fabricCtrl,
                        style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
                        decoration: _inputDecoration('e.g. Cotton Single Jersey 220 GSM'),
                      ),
                      const SizedBox(height: 14),

                      // Row 4: Quantity, Unit, Rolls (3 Columns matching Web)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quantity
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('QUANTITY', isRequired: true),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _qtyCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Required';
                                    final n = double.tryParse(val.trim());
                                    if (n == null || n <= 0) return 'Invalid';
                                    return null;
                                  },
                                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                  decoration: _inputDecoration('0'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Unit Dropdown
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('UNIT'),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _unit,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 18),
                                      items: _units.map((u) {
                                        return DropdownMenuItem<String>(
                                          value: u['code'],
                                          child: Text(
                                            u['label']!,
                                            style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _unit = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Rolls
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('ROLLS'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _rollsCtrl,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 13, color: const Color(0xFF0F172A)),
                                  decoration: _inputDecoration('0'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 5: Notes (Full Width)
                      _buildLabel('NOTES'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
                        decoration: _inputDecoration('Remarks or instructions...'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Web Style Bottom Action Bar with Cancel and Confirm Issue Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F0),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3564),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            'Confirm Issue',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF334155),
            letterSpacing: 0.5,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 12),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
    );
  }
}

// ============================================================================
// Acknowledge Receipt Bottom Sheet Modal (1:1 with Web Admin ModuleStoreDashboard)
// ============================================================================

class _AcknowledgeReceiptModal extends ConsumerStatefulWidget {
  final MaterialIssueItem pendingIssue;
  const _AcknowledgeReceiptModal({required this.pendingIssue});

  @override
  ConsumerState<_AcknowledgeReceiptModal> createState() => _AcknowledgeReceiptModalState();
}

class _AcknowledgeReceiptModalState extends ConsumerState<_AcknowledgeReceiptModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _recQtyCtrl;
  final _shortageCtrl = TextEditingController(text: '0');
  final _rackCtrl = TextEditingController(text: 'PRINT-INTAKE-01');
  final _receiverCtrl = TextEditingController(text: 'Kamal');
  final _notesCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _recQtyCtrl = TextEditingController(text: widget.pendingIssue.quantity.toString());
  }

  @override
  void dispose() {
    _recQtyCtrl.dispose();
    _shortageCtrl.dispose();
    _rackCtrl.dispose();
    _receiverCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final recQty = int.tryParse(_recQtyCtrl.text.trim()) ?? widget.pendingIssue.quantity;
    final shortage = int.tryParse(_shortageCtrl.text.trim()) ?? 0;

    final success = await ref.read(printingStoreProvider.notifier).acknowledgeMaterialReceipt(
      issueId: widget.pendingIssue.id,
      receivedQuantity: recQty,
      shortageQuantity: shortage,
      unit: widget.pendingIssue.unit,
      receivedBy: _receiverCtrl.text.trim().isEmpty ? null : _receiverCtrl.text.trim(),
      rackLocation: _rackCtrl.text.trim().isEmpty ? null : _rackCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Material inward logged successfully.' : 'Failed to acknowledge receipt.'),
          backgroundColor: success ? const Color(0xFF047857) : const Color(0xFFE11D48),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pendingIssue;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        margin: const EdgeInsets.only(top: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header with Cream BG & INWARD ACKNOWLEDGMENT Badge
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F0),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                            ),
                            child: Text(
                              'INWARD ACKNOWLEDGMENT',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3A3564),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Receive ${p.issueChallanNo}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Challan Meta Summary Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow('From Division:', p.fromDivision),
                            const SizedBox(height: 4),
                            _buildSummaryRow('Article:', p.articleNo ?? 'N/A'),
                            const SizedBox(height: 4),
                            _buildSummaryRow('Dispatched Qty:', '${p.quantity} ${p.unit}', valueColor: const Color(0xFF3A3564)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Actual Received & Shortage Qty Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('ACTUAL RECEIVED', isRequired: true),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _recQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                  decoration: _inputDecoration('0'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('SHORTAGE QTY'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _shortageCtrl,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 13, color: const Color(0xFF0F172A)),
                                  decoration: _inputDecoration('0'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Rack / Location & Received By Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('RACK / FLOOR LOCATION'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _rackCtrl,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12.5, color: const Color(0xFF0F172A)),
                                  decoration: _inputDecoration('e.g. PRINT-INTAKE-01'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('RECEIVED BY'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _receiverCtrl,
                                  style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
                                  decoration: _inputDecoration('Supervisor Name'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      _buildLabel('NOTES'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
                        decoration: _inputDecoration('Inspection remarks...'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Action Bar with Cancel and Confirm Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F0),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3564),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            'Acknowledge Inward',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B))),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF334155),
            letterSpacing: 0.5,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 12),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
    );
  }
}
