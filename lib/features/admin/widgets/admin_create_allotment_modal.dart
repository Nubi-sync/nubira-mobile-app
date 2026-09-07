import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';

class BomMaterialItem {
  String id;
  String itemName;
  String requiredQty;
  String source; // 'CLIENT' or 'FACTORY_STORE'
  bool isIssued;

  BomMaterialItem({
    required this.id,
    required this.itemName,
    required this.requiredQty,
    this.source = 'CLIENT',
    this.isIssued = false,
  });
}

class AdminCreateAllotmentModal extends StatefulWidget {
  final VoidCallback onSuccess;

  const AdminCreateAllotmentModal({
    super.key,
    required this.onSuccess,
  });

  @override
  State<AdminCreateAllotmentModal> createState() => _AdminCreateAllotmentModalState();
}

class _AdminCreateAllotmentModalState extends State<AdminCreateAllotmentModal> {
  bool _isLoading = false;
  bool _isInit = true;

  List<dynamic> _challans = [];
  List<dynamic> _linemen = [];
  List<dynamic> _articles = [];

  String? _selectedChallanId;
  String? _selectedLinemanId;
  String? _selectedArticleId;

  final TextEditingController _targetQtyCtrl = TextEditingController(text: '500');
  final TextEditingController _customItemNameCtrl = TextEditingController();
  final TextEditingController _customItemQtyCtrl = TextEditingController();
  String _customItemSource = 'CLIENT';

