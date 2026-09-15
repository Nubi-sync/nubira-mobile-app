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
      backgroundColor: AppTheme.canvasCream,
      appBar: AppBar(
        backgroundColor: AppTheme.cardWhite,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.foregroundInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Floor Supervisor Operations',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.foregroundInk,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.standardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.canvasCream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.standardBorder),
                  ),
                  child: const Center(
                    child: Icon(Icons.tune_rounded, color: AppTheme.brandSteel, size: 22),
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
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.foregroundInk,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Direct line access to operate or verify any workstation in the factory',
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          color: AppTheme.mutedInk,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          ...stations.map((st) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.standardBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.canvasCream,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.standardBorder),
                            ),
                            child: Icon(st.icon, color: AppTheme.brandSteel, size: 22),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.canvasCream,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.standardBorder),
                            ),
                            child: Text(
                              st.badge,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.mutedInk,
                                letterSpacing: 0.5,
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
                          color: AppTheme.foregroundInk,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        st.subtitle,
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          color: AppTheme.mutedInk,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppTheme.brandSteel,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Open Desk',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
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
