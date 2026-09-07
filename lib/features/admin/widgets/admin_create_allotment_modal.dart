import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

class ColorMatrixRow {
  String id;
  String color;
  Map<String, int> quantities;

  ColorMatrixRow({
    required this.id,
    required this.color,
    required this.quantities,
  });

  int get rowTotal => quantities.values.fold(0, (sum, q) => sum + q);
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

  // Dropdown / Data Lists
  List<dynamic> _managers = [];
  List<dynamic> _linemen = [];
  List<dynamic> _articles = [];
  List<dynamic> _challans = [];

  // Section 1: Selection & Order Info
  String? _selectedManagerName;
  String? _selectedLinemanId;
  String? _selectedArticleId;
  String? _selectedChallanId;
  String _selectedArticleDisplay = '';
  String _selectedArticleDesc = '';
  String _priority = 'NORMAL'; // 'NORMAL', 'RUSH', 'CRITICAL'
  
  DateTime _dueDate = DateTime.now().add(const Duration(days: 2));
  final TextEditingController _shiftHoursCtrl = TextEditingController(text: '16');
  final TextEditingController _clientChallanNoCtrl = TextEditingController();
  final List<String> _samplePhotos = [];

  // Section 2: Size & Color Ratio Matrix
  String _activePreset = 'alpha';
  List<String> _selectedSizes = ['S', 'M', 'L', 'XL'];
  final TextEditingController _customSizeCtrl = TextEditingController();
  List<ColorMatrixRow> _colorRows = [
    ColorMatrixRow(id: '1', color: 'Navy Blue', quantities: {}),
    ColorMatrixRow(id: '2', color: 'Black', quantities: {}),
  ];

  // Section 3: BOM Raw Materials & Trims Checklist
  List<BomMaterialItem> _materials = [];
  final TextEditingController _customItemNameCtrl = TextEditingController();
  final TextEditingController _customItemQtyCtrl = TextEditingController();
  String _customItemSource = 'CLIENT';

  final ImagePicker _picker = ImagePicker();

  // Presets mapping
  static const Map<String, List<String>> sizePresets = {
    'alpha': ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', '4XL'],
    'numeric': ['28', '30', '32', '34', '36', '38', '40', '42', '44'],
    'kids_age': ['0-6M', '6-12M', '1-2Y', '2-3Y', '4-5Y', '6-7Y', '8-9Y', '10-12Y', '14-16Y'],
    'kids_num': ['16', '18', '20', '22', '24', '26', '28', '30', '32', '34'],
    'free_size': ['Free Size'],
  };

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _shiftHoursCtrl.dispose();
    _clientChallanNoCtrl.dispose();
    _customSizeCtrl.dispose();
    _customItemNameCtrl.dispose();
    _customItemQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      // 1. Fetch Linemen
      final lmRes = await supabase
          .from('profiles')
          .select('id, username, role')
          .eq('is_active', true)
          .order('username', ascending: true);

      // 2. Fetch Articles
      final artRes = await supabase
          .from('articles')
          .select('id, art_no, description, stitching_rate, size_rates')
          .order('art_no', ascending: true);

      // 3. Fetch Challans
      final chRes = await supabase
          .from('challans')
          .select('id, challan_no, brand, fabric_type, total_qty')
          .order('created_at', ascending: false)
          .limit(50);

      final allProfiles = (lmRes as List?) ?? [];
      final linemenList = allProfiles.where((p) => (p['role']?.toString().toUpperCase() == 'LINEMAN')).toList();
      final managersList = allProfiles.where((p) {
        final r = p['role']?.toString().toUpperCase();
        return r == 'PRODUCTION_MANAGER' || r == 'ADMIN' || r == 'SUPERVISOR';
      }).toList();

      setState(() {
        _linemen = linemenList.isNotEmpty ? linemenList : allProfiles;
        _managers = managersList.isNotEmpty ? managersList : allProfiles;
        _articles = (artRes as List?) ?? [];
        _challans = (chRes as List?) ?? [];

        if (_managers.isNotEmpty) {
          _selectedManagerName = _managers.first['username']?.toString() ?? 'Production Manager';
        }
        if (_linemen.isNotEmpty) {
          _selectedLinemanId = _linemen.first['id']?.toString();
        }
        if (_articles.isNotEmpty) {
          _applySelectedArticle(_articles.first);
        }

        _isInit = false;
      });

