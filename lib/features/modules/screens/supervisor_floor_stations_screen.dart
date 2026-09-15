import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/lineman_dashboard.dart';
import '../../dashboard/mending_dashboard.dart';
import '../../dashboard/qc_dashboard.dart';
import '../../dashboard/store_dashboard.dart';
import '../../dashboard/dispatch_dashboard.dart';

class SupervisorFloorStationsScreen extends ConsumerWidget {
  const SupervisorFloorStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = [
      _StationItem(
        title: 'Lineman Stitching Desk',
        subtitle: 'Real-time lineman line allocations, target piece counts, bundle intake, and live speed rate.',
        badge: 'FLOOR SEWING',
        icon: Icons.content_cut_rounded,
        destination: const LinemanDashboard(),
      ),
      _StationItem(
        title: 'Mending & Verification Desk',
        subtitle: 'Defect logging, alteration triage, replacement claims from safety buffer, and repair clearing.',
        badge: 'ALTERATION CLINIC',
        icon: Icons.build_rounded,
        destination: const MendingDashboard(),
      ),
      _StationItem(
        title: 'QC Inspection Desk',
        subtitle: '100% garment inspection, measurement grading, reject segregation, and final QC clearance stamp.',
        badge: 'QUALITY CONTROL',
        icon: Icons.verified_rounded,
        destination: const QcDashboard(),
      ),
      _StationItem(
        title: 'Store Godown Desk',
        subtitle: 'Raw trims & fabric issuance, multi-size buffer deduction, cutting challan inward and physical inventory.',
        badge: 'CENTRAL GODOWN',
        icon: Icons.storefront_rounded,
        destination: const StoreDashboard(),
      ),
      _StationItem(
        title: 'Dispatch Gate Desk',
        subtitle: 'Carton barcode verification, packing slip audits, GST delivery challan issuance, and gate-out pass.',
        badge: 'GATE DISPATCH',
        icon: Icons.local_shipping_rounded,
        destination: const DispatchDashboard(),
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Floor Supervisor Operations',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.ink,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Center(
                    child: Icon(Icons.tune_rounded, color: AppTheme.steel, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supervisor Absentee & Station Override',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Direct line access to operate or verify any workstation in the factory',
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          color: AppTheme.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ...stations.map((st) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => st.destination),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Icon(st.icon, color: AppTheme.steel, size: 20),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Text(
                              st.badge,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        st.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        st.subtitle,
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          color: AppTheme.inkSoft,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.steel,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Open Desk',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
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

class _StationItem {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Widget destination;

  const _StationItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.destination,
  });
}
