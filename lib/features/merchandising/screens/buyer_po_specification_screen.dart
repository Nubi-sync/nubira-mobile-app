import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/merchandising_models.dart';
import '../providers/merchandising_provider.dart';

class BuyerPOSpecificationScreen extends ConsumerWidget {
  final MerchandisingOrder order;

  const BuyerPOSpecificationScreen({super.key, required this.order});

  static const List<String> defaultSizes = ['XS', 'S', 'M', 'L', 'XL'];

  String _formatEmbellishmentSequence(String seq) {
    if (seq.isEmpty || seq == 'NONE') return 'No Embroidery, No Printing (Cut & Sew)';
    if (seq == 'ONLY_PRINTING') return 'Only Printing';
    if (seq == 'ONLY_EMBROIDERY') return 'Only Embroidery';
    if (seq == 'EMBROIDERY_FIRST_THEN_PRINT') return 'Embroidery First, Then Printing';
    if (seq == 'PRINT_FIRST_THEN_EMBROIDERY') return 'Printing First, Then Embroidery';
    return seq;
  }

  Map<String, dynamic> _parseTechPackMetadata(String? rawFabric) {
    if (rawFabric == null || rawFabric.trim().isEmpty) {
      return {'fabric': '100% Combed Cotton Single Jersey', 'materials': []};
    }
    String cleanFabric = rawFabric;
    List<dynamic> materials = [];

    final bomMatch = RegExp(r'\[BOM_JSON:\s*(\[[\s\S]*?\])\]', caseSensitive: false).firstMatch(cleanFabric);
    if (bomMatch != null && bomMatch.group(1) != null) {
      try {
        materials = (jsonDecode(bomMatch.group(1)!) as List<dynamic>);
      } catch (_) {}
      cleanFabric = cleanFabric.replaceAll(bomMatch.group(0)!, '');
    }

    cleanFabric = cleanFabric.replaceAll(RegExp(r'\[TARGET_CUT_DATE:[^\]]*\]', caseSensitive: false), '');
    cleanFabric = cleanFabric.replaceAll(RegExp(r'\[INSTRUCTIONS:[^\]]*\]', caseSensitive: false), '');
    cleanFabric = cleanFabric.replaceAll(RegExp(r'\[[A-Z_]+:[^\]]*\]', caseSensitive: false), '');
    cleanFabric = cleanFabric.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleanFabric.isEmpty) {
      cleanFabric = '100% Combed Cotton Single Jersey';
    }

