import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';

class PrintingStoreScreen extends ConsumerStatefulWidget {
  const PrintingStoreScreen({super.key});

  @override
  ConsumerState<PrintingStoreScreen> createState() => _PrintingStoreScreenState();
}

class _PrintingStoreScreenState extends ConsumerState<PrintingStoreScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _mockStoreReceipts = [
    {
      'challanNo': 'CH-CUT-PRN-882',
      'from': 'Cutting Floor',
      'items': 'Front & Back Panels - ART-TEE-882 (Size L)',
      'qty': 450,
      'status': 'RECEIVED',
      'date': '24 Sep, 10:30 AM',
    },
    {
      'challanNo': 'CH-CUT-PRN-883',
      'from': 'Cutting Floor',
      'items': 'Front Chest Panels - ART-HOODIE-104 (Size XL)',
      'qty': 300,
      'status': 'ACKNOWLEDGED',
      'date': '25 Sep, 02:15 PM',
    },
  ];

  final List<Map<String, dynamic>> _mockStoreIssues = [
    {
      'challanNo': 'ISSUE-PRN-EMB-01',
      'to': 'Embroidery Studio',
      'items': 'Screen Printed Panels - ART-TEE-882',
      'qty': 450,
      'status': 'DISPATCHED_TO_FLOOR',
      'date': '24 Sep, 04:00 PM',
    },
    {
      'challanNo': 'ISSUE-PRN-SEW-02',
      'to': 'Stitching Line 02',
      'items': 'Plastisol Cured Hoodies - ART-HOODIE-104',
      'qty': 200,
      'status': 'IN_TRANSIT',
      'date': '25 Sep, 05:30 PM',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/printing/store'),
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
                  '/ Floor Store (Panels)',
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
                    child: const Icon(Icons.storefront_outlined, color: Color(0xFF3A3564), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Printing Panel Store & Challans',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Inward cut panels ledger & outward cured transfers',
                          style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // INWARD RECEIPTS SECTION
            Text(
              'INWARD PANEL RECEIPTS (FROM CUTTING)',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),

            ..._mockStoreReceipts.map((rec) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rec['challanNo'] as String,
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          rec['status'] as String,
                          style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rec['items'] as String,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'From: ${rec['from']}',
                        style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        '${rec['qty']} pcs',
                        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ],
              ),
            )),

            const SizedBox(height: 16),

            // OUTWARD ISSUES SECTION
            Text(
              'OUTWARD CURED PANEL ISSUES (TO SEWING / EMBROIDERY)',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),

            ..._mockStoreIssues.map((iss) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        iss['challanNo'] as String,
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          iss['status'] as String,
                          style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    iss['items'] as String,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'To: ${iss['to']}',
                        style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        '${iss['qty']} pcs',
                        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
