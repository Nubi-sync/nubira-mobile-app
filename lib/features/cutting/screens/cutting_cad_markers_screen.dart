import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/screens/enterprise_workspace_hub_screen.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/cutting_models.dart';
import '../providers/cutting_provider.dart';

class CuttingCadMarkersScreen extends ConsumerStatefulWidget {
  const CuttingCadMarkersScreen({super.key});

  @override
  ConsumerState<CuttingCadMarkersScreen> createState() => _CuttingCadMarkersScreenState();
}

class _CuttingCadMarkersScreenState extends ConsumerState<CuttingCadMarkersScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreateMarkerModal() {
    final nameCtrl = TextEditingController(text: 'MKR-ZARA-HD-8801');
    final styleCtrl = TextEditingController(text: 'TP-2026-8801');
    final widthCtrl = TextEditingController(text: '60.0');
    final lengthCtrl = TextEditingController(text: '5.4');
    final efficiencyCtrl = TextEditingController(text: '89.6');
    final ratioCtrl = TextEditingController(text: '1:2:2:1 (Ratio: 6)');
    final patternMasterCtrl = TextEditingController(text: 'R. Veerappan (Master Cutter)');
    String software = 'GERBER_ACCUMARK';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Register CAD Marker & Nesting Plan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3A3564),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Marker Code / Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: styleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Style Ref / Tech Pack',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: software,
                  decoration: InputDecoration(
                    labelText: 'CAD / Nesting Software',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'GERBER_ACCUMARK', child: Text('Gerber AccuMark V15')),
                    DropdownMenuItem(value: 'LECTRA_MODARIS', child: Text('Lectra Modaris Diamino')),
                    DropdownMenuItem(value: 'OPTITEX_PDS', child: Text('Optitex PDS & Marker')),
                    DropdownMenuItem(value: 'CLO3D', child: Text('CLO 3D Nested Plot')),
                  ],
                  onChanged: (v) => setMState(() => software = v ?? 'GERBER_ACCUMARK'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widthCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Width (Inches)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: lengthCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Length (Meters)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: efficiencyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Efficiency (%)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: ratioCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nested Ratio',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: patternMasterCtrl,
                  decoration: InputDecoration(
                    labelText: 'Pattern Master / CAD Operator',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3564),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final eff = double.tryParse(efficiencyCtrl.text.trim()) ?? 89.0;
                      final w = double.tryParse(widthCtrl.text.trim()) ?? 60.0;
                      final l = double.tryParse(lengthCtrl.text.trim()) ?? 5.4;

                      final newMarker = MarkerEfficiency(
                        id: 'mrk-${DateTime.now().millisecondsSinceEpoch}',
                        markerName: nameCtrl.text.trim(),
                        styleRef: styleCtrl.text.trim(),
                        cadSoftware: software,
                        fabricWidthInches: w,
                        markerLengthMeters: l,
                        efficiencyPercent: eff,
                        sizesIncluded: const ['S', 'M', 'L', 'XL'],
                        ratio: ratioCtrl.text.trim(),
                        patternMaster: patternMasterCtrl.text.trim(),
                        status: 'CAD_APPROVED',
                        createdAt: DateTime.now().toIso8601String().split('T')[0],
                      );

                      ref.read(cuttingProvider.notifier).addMarker(newMarker);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('CAD Marker saved & ready for spreading.')),
                      );
                    },
                    child: Text(
                      'Save & Approve Marker',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuttingState = ref.watch(cuttingProvider);
    final markers = cuttingState.markers;

    final query = _searchCtrl.text.trim().toLowerCase();
    final filteredMarkers = markers.where((m) {
      return query.isEmpty ||
          m.markerName.toLowerCase().contains(query) ||
          m.styleRef.toLowerCase().contains(query) ||
          m.cadSoftware.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/cutting/markers'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        trailing: IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3A3564)),
          onPressed: () => ref.read(cuttingProvider.notifier).fetchCuttingData(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF3A3564),
          onRefresh: () => ref.read(cuttingProvider.notifier).fetchCuttingData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Back Row
                InkWell(
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Workspace hub / 03 - Cutting floor',
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                            child: const Icon(Icons.open_in_full_rounded, color: Color(0xFF3A3564), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CAD Markers & Nesting',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF3A3564),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Gerber & Lectra CAD efficiency optimization, grainline constraints, cut width nesting, and piece yield logs',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openCreateMarkerModal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3A3564),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'Add CAD Marker',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search marker code, style, software...',
                    hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Markers List
                if (filteredMarkers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.crop_free_rounded, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'No CAD markers found',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredMarkers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final m = filteredMarkers[index];
                      return _buildMarkerCard(m);
                    },
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkerCard(MarkerEfficiency m) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Text(
                  m.markerName,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3A3564),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  '${m.efficiencyPercent}% EFF',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${m.styleRef} • ${m.styleName}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'CAD Software: ${m.cadSoftware}',
            style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Width: ${m.fabricWidthInches}" • Length: ${m.markerLengthMeters}m',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3A3564),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Ratio: ${m.ratio}',
                style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF475569)),
              ),
              const Spacer(),
              Text(
                m.patternMaster,
                style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