    return {
      'fabric': cleanFabric,
      'materials': materials,
    };
  }

  List<Map<String, String>> _resolveMaterials(MerchandisingOrder ord, TechPackArticleItem? matchedTp) {
    if (ord.bomMaterials.isNotEmpty) {
      return ord.bomMaterials.map((m) {
        if (m is Map) {
          return {
            'component_type': m['component_type']?.toString() ?? 'Material',
            'item_name': m['item_name']?.toString() ?? '-',
            'consumption': m['consumption']?.toString() ?? '-',
            'placement': m['placement']?.toString() ?? '-',
          };
        }
        return {
          'component_type': 'Material',
          'item_name': m.toString(),
          'consumption': '1 PC/pc',
          'placement': 'Garment Assembly',
        };
      }).toList();
    }

    // Parse from fabric metadata
    final parsed = _parseTechPackMetadata(matchedTp?.fabricComposition ?? ord.fabricComposition);
    final rawMats = parsed['materials'] as List<dynamic>;
    if (rawMats.isNotEmpty) {
      return rawMats.map((m) {
        if (m is Map) {
          return {
            'component_type': m['component_type']?.toString() ?? 'Material',
            'item_name': m['item_name']?.toString() ?? '-',
            'consumption': m['consumption']?.toString() ?? '-',
            'placement': m['placement']?.toString() ?? '-',
          };
        }
        return {
          'component_type': 'Material',
          'item_name': m.toString(),
          'consumption': '1 PC/pc',
          'placement': 'Garment Assembly',
        };
      }).toList();
    }

    // Standard Apparel BOM Default matching Web
    return [
      {
        'component_type': 'Shell Fabric',
        'item_name': '100% Combed Cotton Single Jersey',
        'consumption': '1.45 MTR/pc',
        'placement': 'Front, Back Body & Sleeves',
      },
      {
        'component_type': '1x1 Rib Trim',
        'item_name': '95% Cotton 5% Spandex 1x1 Tubular Rib',
        'consumption': '0.15 MTR/pc',
        'placement': 'Crew Neck Collar & Cuffs',
      },
      {
        'component_type': 'Sewing Thread',
        'item_name': '40/2 Spun Polyester High-Tenacity Thread',
        'consumption': '120 MTR/pc',
        'placement': 'All Seams, Overlock & Hem',
      },
      {
        'component_type': 'Main Label',
        'item_name': 'Woven Satin Damask Heat-Cut Soft Label',
        'consumption': '1.00 PC/pc',
        'placement': 'Inside Center Back Neck',
      },
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(merchandisingProvider);
    final matchedTp = state.techPackArticles.where((tp) {
      return tp.id == order.techPackId ||
          tp.styleNumber.trim().toUpperCase() == order.styleRef.trim().toUpperCase();
    }).firstOrNull;

    final effectiveCadFront = order.cadFrontUrl ?? matchedTp?.cadFrontUrl;
    final effectiveCadBack = order.cadBackUrl ?? matchedTp?.cadBackUrl;
    
    final parsedFabricMeta = _parseTechPackMetadata(
      order.fabricComposition.isNotEmpty
          ? order.fabricComposition
          : matchedTp?.fabricComposition,
    );
    final effectiveFabric = parsedFabricMeta['fabric'] as String;
    final effectiveGsm = order.targetGsm > 0 ? order.targetGsm : (matchedTp?.targetGsm ?? 180);
    final effectiveSeq = order.embellishmentSequence.isNotEmpty && order.embellishmentSequence != 'NONE'
        ? order.embellishmentSequence
        : (matchedTp?.embellishmentSequence ?? order.embellishmentSequence);

    final currencySymbol = order.currency == 'USD' ? '\$' : order.currency == 'EUR' ? '€' : '₹';
    final materials = _resolveMaterials(order, matchedTp);

    // Compute column totals for colorway matrix
    final matrix = order.colorMatrix;
    final Map<String, int> columnTotals = {};
    for (final s in defaultSizes) {
      columnTotals[s] = matrix.fold<int>(0, (sum, row) => sum + (row.sizes[s] ?? 0));
    }
    final int grandTotal = matrix.fold<int>(0, (sum, row) => sum + row.total);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EC), // Warm Cream Canvas
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4EC),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: const Icon(Icons.work_outline, color: Color(0xFF332B6B), size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEBF9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'BUYER PO SPECIFICATION',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF332B6B),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          order.poNumber,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF9B9A94),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.brandName} • ${order.styleRef}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6A65), size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =========================================================
            // 1. STATS BLOCK (2-up top + 1 full-width below)
            // =========================================================
            Row(
              children: [
                // Stat 1: Total Ordered Volume
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F4EC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL ORDERED VOLUME',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6B6A65),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            text: order.totalQuantity.toString(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1A),
                            ),
                            children: [
                              TextSpan(
                                text: ' Pcs',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B6A65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Contracted piece volume',
                          style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF9B9A94)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Stat 2: Unit FOB & Contract Value
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F4EC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UNIT FOB & CONTRACT VALUE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6B6A65),
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$currencySymbol${order.unitFobPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1C1C1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total: $currencySymbol${order.totalContractValue >= 100000 ? '${(order.totalContractValue / 100000).toStringAsFixed(2)}L' : order.totalContractValue.toStringAsFixed(0)}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6B6A65),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Stat 3: Target Ex-Factory Date (Full-width)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F4EC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TARGET EX-FACTORY DATE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6B6A65),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF332B6B)),
                          const SizedBox(width: 6),
                          Text(
                            order.exFactoryDate.isNotEmpty ? order.exFactoryDate : 'TBD',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF332B6B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F7EE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x331B7A43)),
                    ),
                    child: Text(
                      'STATUS: ${order.statusLabel.toUpperCase()}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B7A43),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // =========================================================
            // 2. ATTACHED DESIGN REFERENCE & CAD ARTWORK CARD
            // =========================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.image_outlined, size: 17, color: Color(0xFF332B6B)),
                      const SizedBox(width: 8),
                      Text(
                        'ATTACHED DESIGN REFERENCE & CAD ARTWORK',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1C1C1A),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      // Front View Tile
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F4EC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                height: 110,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0x0D000000)),
                                ),
                                child: effectiveCadFront != null && effectiveCadFront.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          effectiveCadFront,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => _buildCadPlaceholder('Front Sketch'),
                                        ),
                                      )
                                    : _buildCadPlaceholder('Front Sketch'),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'FRONT VIEW DESIGN',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF6B6A65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Back View Tile
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F4EC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A000000)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                height: 110,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0x0D000000)),
                                ),
                                child: effectiveCadBack != null && effectiveCadBack.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          effectiveCadBack,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => _buildCadPlaceholder('Back Sketch'),
                                        ),
                                      )
                                    : _buildCadPlaceholder('Back Sketch'),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'BACK VIEW DESIGN',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF6B6A65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // =========================================================
            // 3. GARMENT BLUEPRINT & PRODUCTION ROUTING CARD
            // =========================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checkroom_outlined, size: 18, color: Color(0xFF332B6B)),
                      const SizedBox(width: 8),
                      Text(
                        'GARMENT BLUEPRINT & PRODUCTION ROUTING',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Style Description (Left Column)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STYLE DESCRIPTION',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                order.styleName.isNotEmpty ? order.styleName : '${order.styleRef} Apparel',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$effectiveFabric${effectiveGsm > 0 ? ' • $effectiveGsm GSM' : ''}',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF475569),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Embellishment Flow (Right Column)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EMBELLISHMENT FLOW',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F0),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0x1A000000)),
                                ),
                                child: Text(
                                  _formatEmbellishmentSequence(effectiveSeq),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF332B6B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // =========================================================
            // 4. BILL OF MATERIALS (BOM) & TRIMS CARD
            // =========================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 17, color: Color(0xFF332B6B)),
                          const SizedBox(width: 8),
                          Text(
                            'BILL OF MATERIALS (BOM) & TRIMS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1C1C1A),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F4EC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: Text(
                          '${materials.length} Items',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF332B6B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stacked BOM Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: materials.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final mat = materials[idx];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAF8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Component & Description & Placement
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mat['component_type'] ?? 'Material',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1C1C1A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mat['item_name'] ?? '-',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 11,
                                      color: const Color(0xFF6B6A65),
                                    ),
                                  ),
                                  if (mat['placement'] != null && mat['placement'] != '-') ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      mat['placement']!,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        color: const Color(0xFF9B9A94),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Right: Quantity / Consumption
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0x1A000000)),
                              ),
                              child: Text(
                                mat['consumption'] ?? '1 PC/pc',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF332B6B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // =========================================================
            // 5. COLORWAY & SIZE BREAKDOWN MATRIX CARD
            // =========================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette_outlined, size: 17, color: Color(0xFF332B6B)),
                      const SizedBox(width: 8),
                      Text(
                        'COLORWAY & SIZE BREAKDOWN MATRIX',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1C1C1A),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fixed-width Table (No horizontal scroll)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.6), // Colorway
                        1: FlexColumnWidth(1.1), // XS
                        2: FlexColumnWidth(1.1), // S
                        3: FlexColumnWidth(1.1), // M
                        4: FlexColumnWidth(1.1), // L
                        5: FlexColumnWidth(1.1), // XL
                        6: FlexColumnWidth(1.7), // Total
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        // Table Header
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFF7F4EC)),
                          children: [
                            _buildTableHeaderCell('Colorway', align: TextAlign.left),
                            ...defaultSizes.map((s) => _buildTableHeaderCell(s)),
                            _buildTableHeaderCell('Total', align: TextAlign.right),
                          ],
                        ),

                        // Data Rows
                        ...matrix.map((row) {
                          return TableRow(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(bottom: BorderSide(color: Color(0x0D000000))),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Text(
                                  row.color,
                                  style: GoogleFonts.publicSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1C1C1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...defaultSizes.map((s) {
                                final qty = row.sizes[s] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    '$qty',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      color: const Color(0xFF6B6A65),
                                    ),
                                  ),
                                );
                              }),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Text(
                                  '${row.total}',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF332B6B),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),

                        // Totals Row
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFF7F4EC)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Text(
                                'TOTAL',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1C1C1A),
                                ),
                              ),
                            ),
                            ...defaultSizes.map((s) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  '${columnTotals[s] ?? 0}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1C1C1A),
                                  ),
                                ),
                              );
                            }),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Text(
                                '$grandTotal Pcs',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF332B6B),
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
            ),
            const SizedBox(height: 20),

            // =========================================================
            // 6. CLOSE SPECIFICATION BUTTON
            // =========================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF241D52),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close Specification',
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF6B6A65),
        ),
      ),
    );
  }

  Widget _buildCadPlaceholder(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.checkroom_outlined, size: 30, color: Color(0xFFB6B4AC)),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF9B9A94)),
          ),
        ],
      ),
    );
  }
}
