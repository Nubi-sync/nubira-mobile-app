import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../../main.dart';

class _ArticleVariantRow {
  bool isSelected = true;
  String artNo;
  String? articleId;
  String color;
  String category;
  String product;
  String size;
  int orderQty;
  int deliveryQty;
  int qcCheckedQty;
  final TextEditingController orderController;
  final TextEditingController deliveryController;

  _ArticleVariantRow({
    required this.artNo,
    this.articleId,
    required this.color,
    required this.category,
    required this.product,
    required this.size,
    required this.orderQty,
    required this.deliveryQty,
    required this.qcCheckedQty,
  })  : orderController = TextEditingController(text: orderQty.toString()),
        deliveryController = TextEditingController(text: deliveryQty.toString());

  void dispose() {
    orderController.dispose();
    deliveryController.dispose();
  }
}

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
  int _activePartyTab = 0; // 0: Billed To, 1: Shipping To

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
      final lotTotalPassed = (lot['qc_total_passed'] as int?) ?? 0;

      final List<Map<String, dynamic>> items = [];

      for (var v in vars) {
        final color = (v['color']?.toString().trim() ?? 'Default').toUpperCase();
        final size = (v['size']?.toString().trim() ?? 'M').toUpperCase();
        final orderQty = (v['order_qty'] as int?) ?? (v['allotted_qty'] as int?) ?? (v['quantity'] as int? ?? 0);
        
        int deliveryQty = (v['qc_passed_qty'] as int?) ?? 0;
        if (deliveryQty == 0) {
          if (vars.length == 1 && lotTotalPassed > 0) {
            deliveryQty = lotTotalPassed;
          } else {
            deliveryQty = orderQty;
          }
        }
        final balanceQty = (orderQty - deliveryQty).clamp(0, orderQty);

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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Delivery Challan #$challanNo submitted to Admin for Dispatch Approval!'),
                ),
              ],
            ),
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

  void _showArticleSelectorAndAutoFetchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ArticleAutoFetchSheet(
        availableArticles: _availableArticles,
        onAddItems: (newItems) {
          setState(() {
            _challanItems.addAll(newItems);
            _challanItems.sort((a, b) {
              final artComp = a['art_no'].toString().compareTo(b['art_no'].toString());
              if (artComp != 0) return artComp;
              final colComp = a['color'].toString().compareTo(b['color'].toString());
              if (colComp != 0) return colComp;
              final prodComp = a['product'].toString().compareTo(b['product'].toString());
              if (prodComp != 0) return prodComp;
              return _naturalSizeCompare(a['size'].toString(), b['size'].toString());
            });
          });
        },
      ),
    );
  }

  void _showLoadLotModal() {
    if (_availableLots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active production lots found in factory database.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.70,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
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
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: _availableLots.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                itemBuilder: (ctx, idx) {
                  final lot = _availableLots[idx];
                  final artNo = lot['articles']?['art_no'] ?? 'Lot';
                  final challanId = lot['challan_id'] ?? lot['id'].toString().substring(0, 8);
                  final variants = lot['allotment_variants'] as List<dynamic>? ?? [];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(10)),
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
                      final lotPassed = (lot['qc_total_passed'] as int?) ?? 0;
                      for (var v in variants) {
                        final orderQ = (v['order_qty'] as int?) ?? (v['quantity'] as int? ?? 0);
                        int deliveryQ = (v['qc_passed_qty'] as int?) ?? 0;
                        if (deliveryQ == 0) {
                          if (variants.length == 1 && lotPassed > 0) {
                            deliveryQ = lotPassed;
                          } else {
                            deliveryQ = orderQ;
                          }
                        }
                        final balQ = (orderQ - deliveryQ).clamp(0, orderQ);

                        newItems.add({
                          'art_no': artNo,
                          'article_id': lot['article_id'],
                          'color': (v['color']?.toString() ?? 'Default').toUpperCase(),
                          'category': 'SUIT',
                          'product': 'TOP',
                          'size': (v['size']?.toString() ?? 'M').toUpperCase(),
                          'order_qty': orderQ,
                          'delivery_qty': deliveryQ,
                          'balance_qty': balQ,
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

  // Single source of truth for ultra-clean, non-nested input decoration
  static InputDecoration _cleanInputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffix,
    String? suffixText,
    bool isPrimary = false,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      suffix: suffix,
      suffixText: suffixText,
      suffixStyle: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.inkSoft),
      hintStyle: GoogleFonts.publicSans(
        fontSize: 12,
        color: AppTheme.inkFaint,
        fontWeight: FontWeight.normal,
      ),
      filled: true,
      fillColor: isPrimary ? Colors.white : const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isPrimary ? AppTheme.steel : const Color(0xFFE2E8F0), width: isPrimary ? 1.5 : 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isPrimary ? AppTheme.steel : const Color(0xFFCBD5E1), width: isPrimary ? 1.5 : 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.steel, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.90,
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Modal Header (Clean, underneath status bar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.steelMist,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppTheme.steel, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Challan (Dispatch Ready)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        Text(
                          'Nubira Creation • 8-Column Ollypop Format',
                          style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ============================================
                    // 1. FACTORY GATE PASS & LOGISTICS CARD
                    // ============================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Badge
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.steelMist,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'NUBIRA CREATION • GATE PASS',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.steel,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Dispatch Outward',
                                style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.inkSoft, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Challan No & Date
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CHALLAN NO *', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.inkSoft)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _challanNoController,
                                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                      decoration: _cleanInputDecoration(
                                        hint: 'DC-2026-001',
                                        prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: AppTheme.steel),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('DATE *', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.inkSoft)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _dateController,
                                      style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                      decoration: _cleanInputDecoration(
                                        hint: 'DD-MM-YYYY',
                                        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.inkSoft),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Vehicle No (Full Width & Clean Single Border)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('VEHICLE / TRUCK NUMBER *', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.steel)),
                                  Text('Required for Gate Security', style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.inkSoft)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _vehicleNoController,
                                textCapitalization: TextCapitalization.characters,
                                style: GoogleFonts.jetBrainsMono(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.steel, letterSpacing: 0.5),
                                decoration: _cleanInputDecoration(
                                  hint: 'Enter Vehicle No (e.g. WB 19 A 1234)',
                                  prefixIcon: const Icon(Icons.local_shipping_outlined, size: 20, color: AppTheme.steel),
                                  isPrimary: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ============================================
                    // 2. SEGMENTED PARTY DETAILS CARD
                    // ============================================
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Segmented Tabs: Billed To vs Shipping To
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _activePartyTab = 0),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 7),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _activePartyTab == 0 ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: _activePartyTab == 0
                                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                                            : null,
                                      ),
                                      child: Text(
                                        'BILLED TO (BUYER)',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: _activePartyTab == 0 ? AppTheme.steel : AppTheme.inkSoft,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _activePartyTab = 1),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 7),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _activePartyTab == 1 ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: _activePartyTab == 1
                                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                                            : null,
                                      ),
                                      child: Text(
                                        'SHIPPING TO (GODOWN)',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: _activePartyTab == 1 ? AppTheme.steel : AppTheme.inkSoft,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Active Party Content
                          if (_activePartyTab == 0) ...[
                            if (_isEditingPartyDetails) ...[
                              TextField(controller: _billedToNameController, style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold), decoration: _cleanInputDecoration(hint: 'Buyer Company Name')),
                              const SizedBox(height: 8),
                              TextField(controller: _billedToAddressController, style: GoogleFonts.publicSans(fontSize: 11), decoration: _cleanInputDecoration(hint: 'Registered Office Address')),
                              const SizedBox(height: 8),
                              TextField(controller: _billedToGstinController, style: GoogleFonts.jetBrainsMono(fontSize: 11), decoration: _cleanInputDecoration(hint: 'GSTIN Number')),
                            ] else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.business_rounded, color: AppTheme.steel, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_billedToNameController.text, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                                        const SizedBox(height: 2),
                                        Text(_billedToAddressController.text, style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                          child: Text('GSTIN: ${_billedToGstinController.text}', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ] else ...[
                            if (_isEditingPartyDetails) ...[
                              TextField(controller: _shippingToNameController, style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold), decoration: _cleanInputDecoration(hint: 'Consignee Name')),
                              const SizedBox(height: 8),
                              TextField(controller: _shippingToAddressController, style: GoogleFonts.publicSans(fontSize: 11), decoration: _cleanInputDecoration(hint: 'Godown / Delivery Address')),
                              const SizedBox(height: 8),
                              TextField(controller: _shippingToEmailController, style: GoogleFonts.publicSans(fontSize: 11), decoration: _cleanInputDecoration(hint: 'Dispatch Notification Email')),
                            ] else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.warehouse_rounded, color: AppTheme.steel, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_shippingToNameController.text, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                                        const SizedBox(height: 2),
                                        Text(_shippingToAddressController.text, style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft)),
                                        const SizedBox(height: 4),
                                        Text('Email: ${_shippingToEmailController.text}', style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.inkSoft)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],

                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () => setState(() => _isEditingPartyDetails = !_isEditingPartyDetails),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(
                                  _isEditingPartyDetails ? '✓ Done Editing' : '✎ Edit Party Details',
                                  style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.steel),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ============================================
                    // 3. 8-COLUMN DELIVERY BREAKDOWN TABLE
                    // ============================================
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '8-Column Delivery Breakdown',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.ink),
                            ),
                            if (_challanItems.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  '${_challanItems.length} sizes',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.steel),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_availableLots.isNotEmpty) ...[
                              Expanded(
                                flex: 1,
                                child: OutlinedButton.icon(
                                  onPressed: _showLoadLotModal,
                                  icon: const Icon(Icons.sync_alt_rounded, size: 14, color: AppTheme.steel),
                                  label: Text('Load Lot', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.steel)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _showArticleSelectorAndAutoFetchModal,
                                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                                label: Text('Add Article (Auto-Fetch QC)', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.steel,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_challanItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.inventory_2_outlined, color: AppTheme.steel, size: 24),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Line Items in Delivery Challan',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.ink),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add articles & sizes to dispatch, or load directly from an existing production lot.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _showArticleSelectorAndAutoFetchModal,
                                  icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                                  label: const Text('Add Article (Auto-Fetch QC)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.steel,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                ),
                                if (_availableLots.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: _showLoadLotModal,
                                    icon: const Icon(Icons.download_rounded, size: 15, color: AppTheme.steel),
                                    label: const Text('Load From Lot'),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      foregroundColor: AppTheme.steel,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
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
                                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
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
                    // 4. BAGS & SPOT / NOTES BOX (Crisp native fields)
                    // ============================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Total Bags Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TOTAL BAGS PACKED *', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.inkSoft)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _totalBagsController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink),
                                decoration: _cleanInputDecoration(
                                  hint: 'e.g. 10',
                                  prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 19, color: AppTheme.steel),
                                  suffixText: 'bags',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Spot Remarks Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SPOT / FLOOR REMARKS (OPTIONAL)', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.inkSoft)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _spotNotesController,
                                maxLines: 2,
                                style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.ink),
                                decoration: _cleanInputDecoration(
                                  hint: 'e.g. Balance pcs sent later, floor remarks, special packing...',
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.only(bottom: 22),
                                    child: Icon(Icons.sticky_note_2_outlined, size: 19, color: AppTheme.inkSoft),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ============================================
                    // 5. ADMIN APPROVAL NOTICE
                    // ============================================
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.verified_user_outlined, color: Color(0xFFD97706), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin Approval Gate Active',
                                  style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                                ),
                                Text(
                                  'Challan will be submitted for Admin approval. Upon signoff on Web Admin, security gate printing is released.',
                                  style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF92400E)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ============================================
            // 6. FIXED BOTTOM ACTION BAR (Above System Nav Bar)
            // ============================================
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
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
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isLoading ? 'Submitting...' : 'Submit Challan to Admin',
                            style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
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
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.inkSoft,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isHeader ? 10 : (isTotal ? 10 : 8),
      ),
      child: Text(
        text,
        style: style,
        textAlign: alignRight ? TextAlign.right : (alignCenter ? TextAlign.center : TextAlign.left),
        maxLines: 1,
      ),
    );
  }
}

