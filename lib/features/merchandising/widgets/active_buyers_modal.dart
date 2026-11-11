import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_section_header.dart';
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.mintSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x3314C8B4)),
                    ),
                    child: const Icon(Icons.people_outline_rounded, color: Color(0xFF0F766E), size: 19),
                  ),
                  const SizedBox(width: 10),
                  Text.rich(
                    TextSpan(
                      style: zigzaHeadingStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      children: [
                        const TextSpan(text: 'Active '),
                        TextSpan(
                          text: 'Buyers (${buyers.length})',
                          style: const TextStyle(color: AppTheme.brandRoyalBlue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.faintInk),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 18, color: AppTheme.borderLight),

          Expanded(
            child: buyers.isEmpty
                ? Center(
                    child: Text(
                      'No active buyers contracted yet.',
                      style: zigzaBodyStyle(fontSize: 13, color: AppTheme.faintInk),
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
                            color: isSelected ? const Color(0xFF1D4ED8) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
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
                                        Flexible(
                                          child: Text(
                                            b.buyerName,
                                            style: zigzaHeadingStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected ? Colors.white : AppTheme.headingObsidian,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (b.linkedArticleNumber != null && b.linkedArticleNumber!.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0x33FFFFFF) : AppTheme.mintSurface,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isSelected ? const Color(0x4DFFFFFF) : const Color(0x3314C8B4),
                                              ),
                                            ),
                                            child: Text(
                                              b.linkedArticleNumber!,
                                              style: zigzaHeadingStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected ? Colors.white : AppTheme.headingObsidian,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${NumberFormat.decimalPattern('en_IN').format(b.contractedVolume)} Pcs • ${b.currency == 'INR' ? '₹' : '\$'}${b.pricePerPiece.toStringAsFixed(2)} / pc',
                                      style: zigzaBodyStyle(
                                        fontSize: 11.5,
                                        color: isSelected ? const Color(0xCCFFFFFF) : AppTheme.bodyInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20)
                              else
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
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
