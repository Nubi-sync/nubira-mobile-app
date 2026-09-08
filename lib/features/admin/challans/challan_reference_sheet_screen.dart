import 'package:flutter/material.dart';
import 'challan_models.dart';
import 'widgets/challan_summary_card.dart';

class ChallanReferenceSheetScreen extends StatelessWidget {
  final ChallanGroupedOrder challan;

  const ChallanReferenceSheetScreen({super.key, required this.challan});

  @override
  Widget build(BuildContext context) {
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
          'Challan #${challan.challanNo} Reference Sheet',
          style: const TextStyle(
            color: Color(0xFF1C1C1A),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFDAD9D3), height: 0.8),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDEAF6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.description_outlined, color: Color(0xFF332B6B), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Master Article Reference Sheet',
                              style: TextStyle(
                                color: Color(0xFF1C1C1A),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${challan.articles.length} Article Lines • ${challan.totalPcs.toLocaleString()} Total Pcs',
                              style: const TextStyle(color: Color(0xFF6B6A65), fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEAF6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF332B6B).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${challan.masterStylesCount} Styles',
                        style: const TextStyle(
                          color: Color(0xFF332B6B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFECECE8)),
                const SizedBox(height: 10),

                Row(
                  children: [
                    _buildMetaPill('Brand', challan.brand),
                    const SizedBox(width: 8),
                    if (challan.fabricType != null && challan.fabricType!.isNotEmpty) ...[
                      _buildMetaPill('Fabric', challan.fabricType!),
                      const SizedBox(width: 8),
                    ],
                    _buildMetaPill('Date', challan.challanDate),
                  ],
                ),

                if (challan.deliveryDate != null && challan.deliveryDate!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.event_available, size: 14, color: Color(0xFF6B6A65)),
                      const SizedBox(width: 4),
                      Text(
                        'Due Delivery: ${challan.deliveryDate}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Article Lines & Variant Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1C1A),
                ),
              ),
              Text(
                '${challan.articles.length} Lines',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B6A65), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stacked Article Line Cards
          ...challan.articles.asMap().entries.map((entry) {
            final idx = entry.key;
            final line = entry.value;
            return _buildArticleCard(idx + 1, line);
          }),

          const SizedBox(height: 16),

          // Raw Material BOM Section if available
          if (challan.bomDetails.isNotEmpty) ...[
            const Text(
              'BOM Fabrics / Raw Material Lots',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1C1C1A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
              ),
              child: Column(
                children: challan.bomDetails.map((bom) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFDAD9D3)),
                              ),
                              child: Text(
                                bom.materialType,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF332B6B)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              bom.itemName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1A)),
                            ),
                          ],
                        ),
                        if (bom.requiredQty != null)
                          Text(
                            bom.requiredQty!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B6A65)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArticleCard(int lineNo, ChallanArticleLine line) {
    final themeColor = ColorThemeHelper.getColor(line.colorPattern);
    final bgLight = ColorThemeHelper.getBgLight(line.colorPattern);

    Color statusColor;
    Color statusBg;
    String statusLabel;

    switch (line.status.toUpperCase()) {
      case 'QC_PASSED':
      case 'COMPLETED':
        statusColor = const Color(0xFF047857);
        statusBg = const Color(0xFFECFDF5);
        statusLabel = 'QC Passed';
        break;
      case 'IN_PROGRESS':
        statusColor = const Color(0xFF332B6B);
        statusBg = const Color(0xFFEDEAF6);
        statusLabel = 'In Production';
        break;
      case 'PENDING':
      default:
        statusColor = const Color(0xFF854F0B);
        statusBg = const Color(0xFFFAEEDA);
        statusLabel = 'Pending Allotment';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDAD9D3), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Line number + Art No + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAF8),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFDAD9D3)),
                    ),
                    child: Text(
                      '#$lineNo',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B6A65)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Art: ${line.fullArtCode}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF332B6B),
                    ),
                  ),
                  if (line.patternNo != null && line.patternNo!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '• ${line.patternNo}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B6A65)),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Color dot + Color name + Size tier chip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bgLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: themeColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      line.colorPattern,
                      style: TextStyle(
                        color: themeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDAD9D3)),
                ),
                child: Text(
                  'Size: ${line.sizeRange}',
                  style: const TextStyle(
                    color: Color(0xFF1C1C1A),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: Quantities and Rate
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF8),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFECECE8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${line.totalPcs.toLocaleString()} Pcs',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C1C1A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${line.sets} sets × ${line.pcsPerSet} pcs/set)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B6A65)),
                    ),
                  ],
                ),
                Text(
                  '₹${line.stitchingRate.toStringAsFixed(0)}/pc',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF332B6B)),
                ),
              ],
            ),
          ),

          // Row 4: Lineman Assignment
          if (line.assignedLinemanName != null && line.assignedLinemanName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF332B6B)),
                const SizedBox(width: 4),
                Text(
                  'Assigned to: ${line.assignedLinemanName}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF332B6B),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFDAD9D3)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF1C1C1A),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
