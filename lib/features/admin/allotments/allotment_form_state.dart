import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Predefined standard garment size presets (matching web)
class SizePreset {
  final String key;
  final String label;
  final List<String> sizes;

  const SizePreset({
    required this.key,
    required this.label,
    required this.sizes,
  });

  static const List<SizePreset> presets = [
    SizePreset(
      key: 'alpha',
      label: 'Adult Alpha (XS-4XL)',
      sizes: ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', '4XL'],
    ),
    SizePreset(
      key: 'numeric',
      label: 'Jeans / Numeric (28-44)',
      sizes: ['28', '30', '32', '34', '36', '38', '40', '42', '44'],
    ),
    SizePreset(
      key: 'kids_age',
      label: 'Kids Age (0M-16Y)',
      sizes: ['0-6M', '6-12M', '1-2Y', '2-3Y', '4-5Y', '6-7Y', '8-9Y', '10-12Y', '14-16Y'],
    ),
    SizePreset(
      key: 'kids_num',
      label: 'Kids Numbers (16-34)',
      sizes: ['16', '18', '20', '22', '24', '26', '28', '30', '32', '34'],
    ),
    SizePreset(
      key: 'free_size',
      label: 'Universal (Free Size)',
      sizes: ['Free Size'],
    ),
  ];
}

/// Represents a single color row in the size-color matrix
class ColorMatrixRow {
  final String id;
  String color;
  Map<String, int> quantities; // size -> qty

  ColorMatrixRow({
    required this.id,
    required this.color,
    Map<String, int>? quantities,
  }) : quantities = quantities ?? {};

  int get rowTotal => quantities.values.fold(0, (sum, q) => sum + q);

  ColorMatrixRow copyWith({
    String? id,
    String? color,
    Map<String, int>? quantities,
  }) {
    return ColorMatrixRow(
      id: id ?? this.id,
      color: color ?? this.color,
      quantities: quantities != null ? Map<String, int>.from(quantities) : Map<String, int>.from(this.quantities),
    );
  }
}

/// Represents an item in the raw materials / accessories checklist (BOM)
class BomItem {
  final String id;
  String itemName;
  String requiredQty;
  bool adminIssued;
  String source; // 'CLIENT' | 'FACTORY_STORE'

  BomItem({
    required this.id,
    required this.itemName,
    required this.requiredQty,
    this.adminIssued = false,
    this.source = 'CLIENT',
  });

  BomItem copyWith({
    String? id,
    String? itemName,
    String? requiredQty,
    bool? adminIssued,
    String? source,
  }) {
    return BomItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      requiredQty: requiredQty ?? this.requiredQty,
      adminIssued: adminIssued ?? this.adminIssued,
      source: source ?? this.source,
    );
  }
}

/// Complete form state for the 3-step allotment creation process
class AllotmentFormData {
  // Step 1: Lineman & Target metadata
  String managerName;
  String? linemanId;
  String? linemanName;
  String? articleId;
  String? articleNo;
  String? articleDesc;
  String? challanId;
  String? challanNo;
  String? brand;
  String? fabricType;
  String priority; // 'NORMAL' | 'RUSH' | 'CRITICAL'
  DateTime dueDate;
  int targetHours;
  String clientChallanNo;
  List<String> samplePhotos;

  // Step 2: Size & Color Ratio Matrix
  String activePreset;
  List<String> selectedSizes;
  List<ColorMatrixRow> colorRows;

  // Step 3: Raw Materials Checklist (BOM)
  List<BomItem> materials;

  AllotmentFormData({
    this.managerName = 'Production Manager',
    this.linemanId,
    this.linemanName,
    this.articleId,
    this.articleNo,
    this.articleDesc,
    this.challanId,
    this.challanNo,
    this.brand,
    this.fabricType,
    this.priority = 'NORMAL',
    DateTime? dueDate,
    this.targetHours = 16,
    this.clientChallanNo = '',
    List<String>? samplePhotos,
    this.activePreset = 'alpha',
    List<String>? selectedSizes,
    List<ColorMatrixRow>? colorRows,
    List<BomItem>? materials,
  })  : dueDate = dueDate ?? DateTime.now().add(const Duration(days: 7)),
        samplePhotos = samplePhotos ?? [],
        selectedSizes = selectedSizes ?? ['S', 'M', 'L', 'XL'],
        colorRows = colorRows ?? [
          ColorMatrixRow(
            id: '1',
            color: 'Standard Color',
            quantities: {'S': 0, 'M': 0, 'L': 0, 'XL': 0},
          )
        ],
        materials = materials ?? [];

