import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/merchandising_models.dart';
import '../providers/merchandising_provider.dart';

const List<String> kDefaultSizes = ['XS', 'S', 'M', 'L', 'XL'];

class CreateOrderModal extends ConsumerStatefulWidget {
  final ActiveBuyer? preselectedBuyer;
  const CreateOrderModal({super.key, this.preselectedBuyer});

  @override
  ConsumerState<CreateOrderModal> createState() => _CreateOrderModalState();
}

class _CreateOrderModalState extends ConsumerState<CreateOrderModal> {
  int _step = 1;
  String? _error;
  bool _isSubmitting = false;

  // Selected Option Key: "buyer_<id>", "tp_<id>", "__CUSTOM__"
  String _selectedOptionKey = '';
  ActiveBuyer? _selectedBuyerRef;
  TechPackArticleItem? _selectedTechPack;

  // Step 1 Form Controllers & State
  late TextEditingController _poController;
  late TextEditingController _brandController;
  late TextEditingController _styleRefController;
  late TextEditingController _styleNameController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _dateController;

  String _currency = 'INR';
  DateTime _exFactoryDate = DateTime.now().add(const Duration(days: 25));

  String _embellishmentSeq = 'NONE';
  String _fabricComposition = '100% Combed Cotton';
  int _targetGsm = 180;
  String? _cadFrontUrl;
  String? _cadBackUrl;

