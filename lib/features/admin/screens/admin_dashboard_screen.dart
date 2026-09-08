import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_excel_import_modal.dart';
import '../allotments/widgets/allotment_card_widget.dart';
import '../allotments/allotment_step1_screen.dart';
import '../allotments/allotment_form_state.dart';
import 'admin_shell.dart';
import 'employees_screen.dart';
import 'articles_screen.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiAsync = ref.watch(adminDashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.ink),
          tooltip: 'Menu',
          onPressed: () => adminScaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nubira Creation',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Live Floor Intelligence',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.inkSoft,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.inkSoft),
            tooltip: 'Sync Factory Data',
            onPressed: () {
              ref.invalidate(adminDashboardProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.steel,
        onRefresh: () async {
          ref.invalidate(adminDashboardProvider);
        },
        child: kpiAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.steel),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.red, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load live factory stats',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    err.toString(),
                    style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(adminDashboardProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (kpi) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 4 Primary KPI Cards Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.18,
                children: [
                  AdminStatCard(
                    title: 'Active Challans',
                    value: '${kpi.totalChallans}',
                    icon: Icons.layers_rounded,
                    iconColor: AppTheme.steel,
                    iconBgColor: AppTheme.steelMist,
                    subtitle: 'Hub',
                  ),
                  AdminStatCard(
                    title: 'Floor Production',
                    value: '${kpi.todayProductionQty}',
                    icon: Icons.check_circle_outline,
                    iconColor: AppTheme.green,
                    iconBgColor: AppTheme.greenMist,
                    subtitle: 'Pcs Done',
                  ),
                  AdminStatCard(
                    title: 'QC Passed',
                    value: '${kpi.todayQcPassedQty}',
                    icon: Icons.verified_outlined,
                    iconColor: AppTheme.stitch,
                    iconBgColor: AppTheme.amberMist,
                    subtitle: '${kpi.todayQcAlterQty} Alter',
                  ),
                  AdminStatCard(
                    title: 'Store Inward',
                    value: '${kpi.totalStoreInwardQty}',
                    icon: Icons.warehouse_rounded,
                    iconColor: AppTheme.ink,
                    iconBgColor: AppTheme.border.withValues(alpha: 0.5),
                    subtitle: 'GRN Pcs',
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Quick Actions Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Operations',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickActionButton(
                      context: context,
                      icon: Icons.upload_file_rounded,
                      label: 'Excel Import',
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => AdminExcelImportModal(
                            onImportSuccess: () {
                              ref.invalidate(adminDashboardProvider);
                              ref.invalidate(adminChallansListProvider);
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildQuickActionButton(
                      context: context,
                      icon: Icons.add_task_rounded,
                      label: 'New Allotment',
                      onTap: () {
                        ref.read(allotmentFormProvider.notifier).reset();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllotmentStep1Screen(),
                          ),
                        ).then((_) {
                          ref.invalidate(adminDashboardProvider);
                          ref.invalidate(adminAllotmentsListProvider);
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildQuickActionButton(
                      context: context,
                      icon: Icons.sell_outlined,
                      label: 'Articles',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ArticlesScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildQuickActionButton(
                      context: context,
                      icon: Icons.person_add_outlined,
                      label: 'Add Staff',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EmployeesScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Recent Allotments Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Floor Allotments Stream',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  Text(
                    '${kpi.recentAllotments.length} Active',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.steel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (kpi.recentAllotments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.inbox_outlined, size: 36, color: AppTheme.inkFaint),
                        const SizedBox(height: 8),
                        Text(
                          'No Active Allotments',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...kpi.recentAllotments.take(15).map(
                  (allotment) => AllotmentCardWidget(allotment: allotment),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.steel),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.publicSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
