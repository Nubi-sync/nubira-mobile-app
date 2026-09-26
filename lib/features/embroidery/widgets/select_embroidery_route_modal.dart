import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/embroidery_provider.dart';

const List<Map<String, String>> kEmbroideryManufacturingRoutes = [
  {
    'key': 'PRINT_FIRST_THEN_EMBROIDERY',
    'shortLabel': 'Print first -> Embroidery',
    'badgeLabel': 'Step 2: Printing -> Embroidery',
    'flowDescription': 'Cutting -> Screen & Digital Print -> Multi-Head Embroidery -> Stitching & Sewing',
  },
  {
    'key': 'EMBROIDERY_FIRST_THEN_PRINT',
    'shortLabel': 'Embroidery first -> Print',
    'badgeLabel': 'Step 1: Cutting -> Embroidery',
    'flowDescription': 'Cutting -> Multi-Head Embroidery -> Screen & Digital Print -> Stitching & Sewing',
  },
  {
    'key': 'EMBROIDERY_ONLY',
    'shortLabel': 'Embroidery Only',
    'badgeLabel': 'Direct: Cutting -> Embroidery',
    'flowDescription': 'Cutting -> Multi-Head Embroidery -> Stitching & Sewing (Print bypassed)',
  },
  {
    'key': 'PRINT_ONLY',
    'shortLabel': 'Print Only',
    'badgeLabel': 'Bypassed in Routing',
    'flowDescription': 'Cutting -> Screen & Digital Print -> Stitching & Sewing (Embroidery bypassed)',
  },
];

class SelectEmbroideryRouteModal extends ConsumerWidget {
  final String activeRouteKey;
  final String buyerName;
  final String buyerId;

  const SelectEmbroideryRouteModal({
    super.key,
    required this.activeRouteKey,
    required this.buyerName,
    required this.buyerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        margin: const EdgeInsets.only(top: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(Icons.alt_route_rounded, color: Color(0xFF3A3564), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Manufacturing Route',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Process sequence for $buyerName',
                          style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Route Options
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: kEmbroideryManufacturingRoutes.map((route) {
                    final isSelected = activeRouteKey == route['key'];

                    return InkWell(
                      onTap: () {
                        ref.read(embroideryProvider.notifier).setArticleRoute(buyerId, route['key']!);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Routing updated: ${route['shortLabel']}'),
                            backgroundColor: const Color(0xFF3A3564),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF3A3564) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.1),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white24 : const Color(0xFFFAF7F0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.route_outlined,
                                size: 16,
                                color: isSelected ? Colors.white : const Color(0xFF3A3564),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        route['shortLabel']!,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white24 : const Color(0xFFFAF7F0),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          route['badgeLabel']!,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    route['flowDescription']!,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 11,
                                      color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(Icons.check_circle, color: Colors.white, size: 18),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
