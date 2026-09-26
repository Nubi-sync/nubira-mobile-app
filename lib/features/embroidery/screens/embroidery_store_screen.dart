import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../providers/embroidery_provider.dart';

class EmbroideryStoreScreen extends ConsumerStatefulWidget {
  const EmbroideryStoreScreen({super.key});

  @override
  ConsumerState<EmbroideryStoreScreen> createState() => _EmbroideryStoreScreenState();
}

class _EmbroideryStoreScreenState extends ConsumerState<EmbroideryStoreScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();
  int _selectedTabIndex = 0; // 0: Inwards Received (1), 1: Outward Issues (0), 2: Pending Inward (0)
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showIssueChallanDialog() {
    final articleCtrl = TextEditingController();
    final buyerCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final fabricCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '0');
    final rollsCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    String destination = 'SEWING';
    String unit = 'meters';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Section with Cream background
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: Color(0x1A000000))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0x1A000000)),
                              ),
                              child: Text(
                                'DIV 05 OUTWARD',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF3A3564),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Issue Material Challan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0x1A000000)),
                            ),
                            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Form Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Destination & Article Number
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('DESTINATION', isRequired: true),
                                const SizedBox(height: 6),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: destination,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                                      items: const [
                                        DropdownMenuItem(value: 'SEWING', child: Text('Sewing Floor')),
                                        DropdownMenuItem(value: 'WASHING', child: Text('Washing Division')),
                                        DropdownMenuItem(value: 'PRINTING', child: Text('Printing Studio')),
                                        DropdownMenuItem(value: 'FINISHING', child: Text('Finishing / Packing')),
                                        DropdownMenuItem(value: 'CENTRAL_STORE', child: Text('Central Store')),
                                      ],
                                      onChanged: (v) => setModalState(() => destination = v ?? 'SEWING'),
                                      style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('ARTICLE NUMBER'),
                                const SizedBox(height: 6),
                                _buildTextInput(
                                  controller: articleCtrl,
                                  hintText: 'E.G. 9437',
                                  isMono: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Row 2: Buyer Name & Color / Shade
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('BUYER NAME'),
                                const SizedBox(height: 6),
                                _buildTextInput(
                                  controller: buyerCtrl,
                                  hintText: 'e.g. Zara / HM',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('COLOR / SHADE'),
                                const SizedBox(height: 6),
                                _buildTextInput(
                                  controller: colorCtrl,
                                  hintText: 'e.g. Navy Blue',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Row 3: Fabric / Item Type
                      _buildFieldLabel('FABRIC / ITEM TYPE'),
                      const SizedBox(height: 6),
                      _buildTextInput(
                        controller: fabricCtrl,
                        hintText: 'e.g. Cotton Single Jersey 220 GSM',
                      ),

                      const SizedBox(height: 14),

                      // Row 4: Quantity, Unit, Rolls (3-column grid)
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('QUANTITY', isRequired: true),
                                const SizedBox(height: 6),
                                _buildTextInput(
                                  controller: qtyCtrl,
                                  hintText: '0',
                                  isMono: true,
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('UNIT'),
                                const SizedBox(height: 6),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: unit,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                                      items: const [
                                        DropdownMenuItem(value: 'meters', child: Text('Meters')),
                                        DropdownMenuItem(value: 'pcs', child: Text('Pieces')),
                                        DropdownMenuItem(value: 'kg', child: Text('Kilograms')),
                                        DropdownMenuItem(value: 'rolls', child: Text('Rolls')),
                                      ],
                                      onChanged: (v) => setModalState(() => unit = v ?? 'pcs'),
                                      style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('ROLLS'),
                                const SizedBox(height: 6),
                                _buildTextInput(
                                  controller: rollsCtrl,
                                  hintText: '0',
                                  isMono: true,
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Row 5: Notes
                      _buildFieldLabel('NOTES'),
                      const SizedBox(height: 6),
                      _buildTextInput(
                        controller: notesCtrl,
                        hintText: 'Remarks or instructions...',
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Bar with Cream Background matching Web
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7F0),
                  border: Border(top: BorderSide(color: Color(0x1A000000))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3A3564),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Material Challan for ${qtyCtrl.text} $unit issued to ${destination == "SEWING" ? "Sewing Floor" : destination}!'),
                            backgroundColor: const Color(0xFF047857),
                          ),
                        );
                      },
                      child: Text('Confirm Issue', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text, {bool isRequired = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: GoogleFonts.publicSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF475569),
            letterSpacing: 0.4,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 3),
          const Text('*', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    bool isMono = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.publicSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.publicSans(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.normal,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final embState = ref.watch(embroideryProvider);
    final totalReceived = embState.upstreamPrintingPieces > 0 ? embState.upstreamPrintingPieces : 1300;

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
              // 1. Breadcrumb + Sync Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                            Flexible(
                              child: Text(
                                'Modules / Embroidery Division / Floor Store',
                                style: GoogleFonts.publicSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
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
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                        const SizedBox(width: 4),
                        Text(
                          'PANEL STORE SYNC ACTIVE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 2. Header Card (Embroidery Division Store DIV 05)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
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
                              Row(
                                children: [
                                  Text(
                                    'Embroidery Division Store',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF7F0),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                                    ),
                                    child: Text(
                                      'DIV 05',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Material receipts from preceding stage and handoff issues to next line',
                                style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Action Buttons Row: Central Store Hub + + Issue Challan
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3A3564),
                              side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Central Store Hub connected.')),
                              );
                            },
                            icon: const Icon(Icons.store_outlined, size: 16),
                            label: Text(
                              'Central Store Hub',
                              style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3A3564),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _showIssueChallanDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              '+ Issue Challan',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Four KPI Stat Cards (2x2 Grid matching Web exactly)
              Row(
                children: [
                  Expanded(
                    child: _buildStoreKpi(
                      title: 'TOTAL RECEIVED',
                      topBadge: 'INWARD',
                      topBadgeColor: const Color(0xFF047857),
                      topBadgeBg: const Color(0xFFECFDF5),
                      subtext: 'Inward logged',
                      value: totalReceived.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                      pillText: '1 LOTS',
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStoreKpi(
                      title: 'TOTAL ISSUED',
                      topBadge: 'OUTWARD',
                      topBadgeColor: const Color(0xFF64748B),
                      topBadgeBg: const Color(0xFFFAF7F0),
                      subtext: 'Next line handoff',
                      value: '0',
                      pillText: '0 CHALLANS',
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStoreKpi(
                      title: 'PENDING INWARDS',
                      topBadge: 'PENDING',
                      topBadgeColor: const Color(0xFFD97706),
                      topBadgeBg: const Color(0xFFFFFBEB),
                      subtext: 'Awaiting receipt',
                      value: '0',
                      pillText: 'IN-TRANSIT',
                      icon: Icons.access_time_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStoreKpi(
                      title: 'LOGGED VARIANCE',
                      topBadge: 'SHORTAGE',
                      topBadgeColor: const Color(0xFFEF4444),
                      topBadgeBg: const Color(0xFFFEF2F2),
                      subtext: 'Inward discrepancy',
                      value: '0',
                      pillText: 'UNITS',
                      icon: Icons.error_outline_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 4. Ledger & Tabs Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tab Buttons Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildTabPill(0, 'Inwards Received (1)'),
                                const SizedBox(width: 6),
                                _buildTabPill(1, 'Outward Issues (0)'),
                                const SizedBox(width: 6),
                                _buildTabPill(2, 'Pending Inward (0)'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Search Input
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                              style: GoogleFonts.publicSans(fontSize: 12.5),
                              decoration: const InputDecoration(
                                hintText: 'Search challan, article, division...',
                                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                prefixIcon: Icon(Icons.search, size: 17, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0x14000000)),

                    // Table / List Content
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: _buildLedgerContent(totalReceived),
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

  Widget _buildStoreKpi({
    required String title,
    required String topBadge,
    required Color topBadgeColor,
    required Color topBadgeBg,
    required String subtext,
    required String value,
    required String pillText,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: topBadgeBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: topBadgeColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  topBadge,
                  style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold, color: topBadgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: GoogleFonts.publicSans(fontSize: 10, color: const Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Text(
                  pillText,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3A3564),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564) : const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF3A3564) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLedgerContent(int totalReceived) {
    if (_selectedTabIndex == 0) {
      if (_searchQuery.isNotEmpty) {
        final matches = 'ISS-2026-001003 PRINTING Art #DEMO-101-03 Printed Front Panels EMB-FRAME-01 Sergio Ramos'
            .toLowerCase()
            .contains(_searchQuery);
        if (!matches) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No inward receipts matching "$_searchQuery"',
                style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ),
          );
        }
      }
      // Inwards Received Table Item matching Web Screenshot
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
                Row(
                  children: [
                    Text(
                      'ISS-2026-001003',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        'PRINTING',
                        style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                      ),
                    ),
                  ],
                ),
                Text(
                  '20/09/2026',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Art #DEMO-101-03',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            Text(
              'Printed Front Panels (Sleeve Crest Applique) - Olive Green',
              style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0x14000000)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RECEIVED QTY', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF64748B))),
                    Text(
                      '${totalReceived.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} pcs',
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RACK', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF64748B))),
                    Text('EMB-FRAME-01', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('RECEIVER', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF64748B))),
                    Text('Sergio Ramos', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    } else if (_selectedTabIndex == 1) {
      // Outward Issues
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.outbox_rounded, size: 36, color: Color(0xFF94A3B8)),
              const SizedBox(height: 8),
              Text('No Outward Issues Yet', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text('Issue finished embroidery panel batches to Stitching & Sewing.', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B))),
            ],
          ),
        ),
      );
    } else {
      // Pending Inwards
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 36, color: Color(0xFF047857)),
              const SizedBox(height: 8),
              Text('All Inward Shipments Acknowledged', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text('No pending material transfers awaiting receipt.', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }
  }
}