      _autoCalculateBOM();
    } catch (e) {
      if (mounted) {
        setState(() => _isInit = false);
      }
    }
  }

  void _applySelectedArticle(dynamic article) {
    if (article == null) return;
    _selectedArticleId = article['id']?.toString();
    _selectedArticleDisplay = article['art_no']?.toString() ?? 'Article';
    _selectedArticleDesc = article['description']?.toString() ?? '';

    // Check if article has size rates or tier metadata
    if (article['size_rates'] is Map) {
      final sizeRates = article['size_rates'] as Map;
      final meta = sizeRates['_meta'] is Map ? sizeRates['_meta'] as Map : {};
      final sizeTier = meta['size']?.toString();
      if (sizeTier != null && sizeTier.isNotEmpty) {
        final parts = sizeTier.split(RegExp(r'[/,-]')).map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          _selectedSizes = parts;
        }
      }
    }

    _autoCalculateBOM();
  }

  // Grand Target calculation
  int get grandTargetPieces {
    int sum = 0;
    for (var row in _colorRows) {
      for (var size in _selectedSizes) {
        sum += (row.quantities[size] ?? 0);
      }
    }
    return sum;
  }

  // PPC Speed Calculation
  int get targetRunRatePerHour {
    final total = grandTargetPieces;
    final hours = int.tryParse(_shiftHoursCtrl.text.trim()) ?? 16;
    if (total <= 0 || hours <= 0) return 0;
    return (total / hours).ceil();
  }

  void _applyPreset(String presetKey) {
    final sizes = sizePresets[presetKey];
    if (sizes != null) {
      setState(() {
        _activePreset = presetKey;
        _selectedSizes = List.from(sizes);
      });
      _autoCalculateBOM();
    }
  }

  void _toggleSize(String size) {
    setState(() {
      if (_selectedSizes.contains(size)) {
        if (_selectedSizes.length > 1) {
          _selectedSizes.remove(size);
        }
      } else {
        _selectedSizes.add(size);
      }
    });
    _autoCalculateBOM();
  }

  void _addCustomSize() {
    final custom = _customSizeCtrl.text.trim().toUpperCase();
    if (custom.isNotEmpty && !_selectedSizes.contains(custom)) {
      setState(() {
        _selectedSizes.add(custom);
        _customSizeCtrl.clear();
      });
      _autoCalculateBOM();
    }
  }

  void _addColorRow() {
    setState(() {
      _colorRows.add(
        ColorMatrixRow(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          color: '',
          quantities: {},
        ),
      );
    });
  }

  void _removeColorRow(String id) {
    if (_colorRows.length <= 1) return;
    setState(() {
      _colorRows.removeWhere((r) => r.id == id);
    });
    _autoCalculateBOM();
  }

  void _autoCalculateBOM() {
    final total = grandTargetPieces;
    final targetQty = total > 0 ? total : 500;
    final fabricMeters = (targetQty * 0.45).round();
    final threadCones = (targetQty / 50).ceil().clamp(2, 50);

    final generated = <BomMaterialItem>[
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
        id: 'mat-buttons-${DateTime.now().millisecondsSinceEpoch + 2}',
        itemName: '18L 4-Hole Buttons',
        requiredQty: '${(targetQty * 3)} pcs',
        source: 'CLIENT',
        isIssued: false,
      ),
      BomMaterialItem(
        id: 'mat-brand-${DateTime.now().millisecondsSinceEpoch + 3}',
        itemName: 'Main Brand Label',
        requiredQty: '$targetQty pcs',
        source: 'CLIENT',
        isIssued: false,
      ),
      BomMaterialItem(
        id: 'mat-size-${DateTime.now().millisecondsSinceEpoch + 4}',
        itemName: 'Size Labels',
        requiredQty: '$targetQty pcs',
        source: 'CLIENT',
        isIssued: false,
      ),
    ];

    // Retain any custom added items
    final customItems = _materials.where((m) {
      final n = m.itemName.toLowerCase();
      return !n.contains('fabric roll') &&
          !n.contains('sewing thread') &&
          !n.contains('buttons') &&
          !n.contains('brand label') &&
          !n.contains('size label');
    }).toList();

    setState(() {
      _materials = [...generated, ...customItems];
    });
  }

  void _addPresetBOM(String name, String qtySuffix, double multiplier, String source) {
    final total = grandTargetPieces > 0 ? grandTargetPieces : 500;
    final calculatedQty = (total * multiplier).round();
    final displayQty = '$calculatedQty $qtySuffix';

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

  void _addCustomBOMItem() {
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

  Future<void> _pickImage(ImageSource source) async {
    if (_samplePhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 4 sample photos allowed.')),
      );
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (file != null) {
        final bytes = await File(file.path).readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _samplePhotos.add(base64Image);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selection failed: ${e.toString()}')),
      );
    }
  }

  void _promptImageUrl() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Paste Image URL', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://...',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.steel, foregroundColor: Colors.white),
            onPressed: () {
              final url = ctrl.text.trim();
              if (url.isNotEmpty && _samplePhotos.length < 4) {
                setState(() => _samplePhotos.add(url));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add URL'),
          ),
        ],
      ),
    );
  }

  void _openArticleBrowseDialog() {
    String searchQ = '';
    int activeTab = 0; // 0 = Articles, 1 = Delivery Challans

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filteredArticles = _articles.where((a) {
            final no = a['art_no']?.toString().toLowerCase() ?? '';
            final desc = a['description']?.toString().toLowerCase() ?? '';
            return no.contains(searchQ.toLowerCase()) || desc.contains(searchQ.toLowerCase());
          }).toList();

          final filteredChallans = _challans.where((c) {
            final no = c['challan_no']?.toString().toLowerCase() ?? '';
            final brand = c['brand']?.toString().toLowerCase() ?? '';
            final fabric = c['fabric_type']?.toString().toLowerCase() ?? '';
            return no.contains(searchQ.toLowerCase()) || brand.contains(searchQ.toLowerCase()) || fabric.contains(searchQ.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Article Style or Challan',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text('Articles (${filteredArticles.length})')),
                          selected: activeTab == 0,
                          selectedColor: AppTheme.steelMist,
                          labelStyle: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: activeTab == 0 ? AppTheme.steel : AppTheme.inkSoft),
                          onSelected: (_) => setModalState(() => activeTab = 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text('Challans (${filteredChallans.length})')),
                          selected: activeTab == 1,
                          selectedColor: AppTheme.steelMist,
                          labelStyle: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: activeTab == 1 ? AppTheme.steel : AppTheme.inkSoft),
                          onSelected: (_) => setModalState(() => activeTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: activeTab == 0 ? 'Search article number or style...' : 'Search challan #, brand, fabric...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onChanged: (val) => setModalState(() => searchQ = val),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: activeTab == 0
                      ? ListView.builder(
                          itemCount: filteredArticles.length,
                          itemBuilder: (ctx, idx) {
                            final art = filteredArticles[idx];
                            final isSelected = art['id']?.toString() == _selectedArticleId && _selectedChallanId == null;
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.steelMist : AppTheme.bg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.sell_outlined, color: isSelected ? AppTheme.steel : AppTheme.inkSoft, size: 20),
                              ),
                              title: Text(
                                art['art_no']?.toString() ?? '',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.ink),
                              ),
                              subtitle: Text(
                                art['description']?.toString() ?? 'Standard Garment',
                                style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                              ),
                              trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.steel) : null,
                              onTap: () {
                                setState(() {
                                  _selectedChallanId = null;
                                  _applySelectedArticle(art);
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        )
                      : ListView.builder(
                          itemCount: filteredChallans.length,
                          itemBuilder: (ctx, idx) {
                            final ch = filteredChallans[idx];
                            final isSelected = ch['id']?.toString() == _selectedChallanId;
                            final chNo = ch['challan_no']?.toString() ?? '';
                            final brand = ch['brand']?.toString() ?? '';
                            final fabric = ch['fabric_type']?.toString() ?? '';
                            final qty = ch['total_qty']?.toString() ?? '';

                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.steelMist : AppTheme.bg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.receipt_long_outlined, color: isSelected ? AppTheme.steel : AppTheme.inkSoft, size: 20),
                              ),
                              title: Text(
                                '$chNo  •  $brand',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.ink),
                              ),
                              subtitle: Text(
                                '$fabric ${qty.isNotEmpty ? " • $qty pcs" : ""}',
                                style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                              ),
                              trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.steel) : null,
                              onTap: () {
                                setState(() {
                                  _selectedChallanId = ch['id']?.toString();
                                  _clientChallanNoCtrl.text = chNo;
                                  if (_articles.isNotEmpty) {
                                    _applySelectedArticle(_articles.first);
                                  }
                                  _selectedArticleDisplay = '$chNo ($brand)';
                                  _selectedArticleDesc = fabric;
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitAllotment() async {
    if (_selectedLinemanId == null || _selectedArticleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Lineman and Article.')),
      );
      return;
    }

    final totalPieces = grandTargetPieces;
    if (totalPieces <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least 1 piece quantity in the Size & Color Ratio Matrix.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final todayDate = DateTime.now().toIso8601String().substring(0, 10);
      final dueStr = DateFormat('yyyy-MM-dd').format(_dueDate);
      final shiftHours = int.tryParse(_shiftHoursCtrl.text.trim()) ?? 16;
      final clientChNo = _clientChallanNoCtrl.text.trim();
      final manager = _selectedManagerName ?? 'Production Manager';

      // 1. Insert into allotments
      final allotPayload = {
        'challan_id': _selectedChallanId,
        'lineman_id': _selectedLinemanId,
        'article_id': _selectedArticleId,
        'target_qty': totalPieces,
        'status': 'IN_PROGRESS',
        'qc_status': 'PENDING_STITCHING',
        'mending_status': 'PENDING_STITCHING',
        'allotment_date': todayDate,
      };

      final newAl = await supabase.from('allotments').insert(allotPayload).select('id').single();
      final allotmentId = newAl['id']?.toString();
      if (allotmentId == null) throw Exception('Failed to create allotment');

      // 2. Insert Variants into allotment_variants
      final List<Map<String, dynamic>> variantsToInsert = [];
      for (var row in _colorRows) {
        final colorName = row.color.trim().isEmpty ? 'Standard' : row.color.trim();
        for (var size in _selectedSizes) {
          final qty = row.quantities[size] ?? 0;
          if (qty > 0) {
            variantsToInsert.add({
              'allotment_id': allotmentId,
              'color': colorName,
              'size': size,
              'quantity': qty,
              'completed_qty': 0,
            });
          }
        }
      }

      if (variantsToInsert.isNotEmpty) {
        await supabase.from('allotment_variants').insert(variantsToInsert);
      } else {
        // Fallback single variant
        await supabase.from('allotment_variants').insert({
          'allotment_id': allotmentId,
          'color': 'Standard',
          'size': 'Free Size',
          'quantity': totalPieces,
          'completed_qty': 0,
        });
      }

      // 3. Insert Materials into allotment_materials with complete Web Admin metadata notes
      if (_materials.isNotEmpty) {
        final materialsToInsert = _materials.map((m) {
          final noteObj = {
            'manager_name': manager,
            'due_date': dueStr,
            'target_hours': shiftHours,
            'priority': _priority,
            'client_challan_no': clientChNo,
            'source': m.source,
            'sample_photos': _samplePhotos,
            'item_name': m.itemName,
            'required_qty': m.requiredQty,
            'is_issued': m.isIssued,
            'status': 'PENDING',
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

      // 4. Update Challan status if selected
      if (_selectedChallanId != null) {
        try {
          await supabase.from('challans').update({'status': 'IN_PROGRESS'}).eq('id', _selectedChallanId!);
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.green,
            content: Text('Target Allotment & Material Handover created successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.red,
            content: Text('Error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientCount = _materials.where((m) => m.source == 'CLIENT').length;
    final factoryCount = _materials.where((m) => m.source == 'FACTORY_STORE').length;
    final total = grandTargetPieces;

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle Bar Indicator
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Header with Live Grand Target
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target Allotments & Material Handover',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Assign cut-to-sew size-color ratios & verify raw materials issue',
                          style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.steelMist,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.steel.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('GRAND TARGET', style: GoogleFonts.publicSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.steel)),
                        Text('$total pcs', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.steelDark)),
                      ],
                    ),
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
              const Expanded(
                child: Center(child: CircularProgressIndicator(color: AppTheme.steel)),
              )
            else ...[
              // Scrollable 3-Section Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ==========================================
                      // STEP 1: FLOOR LINEMAN & STYLE ARTICLE
                      // ==========================================
                      _buildSectionContainer(
                        step: '1',
                        title: 'Select Floor Lineman & Style Article',
                        children: [
                          // Production Manager Dropdown
                          _buildLabel('PRODUCTION MANAGER (ALLOTTED BY) *'),
                          DropdownButtonFormField<String>(
                            value: _selectedManagerName,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_pin_outlined, size: 20),
                              hintText: '--Choose Production Manager--',
                            ),
                            items: _managers.map((m) {
                              final un = m['username']?.toString() ?? 'Manager';
                              return DropdownMenuItem(value: un, child: Text(un));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedManagerName = val),
                          ),
                          const SizedBox(height: 4),
                          Text('Select from registered Production Managers in Employee list.', style: GoogleFonts.publicSans(fontSize: 10, color: AppTheme.inkFaint)),
                          const SizedBox(height: 16),

                          // Urgency & Priority Pills
                          _buildLabel('PRODUCTION URGENCY & PRIORITY'),
                          Row(
                            children: [
                              _buildPriorityPill('NORMAL', 'Normal', null, Colors.grey.shade600, AppTheme.bg),
                              const SizedBox(width: 8),
                              _buildPriorityPill('RUSH', 'Rush Order', Icons.bolt, Colors.orange.shade700, Colors.orange.shade50),
                              const SizedBox(width: 8),
                              _buildPriorityPill('CRITICAL', 'Critical / Export', Icons.local_fire_department, Colors.red.shade700, Colors.red.shade50),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Lineman Dropdown
                          _buildLabel('ASSIGN TO LINEMAN *'),
                          DropdownButtonFormField<String>(
                            value: _selectedLinemanId,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.badge_outlined, size: 20),
                              hintText: '--Choose Floor Lineman--',
                            ),
                            items: _linemen.map((l) {
                              final id = l['id'].toString();
                              final un = l['username']?.toString() ?? 'Lineman';
                              return DropdownMenuItem(value: id, child: Text(un));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedLinemanId = val),
                          ),
                          const SizedBox(height: 16),

                          // Style Article Selector
                          _buildLabel('STYLE ARTICLE / JOB COLOR LINE *'),
                          InkWell(
                            onTap: _openArticleBrowseDialog,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.sell_outlined, size: 20, color: AppTheme.steel),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedArticleDisplay.isNotEmpty ? _selectedArticleDisplay : 'Search or choose Style Article...',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: _selectedArticleDisplay.isNotEmpty ? AppTheme.ink : AppTheme.inkFaint,
                                          ),
                                        ),
                                        if (_selectedArticleDesc.isNotEmpty)
                                          Text(
                                            _selectedArticleDesc,
                                            style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.steelMist,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Text('Browse', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.steel)),
                                        const Icon(Icons.chevron_right, size: 16, color: AppTheme.steel),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Due Date & Shift Hours Row
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('TARGET COMPLETION DUE DATE'),
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _dueDate,
                                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                          lastDate: DateTime.now().add(const Duration(days: 365)),
                                        );
                                        if (picked != null) setState(() => _dueDate = picked);
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.bg,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.inkSoft),
                                            const SizedBox(width: 8),
                                            Text(
                                              DateFormat('dd/MM/yyyy').format(_dueDate),
                                              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('ESTIMATED SHIFT HOURS'),
                                    TextField(
                                      controller: _shiftHoursCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.schedule, size: 18),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Speedometer PPC Live Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.steelMist.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.steel.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.speed_rounded, color: AppTheme.steel, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('TARGET LINE SPEED (PPC)', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.steelDark)),
                                    Text(
                                      '$targetRunRatePerHour pcs / hour  •  $grandTargetPieces pcs / shift',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Client Challan #
                          _buildLabel('CLIENT / BUYER DELIVERY CHALLAN # (WORK ORDER)'),
                          TextField(
                            controller: _clientChallanNoCtrl,
                            decoration: const InputDecoration(
                              hintText: 'e.g. CH-8921 / Buyer DC # / Order Ref',
                              prefixIcon: Icon(Icons.receipt_long_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Buyer Sample Photos (0/4)
                          _buildLabel('BUYER SAMPLE PHOTOS (${_samplePhotos.length}/4)'),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.steel,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _samplePhotos.length < 4 ? () => _pickImage(ImageSource.gallery) : null,
                                icon: const Icon(Icons.upload_file, size: 16),
                                label: const Text('Upload File'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.steel,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _samplePhotos.length < 4 ? _promptImageUrl : null,
                                icon: const Icon(Icons.link, size: 16),
                                label: const Text('Paste URL'),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.camera_alt_outlined, color: AppTheme.steel),
                                tooltip: 'Camera',
                                onPressed: _samplePhotos.length < 4 ? () => _pickImage(ImageSource.camera) : null,
                              ),
                            ],
                          ),
                          if (_samplePhotos.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 70,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _samplePhotos.length,
                                itemBuilder: (ctx, idx) {
                                  final img = _samplePhotos[idx];
                                  final isBase64 = img.startsWith('data:image');
                                  return Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(9),
                                          child: isBase64
                                              ? Image.memory(
                                                  base64Decode(img.split(',').last),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                                                )
                                              : Image.network(
                                                  img,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                                                ),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _samplePhotos.removeAt(idx)),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ==========================================
                      // STEP 2: SIZE & COLOR RATIO MATRIX
                      // ==========================================
                      _buildSectionContainer(
                        step: '2',
                        title: 'Size & Color Ratio Matrix',
                        subtitle: 'Configure cutting batch breakdown',
                        children: [
                          // Category Preset Pills
                          _buildLabel('CATEGORY PRESET:'),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildPresetGroupChip('alpha', 'Adult Alpha (XS-5XL)'),
                                _buildPresetGroupChip('numeric', 'Jeans / Numeric (28-44)'),
                                _buildPresetGroupChip('kids_age', 'Kids Age (0M-16Y)'),
                                _buildPresetGroupChip('kids_num', 'Kids Numbers (16-34)'),
                                _buildPresetGroupChip('free_size', 'Universal (Free Size)'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Selected Sizes Chips
                          _buildLabel('SELECTED SIZES FOR THIS ARTICLE:'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._selectedSizes.map((s) => Chip(
                                    label: Text(s, style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700)),
                                    deleteIcon: const Icon(Icons.close, size: 14),
                                    onDeleted: () => _toggleSize(s),
                                    backgroundColor: AppTheme.steelMist,
                                    side: BorderSide(color: AppTheme.steel.withOpacity(0.3)),
                                  )),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 70,
                                    height: 32,
                                    child: TextField(
                                      controller: _customSizeCtrl,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: InputDecoration(
                                        hintText: '+ Size',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.steel,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: _addCustomSize,
                                    child: const Text('Add', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Piece Matrix Breakdown Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLabel('PIECE MATRIX BREAKDOWN:'),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.steel,
                                  side: const BorderSide(color: AppTheme.steel),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _addColorRow,
                                icon: const Icon(Icons.add, size: 15),
                                label: Text('+ Add Color Row', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Color Rows Matrix Cards
                          ..._colorRows.map((row) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: row.color,
                                          decoration: const InputDecoration(
                                            labelText: 'Color / Shade',
                                            hintText: 'e.g. Navy Blue',
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          onChanged: (val) => row.color = val,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.steelMist,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${row.rowTotal} pcs',
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.steelDark),
                                        ),
                                      ),
                                      if (_colorRows.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.inkFaint),
                                          onPressed: () => _removeColorRow(row.id),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Size Inputs Grid
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _selectedSizes.map((sz) {
                                        final qty = row.quantities[sz] ?? 0;
                                        return Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          width: 60,
                                          child: Column(
                                            children: [
                                              Text(sz, style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                                              const SizedBox(height: 2),
                                              TextFormField(
                                                initialValue: qty > 0 ? qty.toString() : '',
                                                keyboardType: TextInputType.number,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                                                decoration: InputDecoration(
                                                  hintText: '0',
                                                  isDense: true,
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                onChanged: (val) {
                                                  final q = int.tryParse(val.trim()) ?? 0;
                                                  setState(() {
                                                    row.quantities[sz] = q;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Total by Size Footer Summary
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('TOTAL BY SIZE:', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.inkSoft)),
                                Text('$total pcs', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.steelDark)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ==========================================
                      // STEP 3: BOM RAW MATERIALS & TRIMS
                      // ==========================================
                      _buildSectionContainer(
                        step: '3',
                        title: 'BOM Raw Materials & Trims Checklist',
                        subtitle: 'Specify material origin: Client / Buyer Consignment vs Factory In-House Sourcing',
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.steelMist,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Client: $clientCount items', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.steelDark)),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Text('Factory: $factoryCount items', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.steel,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _autoCalculateBOM,
                                icon: const Icon(Icons.auto_awesome, size: 14),
                                label: const Text('Auto-BOM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // BOM Items Cards List
                          ..._materials.map((mat) {
                            final isClient = mat.source == 'CLIENT';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: mat.isIssued ? AppTheme.greenMist : AppTheme.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: mat.isIssued ? AppTheme.green : AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  // Checkbox toggle
                                  GestureDetector(
                                    onTap: () => setState(() => mat.isIssued = !mat.isIssued),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: mat.isIssued ? AppTheme.green : Colors.white,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: mat.isIssued ? AppTheme.green : AppTheme.border),
                                      ),
                                      child: mat.isIssued ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Item Name & Qty
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(mat.itemName, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text('Qty: ${mat.requiredQty}', style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
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
                                                  color: isClient ? AppTheme.steelMist : AppTheme.card,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: AppTheme.border),
                                                ),
                                                child: Text(
                                                  isClient ? 'Client Supplied' : 'Factory Sourced',
                                                  style: GoogleFonts.publicSans(fontSize: 9, fontWeight: FontWeight.w700, color: isClient ? AppTheme.steelDark : AppTheme.inkSoft),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Delete
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.inkFaint),
                                    onPressed: () => setState(() => _materials.removeWhere((m) => m.id == mat.id)),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 12),

                          // Quick Presets Chips
                          _buildLabel('QUICK PRESETS:'),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildPresetChip('+18L 4-Hole Buttons', () => _addPresetBOM('18L 4-Hole Buttons', 'pcs', 3.0, 'CLIENT')),
                                _buildPresetChip('+Elastic Waistband 1.5"', () => _addPresetBOM('Elastic Waistband 1.5"', 'Meters', 0.8, 'CLIENT')),
                                _buildPresetChip('+Drawcord / Dori 45"', () => _addPresetBOM('Drawcord / Dori 45"', 'pcs', 1.0, 'CLIENT')),
                                _buildPresetChip('+Metal Eyelets #4', () => _addPresetBOM('Metal Eyelets #4', 'pcs', 2.0, 'CLIENT')),
                                _buildPresetChip('+Care & Wash Labels', () => _addPresetBOM('Care & Wash Labels', 'pcs', 1.0, 'CLIENT')),
                                _buildPresetChip('+Satin Neck Piping Tape', () => _addPresetBOM('Satin Neck Piping Tape', 'Meters', 0.3, 'FACTORY_STORE')),
                                _buildPresetChip('+Desiccant Silica Gel', () => _addPresetBOM('Desiccant Silica Gel', 'Pouches', 0.1, 'FACTORY_STORE')),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Custom Material Input Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _customItemNameCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Custom Material Name',
                                          hintText: 'e.g. Drawcord',
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
                                          hintText: 'e.g. 500 pcs',
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
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                      onPressed: _addCustomBOMItem,
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Sticky Action Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppTheme.card,
                  border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
                ),
                child: SizedBox(
                  width: double.infinity,
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionContainer({
    required String step,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.steelMist,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    step,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.steel),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.ink),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(subtitle, style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft)),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.inkSoft,
        ),
      ),
    );
  }

  Widget _buildPriorityPill(String key, String label, IconData? icon, Color activeColor, Color activeBg) {
    final isSelected = _priority == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _priority = key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : AppTheme.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? activeColor : AppTheme.border, width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: isSelected ? activeColor : AppTheme.inkSoft),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeColor : AppTheme.inkSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetGroupChip(String key, String label) {
    final isSelected = _activePreset == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.steelMist,
        backgroundColor: AppTheme.bg,
        labelStyle: GoogleFonts.publicSans(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppTheme.steel : AppTheme.inkSoft,
        ),
        onSelected: (_) => _applyPreset(key),
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
