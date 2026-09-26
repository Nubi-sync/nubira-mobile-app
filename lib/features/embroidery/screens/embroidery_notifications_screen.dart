import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';

class EmbroideryNotificationsScreen extends ConsumerStatefulWidget {
  const EmbroideryNotificationsScreen({super.key});

  @override
  ConsumerState<EmbroideryNotificationsScreen> createState() => _EmbroideryNotificationsScreenState();
}

class _EmbroideryNotificationsScreenState extends ConsumerState<EmbroideryNotificationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _mockNotifications = [
    {
      'id': 'notif-e1',
      'title': 'DST Punch File Verified & Approved',
      'body': 'Punching master validated 14,800 stitch count chest logo for Article DEMO-101-03.',
      'time': '15 mins ago',
      'isRead': false,
      'type': 'APPROVAL',
      'icon': Icons.check_circle_outline,
      'color': const Color(0xFF047857),
    },
    {
      'id': 'notif-e2',
      'title': 'Tajima 20-Head Line Speed Calibrated',
      'body': 'Machine 01 stabilized at 850 RPM with zero bobbin thread breaks in last shift run.',
      'time': '40 mins ago',
      'isRead': false,
      'type': 'SYSTEM',
      'icon': Icons.precision_manufacturing_outlined,
      'color': const Color(0xFFD97706),
    },
    {
      'id': 'notif-e3',
      'title': '500 Printed Panels Received from Printing Studio',
      'body': 'Lot #PRN-8801 transferred to Embroidery Studio queue ready for hooping & framing.',
      'time': '2 hours ago',
      'isRead': true,
      'type': 'HANDOVER',
      'icon': Icons.move_to_inbox_outlined,
      'color': const Color(0xFF3A3564),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/embroidery/notifications'),
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
                          'Embroidery Studio',
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: Color(0xFF3A3564), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Embroidery Alerts & Handover Feeds',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Real-time stitch sign-offs, DST punch approvals & machine alerts',
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

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white.withValues(alpha: 0.7) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRead ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF3A3564).withValues(alpha: 0.2),
                      width: isRead ? 1.0 : 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (notif['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(notif['icon'] as IconData, color: notif['color'] as Color, size: 18),
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
                                      fontSize: 13,
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
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
                              style: GoogleFonts.publicSans(
                                fontSize: 11.5,
                                color: const Color(0xFF475569),
                                height: 1.35,
                              ),
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
