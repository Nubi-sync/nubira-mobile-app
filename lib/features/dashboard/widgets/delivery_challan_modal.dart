import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../../main.dart';

class DeliveryChallanModal extends StatefulWidget {
  final Map<String, dynamic>? prefilledLot;
  final VoidCallback onSubmitted;

  const DeliveryChallanModal({
    super.key,
    this.prefilledLot,
    required this.onSubmitted,
  });

  @override
  State<DeliveryChallanModal> createState() => _DeliveryChallanModalState();
}

class _DeliveryChallanModalState extends State<DeliveryChallanModal> {
  bool _isLoading = false;
  bool _isEditingPartyDetails = false;

  // Controllers for Header & Logistics
  late final TextEditingController _challanNoController;
  late final TextEditingController _vehicleNoController;
  late final TextEditingController _dateController;
  late final TextEditingController _totalBagsController;
  late final TextEditingController _spotNotesController;

  // Controllers for Billed To
  final _billedToNameController = TextEditingController(text: 'OLLYPOP INDUSTRIES PRIVATE LIMITED');
  final _billedToAddressController = TextEditingController(text: 'Rafi Ahmed Kidwai Road, Kolkata 700055');
  final _billedToGstinController = TextEditingController(text: '19AADCO1064C1ZK');

  // Controllers for Shipping To
  final _shippingToNameController = TextEditingController(text: 'OLLYPOP INDUSTRIES PRIVATE LIMITED');
  final _shippingToAddressController = TextEditingController(text: 'Srijan Logistic Park, Maheshtalla');
  final _shippingToEmailController = TextEditingController(text: 'creationnubira@gmail.com');

  // Items list
  List<Map<String, dynamic>> _challanItems = [];

  // Available articles & lots fetched from database
  List<Map<String, dynamic>> _availableArticles = [];
  List<Map<String, dynamic>> _availableLots = [];

  // Natural size ordering sequence
  static const List<String> _alphaSizeOrder = [
    'XS', 'S', 'M', 'L', 'XL', '2XL', 'XXL', '3XL', 'XXXL', '4XL', '5XL', 'FREE', 'FS'
  ];

  int _naturalSizeCompare(String a, String b) {
    final aUpper = a.trim().toUpperCase();
    final bUpper = b.trim().toUpperCase();

    final aIdx = _alphaSizeOrder.indexOf(aUpper);
    final bIdx = _alphaSizeOrder.indexOf(bUpper);

    if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
    if (aIdx != -1) return -1;
    if (bIdx != -1) return 1;

    final aNum = int.tryParse(aUpper);
    final bNum = int.tryParse(bUpper);
    if (aNum != null && bNum != null) return aNum.compareTo(bNum);

    return aUpper.compareTo(bUpper);
  }

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final initialChallanNo = (widget.prefilledLot?['challans']?['challan_no'] ?? widget.prefilledLot?['challan_id'] ?? '').toString();

    _challanNoController = TextEditingController(text: initialChallanNo);
    _vehicleNoController = TextEditingController(text: '');
    _dateController = TextEditingController(text: dateStr);
    _totalBagsController = TextEditingController(text: '');
    _spotNotesController = TextEditingController(text: '');

