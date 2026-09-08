import 'package:flutter/material.dart';
import '../challan_models.dart';

class ChallanSummaryCard extends StatelessWidget {
  final ChallanGroupedOrder challan;
  final VoidCallback? onTap;
  final VoidCallback? onRecall;
  final VoidCallback? onDelete;

  const ChallanSummaryCard({
    super.key,
    required this.challan,
    this.onTap,
    this.onRecall,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = challan.status.toUpperCase();
    final isAllotted = status == 'IN_PROGRESS' || status == 'QC_PASSED' || status == 'DISPATCHED' || status == 'PARTIALLY_ALLOTTED';

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

    // Find first assigned lineman if any
    final assignedLineman = challan.articles.firstWhere(
      (a) => a.assignedLinemanName != null &&
          a.assignedLinemanName!.isNotEmpty &&
          !a.assignedLinemanName!.toLowerCase().contains('unassigned'),
      orElse: () => ChallanArticleLine(id: '', artNo: '', colorPattern: '', sizeRange: '', totalPcs: 0),
    ).assignedLinemanName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Row: Challan Number + Status Badge + Menu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDEAF6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Color(0xFF332B6B),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Challan #${challan.challanNo}',
                          style: const TextStyle(
                            color: Color(0xFF1C1C1A),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
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
                        if (onRecall != null || onDelete != null)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Color(0xFF6B6A65), size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (val) {
                              if (val == 'RECALL') onRecall?.call();
                              if (val == 'DELETE') onDelete?.call();
                            },
                            itemBuilder: (context) => [
                              if (isAllotted && onRecall != null)
                                const PopupMenuItem(
                                  value: 'RECALL',
                                  child: Row(
                                    children: [
                                      Icon(Icons.replay, size: 16, color: Color(0xFF854F0B)),
                                      SizedBox(width: 8),
                                      Text('Recall to Pending'),
                                    ],
                                  ),
                                ),
                              if (onDelete != null)
                                const PopupMenuItem(
                                  value: 'DELETE',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 16, color: Color(0xFFE11D48)),
                                      SizedBox(width: 8),
                                      Text('Delete Challan', style: TextStyle(color: Color(0xFFE11D48))),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 2. Brand, Fabric and Date
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFDAD9D3)),
                      ),
                      child: Text(
                        challan.brand,
                        style: const TextStyle(
                          color: Color(0xFF1C1C1A),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (challan.fabricType != null && challan.fabricType!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDAD9D3)),
                        ),
                        child: Text(
                          challan.fabricType!,
                          style: const TextStyle(
                            color: Color(0xFF6B6A65),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      challan.challanDate,
                      style: const TextStyle(
                        color: Color(0xFF9B9A94),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3. Master Styles & Variants summary
                Text(
                  '${challan.masterStylesCount} Master Style${challan.masterStylesCount > 1 ? 's' : ''} (${challan.articles.length} Variants)',
                  style: const TextStyle(
                    color: Color(0xFF6B6A65),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),

                // 4. Highlighted Grand Batch Total Sub-Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            '  |  ',
                            style: TextStyle(color: Color(0xFFDAD9D3)),
                          ),
                          Text(
                            '${challan.totalPcs.toLocaleString()} Pcs',
                            style: const TextStyle(
                              color: Color(0xFF1C1C1A),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Grand Batch Total',
                        style: TextStyle(
                          color: Color(0xFF9B9A94),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. Assigned Lineman Badge (if present)
                if (assignedLineman != null && isAllotted) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_pin_circle_outlined, size: 14, color: Color(0xFF332B6B)),
                      const SizedBox(width: 4),
                      Text(
                        'Lineman: $assignedLineman',
                        style: const TextStyle(
                          color: Color(0xFF332B6B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension NumberFormatting on num {
  String toLocaleString() {
    return toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
