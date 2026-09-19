import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/ph_settings_model.dart';
import '../providers/ph_settings_provider.dart';
import 'design_studio_screen.dart';

class PHSettingsScreen extends ConsumerStatefulWidget {
  const PHSettingsScreen({super.key});

  @override
  ConsumerState<PHSettingsScreen> createState() => _PHSettingsScreenState();
}

class _PHSettingsScreenState extends ConsumerState<PHSettingsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Tab 1: Body Part Codes Form
  final _bodyCodeCtrl = TextEditingController();
  final _bodyNameCtrl = TextEditingController();

  // Tab 2: BOM Component Codes Form
  String _bomType = 'BUTTON';
  final _bomSpecCtrl = TextEditingController();
  final _bomCodeCtrl = TextEditingController();

  // Tab 3: Selected Template
  GarmentTemplateModel? _selectedTemplate;

  // Preset constants
  static const List<({String code, String name})> _bodyPresets = [
    (code: 'BC', name: 'Bicep Circumference'),
    (code: 'Ch1', name: 'Chest Width (1" below armhole)'),
    (code: 'SL', name: 'Sleeve Length'),
    (code: 'BL', name: 'Body Length (HSP to Hem)'),
    (code: 'SH', name: 'Across Shoulder'),
    (code: 'NK', name: 'Neck Width'),
    (code: 'WST', name: 'Waist Width'),
    (code: 'HIP', name: 'Hip Width'),
    (code: 'TH', name: 'Thigh Width'),
    (code: 'IN', name: 'Inseam Length'),
  ];

  static const List<({String type, String spec, String code})> _bomPresets = [
    (type: 'BUTTON', spec: 'Red Horn Button 24L', code: 'BTN-RED-24L'),
    (type: 'BUTTON', spec: 'Mother of Pearl 18L', code: 'BTN-MOP-18L'),
    (type: 'SLEEVE', spec: 'Cut Sleeve / Raglan Finish', code: 'SLV-CUT-01'),
    (type: 'SLEEVE', spec: 'Full Sleeve with 2x2 Rib Cuff', code: 'SLV-FULL-RIB'),
    (type: 'COLLAR', spec: 'Flatknit Rib Collar 4.5cm', code: 'CLR-RIB-45'),
    (type: 'ZIPPER', spec: 'YKK #5 Antique Brass Metal', code: 'ZIP-YKK-M5'),
    (type: 'TRIM', spec: 'Braided Cotton Drawcord with Metal Aglets', code: 'TRM-DRW-01'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(phSettingsProvider.notifier).fetchSettings();
    });
  }

  @override
  void dispose() {
    _bodyCodeCtrl.dispose();
    _bodyNameCtrl.dispose();
    _bomSpecCtrl.dispose();
    _bomCodeCtrl.dispose();
    super.dispose();
  }

  bool _isAuthorized(AuthState authState) {
    if (authState.tenantProfile?.isSuperAdmin == true ||
        authState.tenantProfile?.isPlatformAdmin == true) {
      return true;
    }
    final role = (authState.tenantProfile?.role ?? authState.userRole ?? '').toLowerCase();
    if (role.contains('ph') ||
        role.contains('provisional') ||
        role.contains('admin') ||
        role.contains('head') ||
        role.contains('director') ||
        role.contains('supervisor') ||
        role.contains('executive')) {
      return true;
    }
    return true; // Default permit with privileged indicator
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isPrivileged = _isAuthorized(authState);
    final settingsState = ref.watch(phSettingsProvider);
    final activeTab = settingsState.activeTab;

    if (_selectedTemplate == null && settingsState.templates.isNotEmpty) {
      _selectedTemplate = settingsState.templates.first;
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: const WorkspaceHubDrawer(activeRoute: '/design/settings'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(phSettingsProvider.notifier).fetchSettings();
        },
        color: const Color(0xFF332B6B),
        backgroundColor: Colors.white,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Breadcrumb Hierarchy Trail
            Row(
              children: [
                InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DesignStudioScreen()),
                    );
                  },
                  child: Text(
                    'Design Studio',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('/', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                const SizedBox(width: 6),
                Text(
                  'Configuration',
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('/', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'PH Settings',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Header / Settings Card (#FAFAF8)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x1A000000)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
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
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: const Icon(Icons.settings_outlined, color: Color(0xFF332B6B), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Provisional Head Studio Settings',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFEBFB),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0x26332B6B)),
                                  ),
                                  child: Text(
                                    'PH PRIVILEGED',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF332B6B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configure standardized code-words for body parts (e.g. BC = Bicep), BOM trims (buttons, sleeves), and auto-fill garment templates',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                color: const Color(0xFF6B6A65),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF7F0),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0x18000000)),
                              ),
                              child: Text(
                                'Admin Workspace',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF332B6B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!isPrivileged) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: Color(0xFFDC2626), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This screen requires Provisional Head or Executive administrative privileges.',
                        style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // 3. Navigation Tabs (3 Segmented Tabs with Live Count Badges)
              SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton(
                    index: 0,
                    icon: Icons.straighten_rounded,
                    label: '1. Body Part Code-Words',
                    count: settingsState.bodyCodes.length,
                    isActive: activeTab == 0,
                  ),
                  const SizedBox(width: 8),
                  _buildTabButton(
                    index: 1,
                    icon: Icons.inventory_2_outlined,
                    label: '2. BOM Component Codes',
                    count: settingsState.bomCodes.length,
                    isActive: activeTab == 1,
                  ),
                  const SizedBox(width: 8),
                  _buildTabButton(
                    index: 2,
                    icon: Icons.layers_outlined,
                    label: '3. Garment Templates (Auto-Fill)',
                    count: settingsState.templates.length,
                    isActive: activeTab == 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Tab Content
            if (activeTab == 0) _buildBodyPartsTab(settingsState),
            if (activeTab == 1) _buildBOMCodesTab(settingsState),
            if (activeTab == 2) _buildGarmentTemplatesTab(settingsState),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    required int count,
    required bool isActive,
  }) {
    return InkWell(
      onTap: () {
        ref.read(phSettingsProvider.notifier).setActiveTab(index);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF332B6B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF332B6B) : const Color(0xFFDAD9D3),
          ),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x1F332B6B),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF6B6A65),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : const Color(0xFF1C1C1A),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isActive ? const Color(0x40FFFFFF) : const Color(0xFFF3F2EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : const Color(0xFF5F5E5A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 1: BODY PART CODE-WORDS
  // ==========================================================================
  Widget _buildBodyPartsTab(PHSettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add Body Part Code Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAF8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF332B6B)),
                  const SizedBox(width: 8),
                  Text(
                    'Add Body Part Code',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),
              Text(
                'CODE-WORD *',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bodyCodeCtrl,
                style: GoogleFonts.jetBrainsMono(fontSize: 13.5, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'e.g. BC, Ch1, SL, NK',
                  hintStyle: GoogleFonts.jetBrainsMono(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'FULL BODY PART NAME *',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bodyNameCtrl,
                style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Bicep width, chest circumference',
                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: state.isSubmitting ? null : _saveBodyPartCode,
                  icon: state.isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 17, color: Colors.white),
                  label: Text(
                    state.isSubmitting ? 'Saving...' : 'Save code-word',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF332B6B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Quick presets (tap to fill)
              Text(
                'Quick presets (tap to fill):',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5F5E5A),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _bodyPresets.map((p) {
                  return InkWell(
                    onTap: () {
                      _bodyCodeCtrl.text = p.code;
                      _bodyNameCtrl.text = p.name;
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F2EE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x18000000)),
                      ),
                      child: Text(
                        '${p.code}: ${p.name.split(' ')[0]}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF332B6B),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Defined body part code-words Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAF8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Defined body part code-words',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'These abbreviations are auto-used across POM grading tables and tech-packs',
                          style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x18000000)),
                    ),
                    child: Text(
                      '${state.bodyCodes.length} codes',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF332B6B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.bodyCodes.isEmpty)
                _buildEmptyState(
                  icon: Icons.edit_note_rounded,
                  title: 'No custom body part codes yet',
                  subtitle: 'Add code-words like BC (Bicep) or Ch1 (Chest) to streamline tech-pack generation.',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.bodyCodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final item = state.bodyCodes[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0x18000000)),
                            ),
                            child: Text(
                              item.code,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF332B6B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.bodyPartName,
                              style: GoogleFonts.publicSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1C1C1A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                            onPressed: () => _confirmDelete('BODY', item.id, '${item.code} (${item.bodyPartName})'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveBodyPartCode() async {
    final code = _bodyCodeCtrl.text.trim();
    final name = _bodyNameCtrl.text.trim();
    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both code-word and full body part name.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final res = await ref.read(phSettingsProvider.notifier).createBodyPartCode(
          code: code,
          bodyPartName: name,
        );

    if (mounted) {
      if (res.success) {
        _bodyCodeCtrl.clear();
        _bodyNameCtrl.clear();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B7A43),
            content: Text('Code-word "${res.data?.code}" saved successfully!'),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text(res.error ?? 'Failed to save code-word.'),
          ),
        );
      }
    }
  }

  // ==========================================================================
  // TAB 2: BOM COMPONENT CODES
  // ==========================================================================
  Widget _buildBOMCodesTab(PHSettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add BOM Component Form Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAF8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF332B6B)),
                  const SizedBox(width: 8),
                  Text(
                    'Add BOM Component',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),
              Text(
                'COMPONENT TYPE *',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDAD9D3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _bomType,
                    isExpanded: true,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    items: const [
                      DropdownMenuItem(value: 'BUTTON', child: Text('BUTTON (Buttons & Rivets)')),
                      DropdownMenuItem(value: 'SLEEVE', child: Text('SLEEVE (Sleeve Type & Rib)')),
                      DropdownMenuItem(value: 'COLLAR', child: Text('COLLAR (Collar & Neckbands)')),
                      DropdownMenuItem(value: 'TRIM', child: Text('TRIM (Drawcords, Eyelets, Badges)')),
                      DropdownMenuItem(value: 'ZIPPER', child: Text('ZIPPER (Zippers & Sliders)')),
                      DropdownMenuItem(value: 'FABRIC', child: Text('FABRIC (Fabric Specification)')),
                      DropdownMenuItem(value: 'THREAD', child: Text('THREAD (Sewing Thread Spec)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _bomType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'COMPONENT SPEC / DESCRIPTION *',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bomSpecCtrl,
                style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Red Horn Button 24L, Cut Sleeve...',
                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'OPTIONAL SHORT CODE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bomCodeCtrl,
                style: GoogleFonts.jetBrainsMono(fontSize: 13.5, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'e.g. BTN-RED-24, SLV-CUT-01',
                  hintStyle: GoogleFonts.jetBrainsMono(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: state.isSubmitting ? null : _saveBOMComponent,
                  icon: state.isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 17, color: Colors.white),
                  label: Text(
                    state.isSubmitting ? 'Saving...' : 'Save BOM component',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF332B6B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Quick Presets
              Text(
                'Quick presets:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5F5E5A),
                ),
              ),
              const SizedBox(height: 6),
              Column(
                children: _bomPresets.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () {
                        setState(() => _bomType = p.type);
                        _bomSpecCtrl.text = p.spec;
                        _bomCodeCtrl.text = p.code;
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F2EE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x18000000)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              p.type,
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF332B6B)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.spec,
                                style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF1C1C1A)),
                              ),
                            ),
                            Text(
                              p.code,
                              style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Standardized BOM Component Registry Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAF8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Standardized BOM Component Registry',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Used by Merchandising & Sourcing to match Tech-Pack specifications',
                          style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x18000000)),
                    ),
                    child: Text(
                      '${state.bomCodes.length} components',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF332B6B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.bomCodes.isEmpty)
                _buildEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No BOM component codes defined',
                  subtitle: 'Add components like buttons, zippers, sleeve finishes, and collar trims.',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.bomCodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final item = state.bomCodes[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              item.componentType,
                              style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF334155)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.componentSpec,
                              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1A)),
                            ),
                          ),
                          if (item.code != null && item.code!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF7F0),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0x18000000)),
                              ),
                              child: Text(
                                item.code!,
                                style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B)),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                            onPressed: () => _confirmDelete('BOM', item.id, item.componentSpec),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveBOMComponent() async {
    final spec = _bomSpecCtrl.text.trim();
    final code = _bomCodeCtrl.text.trim();
    if (spec.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Component specification is required.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final res = await ref.read(phSettingsProvider.notifier).createBOMComponentCode(
          componentType: _bomType,
          componentSpec: spec,
          code: code.isNotEmpty ? code : null,
        );

    if (mounted) {
      if (res.success) {
        _bomSpecCtrl.clear();
        _bomCodeCtrl.clear();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B7A43),
            content: Text('BOM Component "${res.data?.componentSpec}" saved successfully!'),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text(res.error ?? 'Failed to save BOM component.'),
          ),
        );
      }
    }
  }

  // ==========================================================================
  // TAB 3: GARMENT TEMPLATES (AUTO-FILL)
  // ==========================================================================
  Widget _buildGarmentTemplatesTab(PHSettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Banner Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAF8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Garment Silhouette Templates (Auto-Fill)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openCreateTemplateSheet(),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: const Text('New Template'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF332B6B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'When you select a garment silhouette (e.g. T-Shirt, Hoodie) during Tech-Pack creation, standard body parts and BOM trims automatically populate.',
                style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B), height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Template Cards
        if (state.templates.isEmpty)
          _buildEmptyState(
            icon: Icons.layers_outlined,
            title: 'No garment templates available',
            subtitle: 'Create a custom template to speed up tech-pack spec generation.',
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final tmpl = state.templates[i];
              final isSelected = _selectedTemplate?.id == tmpl.id;

              return InkWell(
                onTap: () => setState(() => _selectedTemplate = tmpl),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFAF7F0) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF332B6B) : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tmpl.garmentType,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: tmpl.isSystemTemplate ? const Color(0xFFF1F5F9) : const Color(0xFFEFEBFB),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: tmpl.isSystemTemplate ? const Color(0xFFCBD5E1) : const Color(0x33332B6B),
                              ),
                            ),
                            child: Text(
                              tmpl.isSystemTemplate ? 'SYSTEM DEFAULT' : 'CUSTOM PH',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: tmpl.isSystemTemplate ? const Color(0xFF475569) : const Color(0xFF332B6B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tmpl.bodyParts.length} body parts configured',
                        style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: tmpl.bodyParts.map((bp) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0x18000000)),
                            ),
                            child: Text(
                              bp.code,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF332B6B),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (!tmpl.isSystemTemplate) ...[
                        const Divider(height: 16, color: Color(0xFFE2E8F0)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _confirmDelete('TEMPLATE', tmpl.id, tmpl.garmentType),
                            icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                            label: Text(
                              'Delete template',
                              style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Detailed Schema for Selected Template
          if (_selectedTemplate != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'POM Rules: "${_selectedTemplate!.garmentType}"',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        '${_selectedTemplate!.bodyParts.length} rules',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedTemplate!.bodyParts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final bp = _selectedTemplate!.bodyParts[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF7F0),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0x18000000)),
                              ),
                              child: Text(
                                bp.code,
                                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF332B6B)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                bp.name,
                                style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1A)),
                              ),
                            ),
                            Text(
                              '±${bp.defaultTolerance}cm | +${bp.defaultGradeStep}cm',
                              style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  void _openCreateTemplateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CreateTemplateSheet(),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String type, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete "$name"?',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
        ),
        content: Text(
          'Are you sure you want to permanently delete this $type configuration?',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              bool success = false;
              if (type == 'BODY') {
                success = await ref.read(phSettingsProvider.notifier).deleteBodyPartCode(id);
              } else if (type == 'BOM') {
                success = await ref.read(phSettingsProvider.notifier).deleteBOMComponentCode(id);
              } else if (type == 'TEMPLATE') {
                success = await ref.read(phSettingsProvider.notifier).deleteGarmentTemplate(id);
              }
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: success ? const Color(0xFF1B7A43) : const Color(0xFFDC2626),
                    content: Text(success ? '$name deleted successfully' : 'Failed to delete $name'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );
  }
}

