import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/merchandising_provider.dart';

class ActiveBuyersModal extends ConsumerWidget {
  const ActiveBuyersModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(merchandisingProvider);
    final buyers = state.buyers;
    final selectedBuyerId = state.selectedBuyerId;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
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
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: const Icon(Icons.people_outline_rounded, color: Color(0xFF332B6B), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Active Buyers (${buyers.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6A65)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Contracted buyer accounts, allocated volumes, and linked articles.',
            style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF6B6A65)),
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          Expanded(
            child: buyers.isEmpty
                ? Center(
                    child: Text(
                      'No active buyers contracted yet.',
                      style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF9B9A94)),
                    ),
                  )
                : ListView.separated(
                    itemCount: buyers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final b = buyers[index];
                      final isSelected = b.id == selectedBuyerId;
                      return InkWell(
                        onTap: () {
                          ref.read(merchandisingProvider.notifier).setSelectedBuyerId(b.id);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF332B6B) : const Color(0xFFFAFAF8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF332B6B) : const Color(0x1A000000),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          b.buyerName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : const Color(0xFF1C1C1A),
                                          ),
                                        ),
                                        if (b.linkedArticleNumber != null && b.linkedArticleNumber!.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0x33FFFFFF) : Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isSelected ? const Color(0x4DFFFFFF) : const Color(0x1A000000),
                                              ),
                                            ),
                                            child: Text(
                                              b.linkedArticleNumber!,
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.white : const Color(0xFF332B6B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${b.contractedVolume.toString()} Pcs • ${b.currency == 'INR' ? '₹' : '\$'}${b.pricePerPiece.toStringAsFixed(2)} / pc',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        color: isSelected ? const Color(0xCCFFFFFF) : const Color(0xFF6B6A65),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20)
                              else
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFF9B9A94), size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
