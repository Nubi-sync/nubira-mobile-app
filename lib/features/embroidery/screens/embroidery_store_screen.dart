import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../providers/embroidery_provider.dart';

class BoxKeyValues {
  static final BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 10,
    offset: const Offset(0, 3),
  );
}

class EmbroideryStoreScreen extends ConsumerStatefulWidget {
  const EmbroideryStoreScreen({super.key});

  @override
  ConsumerState<EmbroideryStoreScreen> createState() => _EmbroideryStoreScreenState();
}

class _EmbroideryStoreScreenState extends ConsumerState<EmbroideryStoreScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();
  int _selectedTabIndex = 0; // 0: Inventory, 1: Receipts from Printing, 2: Issues to Stitching

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final embState = ref.watch(embroideryProvider);
    final selectedBuyer = embState.buyers.isNotEmpty ? embState.buyers.first : null;
    final routeDetails = ref.read(embroideryProvider.notifier).getRouteDetails(selectedBuyer?.id ?? 'byr-hollypop');
    final inHand = routeDetails.inHandPieces;

    final completed = embState.taskAllocations
        .where((t) => t.status == 'VERIFIED_COMPLETED' || t.status == 'COMPLETED')
        .fold<int>(0, (sum, t) => sum + (t.completedPieces > 0 ? t.completedPieces : t.piecesToEmbroider));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/embroidery/store'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF3A3564),
        onRefresh: () => ref.read(embroideryProvider.notifier).loadInitialData(isRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Breadcrumb + Sync Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back, size: 14, color: Color(0xFF3A3564)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Workspace hub / Division 05 - Embroidery store',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF3A3564),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF047857),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'PANEL STORE SYNC ACTIVE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2. Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  boxShadow: [BoxKeyValues.cardShadow],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(14),
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
                                'Embroidery Floor Store (Panels)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F0),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                ),
                                child: Text(
                                  'INWARD & OUTWARD PANEL AUDIT',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF3A3564),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Store & track un-embroidered cut panels received from Printing Studio, hooping staging inventory, and finished embroidered bundles ready for Sewing.',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Three Stat KPI Cards
              _buildStoreKpiCard(
                title: 'UN-EMBROIDERED PANELS',
                value: '$inHand',
                subtext: '$inHand pcs ready on storage rack (from Printing Studio)',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 10),
              _buildStoreKpiCard(
                title: 'FINISHED EMBROIDERED PANELS',
                value: '$completed',
                subtext: '$completed pcs inspected & ready to issue to Stitching Floor',
                icon: Icons.verified_outlined,
              ),
              const SizedBox(height: 10),
              _buildStoreKpiCard(
                title: 'TOTAL PRINTED PANELS RECEIVED',
                value: '${embState.upstreamPrintingPieces}',
                subtext: '${embState.upstreamPrintingPieces} pcs cumulative received against contract Hollypop',
                icon: Icons.move_to_inbox_outlined,
              ),

              const SizedBox(height: 14),

              // 4. Panel Store Ledger Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  boxShadow: [BoxKeyValues.cardShadow],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header & Tab Selector
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F0),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                ),
                                child: const Icon(Icons.table_rows_outlined, color: Color(0xFF3A3564), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Panel Inventory Ledger',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Tab buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildTabButton(0, 'Panels In Hand'),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildTabButton(1, 'Inward Receipts'),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildTabButton(2, 'Issued to Sewing'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0x14000000)),

                    // Tab Contents
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildSelectedTabContent(inHand, completed),
                    ),

                    // Footer summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hollypop • DEMO-101-03',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3A3564),
                            ),
                          ),
                          Text(
                            'Rack: EMB-STG-01',
                            style: GoogleFonts.publicSans(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        boxShadow: [BoxKeyValues.cardShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtext,
                  style: GoogleFonts.publicSans(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: const Color(0xFF3A3564), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(int inHand, int completed) {
    if (_selectedTabIndex == 0) {
      // Inventory In Hand
      return Column(
        children: [
          _buildItemRow(
            ref: 'EMB-STK-01',
            title: 'Hollypop • Premium Graphic Tee',
            detail: 'Article: DEMO-101-03 | Location: Rack A-02',
            qty: '$inHand pcs',
            badge: 'UN-EMBROIDERED',
            badgeColor: const Color(0xFF3A3564),
            badgeBg: const Color(0xFFFAF7F0),
          ),
          const SizedBox(height: 10),
          _buildItemRow(
            ref: 'EMB-FIN-01',
            title: 'Hollypop • Finished Panels',
            detail: 'Article: DEMO-101-03 | Staging Box #3',
            qty: '$completed pcs',
            badge: 'READY FOR SEWING',
            badgeColor: const Color(0xFF047857),
            badgeBg: const Color(0xFFECFDF5),
          ),
        ],
      );
    } else if (_selectedTabIndex == 1) {
      // Inward Receipts
      return Column(
        children: [
          _buildItemRow(
            ref: 'REC-PRINT-9921',
            title: 'Received from Printing Studio',
            detail: 'Challan #PRN-CH-1002 • 1,300 panels',
            qty: '1,300 pcs',
            badge: 'VERIFIED INWARD',
            badgeColor: const Color(0xFF047857),
            badgeBg: const Color(0xFFECFDF5),
          ),
        ],
      );
    } else {
      // Issued to Sewing
      return Column(
        children: [
          _buildItemRow(
            ref: 'ISS-SEW-0101',
            title: 'Issued to Stitching Floor',
            detail: 'Challan #EMB-CH-501 • Sergio Ramos batch',
            qty: '$completed pcs',
            badge: 'ISSUED & IN-TRANSIT',
            badgeColor: const Color(0xFFD97706),
            badgeBg: const Color(0xFFFFFBEB),
          ),
        ],
      );
    }
  }

  Widget _buildItemRow({
    required String ref,
    required String title,
    required String detail,
    required String qty,
    required String badge,
    required Color badgeColor,
    required Color badgeBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
                child: Text(
                  ref,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3A3564),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                detail,
                style: GoogleFonts.publicSans(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                qty,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
