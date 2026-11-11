import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_section_header.dart';
import '../models/buyers_vendors_models.dart';
import '../providers/buyers_vendors_provider.dart';

// ============================================================================
// SHARED MODAL HELPERS
// ============================================================================

Widget _buildModalHandle() {
  return Center(
    child: Container(
      width: 42,
      height: 4,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

Widget _buildFieldLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: zigzaBodyStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.headingObsidian,
      ),
    ),
  );
}

Widget _buildTextField({
  required TextEditingController controller,
  required String hint,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  TextCapitalization textCapitalization = TextCapitalization.none,
  int maxLines = 1,
  int? maxLength,
  ValueChanged<String>? onChanged,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    maxLines: maxLines,
    maxLength: maxLength,
    onChanged: onChanged,
    style: zigzaBodyStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: AppTheme.headingObsidian,
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: zigzaBodyStyle(fontSize: 13, color: AppTheme.faintInk),
      counterText: '',
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 18, color: AppTheme.faintInk)
          : null,
      filled: true,
      fillColor: AppTheme.bgCanvas,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: AppTheme.headingObsidian, width: 1.4),
      ),
    ),
  );
}

Widget _buildErrorBanner(String message) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.badgeRoseBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.badgeRoseBorder),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.badgeRoseText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: zigzaBodyStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.badgeRoseText,
            ),
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// 1. ARTICLE & CONTRACT DETAIL MODAL ("View More" — 3 Tabs)
// ============================================================================

Future<void> showArticleContractDetailSheet(
  BuildContext context, {
  required BuyerArticleHistory article,
  required String buyerName,
  String? buyerContact,
  String? buyerPhone,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ArticleContractDetailSheet(
      article: article,
      buyerName: buyerName,
      buyerContact: buyerContact,
      buyerPhone: buyerPhone,
    ),
  );
}

class _ArticleContractDetailSheet extends StatefulWidget {
  final BuyerArticleHistory article;
  final String buyerName;
  final String? buyerContact;
  final String? buyerPhone;

  const _ArticleContractDetailSheet({
    required this.article,
    required this.buyerName,
    this.buyerContact,
    this.buyerPhone,
  });

  @override
  State<_ArticleContractDetailSheet> createState() => _ArticleContractDetailSheetState();
}

class _ArticleContractDetailSheetState extends State<_ArticleContractDetailSheet> {
  String _activeTab = 'progress'; // 'progress' | 'contract' | 'techpack'
  final NumberFormat _numFmt = NumberFormat('#,##,###', 'en_IN');

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final assigned = article.assignedQty;
    final delivered = article.deliveredQty;
    final remaining = (assigned - delivered) < 0 ? 0 : (assigned - delivered);
    final percent = assigned > 0 ? ((delivered / assigned) * 100).round().clamp(0, 100) : 0;

    final rawFabric = article.techPack.fabricComposition.isNotEmpty
        ? article.techPack.fabricComposition
        : article.fabricType;
    final parsed = parseFabricAndBom(rawFabric);
    final effectiveBom = article.techPack.bomMaterials.isNotEmpty
        ? article.techPack.bomMaterials
        : parsed.materials;

