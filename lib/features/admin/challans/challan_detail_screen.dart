import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/admin_providers.dart';
import '../models/admin_models.dart';
import '../allotments/allotment_form_state.dart';
import '../allotments/allotment_step1_screen.dart';
import 'challan_models.dart';
import 'challan_reference_sheet_screen.dart';
import 'widgets/challan_summary_card.dart';

class ChallanDetailScreen extends ConsumerStatefulWidget {
  final ChallanGroupedOrder challan;

  const ChallanDetailScreen({super.key, required this.challan});

  @override
  ConsumerState<ChallanDetailScreen> createState() => _ChallanDetailScreenState();
}

class _ChallanDetailScreenState extends ConsumerState<ChallanDetailScreen> {
  String? _globalLinemanId;
  final Map<String, String?> _colorLinemanMap = {};

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(raw.trim());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  void initState() {
    super.initState();
    // Default global lineman if any already assigned
    final firstAssigned = widget.challan.articles.firstWhere(
      (a) => a.assignedLinemanId != null && a.assignedLinemanId!.isNotEmpty,
      orElse: () => ChallanArticleLine(id: '', artNo: '', colorPattern: '', sizeRange: '', totalPcs: 0),
    );
    if (firstAssigned.assignedLinemanId != null) {
      _globalLinemanId = firstAssigned.assignedLinemanId;
    }

    // Default per-color linemen
    for (var cl in widget.challan.colorLines) {
      if (cl.assignedLinemanId != null && cl.assignedLinemanId!.isNotEmpty) {
        _colorLinemanMap[cl.colorName] = cl.assignedLinemanId;
      }
    }
  }

