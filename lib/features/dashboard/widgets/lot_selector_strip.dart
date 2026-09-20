import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable horizontal lot-selector strip for floor stations (Mending, QC, Lineman, etc.)
/// Clean, touch-native horizontal card carousel with smooth bouncing physics.
class LotSelectorStrip extends StatefulWidget {
  final List<Map<String, dynamic>> lots;
  final Map<String, dynamic>? selectedLot;
  final ValueChanged<Map<String, dynamic>> onLotSelected;
  final String label;

  const LotSelectorStrip({
    super.key,
    required this.lots,
    required this.selectedLot,
    required this.onLotSelected,
    this.label = 'SELECT A LOT TO WORK ON',
  });

  @override
  State<LotSelectorStrip> createState() => _LotSelectorStripState();
}

class _LotSelectorStripState extends State<LotSelectorStrip> {
  static int _parseQty(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    final str = val.toString().trim();
    final direct = int.tryParse(str);
    if (direct != null) return direct;
    final match = RegExp(r'[-+]?\d+').firstMatch(str);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '') ?? 0;
    }
    return 0;
  }

  static Map<String, dynamic>? _asMap(dynamic val) {
    if (val == null) return null;
    if (val is Map<String, dynamic>) return val;
    if (val is Map) return Map<String, dynamic>.from(val);
    if (val is List && val.isNotEmpty && val.first is Map) {
      return Map<String, dynamic>.from(val.first as Map);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lots.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                ),
                if (widget.lots.length > 1)
                  Text(
                    '${widget.lots.length} LOTS AVAILABLE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.lots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, idx) {
                final lot = widget.lots[idx];
                final isSelected = widget.selectedLot?['id']?.toString() == lot['id']?.toString();

                final art = _asMap(lot['article']) ?? _asMap(lot['articles']);
                final artNo = art?['art_no']?.toString() ?? '4225';
                final challan = _asMap(lot['challans']) ?? _asMap(lot['challan']);
                final challanNo = challan?['challan_no']?.toString() ?? 'CH-${lot['id'].toString().substring(0, 4)}';

                final target = _parseQty(lot['target_qty']);
                final counted = _parseQty(lot['total_counted']);
                final progress = target > 0 ? (counted / target).clamp(0.0, 1.0) : 0.0;
                final isComplete = progress >= 1.0;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onLotSelected(lot),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 136,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF3A3564) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF3A3564) : const Color(0x1A000000),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF3A3564).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : const [
                                BoxShadow(
                                  color: Color(0x06000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ART  $artNo',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                challanNo,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? const Color(0xFFA5B4FC) : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4.5,
                                  backgroundColor: isSelected
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : const Color(0xFFF1F5F9),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isSelected
                                        ? (isComplete ? const Color(0xFF34D399) : const Color(0xFFA5B4FC))
                                        : (isComplete ? const Color(0xFF047857) : const Color(0xFF3A3564)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$counted/$target  pcs',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : (isComplete ? const Color(0xFF047857) : const Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
