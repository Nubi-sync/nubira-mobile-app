import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/admin_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiAsync = ref.watch(adminDashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        elevation: 0,
        title: Text(
          'Reports & Analytics',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
      ),
      body: kpiAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.steel),
        ),
        error: (err, stack) => Center(
          child: Text('Error: ${err.toString()}'),
        ),
        data: (kpi) {
          final totalInspected = kpi.todayQcPassedQty + kpi.todayQcAlterQty;
          final passRate = totalInspected > 0 ? ((kpi.todayQcPassedQty / totalInspected) * 100).toStringAsFixed(1) : '100.0';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Production Summary Card
              _buildReportSection(
                title: 'Production Summary',
                icon: Icons.precision_manufacturing_outlined,
                items: [
                  {'label': 'Total Cutting Challans', 'val': '${kpi.totalChallans}'},
                  {'label': 'Active Target Allotments', 'val': '${kpi.totalAllotments}'},
                  {'label': 'Total Floor Production', 'val': '${kpi.todayProductionQty} Pcs'},
                ],
              ),

              const SizedBox(height: 16),

              // Quality Control & Defect Audit
              _buildReportSection(
                title: 'QC & Mending Audit',
                icon: Icons.verified_outlined,
                items: [
                  {'label': 'QC Passed Quantity', 'val': '${kpi.todayQcPassedQty} Pcs'},
                  {'label': 'Defect / Alter Quantity', 'val': '${kpi.todayQcAlterQty} Pcs'},
                  {'label': 'Floor Pass Rate', 'val': '$passRate%'},
                ],
              ),

              const SizedBox(height: 16),

              // Godown & Dispatch Metrics
              _buildReportSection(
                title: 'Godown & Logistics Audit',
                icon: Icons.local_shipping_outlined,
                items: [
                  {'label': 'Fabric & Trims Inwards (GRN)', 'val': '${kpi.totalStoreInwardQty} Pcs/Mtr'},
                  {'label': 'Total Dispatched Pieces', 'val': '${kpi.totalDispatchedQty} Pcs'},
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportSection({
    required String title,
    required IconData icon,
    required List<Map<String, String>> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.steelMist,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.steel, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['label']!,
                    style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft),
                  ),
                  Text(
                    item['val']!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