  void _handleFullChallanAllotment(List<AdminEmployee> linemen) {
    if (_globalLinemanId == null || _globalLinemanId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Lineman before allotting the full challan.'),
          backgroundColor: Color(0xFF854F0B),
        ),
      );
      return;
    }

    final lineman = linemen.firstWhere(
      (l) => l.id == _globalLinemanId,
      orElse: () => AdminEmployee(
        id: _globalLinemanId!,
        username: 'Lineman',
        role: 'LINEMAN',
        createdAt: DateTime.now(),
      ),
    );

    final articles = ref.read(adminArticlesListProvider).value ?? [];

    ref.read(allotmentFormProvider.notifier).prefillFromFullChallan(
          challan: widget.challan,
          linemanId: lineman.id,
          linemanName: lineman.username,
          articles: articles,
        );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllotmentStep1Screen()),
    ).then((_) {
      ref.invalidate(challanGroupedOrdersProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(adminAllotmentsListProvider);
    });
  }

  void _handleColorLineAllotment(String colorName, List<AdminEmployee> linemen) {
    final linemanId = _colorLinemanMap[colorName] ?? _globalLinemanId;
    if (linemanId == null || linemanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a Lineman for the $colorName line.'),
          backgroundColor: const Color(0xFF854F0B),
        ),
      );
      return;
    }

    final lineman = linemen.firstWhere(
      (l) => l.id == linemanId,
      orElse: () => AdminEmployee(
        id: linemanId,
        username: 'Lineman',
        role: 'LINEMAN',
        createdAt: DateTime.now(),
      ),
    );

    final colorGroup = widget.challan.colorLines.firstWhere(
      (cl) => cl.colorName.trim().toUpperCase() == colorName.trim().toUpperCase(),
      orElse: () => ColorLineGroup(
        colorName: colorName,
        themeColor: const Color(0xFF332B6B),
        bgLight: const Color(0xFFFAFAF8),
        totalPcs: widget.challan.totalPcs,
        sizeBreakdown: {},
      ),
    );

    final articles = ref.read(adminArticlesListProvider).value ?? [];

    ref.read(allotmentFormProvider.notifier).prefillFromColorLineGroup(
          challan: widget.challan,
          colorGroup: colorGroup,
          linemanId: lineman.id,
          linemanName: lineman.username,
          articles: articles,
        );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllotmentStep1Screen()),
    ).then((_) {
      ref.invalidate(challanGroupedOrdersProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(adminAllotmentsListProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(adminEmployeesListProvider);
    final employees = employeesAsync.value ?? [];
    final linemen = employees.where((e) => e.role.toUpperCase() == 'LINEMAN' && e.isActive).toList();
    ref.watch(adminArticlesListProvider); // Preload articles for instant matching

    // Re-watch live challan if updated
    final allChallansAsync = ref.watch(challanGroupedOrdersProvider);
    ChallanGroupedOrder currentChallan = widget.challan;
    if (allChallansAsync.hasValue) {
      final found = allChallansAsync.value!.where((c) => c.id == widget.challan.id);
      if (found.isNotEmpty) currentChallan = found.first;
    }

    final status = currentChallan.status.toUpperCase();

    Color statusColor;
    Color statusBg;
    String statusLabel;

    switch (status) {
      case 'QC_PASSED':
        statusColor = const Color(0xFF047857);
        statusBg = const Color(0xFFECFDF5);
        statusLabel = 'Ready (QC Passed)';
        break;
      case 'DISPATCHED':
        statusColor = Colors.white;
        statusBg = const Color(0xFF1C1C1A);
        statusLabel = 'Dispatched';
        break;
      case 'IN_PROGRESS':
        statusColor = const Color(0xFF332B6B);
        statusBg = const Color(0xFFEDEAF6);
        statusLabel = 'In Production';
        break;
      case 'PARTIALLY_ALLOTTED':
        statusColor = const Color(0xFF854F0B);
        statusBg = const Color(0xFFFAEEDA);
        statusLabel = 'Partially Allotted';
        break;
      case 'PENDING':
      default:
        statusColor = const Color(0xFF854F0B);
        statusBg = const Color(0xFFFAEEDA);
        statusLabel = 'Pending Allotment';
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1C1C1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Challan #${currentChallan.challanNo}',
          style: const TextStyle(
            color: Color(0xFF1C1C1A),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFDAD9D3), height: 0.8),
        ),
      ),
      body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. GRAND BATCH TOTAL SUMMARY CARD
              _buildSummaryHeaderCard(currentChallan),
              const SizedBox(height: 16),

              // 2. SECTION: SMART LINE ALLOTMENT HUB HEADER
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  const Text(
                    'Smart Line Allotment Hub',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F1FB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF0C447C).withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 12, color: Color(0xFF0C447C)),
                        SizedBox(width: 4),
                        Text(
                          'Continuous Sewing Optimizer',
                          style: TextStyle(
                            color: Color(0xFF0C447C),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Assign entire multi-article challan or distribute continuous color shade lines to floor linemen.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B6A65)),
              ),
              const SizedBox(height: 14),

              // 3. 1-CLICK FULL CHALLAN ASSIGNMENT CARD
              _buildFullChallanCard(currentChallan, linemen),
              const SizedBox(height: 20),

              // 4. COLOR-WISE LINE DISTRIBUTION SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Color-wise Line Distribution (${currentChallan.colorLines.length} Lines)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Grouped by continuous sewing color shades to eliminate floor thread changes.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B6A65)),
              ),
              const SizedBox(height: 12),

              // Color line cards
              ...currentChallan.colorLines.map((group) {
                return _buildColorLineCard(currentChallan, group, linemen);
              }),
              const SizedBox(height: 16),

              // 5. VIEW ARTICLE REFERENCE SHEET CTA BUTTON
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEAF6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF332B6B), size: 20),
                  ),
                  title: const Text(
                    'View Challan Article Reference Sheet',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1A)),
                  ),
                  subtitle: Text(
                    '${currentChallan.articles.length} Article Lines • Complete spec breakdown',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF332B6B)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChallanReferenceSheetScreen(challan: currentChallan),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
    );
  }

  Widget _buildSummaryHeaderCard(ChallanGroupedOrder challan) {
    final brandText = challan.brand.trim().isNotEmpty ? challan.brand.trim() : 'OLLYPOP';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFDAD9D3)),
                      ),
                      child: Text(
                        brandText,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1A)),
                      ),
                    ),
                    if (challan.fabricType != null && challan.fabricType!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDAD9D3)),
                        ),
                        child: Text(
                          challan.fabricType!.trim(),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65), fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Dates Row
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF6B6A65)),
              const SizedBox(width: 5),
              const Text(
                'Challan Date: ',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B6A65), fontWeight: FontWeight.w500),
              ),
              Text(
                _formatDate(challan.challanDate),
                style: const TextStyle(fontSize: 12, color: Color(0xFF1C1C1A), fontWeight: FontWeight.bold),
              ),
              if (challan.deliveryDate != null && challan.deliveryDate!.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                const Text(
                  '• Due: ',
                  style: TextStyle(fontSize: 12, color: Color(0xFF854F0B), fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatDate(challan.deliveryDate),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF854F0B), fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Highlighted Grand Batch Total Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFECECE8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${challan.totalSets.toLocaleString()} Sets',
                      style: const TextStyle(
                        color: Color(0xFF332B6B),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text('  |  ', style: TextStyle(color: Color(0xFFDAD9D3))),
                    Text(
                      '${challan.totalPcs.toLocaleString()} Pcs',
                      style: const TextStyle(
                        color: Color(0xFF1C1C1A),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${challan.masterStylesCount} Styles (${challan.articles.length} Lines)',
                  style: const TextStyle(
                    color: Color(0xFF6B6A65),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullChallanCard(ChallanGroupedOrder challan, List<AdminEmployee> linemen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAF6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF332B6B).withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, color: Color(0xFF332B6B), size: 20),
              SizedBox(width: 8),
              Text(
                '1-Click Full Challan Allotment',
                style: TextStyle(
                  color: Color(0xFF332B6B),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Allot all ${challan.articles.length} article lines (${challan.totalPcs.toLocaleString()} pcs) to a single lineman at once.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF1C1C1A)),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDAD9D3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: linemen.any((l) => l.id == _globalLinemanId) ? _globalLinemanId : null,
                      hint: const Text('Select Lineman', style: TextStyle(fontSize: 12, color: Color(0xFF9B9A94))),
                      items: linemen.map((emp) {
                        return DropdownMenuItem(
                          value: emp.id,
                          child: Text(emp.username, style: const TextStyle(fontSize: 12, color: Color(0xFF1C1C1A))),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _globalLinemanId = val),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF332B6B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleFullChallanAllotment(linemen),
                    child: const Text(
                      'Allot Full Challan',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

  Widget _buildColorLineCard(ChallanGroupedOrder challan, ColorLineGroup group, List<AdminEmployee> linemen) {
    final selectedLinemanForColor = _colorLinemanMap[group.colorName] ?? _globalLinemanId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Color Identity Dot + Line Name + Total Pcs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: group.themeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LINE: ${group.colorName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: group.bgLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: group.themeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${group.totalPcs.toLocaleString()} pcs',
                  style: TextStyle(
                    color: group.themeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Size Tier Pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: group.sizeBreakdown.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFECECE8)),
                ),
                child: Text(
                  'Tier ${e.key}: ${e.value} pcs',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65), fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Row 3: Status Banner
          if (group.isAssigned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF047857).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Color(0xFF047857)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Assigned to: ${group.assignedLinemanName} (In Production)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFAEEDA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF854F0B).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFF854F0B)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Not assigned to floor lineman. Sewing line idle.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF854F0B)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),

          // Row 4: Scoped Lineman Selector + Allot Button
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDAD9D3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: linemen.any((l) => l.id == selectedLinemanForColor) ? selectedLinemanForColor : null,
                      hint: const Text('Assign Lineman', style: TextStyle(fontSize: 11, color: Color(0xFF9B9A94))),
                      items: linemen.map((emp) {
                        return DropdownMenuItem(
                          value: emp.id,
                          child: Text(emp.username, style: const TextStyle(fontSize: 11, color: Color(0xFF1C1C1A))),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _colorLinemanMap[group.colorName] = val;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF332B6B),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _handleColorLineAllotment(group.colorName, linemen),
                    child: Text(
                      'Allot ${group.colorName}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
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
}