    _buildInitialItems();
    _fetchDatabaseData();
  }

  @override
  void dispose() {
    _challanNoController.dispose();
    _vehicleNoController.dispose();
    _dateController.dispose();
    _totalBagsController.dispose();
    _spotNotesController.dispose();
    _billedToNameController.dispose();
    _billedToAddressController.dispose();
    _billedToGstinController.dispose();
    _shippingToNameController.dispose();
    _shippingToAddressController.dispose();
    _shippingToEmailController.dispose();
    super.dispose();
  }

  void _buildInitialItems() {
    final lot = widget.prefilledLot;
    if (lot != null && lot['variants'] != null) {
      final vars = lot['variants'] as List<dynamic>;
      final artNo = lot['article']?['art_no'] ?? 'Article';
      final articleId = lot['article_id'];

      final List<Map<String, dynamic>> items = [];

      for (var v in vars) {
        final color = (v['color']?.toString().trim() ?? 'Default').toUpperCase();
        final size = (v['size']?.toString().trim() ?? 'M').toUpperCase();
        final orderQty = (v['quantity'] as int? ?? 0);
        final deliveryQty = orderQty;
        final balanceQty = orderQty - deliveryQty;

        items.add({
          'art_no': artNo,
          'article_id': articleId,
          'color': color,
          'category': 'SUIT',
          'product': 'TOP',
          'size': size,
          'order_qty': orderQty,
          'delivery_qty': deliveryQty,
          'balance_qty': balanceQty,
        });
      }

      items.sort((x, y) => _naturalSizeCompare(x['size'].toString(), y['size'].toString()));
      _challanItems = items;
    } else {
      _challanItems = [];
    }
  }

  Future<void> _fetchDatabaseData() async {
    try {
      if (_challanNoController.text.trim().isEmpty) {
        final lastChallan = await supabase
            .from('delivery_challans')
            .select('challan_no')
            .order('created_at', ascending: false)
            .limit(1);
        if (lastChallan.isNotEmpty && lastChallan.first['challan_no'] != null) {
          final lastNoStr = lastChallan.first['challan_no'].toString();
          final numMatch = RegExp(r'\d+').firstMatch(lastNoStr);
          if (numMatch != null) {
            final nextNum = int.parse(numMatch.group(0)!) + 1;
            if (mounted) _challanNoController.text = 'DC-${DateTime.now().year}-${nextNum.toString().padLeft(3, '0')}';
          }
        }
        if (_challanNoController.text.isEmpty && mounted) {
          _challanNoController.text = 'DC-${DateTime.now().year}-001';
        }
      }

      final articlesRes = await supabase
          .from('articles')
          .select('id, art_no, description')
          .eq('is_active', true)
          .order('art_no');

      final lotsRes = await supabase
          .from('allotments')
          .select('id, challan_id, article_id, status, qc_status, articles(art_no, description), allotment_variants(id, color, size, quantity)')
          .order('created_at', ascending: false)
          .limit(25);

      if (mounted) {
        setState(() {
          _availableArticles = List<Map<String, dynamic>>.from(articlesRes);
          _availableLots = List<Map<String, dynamic>>.from(lotsRes);
        });
      }
    } catch (e) {
      debugPrint('Error fetching database data for challan: $e');
      if (_challanNoController.text.isEmpty && mounted) {
        _challanNoController.text = 'DC-${DateTime.now().year}-001';
      }
    }
  }

  int get _totalOrderQty => _challanItems.fold(0, (sum, i) => sum + (i['order_qty'] as int));
  int get _totalDeliveryQty => _challanItems.fold(0, (sum, i) => sum + (i['delivery_qty'] as int));
  int get _totalBalanceQty => _challanItems.fold(0, (sum, i) => sum + (i['balance_qty'] as int));

  Future<void> _submitToAdmin() async {
    final vehicleNo = _vehicleNoController.text.trim();
    if (vehicleNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Vehicle Number for gate delivery pass.')),
      );
      return;
    }

    if (_challanItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item to the delivery challan.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      final challanNo = _challanNoController.text.trim();
      final totalBags = int.tryParse(_totalBagsController.text.trim()) ?? 0;

      // 1. Create delivery_challan in status PENDING_ADMIN_APPROVAL
      final challanInsertRes = await supabase.from('delivery_challans').insert({
        'challan_no': challanNo,
        'vehicle_no': vehicleNo,
        'spot_notes': _spotNotesController.text.trim(),
        'status': 'PENDING_ADMIN_APPROVAL',
        'billed_to_name': _billedToNameController.text.trim(),
        'billed_to_address': _billedToAddressController.text.trim(),
        'billed_to_gstin': _billedToGstinController.text.trim(),
        'shipping_to_name': _shippingToNameController.text.trim(),
        'shipping_to_address': _shippingToAddressController.text.trim(),
        'shipping_to_email': _shippingToEmailController.text.trim(),
        'total_bags': totalBags,
        'total_order_qty': _totalOrderQty,
        'total_delivery_qty': _totalDeliveryQty,
        'total_balance_qty': _totalBalanceQty,
        'created_by': user?.id,
      }).select('id').single();

      final challanId = challanInsertRes['id'].toString();

      // 2. Insert line items
      int sortOrder = 0;
      for (var item in _challanItems) {
        sortOrder++;
        await supabase.from('challan_items').insert({
          'challan_id': challanId,
          'allotment_id': widget.prefilledLot?['id'],
          'article_id': item['article_id'],
          'size': item['size'],
          'color': item['color'],
          'quantity': item['delivery_qty'],
          'category': item['category'],
          'product_type': item['product'],
          'order_qty': item['order_qty'],
          'delivery_qty': item['delivery_qty'],
          'balance_qty': item['balance_qty'],
          'sort_order': sortOrder,
        });
      }

      // 3. Update allotment status to READY_FOR_DISPATCH if linked
      if (widget.prefilledLot?['id'] != null) {
        await supabase.from('allotments').update({
          'qc_status': 'READY_FOR_DISPATCH',
          'total_bags_packed': totalBags,
          'delivery_challan_id': challanId,
        }).eq('id', widget.prefilledLot!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Submitted to Admin',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Challan #$challanNo has been submitted to Admin for Dispatch Approval.',
                  style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.ink),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• Status: PENDING_ADMIN_APPROVAL', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
                      Text('• Vehicle: $vehicleNo', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.ink)),
                      Text('• Total Pieces: $_totalDeliveryQty pcs', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.ink)),
                      Text('• Total Bags: $totalBags bags', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.ink)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Once approved on Web Admin, security gate dispatch printout will be released.',
                  style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: AppTheme.steel)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving Delivery Challan: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddItemDialog() {
    String selectedArtNo = _availableArticles.isNotEmpty ? _availableArticles.first['art_no'].toString() : '';
    String? selectedArticleId = _availableArticles.isNotEmpty ? _availableArticles.first['id'].toString() : null;

    final colorController = TextEditingController(text: 'White');
    final categoryController = TextEditingController(text: 'SUIT');
    final productController = TextEditingController(text: 'TOP');
    final orderQtyController = TextEditingController();
    final deliveryQtyController = TextEditingController();
    String selectedSize = 'M';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
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
                        'Add Line Item to Challan',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.inkSoft),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Article Selector
                  Text('Article No *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.inkSoft)),
                  const SizedBox(height: 4),
                  if (_availableArticles.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedArtNo.isNotEmpty ? selectedArtNo : null,
                          items: _availableArticles.map((a) {
                            return DropdownMenuItem<String>(
                              value: a['art_no'].toString(),
                              child: Text(
                                '${a['art_no']} — ${a['description'] ?? ''}',
                                style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedArtNo = val;
                                final match = _availableArticles.firstWhere((a) => a['art_no'].toString() == val, orElse: () => {});
                                selectedArticleId = match['id']?.toString();
                              });
                            }
                          },
                        ),
                      ),
                    )
                  else
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Enter Article No (e.g. 501)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => selectedArtNo = val.trim(),
                    ),

                  const SizedBox(height: 12),

                  // Color
                  Text('Color / Shade *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.inkSoft)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: colorController,
                    style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Black, White, Navy',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Size Selector Chips
                  Text('Size *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.inkSoft)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', 'FREE'].map((sz) {
                      final isSelected = selectedSize == sz;
                      return ChoiceChip(
                        label: Text(sz),
                        selected: isSelected,
                        selectedColor: AppTheme.steel,
                        labelStyle: GoogleFonts.jetBrainsMono(
                          color: isSelected ? Colors.white : AppTheme.ink,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setModalState(() => selectedSize = sz),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // Order Qty & Delivery Qty
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order Qty *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.inkSoft)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: orderQtyController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: '0',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.all(12),
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
                            Text('Delivery Qty *', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.steel)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: deliveryQtyController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.steel),
                              decoration: InputDecoration(
                                hintText: '0',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppTheme.steel, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final orderQ = int.tryParse(orderQtyController.text.trim()) ?? 0;
                        final delivQ = int.tryParse(deliveryQtyController.text.trim()) ?? orderQ;
                        if (selectedArtNo.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or enter Article No.')));
                          return;
                        }

                        setState(() {
                          _challanItems.add({
                            'art_no': selectedArtNo,
                            'article_id': selectedArticleId,
                            'color': colorController.text.trim().toUpperCase(),
                            'category': categoryController.text.trim().toUpperCase(),
                            'product': productController.text.trim().toUpperCase(),
                            'size': selectedSize,
                            'order_qty': orderQ,
                            'delivery_qty': delivQ,
                            'balance_qty': orderQ - delivQ,
                          });
                          _challanItems.sort((x, y) => _naturalSizeCompare(x['size'].toString(), y['size'].toString()));
                        });

                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        'Add to Delivery Sheet',
                        style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.steel,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLoadLotModal() {
    if (_availableLots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active lots found in factory database.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Load From Production Lot',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: _availableLots.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final lot = _availableLots[idx];
                  final artNo = lot['articles']?['art_no'] ?? 'Lot';
                  final challanId = lot['challan_id'] ?? lot['id'].toString().substring(0, 8);
                  final variants = lot['allotment_variants'] as List<dynamic>? ?? [];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.inventory_2_outlined, color: AppTheme.steel, size: 20),
                    ),
                    title: Text(
                      'Art #$artNo • Lot: $challanId',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.ink),
                    ),
                    subtitle: Text(
                      '${variants.length} sizes / colors in lot',
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.steel),
                    onTap: () {
                      final List<Map<String, dynamic>> newItems = [];
                      for (var v in variants) {
                        final q = (v['quantity'] as int? ?? 0);
                        newItems.add({
                          'art_no': artNo,
                          'article_id': lot['article_id'],
                          'color': (v['color']?.toString() ?? 'Default').toUpperCase(),
                          'category': 'SUIT',
                          'product': 'TOP',
                          'size': (v['size']?.toString() ?? 'M').toUpperCase(),
                          'order_qty': q,
                          'delivery_qty': q,
                          'balance_qty': 0,
                        });
                      }
                      newItems.sort((x, y) => _naturalSizeCompare(x['size'].toString(), y['size'].toString()));
                      setState(() {
                        _challanItems = newItems;
                        if (lot['challan_id'] != null) {
                          _challanNoController.text = lot['challan_id'].toString();
                        }
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Modal Top Handle & Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.steelMist,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: AppTheme.steel, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Challan (Dispatch Ready)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        Text(
                          'Nubira Creation • 8-Column Ollypop Format',
                          style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // Scrollable Challan Sheet
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ============================================
                    // 1. FACTORY HEADER & METADATA
                    // ============================================
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'NUBIRA CREATION',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.ink,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manufacturer & Exporter of Quality Garments • Maheshtalla, Kolkata',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppTheme.border),
                          const SizedBox(height: 12),

                          // Metadata Fields
                          Row(
                            children: [
                              // Challan No
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CHALLAN NO *', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.inkSoft)),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 38,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                                      alignment: Alignment.centerLeft,
                                      child: TextField(
                                        controller: _challanNoController,
                                        style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.ink),
                                        decoration: const InputDecoration(
                                          hintText: 'e.g. DC-101',
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Date
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('DATE *', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.inkSoft)),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 38,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                                      alignment: Alignment.centerLeft,
                                      child: TextField(
                                        controller: _dateController,
                                        style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.ink),
                                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Vehicle No
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('VEHICLE NO *', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.steel)),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 38,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.steel, width: 1.2),
                                      ),
                                      alignment: Alignment.centerLeft,
                                      child: TextField(
                                        controller: _vehicleNoController,
                                        style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.steel),
                                        decoration: const InputDecoration(
                                          hintText: 'e.g. WB 19 A 1234',
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
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

                    const SizedBox(height: 14),

                    // ============================================
                    // 2. BILLED TO & SHIPPING TO CARDS
                    // ============================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Party / Consignee Details',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.ink),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _isEditingPartyDetails = !_isEditingPartyDetails),
                          icon: Icon(_isEditingPartyDetails ? Icons.check_rounded : Icons.edit_outlined, size: 14, color: AppTheme.steel),
                          label: Text(
                            _isEditingPartyDetails ? 'Done Editing' : 'Edit / Change Address',
                            style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.steel),
                          ),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // BILLED TO
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(4)),
                                  child: Text('BILLED TO:', style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppTheme.steel)),
                                ),
                                const SizedBox(height: 6),
                                if (_isEditingPartyDetails) ...[
                                  TextField(
                                    controller: _billedToNameController,
                                    style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    decoration: const InputDecoration(isDense: true, labelText: 'Buyer Name'),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _billedToAddressController,
                                    maxLines: 2,
                                    style: GoogleFonts.publicSans(fontSize: 11),
                                    decoration: const InputDecoration(isDense: true, labelText: 'Registered Office'),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _billedToGstinController,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 11),
                                    decoration: const InputDecoration(isDense: true, labelText: 'GSTIN'),
                                  ),
                                ] else ...[
                                  Text(
                                    _billedToNameController.text,
                                    style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _billedToAddressController.text,
                                    style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.inkSoft),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'GSTIN: ${_billedToGstinController.text}',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.ink),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // SHIPPING TO
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(4)),
                                  child: Text('SHIPPING TO:', style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppTheme.steel)),
                                ),
                                const SizedBox(height: 6),
                                if (_isEditingPartyDetails) ...[
                                  TextField(
                                    controller: _shippingToNameController,
                                    style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    decoration: const InputDecoration(isDense: true, labelText: 'Consignee Name'),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _shippingToAddressController,
                                    maxLines: 2,
                                    style: GoogleFonts.publicSans(fontSize: 11),
                                    decoration: const InputDecoration(isDense: true, labelText: 'Delivery Godown'),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _shippingToEmailController,
                                    style: GoogleFonts.publicSans(fontSize: 11),
                                    decoration: const InputDecoration(isDense: true, labelText: 'Email'),
                                  ),
                                ] else ...[
                                  Text(
                                    _shippingToNameController.text,
                                    style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _shippingToAddressController.text,
                                    style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.inkSoft),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Email: ${_shippingToEmailController.text}',
                                    style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.inkSoft),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ============================================
                    // 3. AUTHENTIC 8-COLUMN DELIVERY TABLE
                    // ============================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              '8-Column Delivery Breakdown',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.ink),
                            ),
                            if (_challanItems.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  '${_challanItems.length} rows',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.steel),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            if (_availableLots.isNotEmpty) ...[
                              TextButton.icon(
                                onPressed: _showLoadLotModal,
                                icon: const Icon(Icons.sync_alt_rounded, size: 14, color: AppTheme.steel),
                                label: Text('Load Lot', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.steel)),
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), visualDensity: VisualDensity.compact),
                              ),
                              const SizedBox(width: 4),
                            ],
                            ElevatedButton.icon(
                              onPressed: _showAddItemDialog,
                              icon: const Icon(Icons.add_rounded, size: 14),
                              label: Text('Add Item', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.steel,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (_challanItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.inventory_2_outlined, color: AppTheme.steel, size: 22),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Line Items in Delivery Challan',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.ink),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add articles & sizes to dispatch, or load directly from an existing production lot.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _showAddItemDialog,
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Add Line Item'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.steel,
                                    side: const BorderSide(color: AppTheme.steel),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                ),
                                if (_availableLots.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: _showLoadLotModal,
                                    icon: const Icon(Icons.download_rounded, size: 16),
                                    label: const Text('Load From Lot'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.steel,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Table(
                              defaultColumnWidth: const IntrinsicColumnWidth(),
                              border: TableBorder(
                                horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                              ),
                              children: [
                                // HEADER ROW
                                TableRow(
                                  decoration: const BoxDecoration(color: AppTheme.bg),
                                  children: [
                                    _buildDeliveryCell('ART NO', isHeader: true),
                                    _buildDeliveryCell('COLOUR', isHeader: true),
                                    _buildDeliveryCell('CATEGORY', isHeader: true),
                                    _buildDeliveryCell('PRODUCT', isHeader: true),
                                    _buildDeliveryCell('SIZE', isHeader: true),
                                    _buildDeliveryCell('ORDER QTY', isHeader: true, alignRight: true),
                                    _buildDeliveryCell('DELIVERY', isHeader: true, alignRight: true),
                                    _buildDeliveryCell('BALANCE', isHeader: true, alignRight: true),
                                    _buildDeliveryCell('', isHeader: true),
                                  ],
                                ),
                                // DATA ROWS
                                ..._challanItems.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final item = entry.value;
                                  final bal = item['balance_qty'] as int;
                                  return TableRow(
                                    children: [
                                      _buildDeliveryCell(item['art_no'].toString(), isMono: true, isBold: true),
                                      _buildDeliveryCell(item['color'].toString(), isBold: true),
                                      _buildDeliveryCell(item['category'].toString(), isSoft: true),
                                      _buildDeliveryCell(item['product'].toString(), isSoft: true),
                                      _buildDeliveryCell(item['size'].toString(), isMono: true, isBold: true),
                                      _buildDeliveryCell(item['order_qty'].toString(), isMono: true, alignRight: true),
                                      _buildDeliveryCell(item['delivery_qty'].toString(), isMono: true, isBold: true, textColor: AppTheme.steel, alignRight: true),
                                      _buildDeliveryCell(
                                        bal == 0 ? '0' : (bal > 0 ? '+$bal' : '$bal'),
                                        isMono: true,
                                        isBold: true,
                                        alignRight: true,
                                        textColor: bal < 0 ? AppTheme.green : (bal > 0 ? AppTheme.red : AppTheme.inkSoft),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppTheme.red),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          onPressed: () => setState(() => _challanItems.removeAt(idx)),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                // TOTALS ROW
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.grey.shade100),
                                  children: [
                                    _buildDeliveryCell('TOTAL', isBold: true, isTotal: true),
                                    _buildDeliveryCell('BAGS: ${_totalBagsController.text.isEmpty ? "—" : _totalBagsController.text}', isMono: true, isBold: true, textColor: AppTheme.steel),
                                    _buildDeliveryCell('-', isSoft: true, alignCenter: true),
                                    _buildDeliveryCell('-', isSoft: true, alignCenter: true),
                                    _buildDeliveryCell('-', isSoft: true, alignCenter: true),
                                    _buildDeliveryCell('$_totalOrderQty', isMono: true, isBold: true, alignRight: true),
                                    _buildDeliveryCell('$_totalDeliveryQty', isMono: true, isBold: true, textColor: AppTheme.steel, alignRight: true),
                                    _buildDeliveryCell(
                                      '$_totalBalanceQty',
                                      isMono: true,
                                      isBold: true,
                                      alignRight: true,
                                      textColor: _totalBalanceQty > 0 ? AppTheme.red : AppTheme.ink,
                                    ),
                                    _buildDeliveryCell(''),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 14),

                    // ============================================
                    // 4. BAGS & SPOT / NOTES BOX
                    // ============================================
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TOTAL BAGS *', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.inkSoft)),
                              const SizedBox(height: 4),
                              Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                                child: TextField(
                                  controller: _totalBagsController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. 10',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.only(top: 10),
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
                              Text('SPOT / NOTES BOX (FLOOR REMARKS)', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.inkSoft)),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                                child: TextField(
                                  controller: _spotNotesController,
                                  maxLines: 2,
                                  style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.ink),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Note on balance pieces or floor remarks (optional)',
                                    hintStyle: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkFaint),
                                    contentPadding: const EdgeInsets.all(8),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ============================================
                    // 5. ADMIN APPROVAL NOTICE
                    // ============================================
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin Approval Gate Active',
                                  style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                                ),
                                Text(
                                  'Upon submitting, this challan enters PENDING_ADMIN_APPROVAL status. Once Admin approves on Web, PDF printing for the truck driver is unlocked.',
                                  style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF92400E)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ============================================
                    // 6. ACTION BUTTONS
                    // ============================================
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _submitToAdmin,
                              icon: _isLoading
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                _isLoading ? 'Submitting to Admin...' : 'Submit Challan to Admin',
                                style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.steel,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.inkSoft,
                              side: const BorderSide(color: AppTheme.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    bool isMono = false,
    bool isSoft = false,
    bool isTotal = false,
    bool alignRight = false,
    bool alignCenter = false,
    Color? textColor,
  }) {
    TextStyle style;
    if (isHeader) {
      style = GoogleFonts.publicSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: AppTheme.inkSoft,
        letterSpacing: 0.3,
      );
    } else if (isMono) {
      style = GoogleFonts.jetBrainsMono(
        fontSize: isTotal ? 12.5 : 12,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
        color: textColor ?? AppTheme.ink,
      );
    } else {
      style = GoogleFonts.publicSans(
        fontSize: isTotal ? 12 : 11.5,
        fontWeight: isBold ? FontWeight.w700 : (isSoft ? FontWeight.normal : FontWeight.w600),
        color: textColor ?? (isSoft ? AppTheme.inkSoft : AppTheme.ink),
      );
    }

    Alignment alignment = Alignment.centerLeft;
    if (alignRight) alignment = Alignment.centerRight;
    if (alignCenter) alignment = Alignment.center;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isHeader ? 10 : (isTotal ? 10 : 8),
      ),
      alignment: alignment,
      child: Text(text, style: style, maxLines: 1),
    );
  }
}