// ============================================================================
// DEDICATED ARTICLE AUTO-FETCH SHEET (ROBUST STATEFUL LIFECYCLE)
// ============================================================================
class _ArticleAutoFetchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> availableArticles;
  final Function(List<Map<String, dynamic>> items) onAddItems;

  const _ArticleAutoFetchSheet({
    required this.availableArticles,
    required this.onAddItems,
  });

  @override
  State<_ArticleAutoFetchSheet> createState() => _ArticleAutoFetchSheetState();
}

class _ArticleAutoFetchSheetState extends State<_ArticleAutoFetchSheet> {
  late String _selectedArtNo;
  String? _selectedArticleId;
  String _selectedCategory = 'SUIT';
  String _selectedProductMode = 'TOP'; // 'TOP', 'PANT', or 'BOTH (TOP + PANT)'
  late final TextEditingController _customColorController;

  List<_ArticleVariantRow> _previewRows = [];
  bool _isFetching = false;
  String? _fetchStatusMessage;

  static int _compareSizes(String a, String b) {
    const alphaOrder = [
      'XS', 'S', 'M', 'L', 'XL', '2XL', 'XXL', '3XL', 'XXXL', '4XL', '5XL', 'FREE', 'FS'
    ];
    final aUpper = a.trim().toUpperCase();
    final bUpper = b.trim().toUpperCase();
    final aIdx = alphaOrder.indexOf(aUpper);
    final bIdx = alphaOrder.indexOf(bUpper);
    if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
    if (aIdx != -1) return -1;
    if (bIdx != -1) return 1;
    return aUpper.compareTo(bUpper);
  }

