import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../../main.dart';

class DailyReceivingAuditModal extends StatefulWidget {
  final VoidCallback onRefreshNeeded;
  final VoidCallback onOpenManualFallback;

  const DailyReceivingAuditModal({
    super.key,
    required this.onRefreshNeeded,
    required this.onOpenManualFallback,
  });

  @override
  State<DailyReceivingAuditModal> createState() => _DailyReceivingAuditModalState();
}

class _DailyReceivingAuditModalState extends State<DailyReceivingAuditModal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _incomingLots = [];
  String? _processingLotId;

  // Natural size ordering sequence
  static const List<String> _alphaSizeOrder = [
    'XS', 'S', 'M', 'L', 'XL', '2XL', 'XXL', '3XL', 'XXXL', '4XL', '5XL', 'FREE', 'FS'
  ];

  int _naturalSizeCompare(String a, String b) {
    final aUpper = a.trim().toUpperCase();
    final bUpper = b.trim().toUpperCase();

    final aIdx = _alphaSizeOrder.indexOf(aUpper);
    final bIdx = _alphaSizeOrder.indexOf(bUpper);

    if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
    if (aIdx != -1) return -1;
    if (bIdx != -1) return 1;

    final aNum = int.tryParse(aUpper);
    final bNum = int.tryParse(bUpper);
    if (aNum != null && bNum != null) return aNum.compareTo(bNum);

    return aUpper.compareTo(bUpper);
  }

  @override
  void initState() {
    super.initState();
    _fetchIncomingLots();
  }

  Future<void> _fetchIncomingLots() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch allotments pending QC receiving
      final allotmentsRes = await supabase
          .from('allotments')
          .select('''
            id,
            challan_id,
            article_id,
            lineman_id,
            status,
            mending_status,
            qc_status,
            target_qty,
            mending_total_counted,
            mending_verified_at,
            created_at,
            article:articles ( id, art_no, description ),
            lineman:profiles!allotments_lineman_id_fkey ( id, username ),
            challans ( id, challan_no, brand, fabric_type )
          ''')
          .or('mending_status.eq.QC_PENDING,qc_status.eq.PENDING_RECEIVING')
          .order('created_at', ascending: false);

      final List<dynamic> allotmentList = allotmentsRes as List<dynamic>;
      final List<String> lotIds = allotmentList.map((a) => a['id'].toString()).toList();

      if (lotIds.isEmpty) {
        if (mounted) setState(() { _incomingLots = []; _isLoading = false; });
        return;
      }

      // 2. Fetch variants (Admin Allotted target per size/color)
      final variantsRes = await supabase
          .from('allotment_variants')
          .select('id, allotment_id, color, size, quantity')
          .inFilter('allotment_id', lotIds);

      // 3. Fetch mending assignments (Mending physical count per size/color)
      final assignmentsRes = await supabase
          .from('mending_assignments')
          .select('id, allotment_id, color, size, assigned_qty, completed_qty')
          .inFilter('allotment_id', lotIds);

      final List<Map<String, dynamic>> enrichedLots = [];

      for (var a in allotmentList) {
        final aId = a['id'].toString();
        final vars = (variantsRes as List<dynamic>).where((v) => v['allotment_id'].toString() == aId).toList();
        final assigns = (assignmentsRes as List<dynamic>).where((m) => m['allotment_id'].toString() == aId).toList();

        // Distinct colors in this lot
        final Set<String> colors = {};
        for (var v in vars) {
          final c = v['color']?.toString().trim();
          if (c != null && c.isNotEmpty) colors.add(c);
        }
        if (colors.isEmpty) colors.add('Standard');

        // Build size audit matrix per color
        final Map<String, List<Map<String, dynamic>>> sizeMatrixByColor = {};

        for (var color in colors) {
          final colorVars = vars.where((v) => (v['color']?.toString().trim() ?? 'Standard') == color).toList();
          final colorAssigns = assigns.where((m) => (m['color']?.toString().trim() ?? 'Standard') == color).toList();

          // Get all distinct sizes for this color
          final Set<String> distinctSizes = {};
          for (var v in colorVars) {
            final s = v['size']?.toString().trim();
            if (s != null && s.isNotEmpty) distinctSizes.add(s);
          }
          for (var m in colorAssigns) {
            final s = m['size']?.toString().trim();
            if (s != null && s.isNotEmpty) distinctSizes.add(s);
          }

          final sortedSizes = distinctSizes.toList();
          sortedSizes.sort(_naturalSizeCompare);

          final List<Map<String, dynamic>> sizeBreakdowns = [];

          for (var size in sortedSizes) {
            int allotted = 0;
            for (var v in colorVars) {
              if (v['size']?.toString().trim() == size) {
                allotted += (v['quantity'] as int? ?? 0);
              }
            }

            int received = 0;
            for (var m in colorAssigns) {
              if (m['size']?.toString().trim() == size) {
                final c = (m['completed_qty'] as int? ?? 0);
                received += (c > 0 ? c : (m['assigned_qty'] as int? ?? 0));
              }
            }

            // If no assignments completed, fallback to allotted qty or variant
            if (received == 0 && assigns.isEmpty) {
              received = allotted;
            }

            final variance = received - allotted;

            sizeBreakdowns.add({
              'size': size,
              'allotted': allotted,
              'received': received,
              'variance': variance,
            });
          }

          sizeMatrixByColor[color] = sizeBreakdowns;
        }

        // Totals
        int lotTotalAllotted = 0;
        int lotTotalReceived = 0;
        sizeMatrixByColor.forEach((col, list) {
          for (var item in list) {
            lotTotalAllotted += (item['allotted'] as int);
            lotTotalReceived += (item['received'] as int);
          }
        });

        if (lotTotalAllotted == 0) {
          lotTotalAllotted = (a['target_qty'] as int? ?? 0);
        }
        if (lotTotalReceived == 0) {
          lotTotalReceived = (a['mending_total_counted'] as int? ?? lotTotalAllotted);
        }

        final overallVariance = lotTotalReceived - lotTotalAllotted;

        enrichedLots.add({
          ...a,
          'size_matrix_by_color': sizeMatrixByColor,
          'total_allotted': lotTotalAllotted,
          'total_received': lotTotalReceived,
          'overall_variance': overallVariance,
        });
      }

      if (mounted) {
        setState(() {
          _incomingLots = enrichedLots;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching incoming lots: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptLotToQc(Map<String, dynamic> lot) async {
    final lotId = lot['id'].toString();
    final articleId = lot['article_id'];
    final linemanId = lot['lineman_id'];
    final receivedQty = lot['total_received'] as int;
    final variance = lot['overall_variance'] as int;

    setState(() => _processingLotId = lotId);

    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final user = supabase.auth.currentUser;

      // 1. Log RECEIVING entry in qc_logs
      await supabase.from('qc_logs').insert({
        'stage': 'RECEIVING',
        'article_id': articleId,
        'from_lineman_id': linemanId,
        'qty_received': receivedQty,
        'qty_passed': 0,
        'qty_rejected': 0,
        'defect_type': 'NONE',
        'remarks': 'Accepted from Mending Floor ($receivedQty pcs). Variance: ${variance >= 0 ? "+$variance" : "$variance"} pcs',
        'entry_date': todayStr,
      });

      // 2. Update allotment status to QC_RECEIVED
      await supabase.from('allotments').update({
        'qc_status': 'QC_RECEIVED',
        'qc_received_at': DateTime.now().toUtc().toIso8601String(),
        'qc_supervisor_id': user?.id,
      }).eq('id', lotId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.green,
            content: Text(
              'Lot Inwarded Successfully! $receivedQty pcs accepted to QC floor.',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
        widget.onRefreshNeeded();
        _fetchIncomingLots();
      }
    } catch (e) {
      debugPrint('Error accepting lot to QC: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.red, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingLotId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.steelMist,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.move_to_inbox_outlined, color: AppTheme.steel, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Receiving (Incoming Mending Lots)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        Text(
                          'Verify counts against Admin Allotment & Inward to QC Floor',
                          style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.steel))
                  : _incomingLots.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _incomingLots.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (ctx, index) => _buildLotCard(_incomingLots[index]),
                        ),
            ),

            // Footer action for fallback manual entry
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.bg,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Need to receive without mending ticket?',
                    style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpenManualFallback();
                    },
                    icon: const Icon(Icons.add_rounded, size: 16, color: AppTheme.steel),
                    label: Text(
                      'Manual Fallback Inward',
                      style: GoogleFonts.publicSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.steel,
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.steelMist,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.steel, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              'No Incoming Mending Lots',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'When the Mending Floor verifies physical counts and forwards lots, they will immediately appear here with size audit breakdowns.',
              textAlign: TextAlign.center,
              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onOpenManualFallback();
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Direct Manual Inward'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.border),
                foregroundColor: AppTheme.ink,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLotCard(Map<String, dynamic> lot) {
    final lotId = lot['id'].toString();
    final challanNo = lot['challans']?['challan_no'] ?? lot['challan_id'] ?? '-';
    final artNo = lot['article']?['art_no'] ?? '-';
    final artDesc = lot['article']?['description'] ?? '';
    final linemanName = lot['lineman']?['username'] ?? 'Lineman';
    final totalAllotted = lot['total_allotted'] as int;
    final totalReceived = lot['total_received'] as int;
    final overallVariance = lot['overall_variance'] as int;
    final isProcessing = _processingLotId == lotId;

    final isShort = overallVariance < 0;
    final isExcess = overallVariance > 0;

    final matrixByColor = lot['size_matrix_by_color'] as Map<String, List<Map<String, dynamic>>>;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isShort ? AppTheme.amber : AppTheme.border,
          width: isShort ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: const Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.steel,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Challan #$challanNo',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Art: $artNo',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                        ],
                      ),
                      if (artDesc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          artDesc,
                          style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 13, color: AppTheme.steel),
                        const SizedBox(width: 4),
                        Text(
                          linemanName,
                          style: GoogleFonts.publicSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.greenMist,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Count Verified',
                        style: GoogleFonts.publicSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Overall Summary Banner (Side-by-Side KPIs)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isShort ? const Color(0xFFFEF3C7) : AppTheme.steelMist,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isShort ? const Color(0xFFF59E0B) : AppTheme.steel.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALLOTTED (TARGET)',
                          style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.inkSoft),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalAllotted pcs',
                          style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: AppTheme.border),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECEIVED (COUNTED)',
                          style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.inkSoft),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalReceived pcs',
                          style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.steel),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: AppTheme.border),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VARIANCE',
                          style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.inkSoft),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          overallVariance == 0
                              ? '0 (Exact)'
                              : isShort
                                  ? '$overallVariance pcs'
                                  : '+$overallVariance pcs',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isShort
                                ? AppTheme.red
                                : isExcess
                                    ? AppTheme.green
                                    : AppTheme.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Natural Size-Wise Audit Tables for each color
          ...matrixByColor.entries.map((entry) {
            final colorName = entry.key;
            final rows = entry.value;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.steel,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'COLOR: ${colorName.toUpperCase()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildSizeAuditTable(rows),
                  const SizedBox(height: 8),
                ],
              ),
            );
          }),

          // Discrepancy Note (if short)
          if (isShort)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.redMist,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Alert: ${overallVariance.abs()} pcs short from stitching. Inwarding will record this variance.',
                        style: GoogleFonts.publicSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Accept Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : () => _acceptLotToQc(lot),
                icon: isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.verified_outlined, size: 18),
                label: Text(
                  isProcessing ? 'Inwarding Lot...' : 'Accept & Inward $totalReceived Pcs to QC Floor',
                  style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.steel,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeAuditTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            children: [
              // Header Row: Sizes
              TableRow(
                decoration: const BoxDecoration(color: AppTheme.bg),
                children: [
                  _buildTableCell('METRIC', isHeader: true, isMetricLabel: true),
                  ...rows.map((r) => _buildTableCell(r['size'].toString(), isHeader: true)),
                  _buildTableCell('TOTAL', isHeader: true, isTotal: true),
                ],
              ),
              // Row 1: Allotted Qty
              TableRow(
                children: [
                  _buildTableCell('Allotted Qty', isMetricLabel: true),
                  ...rows.map((r) => _buildTableCell(r['allotted'].toString())),
                  _buildTableCell(
                    rows.fold<int>(0, (sum, r) => sum + (r['allotted'] as int)).toString(),
                    isTotal: true,
                  ),
                ],
              ),
              // Row 2: Received Qty
              TableRow(
                children: [
                  _buildTableCell('Received Qty', isMetricLabel: true),
                  ...rows.map((r) => _buildTableCell(
                        r['received'].toString(),
                        textColor: (r['variance'] as int) < 0 ? AppTheme.amber : AppTheme.steel,
                        isBold: true,
                      )),
                  _buildTableCell(
                    rows.fold<int>(0, (sum, r) => sum + (r['received'] as int)).toString(),
                    isTotal: true,
                    textColor: AppTheme.steel,
                    isBold: true,
                  ),
                ],
              ),
              // Row 3: Variance
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade50),
                children: [
                  _buildTableCell('Variance', isMetricLabel: true),
                  ...rows.map((r) {
                    final v = r['variance'] as int;
                    return _buildTableCell(
                      v == 0 ? '0' : (v > 0 ? '+$v' : '$v'),
                      textColor: v < 0 ? AppTheme.red : (v > 0 ? AppTheme.green : AppTheme.inkSoft),
                      isBold: v != 0,
                    );
                  }),
                  _buildTableCell(
                    (() {
                      final totV = rows.fold<int>(0, (sum, r) => sum + (r['variance'] as int));
                      return totV == 0 ? '0' : (totV > 0 ? '+$totV' : '$totV');
                    })(),
                    isTotal: true,
                    textColor: rows.fold<int>(0, (sum, r) => sum + (r['variance'] as int)) < 0 ? AppTheme.red : AppTheme.ink,
                    isBold: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isMetricLabel = false,
    bool isTotal = false,
    Color? textColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        text,
        textAlign: isMetricLabel ? TextAlign.left : TextAlign.center,
        style: isMetricLabel
            ? GoogleFonts.publicSans(
                fontSize: 11,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
                color: isHeader ? AppTheme.inkSoft : AppTheme.ink,
              )
            : GoogleFonts.jetBrainsMono(
                fontSize: 11.5,
                fontWeight: isHeader || isTotal || isBold ? FontWeight.bold : FontWeight.normal,
                color: textColor ?? (isHeader ? AppTheme.inkSoft : (isTotal ? AppTheme.ink : AppTheme.ink)),
              ),
      ),
    );
  }
}