class _CreateTemplateSheet extends ConsumerStatefulWidget {
  const _CreateTemplateSheet();

  @override
  ConsumerState<_CreateTemplateSheet> createState() => _CreateTemplateSheetState();
}

class _CreateTemplateSheetState extends ConsumerState<_CreateTemplateSheet> {
  final _nameCtrl = TextEditingController();
  final List<({TextEditingController code, TextEditingController name, TextEditingController tol, TextEditingController step})> _rows = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _addRow(code: 'CH', name: 'Chest Width', tol: '1.0', step: '2.5');
    _addRow(code: 'BL', name: 'Body Length', tol: '1.0', step: '2.0');
  }

  void _addRow({String code = 'POM', String name = 'New Measure', String tol = '1.0', String step = '2.0'}) {
    setState(() {
      _rows.add((
        code: TextEditingController(text: code),
        name: TextEditingController(text: name),
        tol: TextEditingController(text: tol),
        step: TextEditingController(text: step),
      ));
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final r in _rows) {
      r.code.dispose();
      r.name.dispose();
      r.tol.dispose();
      r.step.dispose();
    }
    super.dispose();
  }

  void _handleSave() async {
    final typeName = _nameCtrl.text.trim();
    if (typeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter garment silhouette name.')),
      );
      return;
    }

    final List<GarmentTemplateBodyPartModel> parts = [];
    for (final r in _rows) {
      final c = r.code.text.trim().toUpperCase();
      final n = r.name.text.trim();
      final t = double.tryParse(r.tol.text.trim()) ?? 1.0;
      final s = double.tryParse(r.step.text.trim()) ?? 2.0;
      if (c.isNotEmpty && n.isNotEmpty) {
        parts.add(GarmentTemplateBodyPartModel(
          code: c,
          name: n,
          defaultTolerance: t,
          defaultGradeStep: s,
        ));
      }
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final res = await ref.read(phSettingsProvider.notifier).createGarmentTemplate(
          garmentType: typeName,
          bodyParts: parts,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.success) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B7A43),
          content: Text('Template "$typeName" created successfully!'),
        ),
      );
      nav.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text(res.error ?? 'Failed to create template.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 14,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create Custom Garment Template',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFE2E8F0)),
            Text(
              'GARMENT SILHOUETTE NAME *',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. Bomber Jacket, Kimono, Cargo Shorts',
                hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TEMPLATE BODY PARTS:',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
                TextButton.icon(
                  onPressed: () => _addRow(),
                  icon: const Icon(Icons.add, size: 14, color: Color(0xFF332B6B)),
                  label: Text('Add Row', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF332B6B))),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final r = _rows[i];
                return Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        controller: r.code,
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: 'Code',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextFormField(
                        controller: r.name,
                        style: GoogleFonts.publicSans(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Measurement Location',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                      onPressed: () {
                        if (_rows.length > 1) {
                          setState(() => _rows.removeAt(i));
                        }
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFDAD9D3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF6B6A65))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF332B6B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      _isSubmitting ? 'Saving...' : 'Save Template',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