  @override
  void initState() {
    super.initState();
    _selectedArtNo = widget.availableArticles.isNotEmpty
        ? widget.availableArticles.first['art_no'].toString()
        : '';
    _selectedArticleId = widget.availableArticles.isNotEmpty
        ? widget.availableArticles.first['id']?.toString()
        : null;
    _customColorController = TextEditingController(text: 'WHITE CHOCOLATE');

    if (_selectedArticleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchVariantsForArticle(_selectedArticleId!, _selectedArtNo);
        }
      });
    }
  }

  @override
  void dispose() {
    _customColorController.dispose();
    for (var r in _previewRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchVariantsForArticle(String artId, String artNo) async {
    if (!mounted) return;
    setState(() {
      _isFetching = true;
      _fetchStatusMessage = 'Auto-fetching QC checked quantities...';
    });

    try {
      final qcLogs = await supabase
          .from('qc_logs')
          .select('stage, color, size, qty_received, qty_passed, qty_rejected')
          .eq('article_id', artId)
          .timeout(const Duration(seconds: 5), onTimeout: () => []);

      final lotRes = await supabase
          .from('allotments')
          .select('id, challan_id, allotment_variants(color, size, quantity)')
          .eq('article_id', artId)
          .limit(10)
          .timeout(const Duration(seconds: 5), onTimeout: () => []);

      if (!mounted) return;

      final Map<String, Map<String, int>> variantMap = {};

      for (var lot in lotRes) {
        final vars = lot['allotment_variants'] as List<dynamic>? ?? [];
        for (var v in vars) {
          final c = (v['color']?.toString() ?? 'WHITE CHOCOLATE').trim().toUpperCase();
          final s = (v['size']?.toString() ?? 'M').trim().toUpperCase();
          final q = (v['quantity'] as int?) ?? 0;
          final key = '$c|||$s';
          variantMap.putIfAbsent(key, () => {'passed': 0, 'received': 0, 'order': 0});
          variantMap[key]!['order'] = (variantMap[key]!['order'] ?? 0) + q;
        }
      }

      for (var log in qcLogs) {
        final c = (log['color']?.toString() ?? 'WHITE CHOCOLATE').trim().toUpperCase();
        final s = (log['size']?.toString() ?? 'M').trim().toUpperCase();
        final p = (log['qty_passed'] as int?) ?? 0;
        final r = (log['qty_received'] as int?) ?? 0;
        final key = '$c|||$s';
        variantMap.putIfAbsent(key, () => {'passed': 0, 'received': 0, 'order': 0});
        variantMap[key]!['passed'] = (variantMap[key]!['passed'] ?? 0) + p;
        variantMap[key]!['received'] = (variantMap[key]!['received'] ?? 0) + r;
      }

      for (var r in _previewRows) {
        r.dispose();
      }

      final List<_ArticleVariantRow> rows = [];

      if (variantMap.isNotEmpty) {
        final sortedKeys = variantMap.keys.toList()
          ..sort((a, b) {
            final sA = a.split('|||')[1];
            final sB = b.split('|||')[1];
            return _compareSizes(sA, sB);
          });

        for (var key in sortedKeys) {
          final parts = key.split('|||');
          final color = parts[0];
          final size = parts[1];
          final stats = variantMap[key]!;
          final passed = stats['passed'] ?? 0;
          final received = stats['received'] ?? 0;
          final order = stats['order'] ?? 0;
          final checkedQty = passed > 0 ? passed : received;
          final delivQty = checkedQty > 0 ? checkedQty : (order > 0 ? order : 0);
          final orderQty = order > 0 ? order : delivQty;

          if (_selectedProductMode == 'BOTH (TOP + PANT)') {
            rows.add(_ArticleVariantRow(
              artNo: artNo,
              articleId: artId,
              color: color,
              category: _selectedCategory,
              product: 'TOP',
              size: size,
              orderQty: orderQty,
              deliveryQty: delivQty,
              qcCheckedQty: checkedQty,
            ));
            rows.add(_ArticleVariantRow(
              artNo: artNo,
              articleId: artId,
              color: color,
              category: _selectedCategory,
              product: 'PANT',
              size: size,
              orderQty: orderQty,
              deliveryQty: delivQty,
              qcCheckedQty: checkedQty,
            ));
          } else {
            rows.add(_ArticleVariantRow(
              artNo: artNo,
              articleId: artId,
              color: color,
              category: _selectedCategory,
              product: _selectedProductMode,
              size: size,
              orderQty: orderQty,
              deliveryQty: delivQty,
              qcCheckedQty: checkedQty,
            ));
          }
        }
      } else {
        final defaultSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
        final activeColor = _customColorController.text.trim().isEmpty ? 'WHITE CHOCOLATE' : _customColorController.text.trim().toUpperCase();
        for (var sz in defaultSizes) {
          if (_selectedProductMode == 'BOTH (TOP + PANT)') {
            rows.add(_ArticleVariantRow(
              artNo: artNo,
              articleId: artId,
              color: activeColor,
              category: _selectedCategory,
              product: 'TOP',
              size: sz,
              orderQty: 0,
              deliveryQty: 0,
              qcCheckedQty: 0,
            ));
            rows.add(_ArticleVariantRow(
              artNo: artNo,
              articleId: artId,
              color: activeColor,
              category: _selectedCategory,
              product: 'PANT',
              size: sz,
              orderQty: 0,
              deliveryQty: 0,
              qcCheckedQty: 0,
            ));
          } else {
            rows.add(_ArticleVariantRow(
              artNo: artNo,
              articleId: artId,
              color: activeColor,
              category: _selectedCategory,
              product: _selectedProductMode,
              size: sz,
              orderQty: 0,
              deliveryQty: 0,
              qcCheckedQty: 0,
            ));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _previewRows = rows;
        _isFetching = false;
        _fetchStatusMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetching = false;
        _fetchStatusMessage = 'Error auto-fetching QC logs: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRows = _previewRows.where((r) => r.isSelected).toList();
    final totalSelectedPcs = selectedRows.fold<int>(
      0,
      (sum, r) => sum + (int.tryParse(r.deliveryController.text.trim()) ?? r.deliveryQty),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Top Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.steel, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Article to Delivery Challan',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Auto-fetch QC passed quantities for Ollypop dispatch',
                        style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.inkSoft),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Main Config & Matrix Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Article Selection Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SELECT ARTICLE NUMBER *',
                              style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.steel),
                            ),
                            if (_selectedArticleId != null)
                              InkWell(
                                onTap: () => _fetchVariantsForArticle(_selectedArticleId!, _selectedArtNo),
                                child: Row(
                                  children: [
                                    const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.steel),
                                    const SizedBox(width: 4),
                                    Text('Re-fetch QC', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.steel)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedArtNo.isNotEmpty ? _selectedArtNo : null,
                          hint: const Text('Select an Article'),
                          items: widget.availableArticles.map((a) {
                            return DropdownMenuItem<String>(
                              value: a['art_no'].toString(),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      a['art_no'].toString(),
                                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.steel),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      a['description'] ?? 'Garment Article',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.ink),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedArtNo = val;
                                final match = widget.availableArticles.firstWhere((a) => a['art_no'].toString() == val, orElse: () => {});
                                _selectedArticleId = match['id']?.toString();
                              });
                              if (_selectedArticleId != null) {
                                _fetchVariantsForArticle(_selectedArticleId!, _selectedArtNo);
                              }
                            }
                          },
                        ),

                        const SizedBox(height: 12),

                        // Category and Product Configuration
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CATEGORY *', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.inkSoft)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedCategory,
                                    items: const ['SUIT', 'FROCK', 'SKIRT', 'KURTI', 'PANT', 'SHIRT', 'OTHER']
                                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold))))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _selectedCategory = v);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PRODUCT MODE *', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.inkSoft)),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    children: ['TOP', 'PANT', 'BOTH (TOP + PANT)'].map((p) {
                                      final isSel = _selectedProductMode == p;
                                      return ChoiceChip(
                                        label: Text(
                                          p == 'BOTH (TOP + PANT)' ? 'BOTH' : p,
                                          style: GoogleFonts.publicSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSel ? Colors.white : AppTheme.ink,
                                          ),
                                        ),
                                        selected: isSel,
                                        selectedColor: AppTheme.steel,
                                        onSelected: (val) {
                                          if (val) {
                                            setState(() => _selectedProductMode = p);
                                            if (_selectedArticleId != null) {
                                              _fetchVariantsForArticle(_selectedArticleId!, _selectedArtNo);
                                            }
                                          }
                                        },
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Color / Shade
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('COLOR / SHADE *', style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.inkSoft)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _customColorController,
                              textCapitalization: TextCapitalization.characters,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                hintText: 'e.g. WHITE CHOCOLATE, NAVY, RED',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  for (var r in _previewRows) {
                                    r.color = val.toUpperCase();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: ['WHITE CHOCOLATE', 'BLACK', 'NAVY', 'RED', 'WINE', 'OLIVE'].map((c) {
                            return InkWell(
                              onTap: () {
                                _customColorController.text = c;
                                setState(() {
                                  for (var r in _previewRows) {
                                    r.color = c;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Text(c, style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Section Header: Sizes Matrix
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'QC CHECKED SIZES & QUANTITIES',
                            style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.ink),
                          ),
                          if (_previewRows.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                '${_previewRows.length} rows',
                                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.steel),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_previewRows.isNotEmpty)
                        InkWell(
                          onTap: () {
                            final allSelected = _previewRows.every((r) => r.isSelected);
                            setState(() {
                              for (var r in _previewRows) {
                                r.isSelected = !allSelected;
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              _previewRows.every((r) => r.isSelected) ? 'Deselect All' : 'Select All',
                              style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.steel),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Preview Table
                  if (_isFetching)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(color: AppTheme.steel, strokeWidth: 2.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _fetchStatusMessage ?? 'Fetching QC Checked Pieces...',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Querying qc_logs & production lots for Art #$_selectedArtNo',
                            style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
                          ),
                        ],
                      ),
                    )
                  else if (_previewRows.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppTheme.steel, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            'No Variants Found for Art #$_selectedArtNo',
                            style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select another article or enter custom breakdown.',
                            style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              color: const Color(0xFFF1F5F9),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  const SizedBox(width: 32), // Checkbox space
                                  Expanded(flex: 2, child: Text('SIZE', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.inkSoft))),
                                  Expanded(flex: 3, child: Text('PRODUCT', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.inkSoft))),
                                  Expanded(flex: 3, child: Text('ORDER QTY', textAlign: TextAlign.center, style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.inkSoft))),
                                  Expanded(flex: 3, child: Text('DELIVERY', textAlign: TextAlign.center, style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.steel))),
                                  Expanded(flex: 2, child: Text('BAL', textAlign: TextAlign.right, style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.inkSoft))),
                                ],
                              ),
                            ),

                            // Table Rows
                            ..._previewRows.map((row) {
                              final oQty = int.tryParse(row.orderController.text.trim()) ?? row.orderQty;
                              final dQty = int.tryParse(row.deliveryController.text.trim()) ?? row.deliveryQty;
                              final bal = oQty - dQty;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                ),
                                child: Row(
                                  children: [
                                    // Selection Checkbox
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: Checkbox(
                                        value: row.isSelected,
                                        activeColor: AppTheme.steel,
                                        onChanged: (val) => setState(() => row.isSelected = val ?? true),
                                      ),
                                    ),

                                    // Size Badge
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.steelMist,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          row.size,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.steel,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 6),

                                    // Product Part (TOP or PANT)
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        row.product,
                                        style: GoogleFonts.publicSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: row.product == 'TOP' ? AppTheme.steel : const Color(0xFF0F766E),
                                        ),
                                      ),
                                    ),

                                    // Order Qty Input
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 3),
                                        child: SizedBox(
                                          height: 34,
                                          child: TextField(
                                            controller: row.orderController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: InputDecoration(
                                              contentPadding: EdgeInsets.zero,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Delivery Qty Input (Editable, auto-filled from QC)
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 3),
                                        child: SizedBox(
                                          height: 34,
                                          child: TextField(
                                            controller: row.deliveryController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.steel),
                                            decoration: InputDecoration(
                                              contentPadding: EdgeInsets.zero,
                                              filled: true,
                                              fillColor: const Color(0xFFEFF6FF),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.steel, width: 1.2)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.steel, width: 1.2)),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Balance Display
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        bal == 0 ? '0' : (bal > 0 ? '+$bal' : '$bal'),
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: bal == 0 ? AppTheme.inkSoft : (bal < 0 ? AppTheme.green : AppTheme.red),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Sticky Bottom Summary & 1-Click Action Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -3)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${selectedRows.length} rows selected',
                        style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.ink),
                      ),
                      Row(
                        children: [
                          Text('Dispatch Total: ', style: GoogleFonts.publicSans(fontSize: 11.5, color: AppTheme.inkSoft)),
                          Text(
                            '$totalSelectedPcs PCS',
                            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.steel),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: selectedRows.isEmpty
                          ? null
                          : () {
                              final List<Map<String, dynamic>> newItems = [];
                              for (var r in selectedRows) {
                                final orderVal = int.tryParse(r.orderController.text.trim()) ?? r.orderQty;
                                final delivVal = int.tryParse(r.deliveryController.text.trim()) ?? r.deliveryQty;
                                newItems.add({
                                  'art_no': r.artNo,
                                  'article_id': r.articleId,
                                  'color': r.color,
                                  'category': r.category,
                                  'product': r.product,
                                  'size': r.size,
                                  'order_qty': orderVal,
                                  'delivery_qty': delivVal,
                                  'balance_qty': orderVal - delivVal,
                                });
                              }

                              widget.onAddItems(newItems);
                              Navigator.pop(context);
                            },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        'Add All (${selectedRows.length} Sizes • $totalSelectedPcs Pcs) to Challan',
                        style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.steel,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

