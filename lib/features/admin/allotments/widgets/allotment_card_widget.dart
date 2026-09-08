import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';

class AllotmentCardWidget extends StatelessWidget {
  final AdminAllotment allotment;
  final VoidCallback? onTap;
  final ValueChanged<String>? onStatusChange;
  final VoidCallback? onDelete;

  const AllotmentCardWidget({
    super.key,
    required this.allotment,
    this.onTap,
    this.onStatusChange,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = allotment.status.toUpperCase();
    final targetQty = allotment.targetQty;
    final achievedQty = allotment.achievedQty;
    final progress = targetQty > 0 ? (achievedQty / targetQty).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();

    Color statusColor;
    Color statusBg;
    String statusLabel;

    switch (status) {
      case 'COMPLETED':
        statusColor = AppTheme.green;
        statusBg = AppTheme.greenMist;
        statusLabel = 'Completed';
        break;
      case 'CANCELLED':
        statusColor = AppTheme.red;
        statusBg = AppTheme.redMist;
        statusLabel = 'Cancelled';
        break;
      case 'IN_PROGRESS':
      default:
        statusColor = AppTheme.amber;
        statusBg = AppTheme.amberMist;
        statusLabel = 'In Progress';
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Lineman Name + Status Badge + Action Menu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.steelMist,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: AppTheme.steel,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  allotment.linemanName ?? 'Assigned Lineman',
                                  style: const TextStyle(
                                    color: AppTheme.ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  allotment.allotmentDate ?? 'Today',
                                  style: const TextStyle(
                                    color: AppTheme.inkFaint,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onStatusChange != null || onDelete != null)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AppTheme.inkSoft, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (val) {
                          if (val == 'DELETE') {
                            onDelete?.call();
                          } else {
                            onStatusChange?.call(val);
                          }
                        },
                        itemBuilder: (context) => [
                          if (status != 'IN_PROGRESS')
                            const PopupMenuItem(
                              value: 'IN_PROGRESS',
                              child: Text('Mark In Progress'),
                            ),
                          if (status != 'COMPLETED')
                            const PopupMenuItem(
                              value: 'COMPLETED',
                              child: Text('Mark Completed'),
                            ),
                          if (status != 'CANCELLED')
                            const PopupMenuItem(
                              value: 'CANCELLED',
                              child: Text('Mark Cancelled'),
                            ),
                          if (onDelete != null) ...[
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'DELETE',
                              child: Text(
                                'Delete Allotment',
                                style: TextStyle(color: AppTheme.red),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Article Details & Brand Tag
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Art #${allotment.articleNo ?? 'N/A'}${allotment.articleDescription != null && allotment.articleDescription!.isNotEmpty ? ' • ${allotment.articleDescription}' : ''}',
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (allotment.brand != null || allotment.challanNo != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${allotment.brand ?? 'OLLYPOP'}${allotment.challanNo != null ? ' (Challan #${allotment.challanNo})' : ''}',
                              style: const TextStyle(
                                color: AppTheme.inkSoft,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (allotment.priority == 'RUSH' || allotment.priority == 'CRITICAL')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.redMist,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          allotment.priority,
                          style: const TextStyle(
                            color: AppTheme.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Progress Bar & Piece Counts
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$achievedQty / $targetQty pcs',
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: AppTheme.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppTheme.steelMist,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? AppTheme.green : AppTheme.steel,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 4. Material Handover Summary Pill
                Row(
                  children: [
                    Icon(
                      allotment.areMaterialsIssued
                          ? Icons.check_circle_outline
                          : Icons.inventory_2_outlined,
                      size: 14,
                      color: allotment.areMaterialsIssued
                          ? AppTheme.green
                          : AppTheme.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      allotment.materialHandoverStatus,
                      style: TextStyle(
                        color: allotment.areMaterialsIssued
                            ? AppTheme.green
                            : AppTheme.inkSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (allotment.variants.isNotEmpty)
                      Text(
                        '${allotment.variants.length} Variants',
                        style: const TextStyle(
                          color: AppTheme.inkFaint,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