  /// Calculate grand total target pieces across all colors and sizes
  int get totalPieces {
    int sum = 0;
    for (var r in colorRows) {
      for (var size in selectedSizes) {
        sum += (r.quantities[size] ?? 0);
      }
    }
    return sum;
  }

  /// Estimated pieces per hour PPC rate
  double get pcsPerHour {
    if (targetHours <= 0) return 0;
    return (totalPieces / targetHours);
  }

  /// Estimated pieces per 8-hour shift PPC rate
  double get pcsPerShift {
    if (targetHours <= 0) return 0;
    return (totalPieces / targetHours) * 8;
  }

  bool get isStep1Valid {
    return (linemanId != null && linemanId!.isNotEmpty) &&
        (articleId != null && articleId!.isNotEmpty);
  }

  bool get isStep2Valid {
    return selectedSizes.isNotEmpty && totalPieces > 0;
  }

  /// Generate auto-calculated BOM matching the Web Admin algorithm
  void autoGenerateBom() {
    final total = totalPieces;
    final List<BomItem> list = [];
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Fabric Lot (Client)
    final fabName = (fabricType != null && fabricType!.isNotEmpty)
        ? '$fabricType Fabric Lot'
        : 'Fabric Lot (As per marker)';
    list.add(BomItem(
      id: 'fab_${now}_1',
      itemName: fabName,
      requiredQty: 'As per roll marker',
      adminIssued: false,
      source: 'CLIENT',
    ));

    // 2. Sewing Thread Cones (Factory Store) - 1 cone per 250 pcs, min 4
    final threadCones = (total > 0) ? (total / 250).ceil() : 4;
    final minThread = threadCones < 4 ? 4 : threadCones;
    list.add(BomItem(
      id: 'thr_${now}_2',
      itemName: 'Matching Sewing Thread Cones',
      requiredQty: '$minThread Cones',
      adminIssued: false,
      source: 'FACTORY_STORE',
    ));

    // 3. Brand Main Neck Labels (Client)
    final brandLabel = (brand != null && brand!.isNotEmpty) ? '$brand Main Neck Labels' : 'Main Neck Labels';
    list.add(BomItem(
      id: 'lbl_${now}_3',
      itemName: brandLabel,
      requiredQty: total > 0 ? '$total pcs' : 'As required',
      adminIssued: false,
      source: 'CLIENT',
    ));

    // 4. Size Labels (Client)
    final sizesListStr = selectedSizes.isNotEmpty ? selectedSizes.join(', ') : 'All Sizes';
    list.add(BomItem(
      id: 'sz_${now}_4',
      itemName: 'Size Labels ($sizesListStr)',
      requiredQty: total > 0 ? '$total pcs' : 'As required',
      adminIssued: false,
      source: 'CLIENT',
    ));

    // 5. Master Polybags (Client)
    list.add(BomItem(
      id: 'poly_${now}_5',
      itemName: 'Master Polybags (Packaging)',
      requiredQty: total > 0 ? '$total pcs' : 'As required',
      adminIssued: false,
      source: 'CLIENT',
    ));

    materials = list;
  }
}

/// Riverpod StateNotifier for managing the multi-step form state
class AllotmentFormNotifier extends StateNotifier<AllotmentFormData> {
  AllotmentFormNotifier() : super(AllotmentFormData());

  void setManagerName(String name) {
    state.managerName = name;
    _notify();
  }

  void setLineman(String id, String name) {
    state.linemanId = id;
    state.linemanName = name;
    _notify();
  }

  void setArticle({
    required String articleId,
    required String articleNo,
    String? articleDesc,
    String? challanId,
    String? challanNo,
    String? brand,
    String? fabricType,
  }) {
    state.articleId = articleId;
    state.articleNo = articleNo;
    state.articleDesc = articleDesc;
    state.challanId = challanId;
    state.challanNo = challanNo;
    state.brand = brand;
    state.fabricType = fabricType;
    if (challanNo != null && challanNo.isNotEmpty) {
      final cRef = challanNo.startsWith('JOB-') ? challanNo : 'JOB-$challanNo';
      state.clientChallanNo = cRef;
    }
    _notify();
  }

