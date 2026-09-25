import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';

class PrintingNotificationsScreen extends ConsumerStatefulWidget {
  const PrintingNotificationsScreen({super.key});

  @override
  ConsumerState<PrintingNotificationsScreen> createState() => _PrintingNotificationsScreenState();
}

class _PrintingNotificationsScreenState extends ConsumerState<PrintingNotificationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _mockNotifications = [
    {
      'id': 'notif-p1',
      'title': 'Strike Off Color Swatch Approved',
      'body': 'Buyer Technical QA approved Plastisol Delta E 0.38 for Article ART-TEE-882.',
      'time': '10 mins ago',
      'isRead': false,
      'type': 'APPROVAL',
      'icon': Icons.check_circle_outline,
      'color': Color(0xFF047857),
    },
    {
      'id': 'notif-p2',
      'title': 'Curing Oven Conveyor Temp Optimal',
      'body': 'Industrial Tunnel Oven 01 probe stabilized at 165°C for batch run.',
      'time': '35 mins ago',
      'isRead': false,
      'type': 'SYSTEM',
      'icon': Icons.local_fire_department_outlined,
      'color': Color(0xFFD97706),
    },
    {
      'id': 'notif-p3',
      'title': '450 Cut Panels Received from Cutting Floor',
      'body': 'Lot #CUT-882 transferred to Print Table 01 queue awaiting table lay.',
      'time': '2 hours ago',
      'isRead': true,
      'type': 'HANDOVER',
      'icon': Icons.move_to_inbox_outlined,
      'color': Color(0xFF3A3564),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/printing/notifications'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back, size: 13, color: Color(0xFF3A3564)),
                        const SizedBox(width: 4),
                        Text(
                          'Printing Studio',
                          style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/ Floor Notifications',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                    ),
                    child: const Icon(Icons.notifications_active_outlined, color: Color(0xFF3A3564), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Printing Floor Alerts',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Real-time strike-off approvals, curing alerts & lot handovers',
                          style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Notifications List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _mockNotifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final notif = _mockNotifications[idx];
                final isRead = notif['isRead'] as bool;
                final color = notif['color'] as Color;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isRead ? Colors.black.withValues(alpha: 0.08) : color.withValues(alpha: 0.3),
                      width: isRead ? 1 : 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(notif['icon'] as IconData, size: 20, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    notif['title'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Text(
                                  notif['time'] as String,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif['body'] as String,
                              style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF475569), height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