  // Step 2 Matrix State
  List<String> _colors = ['Standard'];
  Map<String, Map<String, int>> _matrixData = {
    'Standard': {'XS': 50, 'S': 200, 'M': 400, 'L': 250, 'XL': 100}
  };
  final TextEditingController _newColorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _poController = TextEditingController(text: _generateAutoPoNumber());
    _brandController = TextEditingController();
    _styleRefController = TextEditingController();
    _styleNameController = TextEditingController();
    _quantityController = TextEditingController(text: '1000');
    _priceController = TextEditingController(text: '1450.00');
    _dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(_exFactoryDate),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromState();
    });
  }

  @override
  void dispose() {
    _poController.dispose();
    _brandController.dispose();
    _styleRefController.dispose();
    _styleNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _dateController.dispose();
    _newColorController.dispose();
    super.dispose();
  }

  String _generateAutoPoNumber([String? buyerCode]) {
    final yr = DateTime.now().year;
    final rand = 1000 + Random().nextInt(9000);
    final cleanCode = (buyerCode ?? '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final prefix = cleanCode.isNotEmpty ? (cleanCode.length >= 4 ? cleanCode.substring(0, 4) : cleanCode) : 'PO';
    return '$prefix-$yr-$rand';
  }

  Map<String, int> _distributeQuantity(int amount, List<String> sizes) {
    final result = <String, int>{};
    for (final s in sizes) {
      result[s] = 0;
    }
    if (amount <= 0) return result;

    final ratios = {'XS': 0.05, 'S': 0.20, 'M': 0.40, 'L': 0.25, 'XL': 0.10};
    int allocated = 0;
    for (int i = 0; i < sizes.length; i++) {
      final s = sizes[i];
      if (i == sizes.length - 1) {
        result[s] = max(0, amount - allocated);
      } else {
        final r = ratios[s] ?? (1.0 / sizes.length);
        final q = (amount * r).round();
        result[s] = q;
        allocated += q;
      }
    }
    return result;
  }

  void _initializeFromState() {
    final state = ref.read(merchandisingProvider);
    final buyers = state.buyers;
    final techPacks = state.techPackArticles;

    if (widget.preselectedBuyer != null) {
      _handleSelectOption('buyer_${widget.preselectedBuyer!.id}', buyers, techPacks);
      return;
    }

    final linked = buyers.where((b) => b.linkedArticleNumber != null && b.linkedArticleNumber!.isNotEmpty).firstOrNull;
    if (linked != null) {
      _handleSelectOption('buyer_${linked.id}', buyers, techPacks);
    } else if (techPacks.isNotEmpty) {
      _handleSelectOption('tp_${techPacks.first.id}', buyers, techPacks);
    }
  }

  void _handleSelectOption(String key, List<ActiveBuyer> buyers, List<TechPackArticleItem> techPacks) {
    setState(() {
      _selectedOptionKey = key;
      _error = null;

      if (key == '__CUSTOM__' || key.isEmpty) {
        _selectedBuyerRef = null;
        _selectedTechPack = null;
        _brandController.clear();
        _styleRefController.clear();
        _styleNameController.clear();
        _embellishmentSeq = 'NONE';
        _fabricComposition = '100% Cotton';
        _targetGsm = 180;
        _cadFrontUrl = null;
        _cadBackUrl = null;
        return;
      }

      if (key.startsWith('buyer_')) {
        final buyerId = key.replaceFirst('buyer_', '');
        final b = buyers.where((x) => x.id == buyerId).firstOrNull;
        if (b == null) return;

        _selectedBuyerRef = b;
        _brandController.text = b.brandName?.isNotEmpty == true ? b.brandName! : b.buyerName;
        _styleRefController.text = b.linkedArticleNumber ?? '';
        _currency = b.currency;

        final qty = b.contractedVolume > 0 ? b.contractedVolume : 1000;
        _quantityController.text = qty.toString();

        final price = b.pricePerPiece > 0 ? b.pricePerPiece : 1450.0;
        _priceController.text = price.toStringAsFixed(2);

        _poController.text = _generateAutoPoNumber(b.buyerCode);

        final artClean = (b.linkedArticleNumber ?? '').trim().toUpperCase();
        final tp = techPacks.where((t) => t.styleNumber.trim().toUpperCase() == artClean).firstOrNull;

        if (tp != null) {
          _selectedTechPack = tp;
          _styleNameController.text = '${tp.category} Style ${tp.styleNumber} (${tp.fabricComposition}, ${tp.targetGsm} GSM)';
          _embellishmentSeq = tp.embellishmentSequence;
          _fabricComposition = tp.fabricComposition;
          _targetGsm = tp.targetGsm;
          _cadFrontUrl = tp.cadFrontUrl;
          _cadBackUrl = tp.cadBackUrl;
        } else {
          _selectedTechPack = null;
          _styleNameController.text = '${b.buyerName} Contract ${b.linkedArticleNumber ?? ""}';
          _embellishmentSeq = 'NONE';
          _fabricComposition = '100% Combed Cotton Single Jersey';
          _targetGsm = 180;
          _cadFrontUrl = null;
          _cadBackUrl = null;
        }

        _colors = ['Standard'];
        _matrixData = {'Standard': _distributeQuantity(qty, kDefaultSizes)};
      } else if (key.startsWith('tp_')) {
        final tpId = key.replaceFirst('tp_', '');
        final tp = techPacks.where((t) => t.id == tpId).firstOrNull;
        if (tp == null) return;

        _selectedTechPack = tp;
        _selectedBuyerRef = null;
        _styleRefController.text = tp.styleNumber;
        _styleNameController.text = '${tp.category} Style ${tp.styleNumber} (${tp.fabricComposition}, ${tp.targetGsm} GSM)';
        _embellishmentSeq = tp.embellishmentSequence;
        _fabricComposition = tp.fabricComposition;
        _targetGsm = tp.targetGsm;
        _cadFrontUrl = tp.cadFrontUrl;
        _cadBackUrl = tp.cadBackUrl;

        if (tp.brandName != null && tp.brandName!.toUpperCase() != 'INHOUSE' && _brandController.text.isEmpty) {
          _brandController.text = tp.brandName!;
        }

        final qty = int.tryParse(_quantityController.text) ?? 1000;
        _colors = ['Standard'];
        _matrixData = {'Standard': _distributeQuantity(qty, kDefaultSizes)};
      }
    });
  }

  int get _currentMatrixSum {
    return _colors.fold<int>(0, (sum, color) {
      final row = _matrixData[color] ?? {};
      final rowTotal = kDefaultSizes.fold<int>(0, (rSum, s) => rSum + (row[s] ?? 0));
      return sum + rowTotal;
    });
  }

  int get _targetQty => int.tryParse(_quantityController.text) ?? 0;
  int get _qtyDelta => _targetQty - _currentMatrixSum;

  void _handleNextToStep2() {
    setState(() => _error = null);

    if (_poController.text.trim().isEmpty) {
      setState(() => _error = 'Buyer PO Number is mandatory.');
      return;
    }
    if (_brandController.text.trim().isEmpty) {
      setState(() => _error = 'Please specify Brand / Principal Buyer name.');
      return;
    }
    if (_styleRefController.text.trim().isEmpty) {
      setState(() => _error = 'Please specify or select an Article / Style Reference.');
      return;
    }
    if (_targetQty <= 0) {
      setState(() => _error = 'Total Order Quantity must be greater than 0.');
      return;
    }

    if (_colors.length == 1 && _currentMatrixSum != _targetQty) {
      setState(() {
        _matrixData = {_colors.first: _distributeQuantity(_targetQty, kDefaultSizes)};
      });
    }

    setState(() => _step = 2);
  }

  void _handleCellChange(String color, String size, String value) {
    final num = int.tryParse(value) ?? 0;
    setState(() {
      if (!_matrixData.containsKey(color)) {
        _matrixData[color] = {};
      }
      _matrixData[color]![size] = max(0, num);
    });
  }

  void _handleAddColor() {
    final formatted = _newColorController.text.trim();
    if (formatted.isEmpty) return;

    if (_colors.any((c) => c.toLowerCase() == formatted.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Color "$formatted" already exists in matrix.')),
      );
      return;
    }

    setState(() {
      final updatedColors = [..._colors, formatted];
      _colors = updatedColors;
      _newColorController.clear();

      final perColor = _targetQty ~/ updatedColors.length;
      final newMatrix = <String, Map<String, int>>{};
      int allocated = 0;

      for (int i = 0; i < updatedColors.length; i++) {
        final c = updatedColors[i];
        final isLast = (i == updatedColors.length - 1);
        final cQty = isLast ? (_targetQty - allocated) : perColor;
        allocated += cQty;
        newMatrix[c] = _distributeQuantity(cQty, kDefaultSizes);
      }
      _matrixData = newMatrix;
    });
  }

  void _handleRemoveColor(String colorToRemove) {
    if (_colors.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must keep at least one colorway in the matrix.')),
      );
      return;
    }

    setState(() {
      final updatedColors = _colors.where((c) => c != colorToRemove).toList();
      _colors = updatedColors;

      final perColor = _targetQty ~/ updatedColors.length;
      final newMatrix = <String, Map<String, int>>{};
      int allocated = 0;

      for (int i = 0; i < updatedColors.length; i++) {
        final c = updatedColors[i];
        final isLast = (i == updatedColors.length - 1);
        final cQty = isLast ? (_targetQty - allocated) : perColor;
        allocated += cQty;
        newMatrix[c] = _distributeQuantity(cQty, kDefaultSizes);
      }
      _matrixData = newMatrix;
    });
  }

  void _handleRebalanceAll() {
    if (_colors.isEmpty) return;
    setState(() {
      final perColor = _targetQty ~/ _colors.length;
      final newMatrix = <String, Map<String, int>>{};
      int allocated = 0;

      for (int i = 0; i < _colors.length; i++) {
        final c = _colors[i];
        final isLast = (i == _colors.length - 1);
        final cQty = isLast ? (_targetQty - allocated) : perColor;
        allocated += cQty;
        newMatrix[c] = _distributeQuantity(cQty, kDefaultSizes);
      }
      _matrixData = newMatrix;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Matrix quantities auto-balanced evenly!')),
    );
  }

  Future<void> _handleSubmit() async {
    if (_colors.isEmpty) {
      setState(() => _error = 'Please add at least one colorway.');
      return;
    }
    if (_currentMatrixSum != _targetQty) {
      setState(() => _error = 'Matrix total ($_currentMatrixSum pcs) must match PO target ($_targetQty pcs). Delta: $_qtyDelta pcs.');
      return;
    }

    setState(() => _isSubmitting = true);

    final colorMatrix = _colors.map((c) {
      final row = _matrixData[c] ?? {};
      final rowTotal = kDefaultSizes.fold<int>(0, (acc, s) => acc + (row[s] ?? 0));
      return ColorSizeMatrixItem(
        color: c,
        sizes: Map<String, int>.from(row),
        total: rowTotal,
      );
    }).toList();

    final unitPrice = double.tryParse(_priceController.text) ?? 1450.0;

    final success = await ref.read(merchandisingProvider.notifier).createBuyerOrder(
          poNumber: _poController.text.trim(),
          brandName: _brandController.text.trim(),
          styleRef: _styleRefController.text.trim(),
          totalQuantity: _targetQty,
          unitFobPrice: unitPrice,
          currency: _currency,
          exFactoryDate: _dateController.text.trim(),
          colorMatrix: colorMatrix,
          techPackId: _selectedTechPack?.id,
        );

    final buyerContract = ActiveBuyer(
      id: _selectedBuyerRef?.id ?? 'BYR-${DateTime.now().millisecondsSinceEpoch}',
      buyerName: _brandController.text.trim(),
      buyerCode: _selectedBuyerRef?.buyerCode ?? (_brandController.text.trim().length >= 4 ? _brandController.text.trim().substring(0, 4).toUpperCase() : 'BUYER'),
      brandName: _brandController.text.trim(),
      contractedVolume: _targetQty,
      pricePerPiece: unitPrice,
      totalContractValue: _targetQty * unitPrice,
      currency: _currency,
      linkedArticleNumber: _styleRefController.text.trim(),
      linkedArticleId: _selectedTechPack?.id,
      linkedArticleName: _styleNameController.text.trim(),
      status: 'CONTRACTED',
    );
    await ref.read(merchandisingProvider.notifier).createActiveBuyer(buyerContract);

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.pop(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PO ${_poController.text.trim()} booked & specs dispatched to cutting!'),
            backgroundColor: const Color(0xFF1B7A43),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchandisingProvider);
    final buyers = state.buyers;
    final techPacks = state.techPackArticles;
    final linkedBuyers = buyers.where((b) => b.linkedArticleNumber != null && b.linkedArticleNumber!.isNotEmpty).toList();

    final unitPriceNum = double.tryParse(_priceController.text) ?? 0.0;
    final estimatedRevenue = _targetQty * unitPriceNum;
    final curSym = _currency == 'INR' ? '₹' : _currency == 'USD' ? '\$' : _currency == 'EUR' ? '€' : '£';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F4EC), // Warm Cream Canvas matching Web
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // =========================================================
          // HEADER (Matching Web Exactly)
          // =========================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: Text(
                      'MASTER BUYER PO BOOKING',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF241D52),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Step $_step of 2',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9B9A94),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6A65), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _step == 1 ? '1. Commercial Contract & Specs' : '2. Colorway & Size Distribution',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1A),
            ),
          ),
          const Divider(height: 18, color: Color(0x1A000000)),

          // Error Banner
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFC0392B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFC0392B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // =========================================================
          // SCROLLABLE BODY
          // =========================================================
          Expanded(
            child: SingleChildScrollView(
              child: _step == 1
                  ? _buildStep1(linkedBuyers, techPacks, curSym, estimatedRevenue)
                  : _buildStep2(curSym),
            ),
          ),

          // =========================================================
          // FOOTER CONTROLS
          // =========================================================
          const SizedBox(height: 12),
          Row(
            children: [
              if (_step == 2)
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B6A65),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x1A000000)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text(
                      'Back',
                      style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => setState(() => _step = 1),
                  ),
                )
              else
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B6A65),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x1A000000)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const SizedBox(width: 10),

              if (_step == 1)
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF241D52),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: _handleNextToStep2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue to Color Matrix',
                          style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF241D52),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: (_isSubmitting || _currentMatrixSum != _targetQty) ? null : _handleSubmit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Confirm & Book PO',
                                style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP 1 WIDGETS
  // ==========================================================================
  Widget _buildStep1(List<ActiveBuyer> linkedBuyers, List<TechPackArticleItem> techPacks, String curSym, double revenue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Contract Dropdown Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x1A000000)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'SELECT CONTRACTED BUYER & LINKED ARTICLE *',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6B6A65),
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${linkedBuyers.length} Contract(s)',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF332B6B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedOptionKey.isNotEmpty ? _selectedOptionKey : null,
                isExpanded: true,
                decoration: _inputDecoration(hint: '-- Choose Contracted Buyer / Article --'),
                items: [
                  if (linkedBuyers.isNotEmpty)
                    ...linkedBuyers.map((b) {
                      return DropdownMenuItem(
                        value: 'buyer_${b.id}',
                        child: Text(
                          '${b.buyerName} — Art #${b.linkedArticleNumber} (${NumberFormat.decimalPattern('en_IN').format(b.contractedVolume)} Pcs)',
                          style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  if (techPacks.isNotEmpty)
                    ...techPacks.map((tp) {
                      return DropdownMenuItem(
                        value: 'tp_${tp.id}',
                        child: Text(
                          '${tp.styleNumber} — ${tp.category} (${tp.fabricComposition})',
                          style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  const DropdownMenuItem(
                    value: '__CUSTOM__',
                    child: Text('+ Custom Style Reference (Manual Entry)', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    final state = ref.read(merchandisingProvider);
                    _handleSelectOption(val, state.buyers, state.techPackArticles);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. PO Number & Brand
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('BUYER PO NUMBER *', style: _labelStyle),
                        Text('Auto', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF9B9A94))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _poController.text,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF241D52),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _poController.text = _generateAutoPoNumber(_selectedBuyerRef?.buyerCode);
                            });
                          },
                          child: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF332B6B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BRAND / PRINCIPAL BUYER *', style: _labelStyle),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _brandController,
                      readOnly: _selectedBuyerRef != null,
                      style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A)),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: 'e.g. Hollypop',
                        hintStyle: TextStyle(fontSize: 12, color: Color(0xFFB6B4AC)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 3. CAD Visual Tiles (Front & Back)
        if (_cadFrontUrl != null || _cadBackUrl != null || _selectedTechPack != null) ...[
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 95,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_cadFrontUrl != null && _cadFrontUrl!.isNotEmpty)
                        Expanded(
                          child: Image.network(
                            _cadFrontUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.checkroom_outlined, size: 28, color: Color(0xFF9B9A94)),
                          ),
                        )
                      else
                        const Icon(Icons.checkroom_outlined, size: 28, color: Color(0xFF9B9A94)),
                      const SizedBox(height: 4),
                      Text('FRONT VIEW CAD', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF6B6A65))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 95,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_cadBackUrl != null && _cadBackUrl!.isNotEmpty)
                        Expanded(
                          child: Image.network(
                            _cadBackUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.checkroom_outlined, size: 28, color: Color(0xFF9B9A94)),
                          ),
                        )
                      else
                        const Icon(Icons.checkroom_outlined, size: 28, color: Color(0xFF9B9A94)),
                      const SizedBox(height: 4),
                      Text('BACK VIEW CAD', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF6B6A65))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // 4. Style Reference & Ex-Factory Date
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ARTICLE / STYLE REF *', style: _labelStyle),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _styleRefController,
                      readOnly: _selectedBuyerRef != null,
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A)),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: 'e.g. ART-101',
                        hintStyle: TextStyle(fontSize: 12, color: Color(0xFFB6B4AC)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _exFactoryDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _exFactoryDate = picked;
                      _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TARGET EX-FACTORY DATE *', style: _labelStyle),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF332B6B)),
                          const SizedBox(width: 6),
                          Text(
                            _dateController.text,
                            style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 5. Read-only Info Chips: Embellishment Routing & Fabric Weight
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EMBELLISHMENT ROUTING', style: _chipLabelStyle),
                    const SizedBox(height: 3),
                    Text(
                      _embellishmentSeq == 'NONE'
                          ? 'Cut & Sew'
                          : (_embellishmentSeq == 'ONLY_PRINTING'
                              ? 'Only Printing'
                              : (_embellishmentSeq == 'ONLY_EMBROIDERY'
                                  ? 'Only Embroidery'
                                  : 'Printing & Embroidery')),
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FABRIC & WEIGHT', style: _chipLabelStyle),
                    const SizedBox(height: 3),
                    Text(
                      '$_fabricComposition • $_targetGsm GSM',
                      style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 6. Currency, FOB Rate, Total Quantity
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENCY', style: _labelStyle),
                    const SizedBox(height: 2),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currency,
                        isDense: true,
                        isExpanded: true,
                        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A)),
                        items: const [
                          DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                          DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                          DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                        ],
                        onChanged: (v) => setState(() => _currency = v ?? 'INR'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UNIT FOB ($curSym) *', style: _labelStyle),
                    const SizedBox(height: 2),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ORDER QTY (PCS) *', style: _labelStyle),
                    const SizedBox(height: 2),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 7. Estimated Revenue Summary Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1A000000)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Commercial Revenue:',
                style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6B6A65)),
              ),
              Text(
                '$curSym${NumberFormat.decimalPattern('en_IN').format(revenue.round())}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF332B6B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // STEP 2 WIDGETS
  // ==========================================================================
  Widget _buildStep2(String curSym) {
    final bomItems = _selectedTechPack != null
        ? [
            {'component': 'Shell Fabric', 'desc': _fabricComposition, 'cons': '1.45 MTR/pc', 'placement': 'Front & Back Body'},
            {'component': 'Collar Trim', 'desc': '1x1 Spandex Rib Knit', 'cons': '0.15 MTR/pc', 'placement': 'Neckband Collar'},
            {'component': 'Sewing Thread', 'desc': '40/2 Spun Poly Thread', 'cons': '120 MTR/pc', 'placement': 'Seams & Overlock'},
            {'component': 'Main Label', 'desc': 'Woven Satin Damask Label', 'cons': '1.0 PC/pc', 'placement': 'Center Back Neck'},
          ]
        : [
            {'component': 'Body Fabric', 'desc': _fabricComposition, 'cons': '1.40 MTR/pc', 'placement': 'Full Garment'},
            {'component': 'Sewing Thread', 'desc': 'Standard Polyester', 'cons': '100 MTR/pc', 'placement': 'All Seams'},
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Bill of Materials (BOM) Sheet Card (Mobile Stacked)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x1A000000)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(bottom: BorderSide(color: Color(0x1A000000))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF332B6B)),
                        const SizedBox(width: 6),
                        Text(
                          'BOM & TRIMS SHEET',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: Text(
                        '${bomItems.length} Components · Read-only',
                        style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B)),
                      ),
                    ),
                  ],
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bomItems.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (ctx, i) {
                  final m = bomItems[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['component']!, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A))),
                            Text('${m['desc']} • ${m['placement']}', style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF6B6A65))),
                          ],
                        ),
                        Text(m['cons']!, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B))),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Metric Balance Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1A000000)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TARGET CONTRACT', style: _chipLabelStyle),
                  const SizedBox(height: 2),
                  Text('${NumberFormat.decimalPattern('en_IN').format(_targetQty)} Pcs', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MATRIX SUM', style: _chipLabelStyle),
                  const SizedBox(height: 2),
                  Text(
                    '${NumberFormat.decimalPattern('en_IN').format(_currentMatrixSum)} Pcs',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _currentMatrixSum == _targetQty ? const Color(0xFF1B7A43) : const Color(0xFFC0392B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _qtyDelta == 0 ? const Color(0xFFE9F7EE) : const Color(0xFFFFECEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _qtyDelta == 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _qtyDelta == 0 ? 'Balanced (0)' : '${_qtyDelta > 0 ? "+" : ""}$_qtyDelta pcs',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _qtyDelta == 0 ? const Color(0xFF1B7A43) : const Color(0xFFC0392B),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Add Colorway Input & Auto Balance
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: TextField(
                  controller: _newColorController,
                  decoration: const InputDecoration(
                    hintText: 'Add colorway (e.g. Navy Blue)...',
                    hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFFB6B4AC)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _handleAddColor(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFAF7F0),
                foregroundColor: const Color(0xFF332B6B),
                side: const BorderSide(color: Color(0x1A000000)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('+ Add Color', style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
              onPressed: _handleAddColor,
            ),
            if (_colors.length > 1) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.balance_rounded, size: 18, color: Color(0xFF332B6B)),
                tooltip: 'Auto-Balance All Quantities',
                onPressed: _handleRebalanceAll,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // 4. Colorway x Size Matrix Grid (Card style per color)
        ..._colors.map((color) {
          final row = _matrixData[color] ?? {};
          final rowTotal = kDefaultSizes.fold<int>(0, (sum, s) => sum + (row[s] ?? 0));

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1A000000)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(color, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A))),
                    Row(
                      children: [
                        Text('Total: $rowTotal Pcs', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF332B6B))),
                        if (_colors.length > 1) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFC0392B)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _handleRemoveColor(color),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: kDefaultSizes.map((size) {
                    final val = row[size] ?? 0;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAF8),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: Column(
                          children: [
                            Text(size, style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF6B6A65))),
                            const SizedBox(height: 2),
                            TextFormField(
                              initialValue: val.toString(),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1A)),
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none),
                              onChanged: (v) => _handleCellChange(color, size, v),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  TextStyle get _labelStyle => GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF9B9A94), letterSpacing: 0.3);
  TextStyle get _chipLabelStyle => GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF9B9A94), letterSpacing: 0.3);

  InputDecoration _inputDecoration({String hint = ''}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFFB6B4AC)),
      filled: true,
      fillColor: const Color(0xFFFAFAF8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1A000000))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1A000000))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5)),
    );
  }
}
