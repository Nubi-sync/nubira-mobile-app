import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/admin_models.dart';

class AdminAllotmentCard extends StatelessWidget {
  final AdminAllotment allotment;
  final VoidCallback? onTap;

  const AdminAllotmentCard({
    super.key,
    required this.allotment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = allotment.status == 'COMPLETED';
    final isInProgress = allotment.status == 'IN_PROGRESS';

    final statusBg = isCompleted
        ? AppTheme.greenMist
        : (isInProgress ? AppTheme.steelMist : AppTheme.amberMist);
    final statusColor = isCompleted
        ? AppTheme.green
        : (isInProgress ? AppTheme.steel : AppTheme.amber);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
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
                // Top Row: Lineman Name & Status Chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.steelMist,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person, color: AppTheme.steel, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          allotment.linemanName ?? 'Unassigned Lineman',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        allotment.status,
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

                // Middle Row: Article No, Challan No & Target Qty
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Art: ${allotment.articleNo ?? 'N/A'}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.steel,
                              ),
                            ),
                            if (allotment.brand != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.bg,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.border, width: 0.8),
                                ),
                                child: Text(
                                  allotment.brand!,
                                  style: GoogleFonts.publicSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.inkSoft,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Challan: #${allotment.challanNo ?? 'N/A'}',
                          style: GoogleFonts.publicSans(
                            fontSize: 12,
                            color: AppTheme.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${allotment.targetQty}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        Text(
                          'Target Pcs',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            color: AppTheme.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // QC / Mending Mini Tracker
                if (allotment.qcTotalPassed != null || allotment.mendingTotalCounted != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (allotment.mendingTotalCounted != null)
                          Text(
                            'Mending Counted: ${allotment.mendingTotalCounted}',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.inkSoft,
                            ),
                          ),
                        if (allotment.qcTotalPassed != null)
                          Text(
                            'QC Passed: ${allotment.qcTotalPassed}',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.green,
                            ),
                          ),
                      ],
                    ),
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
