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
    final autoNo = (widget.prefilledLot?['challans']?['challan_no'] ?? widget.prefilledLot?['challan_id'] ?? '${350 + now.day}').toString();

    _challanNoController = TextEditingController(text: autoNo);
    _vehicleNoController = TextEditingController(text: 'WB 19 A 1234');
    _dateController = TextEditingController(text: dateStr);
    _totalBagsController = TextEditingController(text: '45');
    _spotNotesController = TextEditingController(
      text: 'NOTE: Cream L size - small touchup required in 22 pcs, pcs packed separate.\nBalance pcs will send in evening.',
    );

    _buildInitialItems();
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
      final artNo = lot['article']?['art_no'] ?? '5223';
      final articleId = lot['article_id'];

      final List<Map<String, dynamic>> items = [];

      for (var v in vars) {
        final color = (v['color']?.toString().trim() ?? 'White Chocolate').toUpperCase();
        final size = (v['size']?.toString().trim() ?? 'M').toUpperCase();
        final orderQty = (v['quantity'] as int? ?? 400);
        // Default delivery is orderQty or slightly adjusted based on QC pass
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
      // Default standard demonstration set matching authentic Ollypop challan
      _challanItems = [
        {'art_no': '5223', 'color': 'WHITE CHOCOLATE', 'category': 'SUIT', 'product': 'TOP', 'size': 'XS', 'order_qty': 240, 'delivery_qty': 243, 'balance_qty': -3},
        {'art_no': '5223', 'color': 'WHITE CHOCOLATE', 'category': 'SUIT', 'product': 'TOP', 'size': 'S', 'order_qty': 240, 'delivery_qty': 244, 'balance_qty': -4},
        {'art_no': '5223A', 'color': 'WHITE CHOCOLATE', 'category': 'SUIT', 'product': 'TOP', 'size': 'M', 'order_qty': 400, 'delivery_qty': 397, 'balance_qty': 3},
        {'art_no': '5223A', 'color': 'WHITE CHOCOLATE', 'category': 'SUIT', 'product': 'TOP', 'size': 'L', 'order_qty': 400, 'delivery_qty': 398, 'balance_qty': 2},
        {'art_no': '5223A', 'color': 'WHITE CHOCOLATE', 'category': 'SUIT', 'product': 'TOP', 'size': 'XL', 'order_qty': 400, 'delivery_qty': 380, 'balance_qty': 20},
        {'art_no': '5223A', 'color': 'WHITE CHOCOLATE', 'category': 'SUIT', 'product': 'TOP', 'size': 'XXL', 'order_qty': 320, 'delivery_qty': 310, 'balance_qty': 10},
      ];
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
                      Text('Status: PENDING_ADMIN_APPROVAL', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.steel)),
                      Text('Vehicle: $vehicleNo', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
                      Text('Delivery Qty: $_totalDeliveryQty pcs in $totalBags bags', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'No truck leaves the gate until Admin reviews & signs off the digital challan.',
                  style: GoogleFonts.publicSans(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppTheme.inkFaint),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.steel,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting delivery challan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.red, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Modal Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.steelMist,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_outlined, color: AppTheme.steel, size: 20),
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
                                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
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
                                          hintText: 'WB 19 A 1234',
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
                    // 2. BILLED TO & SHIPPING TO CARDS (SMART AUTO + MANUAL EDIT)
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
                                    decoration: const InputDecoration(isDense: true, labelText: 'Billing Address'),
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
                                    style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.ink),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

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
                    Text(
                      '8-Column Delivery Breakdown',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 6),

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
                          child: DataTable(
                            headingRowHeight: 38,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 40,
                            columnSpacing: 14,
                            headingRowColor: WidgetStateProperty.all(AppTheme.bg),
                            columns: [
                              _buildCol('ART NO'),
                              _buildCol('COLOUR'),
                              _buildCol('CATEGORY'),
                              _buildCol('PRODUCT'),
                              _buildCol('SIZE'),
                              _buildCol('ORDER QTY', isNum: true),
                              _buildCol('DELIVERY', isNum: true),
                              _buildCol('BALANCE', isNum: true),
                            ],
                            rows: [
                              ..._challanItems.map((item) {
                                final bal = item['balance_qty'] as int;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(item['art_no'].toString(), style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold))),
                                    DataCell(Text(item['color'].toString(), style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.w600))),
                                    DataCell(Text(item['category'].toString(), style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft))),
                                    DataCell(Text(item['product'].toString(), style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft))),
                                    DataCell(Text(item['size'].toString(), style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold))),
                                    DataCell(Text(item['order_qty'].toString(), style: GoogleFonts.jetBrainsMono(fontSize: 12))),
                                    DataCell(Text(item['delivery_qty'].toString(), style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.steel))),
                                    DataCell(Text(
                                      bal == 0 ? '0' : (bal > 0 ? '+$bal' : '$bal'),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: bal < 0 ? AppTheme.green : (bal > 0 ? AppTheme.red : AppTheme.inkSoft),
                                      ),
                                    )),
                                  ],
                                );
                              }),
                              // TOTALS ROW
                              DataRow(
                                color: WidgetStateProperty.all(Colors.grey.shade100),
                                cells: [
                                  DataCell(Text('TOTAL', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.ink))),
                                  DataCell(Text('BAGS: ${_totalBagsController.text}', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.steel))),
                                  const DataCell(Text('-')),
                                  const DataCell(Text('-')),
                                  const DataCell(Text('-')),
                                  DataCell(Text('$_totalOrderQty', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w900))),
                                  DataCell(Text('$_totalDeliveryQty', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppTheme.steel))),
                                  DataCell(Text(
                                    '$_totalBalanceQty',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w900, color: _totalBalanceQty > 0 ? AppTheme.red : AppTheme.ink),
                                  )),
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
                                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.only(top: 10)),
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
                                    hintText: 'e.g. Note on balance pieces or packing details',
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
                    // 6. SUBMISSION BUTTONS
                    // ============================================
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _submitToAdmin,
                              icon: _isLoading
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                _isLoading ? 'Submitting...' : 'Submit to Admin for Dispatch Approval',
                                style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.steel,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                              side: const BorderSide(color: AppTheme.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  DataColumn _buildCol(String title, {bool isNum = false}) {
    return DataColumn(
      numeric: isNum,
      label: Text(
        title,
        style: GoogleFonts.publicSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppTheme.inkSoft,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