  void setPriority(String p) {
    state.priority = p;
    _notify();
  }

  void setDueDate(DateTime dt) {
    state.dueDate = dt;
    _notify();
  }

  void setTargetHours(int hours) {
    state.targetHours = hours;
    _notify();
  }

  void setClientChallanNo(String no) {
    state.clientChallanNo = no;
    _notify();
  }

  void setSamplePhotos(List<String> photos) {
    state.samplePhotos = photos;
    _notify();
  }

  void setPreset(String presetKey) {
    final found = SizePreset.presets.firstWhere(
      (p) => p.key == presetKey,
      orElse: () => SizePreset.presets.first,
    );
    state.activePreset = found.key;
    state.selectedSizes = List<String>.from(found.sizes);

    // Update quantities map for all existing color rows
    for (var r in state.colorRows) {
      for (var s in state.selectedSizes) {
        r.quantities.putIfAbsent(s, () => 0);
      }
    }
    _notify();
  }

  void addCustomSize(String size) {
    final clean = size.trim().toUpperCase();
    if (clean.isNotEmpty && !state.selectedSizes.contains(clean)) {
      state.selectedSizes.add(clean);
      for (var r in state.colorRows) {
        r.quantities[clean] = 0;
      }
      _notify();
    }
  }

  void removeSize(String size) {
    state.selectedSizes.remove(size);
    for (var r in state.colorRows) {
      r.quantities.remove(size);
    }
    _notify();
  }

  void addColorRow([String? colorName]) {
    final nextId = (state.colorRows.length + 1).toString();
    final row = ColorMatrixRow(
      id: nextId,
      color: colorName ?? 'Color $nextId',
      quantities: {for (var s in state.selectedSizes) s: 0},
    );
    state.colorRows.add(row);
    _notify();
  }

  void removeColorRow(String id) {
    if (state.colorRows.length > 1) {
      state.colorRows.removeWhere((r) => r.id == id);
      _notify();
    }
  }

  void updateColorName(String id, String newName) {
    final idx = state.colorRows.indexWhere((r) => r.id == id);
    if (idx != -1) {
      state.colorRows[idx].color = newName;
      _notify();
    }
  }

  void updateQuantity(String rowId, String size, int qty) {
    final idx = state.colorRows.indexWhere((r) => r.id == rowId);
    if (idx != -1) {
      state.colorRows[idx].quantities[size] = qty < 0 ? 0 : qty;
      _notify();
    }
  }

  void setCustomColorRows(List<ColorMatrixRow> rows) {
    state.colorRows = rows;
    _notify();
  }

  void setSelectedSizes(List<String> sizes) {
    state.selectedSizes = sizes;
    _notify();
  }

  void autoGenerateBom() {
    state.autoGenerateBom();
    _notify();
  }

  void addMaterialItem(BomItem item) {
    state.materials.add(item);
    _notify();
  }

  void removeMaterialItem(String id) {
    state.materials.removeWhere((m) => m.id == id);
    _notify();
  }

  void toggleMaterialSource(String id) {
    final idx = state.materials.indexWhere((m) => m.id == id);
    if (idx != -1) {
      state.materials[idx].source =
          state.materials[idx].source == 'CLIENT' ? 'FACTORY_STORE' : 'CLIENT';
      _notify();
    }
  }

  void reset() {
    state = AllotmentFormData();
  }

  void _notify() {
    state = AllotmentFormData(
      managerName: state.managerName,
      linemanId: state.linemanId,
      linemanName: state.linemanName,
      articleId: state.articleId,
      articleNo: state.articleNo,
      articleDesc: state.articleDesc,
      challanId: state.challanId,
      challanNo: state.challanNo,
      brand: state.brand,
      fabricType: state.fabricType,
      priority: state.priority,
      dueDate: state.dueDate,
      targetHours: state.targetHours,
      clientChallanNo: state.clientChallanNo,
      samplePhotos: List<String>.from(state.samplePhotos),
      activePreset: state.activePreset,
      selectedSizes: List<String>.from(state.selectedSizes),
      colorRows: state.colorRows.map((r) => r.copyWith()).toList(),
      materials: state.materials.map((m) => m.copyWith()).toList(),
    );
  }
}

final allotmentFormProvider =
    StateNotifierProvider<AllotmentFormNotifier, AllotmentFormData>((ref) {
  return AllotmentFormNotifier();
});
