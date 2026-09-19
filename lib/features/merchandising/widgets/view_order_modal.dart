import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/merchandising_models.dart';

class ViewOrderModal extends StatelessWidget {
  final MerchandisingOrder order;

  const ViewOrderModal({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAF8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: const Icon(Icons.description_outlined, color: Color(0xFF332B6B), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.poNumber,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF332B6B),
                              ),
                            ),
                            Text(
                              order.brandName,
                              style: GoogleFonts.publicSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1C1C1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F7EE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x331B7A43)),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B7A43),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),

            // Key Order Specs Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: Column(
                children: [
                  _buildSpecRow('Article / Style', order.styleRef),
                  const SizedBox(height: 8),
                  _buildSpecRow('Category & Spec', order.styleName),
                  const SizedBox(height: 8),
                  _buildSpecRow('Total Volume', '${order.totalQuantity.toString()} Pcs'),
                  const SizedBox(height: 8),
                  _buildSpecRow('Unit FOB Rate', '${order.currency == 'INR' ? '₹' : '\$'}${order.unitFobPrice.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _buildSpecRow('Contract Value', '${order.currency == 'INR' ? '₹' : '\$'}${order.totalContractValue.toStringAsFixed(0)}'),
                  const SizedBox(height: 8),
                  _buildSpecRow('Ex-Factory Target', order.exFactoryDate.isNotEmpty ? order.exFactoryDate : 'TBD'),
                  const SizedBox(height: 8),
                  _buildSpecRow('Routing Pipeline', order.routeLabel),
                  const SizedBox(height: 8),
                  _buildSpecRow('Fabric Composition', order.fabricComposition),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Color Size Matrix
            Text(
              'COLOR & SIZE BREAKDOWN',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6B6A65),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            if (order.colorMatrix.isNotEmpty)
              ...order.colorMatrix.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.color,
                            style: GoogleFonts.publicSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1C1C1A),
                            ),
                          ),
                          Text(
                            '${item.total} pcs',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF332B6B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: item.sizes.entries.map((sz) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAF8),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0x1A000000)),
                            ),
                            child: Text(
                              '${sz.key}: ${sz.value}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1C1C1A),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              })
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Standard size ratio allocated (100% contract volume).',
                  style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF6B6A65)),
                ),
              ),

            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF332B6B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close Details',
                style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 11.5,
            color: const Color(0xFF6B6A65),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C1C1A),
            ),
          ),
        ),
      ],
    );
  }
}
