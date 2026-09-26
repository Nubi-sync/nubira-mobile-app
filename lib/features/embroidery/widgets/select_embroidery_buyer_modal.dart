import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/embroidery_provider.dart';

class SelectEmbroideryBuyerModal extends ConsumerStatefulWidget {
  const SelectEmbroideryBuyerModal({super.key});

  @override
  ConsumerState<SelectEmbroideryBuyerModal> createState() => _SelectEmbroideryBuyerModalState();
}

class _SelectEmbroideryBuyerModalState extends ConsumerState<SelectEmbroideryBuyerModal> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(embroideryProvider);
    final activeSelectedId = state.selectedBuyerId.isEmpty ? 'ALL' : state.selectedBuyerId;

    final filteredBuyers = state.buyers.where((b) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      final name = b.buyerName.toLowerCase();
      final code = (b.buyerCode ?? '').toLowerCase();
      final article = (b.linkedArticleNumber ?? '').toLowerCase();
      return name.contains(q) || code.contains(q) || article.contains(q);
    }).toList();

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
                      child: const Icon(Icons.people_outline, color: Color(0xFF3A3564), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Buyer & Contract',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Filter embroidery floor schedule & quotas',
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

            const SizedBox(height: 14),

            // Search Field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: GoogleFonts.publicSans(fontSize: 13),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                  hintText: 'Search buyers, articles...',
                  hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  isDense: true,
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Scrollable list of options
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 1. ALL BUYERS OPTION
                    InkWell(
                      onTap: () {
                        ref.read(embroideryProvider.notifier).selectBuyer('ALL');
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: activeSelectedId == 'ALL' ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: activeSelectedId == 'ALL' ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'All Active Buyers',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: activeSelectedId == 'ALL' ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Showing aggregated floor tasks across all contracted brands',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 11,
                                      color: activeSelectedId == 'ALL' ? Colors.white70 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (activeSelectedId == 'ALL') ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle, color: Colors.white, size: 18),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // 2. BUYER CONTRACT ITEMS
                    ...filteredBuyers.map((b) {
                      final isSelected = activeSelectedId == b.id;
                      final cutPieces = b.completedCutPieces;

                      return InkWell(
                        key: ValueKey(b.id),
                        onTap: () {
                          ref.read(embroideryProvider.notifier).selectBuyer(b.id);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF3A3564) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.1),
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
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (b.buyerCode != null && b.buyerCode!.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.white24 : const Color(0xFFFAF7F0),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isSelected ? Colors.white30 : Colors.black.withValues(alpha: 0.1),
                                              ),
                                            ),
                                            child: Text(
                                              b.buyerCode!,
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.white : const Color(0xFF3A3564),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${cutPieces.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} Cut Pcs (of ${b.contractedVolume.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} BPO) • Article: ${b.linkedArticleNumber ?? "Pending"}',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 11,
                                        color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
