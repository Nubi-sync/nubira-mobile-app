import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/admin_models.dart';

class AdminChallanCard extends StatelessWidget {
  final AdminChallan challan;
  final VoidCallback? onTap;
  final VoidCallback? onAllotTap;

  const AdminChallanCard({
    super.key,
    required this.challan,
    this.onTap,
    this.onAllotTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = challan.status == 'COMPLETED';
    final isInProgress = challan.status == 'IN_PROGRESS';

    final statusBg = isCompleted
        ? AppTheme.greenMist
        : (isInProgress ? AppTheme.steelMist : AppTheme.amberMist);
    final statusColor = isCompleted
        ? AppTheme.green
        : (isInProgress ? AppTheme.steel : AppTheme.amber);

    final brandDisplay = challan.brand.trim().isNotEmpty ? challan.brand.trim() : 'OLLYPOP';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Brand & Status chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.steelTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            brandDisplay,
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.steelDark,
                            ),
                          ),
                        ),
                        if (challan.fabricType != null && challan.fabricType!.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            challan.fabricType!.trim(),
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              color: AppTheme.inkSoft,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        challan.status,
                        style: GoogleFonts.publicSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Challan No & Total Qty
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Challan #${challan.challanNo}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                          if (challan.description != null && challan.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              challan.description!.trim(),
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                color: AppTheme.inkSoft,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${challan.totalQty}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.steel,
                          ),
                        ),
                        Text(
                          'Total Pcs',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            color: AppTheme.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (onAllotTap != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: onAllotTap,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.steel,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_task, size: 16),
                        label: Text(
                          'Allot to Lineman',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