  List<BomMaterialItem> _materials = [];

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  @override
  void dispose() {
    _targetQtyCtrl.dispose();
    _customItemNameCtrl.dispose();
    _customItemQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final chRes = await supabase.from('challans').select('id, challan_no, brand, fabric_type').order('created_at', ascending: false).limit(50);
      final lmRes = await supabase.from('profiles').select('id, username').eq('is_active', true);
      final artRes = await supabase.from('articles').select('id, art_no, description').eq('is_active', true);

      setState(() {
        _challans = (chRes as List?) ?? [];
        _linemen = (lmRes as List?) ?? [];
        _articles = (artRes as List?) ?? [];

        if (_challans.isNotEmpty) _selectedChallanId = _challans.first['id'].toString();
        if (_linemen.isNotEmpty) _selectedLinemanId = _linemen.first['id'].toString();
        if (_articles.isNotEmpty) _selectedArticleId = _articles.first['id'].toString();

        _isInit = false;
      });

      _autoCalculateBOM();
    } catch (e) {
      if (mounted) {
        setState(() => _isInit = false);
      }
    }
  }

  void _autoCalculateBOM() {
    final qty = int.tryParse(_targetQtyCtrl.text.trim()) ?? 500;
    final fabricMeters = (qty * 0.45).round();
    final threadCones = (qty / 50).ceil().clamp(2, 50);

    setState(() {
      _materials = [
        BomMaterialItem(
          id: 'mat-fabric-${DateTime.now().millisecondsSinceEpoch}',
          itemName: 'Main Fabric Roll',
          requiredQty: '$fabricMeters Meters',
          source: 'CLIENT',
          isIssued: false,
        ),
        BomMaterialItem(
          id: 'mat-thread-${DateTime.now().millisecondsSinceEpoch + 1}',
          itemName: 'Matching Sewing Thread',
          requiredQty: '$threadCones Cones',
          source: 'FACTORY_STORE',
          isIssued: false,
        ),
        BomMaterialItem(
          id: 'mat-label-${DateTime.now().millisecondsSinceEpoch + 2}',
          itemName: 'Main Brand Label',
          requiredQty: '$qty pcs',
          source: 'CLIENT',
          isIssued: false,
        ),
        BomMaterialItem(
          id: 'mat-size-${DateTime.now().millisecondsSinceEpoch + 3}',
          itemName: 'Size Labels',
          requiredQty: '$qty pcs',
          source: 'CLIENT',
          isIssued: false,
        ),
      ];
    });
  }

  void _addPreset(String name, String qtySuffix, double multiplier, String source) {
    final targetQty = int.tryParse(_targetQtyCtrl.text.trim()) ?? 500;
    final calculatedQty = (targetQty * multiplier).round();
    final displayQty = '$calculatedQty $qtySuffix';

    // Check if already exists
    if (_materials.any((m) => m.itemName.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name is already in the BOM checklist.')),
      );
      return;
    }

    setState(() {
      _materials.add(
        BomMaterialItem(
          id: 'mat-preset-${DateTime.now().millisecondsSinceEpoch}',
          itemName: name,
          requiredQty: displayQty,
          source: source,
          isIssued: false,
        ),
      );
    });
  }

  void _addCustomItem() {
    final name = _customItemNameCtrl.text.trim();
    final qty = _customItemQtyCtrl.text.trim();
    if (name.isEmpty || qty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Material Name and Quantity.')),
      );
      return;
    }

    setState(() {
      _materials.add(
        BomMaterialItem(
          id: 'mat-custom-${DateTime.now().millisecondsSinceEpoch}',
          itemName: name,
          requiredQty: qty,
          source: _customItemSource,
          isIssued: false,
        ),
      );
      _customItemNameCtrl.clear();
      _customItemQtyCtrl.clear();
    });
  }

  Future<void> _submitAllotment() async {
    if (_selectedChallanId == null || _selectedLinemanId == null || _selectedArticleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Challan, Lineman, and Article.')),
      );
      return;
    }

    final qty = int.tryParse(_targetQtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Target Quantity.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final todayDate = DateTime.now().toIso8601String().substring(0, 10);

      // 1. Insert Allotment
      final newAl = await supabase.from('allotments').insert({
        'challan_id': _selectedChallanId,
        'lineman_id': _selectedLinemanId,
        'article_id': _selectedArticleId,
        'target_qty': qty,
        'status': 'IN_PROGRESS',
        'qc_status': 'PENDING_STITCHING',
        'mending_status': 'PENDING_STITCHING',
        'allotment_date': todayDate,
      }).select('id').single();

      final allotmentId = newAl['id']?.toString();
      if (allotmentId == null) throw Exception('Failed to create allotment header');

      // 2. Insert Default Variant (Free Size / Standard)
      await supabase.from('allotment_variants').insert({
        'allotment_id': allotmentId,
        'color': 'Standard',
        'size': 'Free Size',
        'quantity': qty,
        'completed_qty': 0,
      });

      // 3. Insert All BOM Materials
      if (_materials.isNotEmpty) {
        final materialsToInsert = _materials.map((m) {
          final noteObj = {
            'source': m.source,
            'is_issued': m.isIssued,
            'item_name': m.itemName,
            'required_qty': m.requiredQty,
          };

          return {
            'allotment_id': allotmentId,
            'item_name': m.itemName,
            'required_qty': m.requiredQty,
            'admin_issued': m.isIssued,
            'notes': jsonEncode(noteObj),
          };
        }).toList();

        await supabase.from('allotment_materials').insert(materialsToInsert);
      }

      // 4. Update Challan status to IN_PROGRESS
      await supabase.from('challans').update({'status': 'IN_PROGRESS'}).eq('id', _selectedChallanId!);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.green,
            content: Text('Target Allotment & BOM Trims assigned successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientSuppliedCount = _materials.where((m) => m.source == 'CLIENT').length;
    final factorySourcedCount = _materials.where((m) => m.source == 'FACTORY_STORE').length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar indicator
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.steelMist,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_turned_in_rounded, color: AppTheme.steel, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Target Allotment',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                          ),
                          Text(
                            'Order allotment & BOM material issuance',
                            style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.inkSoft),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            if (_isInit)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60.0),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.steel),
                ),
              )
            else ...[
              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // --- SECTION 1: ORDER INFO ---
                    Text(
                      '1. Order & Lineman Selection',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink),
                    ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _selectedChallanId,
                    decoration: const InputDecoration(labelText: 'Select Delivery Challan *', prefixIcon: Icon(Icons.layers_outlined, size: 20)),
                    items: _challans.map((c) {
                      final id = c['id'].toString();
                      final chNo = c['challan_no']?.toString() ?? 'Challan';
                      final brand = c['brand']?.toString() ?? '';
                      return DropdownMenuItem(value: id, child: Text('$chNo ($brand)'));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedChallanId = val),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _selectedLinemanId,
                    decoration: const InputDecoration(labelText: 'Assign Lineman / Tailor *', prefixIcon: Icon(Icons.person_outline, size: 20)),
                    items: _linemen.map((l) {
                      final id = l['id'].toString();
                      final un = l['username']?.toString() ?? 'Lineman';
                      return DropdownMenuItem(value: id, child: Text(un));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedLinemanId = val),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _selectedArticleId,
                    decoration: const InputDecoration(labelText: 'Select Article Style *', prefixIcon: Icon(Icons.sell_outlined, size: 20)),
                    items: _articles.map((a) {
                      final id = a['id'].toString();
                      final artNo = a['art_no']?.toString() ?? '';
                      final desc = a['description']?.toString() ?? '';
                      return DropdownMenuItem(value: id, child: Text('$artNo ${desc.isNotEmpty ? '- $desc' : ''}'));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedArticleId = val),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _targetQtyCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _autoCalculateBOM(),
                    decoration: const InputDecoration(labelText: 'Target Quantity (Pieces) *', prefixIcon: Icon(Icons.numbers, size: 20)),
                  ),

                  const SizedBox(height: 24),
                  const Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 20),

                  // --- SECTION 2: BOM CHECKLIST (EXACT MATCH TO WEB) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '2. BOM Raw Materials & Trims Checklist',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Client Consignment vs Factory In-House Sourcing',
                            style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.steel,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _autoCalculateBOM,
                        icon: const Icon(Icons.auto_awesome, size: 15),
                        label: Text('Auto-BOM', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Summary Badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.steelTint,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.business, size: 14, color: AppTheme.steel),
                            const SizedBox(width: 5),
                            Text('Client Supplied: $clientSuppliedCount items', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.steelDark)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 14, color: AppTheme.inkSoft),
                            const SizedBox(width: 5),
                            Text('Factory: $factorySourcedCount items', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // BOM Cards Grid / List
                  ..._materials.map((mat) {
                    final isClient = mat.source == 'CLIENT';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: mat.isIssued ? AppTheme.greenMist : AppTheme.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: mat.isIssued ? AppTheme.green : AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          // Checkbox (Issued toggle)
                          GestureDetector(
                            onTap: () {
                              setState(() => mat.isIssued = !mat.isIssued);
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: mat.isIssued ? AppTheme.green : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: mat.isIssued ? AppTheme.green : AppTheme.border),
                              ),
                              child: mat.isIssued ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Material Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mat.itemName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      'Qty: ${mat.requiredQty}',
                                      style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.inkSoft),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          mat.source = isClient ? 'FACTORY_STORE' : 'CLIENT';
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isClient ? AppTheme.steelTint : AppTheme.card,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Text(
                                          isClient ? 'Client Supplied' : 'Factory Sourced',
                                          style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: isClient ? AppTheme.steelDark : AppTheme.inkSoft),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Delete button
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.inkFaint),
                            onPressed: () {
                              setState(() => _materials.removeWhere((m) => m.id == mat.id));
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  // Quick Presets Horizontal Scroll
                  Text(
                    'QUICK PRESETS:',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.inkFaint),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('+18L 4-Hole Buttons', () => _addPreset('18L 4-Hole Buttons', 'pcs', 3.0, 'CLIENT')),
                        _buildPresetChip('+Elastic Waistband 1.5"', () => _addPreset('Elastic Waistband 1.5"', 'Meters', 0.8, 'CLIENT')),
                        _buildPresetChip('+Drawcord / Dori 45"', () => _addPreset('Drawcord / Dori 45"', 'pcs', 1.0, 'CLIENT')),
                        _buildPresetChip('+Metal Eyelets #4', () => _addPreset('Metal Eyelets #4', 'pcs', 2.0, 'CLIENT')),
                        _buildPresetChip('+Care & Wash Labels', () => _addPreset('Care & Wash Labels', 'pcs', 1.0, 'CLIENT')),
                        _buildPresetChip('+Satin Neck Piping', () => _addPreset('Satin Neck Piping Tape', 'Meters', 0.3, 'FACTORY_STORE')),
                        _buildPresetChip('+Desiccant Silica Gel', () => _addPreset('Desiccant Silica Gel', 'Pouches', 0.1, 'FACTORY_STORE')),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Add Custom Item Form
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _customItemNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Custom Item Name',
                                  hintText: 'e.g. Drawcord, Eyelets',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _customItemQtyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Qty / Unit',
                                  hintText: 'e.g. 1500 pcs',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _customItemSource,
                                isDense: true,
                                decoration: const InputDecoration(labelText: 'Origin'),
                                items: const [
                                  DropdownMenuItem(value: 'CLIENT', child: Text('Client Supplied (Buyer)')),
                                  DropdownMenuItem(value: 'FACTORY_STORE', child: Text('Factory Sourced')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _customItemSource = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.steel,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              onPressed: _addCustomItem,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Item'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.card,
                border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.steel,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submitAllotment,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Save Allotment & Issue Trims to Lineman',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: AppTheme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppTheme.border)),
        labelStyle: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.steel),
      ),
    );
  }
}
