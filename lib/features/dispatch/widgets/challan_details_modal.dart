import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/dispatch_models.dart';
import '../providers/dispatch_provider.dart';

class ChallanDetailsModal extends ConsumerStatefulWidget {
  final DeliveryChallanModel challan;

  const ChallanDetailsModal({
    super.key,
    required this.challan,
  });

  @override
  ConsumerState<ChallanDetailsModal> createState() => _ChallanDetailsModalState();
}

class _ChallanDetailsModalState extends ConsumerState<ChallanDetailsModal> {
  static const Color kCanvasColor = Color(0xFFFAF7F0);
  static const Color kCardBg = Color(0xFFFFFFFF);
  static const Color kPrimaryBrand = Color(0xFF3A3564);
  static const Color kBorderColor = Color(0xFFE7E1D6);
  static const Color kMutedText = Color(0xFF7A7488);
  static const Color kInkText = Color(0xFF232028);

  bool _isApproving = false;

  Future<void> _approve() async {
    setState(() => _isApproving = true);
    try {
      await ref.read(dispatchProvider.notifier).approveChallan(widget.challan.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              '✓ Challan #${widget.challan.challanNo} authorized for Gate Out & Dispatch!',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFE11D48), content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.challan;

    Color reconBg;
    Color reconText;
    if (ch.reconciliationStatus == 'DISCREPANCY') {
      reconBg = const Color(0xFFFFE4E6);
      reconText = const Color(0xFFBE123C);
    } else if (ch.reconciliationStatus == 'PENDING') {
      reconBg = const Color(0xFFFEF3C7);
      reconText = const Color(0xFFB45309);
    } else {
      reconBg = const Color(0xFFD1FAE5);
      reconText = const Color(0xFF047857);
    }

    final isApproved = ch.status == 'APPROVED_FOR_DISPATCH' || ch.status == 'DELIVERED';

    return Dialog(
      backgroundColor: kCardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kCanvasColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(bottom: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: const Icon(Icons.description_outlined, color: kPrimaryBrand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Delivery Challan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: kInkText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: kPrimaryBrand,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ch.challanNo,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ch.buyerName} • ${ch.deliveryDate}',
                          style: GoogleFonts.publicSans(
                            fontSize: 12,
                            color: kMutedText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        border: Border.all(color: kBorderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 16, color: kMutedText),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Reconciliation Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: reconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                ch.reconciliationStatus == 'DISCREPANCY'
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle_outline,
                                size: 16,
                                color: reconText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Reconciliation: ${ch.reconciliationLabel}',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: reconText,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            ch.status,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: reconText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Reconciliation Quantities Grid
                    Row(
                      children: [
                        _buildStatBox('CUT QTY', '${ch.cutQty} pcs'),
                        const SizedBox(width: 8),
                        _buildStatBox('COUNTED', '${ch.countedQty} pcs'),
                        const SizedBox(width: 8),
                        _buildStatBox('DISPATCHED', '${ch.totalPieces} pcs', isHighlight: true),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Logistics Metadata
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: Column(
                        children: [
                          _buildMetaRow('Destination:', ch.destination ?? 'Factory Gate'),
                          const SizedBox(height: 6),
                          _buildMetaRow('Vehicle / Truck:', ch.vehicleNo ?? 'Direct Transport'),
                          const SizedBox(height: 6),
                          _buildMetaRow('Driver Name:', ch.driverName ?? 'Unassigned'),
                          if (ch.driverPhone != null && ch.driverPhone!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _buildMetaRow('Driver Phone:', ch.driverPhone!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Items List
                    Text(
                      'MANIFEST ARTICLES (${ch.items.length})',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: kInkText,
                      ),
                    ),
                    const SizedBox(height: 6),

                    if (ch.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('Total ${ch.totalPieces} garments dispatched.', style: GoogleFonts.publicSans(fontSize: 12, color: kMutedText)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: ch.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (ctx, i) {
                          final item = ch.items[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: kCardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kBorderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.articleArtNo ?? 'Art #${item.articleId.substring(0, min(6, item.articleId.length))}',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: kInkText,
                                      ),
                                    ),
                                    Text(
                                      '${item.color ?? 'Standard'} • Size ${item.size ?? 'Free'}',
                                      style: GoogleFonts.publicSans(fontSize: 11, color: kMutedText),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: kCanvasColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: kBorderColor),
                                  ),
                                  child: Text(
                                    '${item.quantity} pcs',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: kPrimaryBrand,
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
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kCanvasColor,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(top: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kBorderColor),
                      backgroundColor: kCardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Close', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: kInkText)),
                  ),
                  const SizedBox(width: 10),
                  if (!isApproved)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isApproving ? null : _approve,
                        icon: _isApproving
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.verified_outlined, size: 16),
                        label: Text(
                          _isApproving ? 'Authorizing...' : 'Authorize Gate Out',
                          style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryBrand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '✓ Gate Out Authorized',
                          style: GoogleFonts.publicSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF047857),
                          ),
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

  Widget _buildStatBox(String label, String value, {bool isHighlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isHighlight ? kPrimaryBrand.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isHighlight ? kPrimaryBrand.withValues(alpha: 0.3) : kBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: kMutedText)),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isHighlight ? kPrimaryBrand : kInkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.publicSans(fontSize: 11.5, color: kMutedText)),
        Text(value, style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: kInkText)),
      ],
    );
  }
}