    final contract = article.contract;
    final currencySymbol =
        contract.currency == 'EUR' ? '€' : (contract.currency == 'INR' ? '₹' : '\$');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModalHandle(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mintSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.badgeMintBorder),
                                  ),
                                  child: Text(
                                    article.artNo,
                                    style: zigzaHeadingStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: article.sourceType == 'MERCHANDISING_PO'
                                        ? const Color(0xFFF3E8FF)
                                        : AppTheme.subtleDivider,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: article.sourceType == 'MERCHANDISING_PO'
                                          ? const Color(0xFFD8B4FE)
                                          : AppTheme.borderLight,
                                    ),
                                  ),
                                  child: Text(
                                    article.sourceType == 'MERCHANDISING_PO'
                                        ? 'Merchandising PO'
                                        : 'Floor Challan',
                                    style: zigzaBodyStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: article.sourceType == 'MERCHANDISING_PO'
                                          ? const Color(0xFF7E22CE)
                                          : AppTheme.headingObsidian,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${article.sourceType == 'MERCHANDISING_PO' ? 'PO' : 'CH'} #${article.challanNo}',
                                  style: zigzaHeadingStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.bodyInk,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.buyerName,
                              style: zigzaHeadingStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            if (article.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                article.description,
                                style: zigzaBodyStyle(fontSize: 12, color: AppTheme.faintInk),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.bodyInk),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3-Tab Switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.bgCanvas,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  children: [
                    _buildTabPill('progress', 'Live Review', Icons.trending_up_rounded),
                    _buildTabPill('contract', 'Contract', Icons.description_outlined),
                    _buildTabPill('techpack', 'Tech Pack', Icons.design_services_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.borderLight),

            // Scrollable Tab Body
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: _activeTab == 'progress'
                    ? _buildProgressTab(assigned, delivered, remaining, percent)
                    : _activeTab == 'contract'
                        ? _buildContractTab(assigned, currencySymbol, contract)
                        : _buildTechPackTab(parsed.cleanFabric, effectiveBom),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill(String key, String label, IconData icon) {
    final selected = _activeTab == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected ? Border.all(color: AppTheme.borderLight) : null,
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? AppTheme.brandRoyalBlue : AppTheme.bodyInk,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zigzaBodyStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? AppTheme.headingObsidian : AppTheme.bodyInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressTab(int assigned, int delivered, int remaining, int percent) {
    final fr = widget.article.floorReview;
    final stages = [
      ('1. In Pending', fr.inPending),
      ('2. In Cutting', fr.inCutting),
      ('3. In Printing', fr.inPrinting),
      ('4. In Embroidery', fr.inEmbroidery),
      ('5. In Sewing', fr.inSewing),
      ('6. Iron', fr.iron),
      ('7. Washing', fr.washing),
      ('8. Alter', fr.alter),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Review Header Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZigzaSectionHeader(
                icon: Icons.trending_up_rounded,
                title: 'Live',
                accent: 'Review',
                badge: '${_numFmt.format(assigned)} pcs',
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stages.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.55,
                ),
                itemBuilder: (ctx, i) {
                  final stage = stages[i];
                  final pct = assigned > 0 ? ((stage.$2 / assigned) * 100).round() : 0;
                  return Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCanvas,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                stage.$1.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: zigzaBodyStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.bodyInk,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.mintSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.badgeMintBorder),
                              ),
                              child: Text(
                                '$pct%',
                                style: zigzaHeadingStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _numFmt.format(stage.$2),
                          style: zigzaHeadingStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (pct / 100).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: AppTheme.borderLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.brandRoyalBlue),
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

        // Outward Gate Delivery Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCanvas,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_rounded, size: 16, color: Color(0xFF0F766E)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Outward Gate Delivery',
                            style: zigzaHeadingStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_numFmt.format(delivered)} / ${_numFmt.format(assigned)} ($percent%)',
                    style: zigzaHeadingStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (percent / 100).clamp(0.0, 1.0),
                  minHeight: 9,
                  backgroundColor: AppTheme.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percent >= 100
                        ? AppTheme.badgeEmeraldText
                        : (percent > 50 ? AppTheme.brandMint : AppTheme.brandRoyalBlue),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildGateMiniCard('Contracted', '${_numFmt.format(assigned)} pcs', AppTheme.headingObsidian),
                  const SizedBox(width: 8),
                  _buildGateMiniCard('Delivered', '${_numFmt.format(delivered)} pcs', AppTheme.badgeEmeraldText),
                  const SizedBox(width: 8),
                  _buildGateMiniCard('In WIP', '${_numFmt.format(remaining)} pcs', AppTheme.badgeAmberText),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGateMiniCard(String label, String value, Color valColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: zigzaBodyStyle(fontSize: 10.5, color: AppTheme.faintInk, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              textAlign: TextAlign.center,
              style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: valColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractTab(int assigned, String currencySymbol, BuyerContractSpec contract) {
    final defaultSizes = ['XS', 'S', 'M', 'L', 'XL'];
    final customSizes = <String>{};
    for (final row in contract.colorMatrix) {
      for (final s in row.sizes.keys) {
        if (!defaultSizes.contains(s)) customSizes.add(s);
      }
    }
    final sizeCols = [...defaultSizes, ...customSizes];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Contract Metrics
        Row(
          children: [
            Expanded(
              child: _buildContractStatCard(
                'Ordered Volume',
                '${_numFmt.format(assigned)} Pcs',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildContractStatCard(
                'Unit FOB',
                '$currencySymbol${contract.fobPrice.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildContractStatCard(
                'Total Contract Value',
                '$currencySymbol${_numFmt.format(contract.totalContractValue.round())}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildContractStatCard(
                'Ex-Factory Date',
                contract.deliveryDate.isNotEmpty ? contract.deliveryDate : 'As scheduled',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Colorway & Size Matrix
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZigzaSectionHeader(
                icon: Icons.palette_outlined,
                title: 'Colorway &',
                accent: 'Size Matrix',
                badge: '${contract.colorMatrix.length} Rows',
              ),
              const SizedBox(height: 10),
              if (contract.colorMatrix.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCanvas,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Colorway: ${widget.article.colorPattern} • Size Ratio: ${widget.article.sizeRange} (${_numFmt.format(assigned)} Pcs)',
                    style: zigzaBodyStyle(fontSize: 12, color: AppTheme.bodyInk),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 42,
                    horizontalMargin: 10,
                    columnSpacing: 16,
                    headingRowColor: WidgetStateProperty.all(AppTheme.bgCanvas),
                    columns: [
                      DataColumn(
                        label: Text('COLORWAY',
                            style: zigzaHeadingStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                      ...sizeCols.map(
                        (s) => DataColumn(
                          numeric: true,
                          label: Text(s,
                              style: zigzaHeadingStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      DataColumn(
                        numeric: true,
                        label: Text('TOTAL',
                            style: zigzaHeadingStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                    rows: contract.colorMatrix.map((r) {
                      return DataRow(
                        cells: [
                          DataCell(Text(r.color,
                              style: zigzaBodyStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.headingObsidian))),
                          ...sizeCols.map(
                            (s) => DataCell(
                              Text(
                                _numFmt.format(r.sizes[s] ?? 0),
                                style: zigzaBodyStyle(fontSize: 12, color: AppTheme.bodyInk),
                              ),
                            ),
                          ),
                          DataCell(Text(
                            _numFmt.format(r.total),
                            style: zigzaHeadingStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Commercial Terms
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCanvas,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZigzaSectionHeader(
                icon: Icons.description_outlined,
                title: 'Commercial',
                accent: 'Terms',
              ),
              const SizedBox(height: 10),
              _buildTermRow('Contract / PO No.', widget.article.challanNo),
              _buildTermRow(
                  'Contract Date',
                  widget.article.contractDate.isNotEmpty
                      ? widget.article.contractDate
                      : 'N/A'),
              _buildTermRow('Buyer Entity', widget.buyerName),
              _buildTermRow(
                  'Delivery Ex-Factory',
                  widget.article.deliveryDate.isNotEmpty
                      ? widget.article.deliveryDate
                      : 'As scheduled'),
              if (widget.article.challanNotes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.badgeAmberBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.badgeAmberBorder),
                  ),
                  child: Text(
                    'Remarks: ${widget.article.challanNotes}',
                    style: zigzaBodyStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.badgeAmberText,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContractStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: zigzaBodyStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.faintInk),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: zigzaHeadingStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildTermRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: zigzaBodyStyle(fontSize: 12, color: AppTheme.faintInk)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechPackTab(String cleanFabric, List<ParsedBomMaterial> bom) {
    final tp = widget.article.techPack;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Master Spec Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCanvas,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MASTER TECHNICAL SPECIFICATION',
                style: zigzaBodyStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.faintInk),
              ),
              const SizedBox(height: 4),
              Text(
                '${tp.styleNumber} • ${tp.category}',
                style: zigzaHeadingStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Fabric: $cleanFabric • Target GSM: ${tp.targetGsm} GSM',
                style: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.bodyInk, height: 1.4),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.badgeMintBorder),
                ),
                child: Text(
                  formatEmbellishmentSequence(tp.embellishmentSequence),
                  style: zigzaBodyStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.headingObsidian,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // CAD Drawings Preview
        if (tp.cadFrontUrl.isNotEmpty || tp.cadBackUrl.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ZigzaSectionHeader(
                  icon: Icons.image_outlined,
                  title: 'CAD',
                  accent: 'Drawings',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (tp.cadFrontUrl.isNotEmpty)
                      Expanded(child: _buildCadTile('Front CAD Sketch', tp.cadFrontUrl)),
                    if (tp.cadFrontUrl.isNotEmpty && tp.cadBackUrl.isNotEmpty)
                      const SizedBox(width: 10),
                    if (tp.cadBackUrl.isNotEmpty)
                      Expanded(child: _buildCadTile('Back CAD Sketch', tp.cadBackUrl)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // BOM & Trims
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZigzaSectionHeader(
                icon: Icons.inventory_2_outlined,
                title: 'BOM &',
                accent: 'Trims',
                badge: '${bom.length} ${bom.length == 1 ? 'Item' : 'Items'}',
              ),
              const SizedBox(height: 10),
              if (bom.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No additional BOM trims recorded for this tech pack.',
                    style: zigzaBodyStyle(fontSize: 12, color: AppTheme.faintInk),
                  ),
                )
              else
                ...bom.map((mat) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCanvas,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mat.componentType,
                                style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${mat.itemName} • Placement: ${mat.placement}',
                                style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Text(
                            mat.consumption,
                            style: zigzaHeadingStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Construction Notes
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCanvas,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONSTRUCTION & SEAM NOTES',
                style: zigzaBodyStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.faintInk),
              ),
              const SizedBox(height: 4),
              Text(
                tp.constructionNotes.isNotEmpty
                    ? tp.constructionNotes
                    : 'Standard 4-thread overlock with 1/4" margin. Double-needle bottom hem and sleeve cuffs.',
                style: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.bodyInk, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCadTile(String label, String url) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              height: 110,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 110,
                child: Center(
                  child: Icon(Icons.broken_image_outlined, color: AppTheme.faintInk, size: 32),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: zigzaBodyStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.bodyInk),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. ADD / EDIT BUYER PROFILE MODAL
// ============================================================================

Future<bool?> showAddEditBuyerSheet(
  BuildContext context, {
  BuyerItem? buyer,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddEditBuyerSheet(buyer: buyer),
  );
}

class _AddEditBuyerSheet extends ConsumerStatefulWidget {
  final BuyerItem? buyer;

  const _AddEditBuyerSheet({this.buyer});

  @override
  ConsumerState<_AddEditBuyerSheet> createState() => _AddEditBuyerSheetState();
}

class _AddEditBuyerSheetState extends ConsumerState<_AddEditBuyerSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _personCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _addressCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = widget.buyer;
    _nameCtrl = TextEditingController(text: b?.brandName ?? '');
    _codeCtrl = TextEditingController(text: b?.brandCode ?? '');
    _personCtrl = TextEditingController(text: b?.contactPerson ?? '');
    _phoneCtrl = TextEditingController(text: b?.phone ?? '');
    _emailCtrl = TextEditingController(text: b?.email ?? '');
    _cityCtrl = TextEditingController(text: b?.city ?? '');
    _gstCtrl = TextEditingController(text: b?.gstin ?? '');
    _addressCtrl = TextEditingController(text: b?.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _personCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _gstCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final name = _nameCtrl.text.trim().toUpperCase();
    final person = _personCtrl.text.trim();
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final phone = digits.length > 10 ? digits.substring(digits.length - 10) : digits;

    if (name.isEmpty) {
      setState(() => _error = 'Please enter Buyer / Company Name.');
      return;
    }
    if (person.isEmpty) {
      setState(() => _error = 'Please enter Contact Person Name.');
      return;
    }
    if (phone.length < 10) {
      setState(() => _error = 'Please enter a valid 10-digit mobile number.');
      return;
    }

    final res = await ref.read(buyersVendorsProvider.notifier).createOrUpdateBuyer(
          existingId: widget.buyer?.id,
          brandName: name,
          brandCode: _codeCtrl.text.trim(),
          contactPerson: person,
          phone: phone,
          email: _emailCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          gstin: _gstCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
        );

    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = res.error ?? 'Failed to save buyer profile.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.buyer != null;
    final isSubmitting = ref.watch(buyersVendorsProvider.select((s) => s.isSubmitting));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModalHandle(),
            ZigzaSectionHeader(
              icon: Icons.business_rounded,
              title: isEditing ? 'Edit' : 'Add',
              accent: isEditing ? 'Buyer Profile' : 'New Buyer',
              action: IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.bodyInk, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null) _buildErrorBanner(_error!),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFieldLabel('Buyer / Brand Name *'),
                    _buildTextField(
                      controller: _nameCtrl,
                      hint: 'e.g. OLLYPOP',
                      prefixIcon: Icons.storefront_outlined,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Contact Person *'),
                              _buildTextField(
                                controller: _personCtrl,
                                hint: 'Full name',
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Buyer Code'),
                              _buildTextField(
                                controller: _codeCtrl,
                                hint: 'e.g. OP',
                                prefixIcon: Icons.tag_rounded,
                                textCapitalization: TextCapitalization.characters,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel('Mobile Number *'),
                    _buildTextField(
                      controller: _phoneCtrl,
                      hint: '10-digit mobile number',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('City / State'),
                              _buildTextField(
                                controller: _cityCtrl,
                                hint: 'e.g. Mumbai, MH',
                                prefixIcon: Icons.location_on_outlined,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('GSTIN (Optional)'),
                              _buildTextField(
                                controller: _gstCtrl,
                                hint: '15-char GSTIN',
                                prefixIcon: Icons.verified_outlined,
                                textCapitalization: TextCapitalization.characters,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel('Email (Optional)'),
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: 'buyer@company.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel('Billing / Office Address (Optional)'),
                    _buildTextField(
                      controller: _addressCtrl,
                      hint: 'Street, Industrial Estate, PIN',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandRoyalBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: isSubmitting ? null : _submit,
              child: isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isEditing ? 'Save Changes' : 'Register Buyer',
                      style: zigzaBodyStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. ASSIGN / EDIT MODULE VENDOR MODAL
// ============================================================================

Future<String?> showAssignVendorSheet(
  BuildContext context, {
  required ModuleVendorItem moduleItem,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AssignVendorSheet(moduleItem: moduleItem),
  );
}

class _AssignVendorSheet extends ConsumerStatefulWidget {
  final ModuleVendorItem moduleItem;

  const _AssignVendorSheet({required this.moduleItem});

  @override
  ConsumerState<_AssignVendorSheet> createState() => _AssignVendorSheetState();
}

class _AssignVendorSheetState extends ConsumerState<_AssignVendorSheet> {
  late final TextEditingController _companyCtrl;
  late final TextEditingController _personCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final v = widget.moduleItem.assignedVendor;
    _companyCtrl = TextEditingController(text: v?.companyName ?? '');
    _personCtrl = TextEditingController(text: v?.contactPerson ?? '');
    _phoneCtrl = TextEditingController(text: v?.phone ?? '');
    _notesCtrl = TextEditingController(text: v?.notes ?? '');
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _personCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final res = await ref.read(buyersVendorsProvider.notifier).assignModuleVendor(
          moduleItem: widget.moduleItem,
          companyName: _companyCtrl.text,
          contactPerson: _personCtrl.text,
          phone: _phoneCtrl.text,
          notes: _notesCtrl.text,
        );
    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context, 'assigned');
    } else {
      setState(() => _error = res.error ?? 'Failed to assign vendor.');
    }
  }

  Future<void> _remove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Vendor',
          style: zigzaHeadingStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Remove assigned vendor from ${widget.moduleItem.moduleName}?',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final res = await ref
        .read(buyersVendorsProvider.notifier)
        .removeModuleVendor(widget.moduleItem.moduleRoute);
    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context, 'removed');
    } else {
      setState(() => _error = res.error ?? 'Failed to remove vendor.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.moduleItem.assignedVendor != null;
    final isSubmitting = ref.watch(buyersVendorsProvider.select((s) => s.isSubmitting));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModalHandle(),
            ZigzaSectionHeader(
              icon: iconDataForModuleIconName(widget.moduleItem.iconName),
              title: isEditing ? 'Edit' : 'Assign',
              accent: 'Vendor',
              badge: widget.moduleItem.moduleCode,
              action: IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.bodyInk, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.moduleItem.moduleName,
              style: zigzaHeadingStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_error != null) _buildErrorBanner(_error!),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFieldLabel('Vendor Company Name *'),
                    _buildTextField(
                      controller: _companyCtrl,
                      hint: 'e.g. Shanti Embroidery Works',
                      prefixIcon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel('Contact Person *'),
                    _buildTextField(
                      controller: _personCtrl,
                      hint: 'Representative / Master name',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel('Mobile Number *'),
                    _buildTextField(
                      controller: _phoneCtrl,
                      hint: '10-digit mobile number',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel('Scope / Contract Notes (Optional)'),
                    _buildTextField(
                      controller: _notesCtrl,
                      hint: 'Per-piece job work rate, capacity, turnaround terms...',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (isEditing) ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.badgeRoseText,
                      side: const BorderSide(color: AppTheme.badgeRoseBorder),
                      backgroundColor: AppTheme.badgeRoseBg,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSubmitting ? null : _remove,
                    child: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandRoyalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isEditing ? 'Save Vendor' : 'Assign Vendor',
                            style: zigzaBodyStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. ADD CUSTOM MODULE MODAL
// ============================================================================

Future<String?> showAddCustomModuleSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AddCustomModuleSheet(),
  );
}

class _AddCustomModuleSheet extends ConsumerStatefulWidget {
  const _AddCustomModuleSheet();

  @override
  ConsumerState<_AddCustomModuleSheet> createState() => _AddCustomModuleSheetState();
}

class _AddCustomModuleSheetState extends ConsumerState<_AddCustomModuleSheet> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _desigCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _vendorCompCtrl = TextEditingController();
  final _vendorPersonCtrl = TextEditingController();
  final _vendorPhoneCtrl = TextEditingController();
  final _vendorNotesCtrl = TextEditingController();

  String _selectedIcon = 'Layers';
  bool _assignVendorNow = false;
  bool _codeTouched = false;
  bool _desigTouched = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _desigCtrl.dispose();
    _descCtrl.dispose();
    _vendorCompCtrl.dispose();
    _vendorPersonCtrl.dispose();
    _vendorPhoneCtrl.dispose();
    _vendorNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final modName = _nameCtrl.text.trim();
    if (modName.isEmpty) {
      setState(() => _error = 'Please enter a valid Module Name.');
      return;
    }

    if (_assignVendorNow) {
      final vc = _vendorCompCtrl.text.trim();
      final vp = _vendorPersonCtrl.text.trim();
      final digits = _vendorPhoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      final phone = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
      if (vc.isEmpty) {
        setState(() => _error = 'Please enter Vendor Company Name or toggle off vendor assignment.');
        return;
      }
      if (vp.isEmpty) {
        setState(() => _error = 'Please enter Contact Person Name.');
        return;
      }
      if (phone.length < 10) {
        setState(() => _error = 'Please enter a valid 10-digit mobile number.');
        return;
      }
    }

    final res = await ref.read(buyersVendorsProvider.notifier).createCustomModule(
          moduleName: modName,
          moduleCode: _codeCtrl.text.trim(),
          defaultDesignation: _desigCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          iconName: _selectedIcon,
          vendorCompanyName: _assignVendorNow ? _vendorCompCtrl.text.trim() : null,
          contactPerson: _assignVendorNow ? _vendorPersonCtrl.text.trim() : null,
          phone: _assignVendorNow ? _vendorPhoneCtrl.text.trim() : null,
          vendorNotes: _assignVendorNow ? _vendorNotesCtrl.text.trim() : null,
        );

    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context, modName);
    } else {
      setState(() => _error = res.error ?? 'Failed to create custom module.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(buyersVendorsProvider.select((s) => s.isSubmitting));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModalHandle(),
            ZigzaSectionHeader(
              icon: Icons.add_box_outlined,
              title: 'Add Custom',
              accent: 'Module',
              action: IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.bodyInk, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null) _buildErrorBanner(_error!),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFieldLabel('Module Name *'),
                    _buildTextField(
                      controller: _nameCtrl,
                      hint: 'e.g. Kaj-Button Station',
                      prefixIcon: Icons.layers_outlined,
                      onChanged: (val) {
                        final cleaned = val.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
                        if (cleaned.isNotEmpty) {
                          if (!_codeTouched) {
                            _codeCtrl.text =
                                (cleaned.length > 4 ? cleaned.substring(0, 4) : cleaned)
                                    .toUpperCase();
                          }
                          if (!_desigTouched) {
                            _desigCtrl.text = '$val In-Charge';
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Module Code'),
                              _buildTextField(
                                controller: _codeCtrl,
                                hint: 'e.g. KAJ',
                                textCapitalization: TextCapitalization.characters,
                                onChanged: (_) => _codeTouched = true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Station Designation'),
                              _buildTextField(
                                controller: _desigCtrl,
                                hint: 'Station Head / In-Charge',
                                onChanged: (_) => _desigTouched = true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel('Operational Description'),
                    _buildTextField(
                      controller: _descCtrl,
                      hint: 'Key responsibilities of this floor unit...',
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel('Select Module Icon'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kAvailableModuleIcons.map((opt) {
                        final selected = _selectedIcon == opt.name;
                        return InkWell(
                          onTap: () => setState(() => _selectedIcon = opt.name),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selected ? AppTheme.mintSurface : AppTheme.bgCanvas,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? AppTheme.brandRoyalBlue : AppTheme.borderLight,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Icon(
                              opt.icon,
                              size: 20,
                              color: selected ? AppTheme.brandRoyalBlue : AppTheme.bodyInk,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Optional vendor toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Assign Job-Work Vendor Now',
                            style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Switch.adaptive(
                            value: _assignVendorNow,
                            activeTrackColor: AppTheme.brandRoyalBlue,
                            onChanged: (v) => setState(() => _assignVendorNow = v),
                          ),
                        ],
                      ),
                    ),
                    if (_assignVendorNow) ...[
                      const SizedBox(height: 12),
                      _buildFieldLabel('Vendor Company Name *'),
                      _buildTextField(
                        controller: _vendorCompCtrl,
                        hint: 'External job-worker / company',
                        prefixIcon: Icons.business_outlined,
                      ),
                      const SizedBox(height: 10),
                      _buildFieldLabel('Contact Person *'),
                      _buildTextField(
                        controller: _vendorPersonCtrl,
                        hint: 'Representative name',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 10),
                      _buildFieldLabel('Mobile Number *'),
                      _buildTextField(
                        controller: _vendorPhoneCtrl,
                        hint: '10-digit mobile number',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                      ),
                      const SizedBox(height: 10),
                      _buildFieldLabel('Vendor Scope / Notes (Optional)'),
                      _buildTextField(
                        controller: _vendorNotesCtrl,
                        hint: 'Rate or contract terms...',
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandRoyalBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: isSubmitting ? null : _submit,
              child: isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Create Custom Module',
                      style: zigzaBodyStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
