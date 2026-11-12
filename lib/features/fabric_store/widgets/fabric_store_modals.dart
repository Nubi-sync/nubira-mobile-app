import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/fabric_store_models.dart';
import '../providers/fabric_store_provider.dart';

final NumberFormat _inNumFmt = NumberFormat('#,##,###', 'en_IN');

String _fmtNum(num v) {
  if (v == v.roundToDouble()) return _inNumFmt.format(v.round());
  return v.toStringAsFixed(1);
}

InputDecoration _storeFieldDecoration({
  required String hint,
  String? suffixText,
}) {
  return InputDecoration(
    hintText: hint,
    suffixText: suffixText,
    suffixStyle: zigzaBodyStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.faintInk),
    hintStyle: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.faintInk),
    filled: true,
    fillColor: AppTheme.bgCanvas,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AppTheme.borderLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AppTheme.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AppTheme.headingObsidian, width: 1.3),
    ),
  );
}

Future<void> showFabricStoreDetailSheet(
  BuildContext context, {
  FabricAllocationItem? fabric,
  TrimAllocationItem? trim,
  required String companyName,
  VoidCallback? onAssignPressed,
}) async {
  final isFabric = fabric != null;
  if (!isFabric && trim == null) return;

  final itemName = isFabric ? fabric.fabricType : trim!.itemName;
  final categoryOrColor = isFabric ? fabric.color : trim!.category;
  final unit = isFabric ? 'meters' : trim!.unit;
  final double totalStock = isFabric ? fabric.totalMeters : trim!.totalInStore.toDouble();
  final double assignedQty = isFabric ? fabric.bookedMeters : trim!.assignedQuantity.toDouble();
  final double freeQty = isFabric ? fabric.availableMeters : trim!.freeQuantity.toDouble();
  final int allocPercent = isFabric ? fabric.allocationPercentage : trim!.allocationPercentage;
  final String? assignedArticle = isFabric ? fabric.bookedForArticle : trim!.assignedArticle;
  final bool isAssigned = (assignedArticle != null && assignedArticle.isNotEmpty) && assignedQty > 0;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.mintSurface,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: AppTheme.badgeMintBorder),
                          ),
                          child: Center(
                            child: Text(
                              getStoreAvatarInitials(itemName),
                              style: zigzaHeadingStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.headingObsidian,
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
                                      itemName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: zigzaHeadingStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgCanvas,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.borderLight),
                                    ),
                                    child: Text(
                                      categoryOrColor,
                                      style: zigzaHeadingStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.bodyInk,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${isFabric ? 'Godown Fabric Stock' : 'BOM Trim Details'} • $companyName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: AppTheme.bodyInk),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.borderLight),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 3 Metric Tiles
                      Row(
                        children: [
                          Expanded(
                            child: _DetailStatTile(
                              label: 'IN STORE',
                              value: _fmtNum(totalStock),
                              unit: unit,
                              bg: AppTheme.bgCanvas,
                              border: AppTheme.borderLight,
                              valueColor: AppTheme.headingObsidian,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DetailStatTile(
                              label: 'ASSIGNED',
                              value: _fmtNum(assignedQty),
                              unit: unit,
                              bg: const Color(0xFFEFF6FF),
                              border: const Color(0xFFBFDBFE),
                              valueColor: AppTheme.brandRoyalBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DetailStatTile(
                              label: 'FREE LEFT',
                              value: _fmtNum(freeQty),
                              unit: unit,
                              bg: const Color(0xFFECFDF5),
                              border: const Color(0xFFA7F3D0),
                              valueColor: const Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Allocation Progress Card
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        'TARGET ARTICLE: ',
                                        style: zigzaBodyStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.faintInk,
                                        ),
                                      ),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cardSurface,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.borderLight),
                                          ),
                                          child: Text(
                                            isAssigned ? assignedArticle : 'Free Stock',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: zigzaHeadingStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isAssigned ? AppTheme.headingObsidian : AppTheme.bodyInk,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mintSurface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.badgeMintBorder),
                                  ),
                                  child: Text(
                                    '$allocPercent% Allocated',
                                    style: zigzaHeadingStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F766E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_fmtNum(assignedQty)} $unit assigned',
                                  style: zigzaBodyStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.headingObsidian,
                                  ),
                                ),
                                Text(
                                  '${_fmtNum(freeQty)} $unit free',
                                  style: zigzaBodyStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.bodyInk,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (allocPercent / 100).clamp(0.0, 1.0),
                                minHeight: 7,
                                backgroundColor: AppTheme.borderLight,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.brandRoyalBlue),
                              ),
                            ),
                            if (isFabric && fabric.articlePo != null && fabric.articlePo!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: AppTheme.borderLight),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Purchase Order (PO)',
                                    style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk),
                                  ),
                                  Text(
                                    fabric.articlePo!,
                                    style: zigzaHeadingStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Warehouse & Supply Details
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
                              'WAREHOUSE & SUPPLY DETAILS',
                              style: zigzaBodyStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.faintInk,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (isFabric) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Rack Location', style: zigzaBodyStyle(fontSize: 11, color: AppTheme.bodyInk)),
                                        const SizedBox(height: 2),
                                        Text(
                                          fabric.rackLocation,
                                          style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Rolls Count', style: zigzaBodyStyle(fontSize: 11, color: AppTheme.bodyInk)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${fabric.totalRolls} rolls',
                                          style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text('Supplier / Mill', style: zigzaBodyStyle(fontSize: 11, color: AppTheme.bodyInk)),
                              const SizedBox(height: 2),
                              Text(
                                fabric.supplierName,
                                style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              if (fabric.buyerName != null && fabric.buyerName!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Buyer / Brand', style: zigzaBodyStyle(fontSize: 11, color: AppTheme.bodyInk)),
                                const SizedBox(height: 2),
                                Text(
                                  fabric.buyerName!,
                                  style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Category', style: zigzaBodyStyle(fontSize: 11, color: AppTheme.bodyInk)),
                                        const SizedBox(height: 2),
                                        Text(
                                          trim!.category,
                                          style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Unit', style: zigzaBodyStyle(fontSize: 11, color: AppTheme.bodyInk)),
                                        const SizedBox(height: 2),
                                        Text(
                                          trim.unit,
                                          style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (trim.notes != null && trim.notes!.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Notes & Placement', style: zigzaBodyStyle(fontSize: 11, color: AppTheme.bodyInk)),
                                const SizedBox(height: 2),
                                Text(
                                  trim.notes!,
                                  style: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.headingObsidian),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: const BoxDecoration(
                  color: AppTheme.cardSurface,
                  border: Border(top: BorderSide(color: AppTheme.borderLight)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.headingObsidian,
                          side: const BorderSide(color: AppTheme.borderLight),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                        child: Text('Close', style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    if (isFabric && onAssignPressed != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onAssignPressed();
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: Text(
                            'Assign Article',
                            style: zigzaHeadingStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandRoyalBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showAssignFabricSheet(
  BuildContext context,
  WidgetRef ref, {
  required FabricAllocationItem fabric,
  required List<ActiveArticleOption> activeArticles,
  required void Function(String message, {bool isError}) onMessage,
}) async {
  String selectedArticle =
      (fabric.bookedForArticle != null && fabric.bookedForArticle!.isNotEmpty)
          ? fabric.bookedForArticle!
          : (activeArticles.isNotEmpty ? activeArticles.first.artNo : '');

  final knownArtNos = activeArticles.map((a) => a.artNo).toSet();
  String customArticle = '';
  if (selectedArticle.isNotEmpty && !knownArtNos.contains(selectedArticle)) {
    customArticle = selectedArticle;
    selectedArticle = 'CUSTOM';
  }

  final customCtrl = TextEditingController(text: customArticle);
  final initialMeters = fabric.bookedMeters > 0 ? fabric.bookedMeters : fabric.totalMeters;
  final metersCtrl = TextEditingController(text: _fmtNumPlain(initialMeters));
  String? errorMsg;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isSubmitting = ref.watch(fabricStoreProvider).isSubmitting;
          final totalM = fabric.totalMeters;
          final parsedM = double.tryParse(metersCtrl.text.trim()) ?? 0.0;
          final clampedM = parsedM.clamp(0.0, totalM).toDouble();
          final freeM = (totalM - clampedM) > 0 ? (totalM - clampedM) : 0.0;
          final pct = totalM > 0 ? ((clampedM / totalM) * 100).round().clamp(0, 100) : 0;
          final targetArt = selectedArticle == 'CUSTOM' ? customCtrl.text.trim() : selectedArticle.trim();

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.borderLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                child: const Icon(Icons.layers_outlined, color: Color(0xFF0F766E), size: 20),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Assign Cloth to Article',
                                      style: zigzaHeadingStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      '${fabric.fabricType} • ${fabric.color}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close_rounded, color: AppTheme.bodyInk),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderLight),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (errorMsg != null) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.badgeRoseBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  errorMsg!,
                                  style: zigzaBodyStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.badgeRoseText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.bgCanvas,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Total in Store', style: zigzaBodyStyle(fontSize: 11, color: AppTheme.bodyInk)),
                                      Text(
                                        '${_fmtNum(totalM)} m',
                                        style: zigzaHeadingStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Rack Location', style: zigzaBodyStyle(fontSize: 11, color: AppTheme.bodyInk)),
                                      Text(
                                        fabric.rackLocation,
                                        style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'TARGET ARTICLE / STYLE',
                              style: zigzaBodyStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.bodyInk,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedArticle,
                              isExpanded: true,
                              decoration: _storeFieldDecoration(hint: 'Select article'),
                              style: zigzaBodyStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.headingObsidian,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('-- Free Godown Stock --'),
                                ),
                                ...activeArticles.map((art) => DropdownMenuItem(
                                      value: art.artNo,
                                      child: Text(art.label, overflow: TextOverflow.ellipsis),
                                    )),
                                const DropdownMenuItem(
                                  value: 'CUSTOM',
                                  child: Text('+ Custom Article / PO...'),
                                ),
                              ],
                              onChanged: (val) => setModalState(() {
                                selectedArticle = val ?? '';
                              }),
                            ),
                            if (selectedArticle == 'CUSTOM') ...[
                              const SizedBox(height: 10),
                              TextField(
                                controller: customCtrl,
                                onChanged: (_) => setModalState(() {}),
                                decoration: _storeFieldDecoration(hint: 'e.g. ART-2026-99'),
                                style: zigzaBodyStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'METERS TO ASSIGN',
                                  style: zigzaBodyStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.bodyInk,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => setModalState(() {
                                    metersCtrl.text = _fmtNumPlain(totalM);
                                  }),
                                  child: Text(
                                    'Allocate 100% (${_fmtNum(totalM)}m)',
                                    style: zigzaHeadingStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.brandRoyalBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: metersCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setModalState(() {}),
                              decoration: _storeFieldDecoration(hint: '0', suffixText: 'meters'),
                              style: zigzaHeadingStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.bgCanvas,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Assigned to ${targetArt.isEmpty ? 'Unassigned' : targetArt}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: zigzaBodyStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.bodyInk,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.mintSurface,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: AppTheme.badgeMintBorder),
                                        ),
                                        child: Text(
                                          '$pct%',
                                          style: zigzaHeadingStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F766E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: (pct / 100).clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor: AppTheme.borderLight,
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.brandRoyalBlue),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${_fmtNum(clampedM)}m assigned',
                                        style: zigzaBodyStyle(fontSize: 11, color: AppTheme.headingObsidian, fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        '${_fmtNum(freeM)}m free',
                                        style: zigzaBodyStyle(fontSize: 11, color: AppTheme.bodyInk),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      decoration: const BoxDecoration(
                        color: AppTheme.cardSurface,
                        border: Border(top: BorderSide(color: AppTheme.borderLight)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.headingObsidian,
                                side: const BorderSide(color: AppTheme.borderLight),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                              ),
                              child: Text('Cancel', style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final reqMeters = double.tryParse(metersCtrl.text.trim()) ?? -1;
                                      if (reqMeters < 0) {
                                        setModalState(() => errorMsg = 'Enter valid non-negative meters.');
                                        return;
                                      }
                                      if (reqMeters > totalM) {
                                        setModalState(() => errorMsg = 'Cannot exceed ${_fmtNum(totalM)}m in store.');
                                        return;
                                      }
                                      final res = await ref
                                          .read(fabricStoreProvider.notifier)
                                          .updateFabricArticleAllocation(
                                            inventoryId: fabric.id,
                                            articleNo: targetArt,
                                            bookedMeters: reqMeters,
                                          );
                                      if (res.success) {
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        onMessage(
                                          'Cloth assigned to ${targetArt.isEmpty ? 'Free Stock' : 'Article $targetArt'}',
                                        );
                                      } else {
                                        setModalState(() => errorMsg = res.error ?? 'Failed to update allocation');
                                      }
                                    },
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                              label: Text(
                                isSubmitting ? 'Saving...' : 'Confirm Allocation',
                                style: zigzaHeadingStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.brandRoyalBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  customCtrl.dispose();
  metersCtrl.dispose();
}

Future<void> showAddClothSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<ActiveArticleOption> activeArticles,
  required void Function(String message, {bool isError}) onMessage,
}) async {
  final fabricTypeCtrl = TextEditingController();
  final colorCtrl = TextEditingController();
  final supplierCtrl = TextEditingController();
  final rackCtrl = TextEditingController(text: 'RACK-A-01');
  final totalMetersCtrl = TextEditingController();
  final rollsCtrl = TextEditingController(text: '1');
  final customArticleCtrl = TextEditingController();
  final bookedMetersCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  String selectedArticle = '';
  String? errorMsg;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isSubmitting = ref.watch(fabricStoreProvider).isSubmitting;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.9,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.borderLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                child: const Icon(Icons.content_cut_rounded, color: Color(0xFF0F766E), size: 20),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Record Cloth Inward',
                                      style: zigzaHeadingStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      'Add fabric balance and assign to an article.',
                                      style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close_rounded, color: AppTheme.bodyInk),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderLight),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (errorMsg != null) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.badgeRoseBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  errorMsg!,
                                  style: zigzaBodyStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.badgeRoseText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _FieldLabel('CLOTH / FABRIC TYPE *'),
                            TextField(
                              controller: fabricTypeCtrl,
                              decoration: _storeFieldDecoration(hint: 'e.g. Single Jersey 220 GSM'),
                              style: zigzaBodyStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 11),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _FieldLabel('COLOR *'),
                                      TextField(
                                        controller: colorCtrl,
                                        decoration: _storeFieldDecoration(hint: 'e.g. Navy Blue'),
                                        style: zigzaBodyStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _FieldLabel('RACK LOCATION'),
                                      TextField(
                                        controller: rackCtrl,
                                        decoration: _storeFieldDecoration(hint: 'RACK-A-01'),
                                        style: zigzaBodyStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            _FieldLabel('SUPPLIER / MILL NAME'),
                            TextField(
                              controller: supplierCtrl,
                              decoration: _storeFieldDecoration(hint: 'e.g. Vardhman Textiles'),
                              style: zigzaBodyStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 11),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _FieldLabel('TOTAL METERS *'),
                                      TextField(
                                        controller: totalMetersCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: _storeFieldDecoration(hint: '5000', suffixText: 'm'),
                                        style: zigzaHeadingStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _FieldLabel('ROLLS COUNT'),
                                      TextField(
                                        controller: rollsCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: _storeFieldDecoration(hint: '25'),
                                        style: zigzaHeadingStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.bgCanvas,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('ARTICLE ALLOCATION (OPTIONAL)'),
                                  DropdownButtonFormField<String>(
                                    value: selectedArticle,
                                    isExpanded: true,
                                    decoration: _storeFieldDecoration(hint: 'Select article'),
                                    style: zigzaBodyStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                    items: [
                                      const DropdownMenuItem(value: '', child: Text('-- Leave as Free Stock --')),
                                      ...activeArticles.map((a) => DropdownMenuItem(
                                            value: a.artNo,
                                            child: Text(a.label, overflow: TextOverflow.ellipsis),
                                          )),
                                      const DropdownMenuItem(value: 'CUSTOM', child: Text('+ Custom Article...')),
                                    ],
                                    onChanged: (val) => setModalState(() {
                                      selectedArticle = val ?? '';
                                    }),
                                  ),
                                  if (selectedArticle == 'CUSTOM') ...[
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: customArticleCtrl,
                                      decoration: _storeFieldDecoration(hint: 'Enter Article / PO code'),
                                      style: zigzaBodyStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: bookedMetersCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: _storeFieldDecoration(hint: 'Assigned meters (optional)', suffixText: 'm'),
                                    style: zigzaHeadingStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 11),
                            _FieldLabel('NOTES (OPTIONAL)'),
                            TextField(
                              controller: notesCtrl,
                              maxLines: 2,
                              decoration: _storeFieldDecoration(hint: 'GSM, lot no., or inward remarks...'),
                              style: zigzaBodyStyle(fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      decoration: const BoxDecoration(
                        color: AppTheme.cardSurface,
                        border: Border(top: BorderSide(color: AppTheme.borderLight)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.headingObsidian,
                                side: const BorderSide(color: AppTheme.borderLight),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                              ),
                              child: Text('Cancel', style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final fabricType = fabricTypeCtrl.text.trim();
                                      final color = colorCtrl.text.trim();
                                      final totalM = double.tryParse(totalMetersCtrl.text.trim()) ?? 0;
                                      final rolls = int.tryParse(rollsCtrl.text.trim()) ?? 1;
                                      final bookedM = double.tryParse(bookedMetersCtrl.text.trim()) ?? 0;
                                      final artNo = selectedArticle == 'CUSTOM'
                                          ? customArticleCtrl.text.trim()
                                          : selectedArticle.trim();

                                      if (fabricType.isEmpty) {
                                        setModalState(() => errorMsg = 'Please enter Fabric Type.');
                                        return;
                                      }
                                      if (color.isEmpty) {
                                        setModalState(() => errorMsg = 'Please specify fabric color.');
                                        return;
                                      }
                                      if (totalM <= 0) {
                                        setModalState(() => errorMsg = 'Please enter positive total meters.');
                                        return;
                                      }

                                      final res = await ref.read(fabricStoreProvider.notifier).addFabricCloth(
                                            fabricType: fabricType,
                                            color: color,
                                            supplierName: supplierCtrl.text.trim(),
                                            totalMeters: totalM,
                                            totalRolls: rolls,
                                            rackLocation: rackCtrl.text.trim(),
                                            bookedForArticle: artNo.isEmpty ? null : artNo,
                                            bookedMeters: bookedM,
                                            notes: notesCtrl.text.trim(),
                                          );
                                      if (res.success) {
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        onMessage('New cloth added to store');
                                      } else {
                                        setModalState(() => errorMsg = res.error ?? 'Failed to add cloth');
                                      }
                                    },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(
                                isSubmitting ? 'Saving...' : 'Add Cloth Inward',
                                style: zigzaHeadingStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.brandRoyalBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  fabricTypeCtrl.dispose();
  colorCtrl.dispose();
  supplierCtrl.dispose();
  rackCtrl.dispose();
  totalMetersCtrl.dispose();
  rollsCtrl.dispose();
  customArticleCtrl.dispose();
  bookedMetersCtrl.dispose();
  notesCtrl.dispose();
}

String _fmtNumPlain(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(1);
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: zigzaBodyStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.bodyInk,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DetailStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color bg;
  final Color border;
  final Color valueColor;

  const _DetailStatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.bg,
    required this.border,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: zigzaBodyStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.bodyInk,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: zigzaHeadingStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: zigzaBodyStyle(fontSize: 10, color: AppTheme.bodyInk),
          ),
        ],
      ),
    );
  }
}

