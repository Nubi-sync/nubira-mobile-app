import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/printing_models.dart';
import '../providers/printing_provider.dart';

class SelectPrintingRouteModal extends ConsumerWidget {
  final String activeRouteKey;
  final String buyerName;
  final String buyerId;

  const SelectPrintingRouteModal({
    super.key,
    required this.activeRouteKey,
    required this.buyerName,
    required this.buyerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                        'Process flow for $buyerName',
                        style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24),

          ...kPrintingRouteOptions.map((opt) {
            final isSelected = opt.key == activeRouteKey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () {
                  ref.read(printingProvider.notifier).setAndSyncRoute(buyerId, opt.key);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Manufacturing route updated to: ${opt.shortLabel}'),
                      backgroundColor: const Color(0xFF3A3564),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  opt.shortLabel,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    opt.stepIndicator,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : const Color(0xFF3A3564),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              opt.fullFlow,
                              style: GoogleFonts.publicSans(
                                fontSize: 11.5,
                                color: isSelected ? const Color(0xFFE2E8F0) : const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
