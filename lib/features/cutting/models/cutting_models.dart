class CuttingWorker {
  final String id;
  final String? workerUserId;
  final String workerName;
  final String phoneNumber;
  final String? workerEmail;
  final List<String> roles;
  final String role;
  final String status;
  final int assignedPieces;
  final int completedPieces;
  final String? companyName;
  final String createdAt;
  final String? updatedAt;

  const CuttingWorker({
    required this.id,
    this.workerUserId,
    required this.workerName,
    required this.phoneNumber,
    this.workerEmail,
    this.roles = const ['KNIFE_CUTTER'],
    this.role = 'Knife Cutter',
    this.status = 'ACTIVE',
    this.assignedPieces = 0,
    this.completedPieces = 0,
    this.companyName,
    required this.createdAt,
    this.updatedAt,
  });

  CuttingWorker copyWith({
    String? id,
    String? workerUserId,
    String? workerName,
    String? phoneNumber,
    String? workerEmail,
    List<String>? roles,
    String? role,
    String? status,
    int? assignedPieces,
    int? completedPieces,
    String? companyName,
    String? createdAt,
    String? updatedAt,
  }) {
    return CuttingWorker(
      id: id ?? this.id,
      workerUserId: workerUserId ?? this.workerUserId,
      workerName: workerName ?? this.workerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      workerEmail: workerEmail ?? this.workerEmail,
      roles: roles ?? this.roles,
      role: role ?? this.role,
      status: status ?? this.status,
      assignedPieces: assignedPieces ?? this.assignedPieces,
      completedPieces: completedPieces ?? this.completedPieces,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CuttingWorker.fromJson(Map<String, dynamic> json) {
    List<String> parsedRoles = [];
    if (json['roles'] is List) {
      parsedRoles = (json['roles'] as List).map((e) => e.toString()).toList();
    } else if (json['role'] != null) {
      parsedRoles = [json['role'].toString()];
    }
    if (parsedRoles.isEmpty) parsedRoles = ['KNIFE_CUTTER'];

    final roleLabel = json['role']?.toString() ??
        parsedRoles.map((r) => r.replaceAll('_', ' ')).join(', ');

    return CuttingWorker(
      id: json['id']?.toString() ?? '',
      workerUserId: json['worker_user_id']?.toString(),
      workerName: json['worker_name']?.toString() ?? 'Worker',
      phoneNumber: json['phone_number']?.toString() ?? '',
      workerEmail: json['worker_email']?.toString(),
      roles: parsedRoles,
      role: roleLabel,
      status: json['status']?.toString() ?? 'ACTIVE',
      assignedPieces: (json['assigned_pieces'] as num?)?.toInt() ?? 0,
      completedPieces: (json['completed_pieces'] as num?)?.toInt() ?? 0,
      companyName: json['company_name']?.toString(),
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (workerUserId != null) 'worker_user_id': workerUserId,
      'worker_name': workerName,
      'phone_number': phoneNumber,
      if (workerEmail != null) 'worker_email': workerEmail,
      'roles': roles,
      'role': role,
      'status': status,
      'assigned_pieces': assignedPieces,
      'completed_pieces': completedPieces,
      if (companyName != null) 'company_name': companyName,
      'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }
}

class CuttingTaskAllocation {
  final String id;
  final String taskRef;
  final String? buyerId;
  final String buyerName;
  final String articleNumber;
  final String articleName;
  final String workerId;
  final String workerName;
  final String? workerPhone;
  final String tableNumber;
  final int piecesToCut;
  final int completedPieces;
  final double allotedHours;
  final String? dueTime;
  final String? startedAt;
  final String? completedAt;
  final String? notes;
  final String status; // 'ASSIGNED', 'IN_PROGRESS', 'WORKER_COMPLETED', 'VERIFIED_COMPLETED', 'COMPLETED'
  final String? companyName;
  final String createdAt;
  final String? updatedAt;

  const CuttingTaskAllocation({
    required this.id,
    required this.taskRef,
    this.buyerId,
    required this.buyerName,
    required this.articleNumber,
    required this.articleName,
    required this.workerId,
    required this.workerName,
    this.workerPhone,
    this.tableNumber = 'Table 01',
    required this.piecesToCut,
    this.completedPieces = 0,
    this.allotedHours = 4.0,
    this.dueTime,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.status = 'ASSIGNED',
    this.companyName,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isCompleted => status == 'VERIFIED_COMPLETED' || status == 'COMPLETED';
  bool get isWorkerCompleted => status == 'WORKER_COMPLETED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isAssigned => status == 'ASSIGNED';

  CuttingTaskAllocation copyWith({
    String? id,
    String? taskRef,
    String? buyerId,
    String? buyerName,
    String? articleNumber,
    String? articleName,
    String? workerId,
    String? workerName,
    String? workerPhone,
    String? tableNumber,
    int? piecesToCut,
    int? completedPieces,
    double? allotedHours,
    String? dueTime,
    String? startedAt,
    String? completedAt,
    String? notes,
    String? status,
    String? companyName,
    String? createdAt,
    String? updatedAt,
  }) {
    return CuttingTaskAllocation(
      id: id ?? this.id,
      taskRef: taskRef ?? this.taskRef,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      articleNumber: articleNumber ?? this.articleNumber,
      articleName: articleName ?? this.articleName,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      workerPhone: workerPhone ?? this.workerPhone,
      tableNumber: tableNumber ?? this.tableNumber,
      piecesToCut: piecesToCut ?? this.piecesToCut,
      completedPieces: completedPieces ?? this.completedPieces,
      allotedHours: allotedHours ?? this.allotedHours,
      dueTime: dueTime ?? this.dueTime,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CuttingTaskAllocation.fromJson(Map<String, dynamic> json) {
    return CuttingTaskAllocation(
      id: json['id']?.toString() ?? '',
      taskRef: json['task_ref']?.toString() ?? 'TSK-${DateTime.now().millisecondsSinceEpoch % 10000}',
      buyerId: json['buyer_id']?.toString(),
      buyerName: json['buyer_name']?.toString() ?? 'Direct Buyer',
      articleNumber: json['article_number']?.toString() ?? 'ART-01',
      articleName: json['article_name']?.toString() ?? 'Garment Article',
      workerId: json['worker_id']?.toString() ?? '',
      workerName: json['worker_name']?.toString() ?? 'Assigned Worker',
      workerPhone: json['worker_phone']?.toString(),
      tableNumber: json['table_number']?.toString() ?? 'Table 01',
      piecesToCut: (json['pieces_to_cut'] as num?)?.toInt() ?? 0,
      completedPieces: (json['completed_pieces'] as num?)?.toInt() ?? 0,
      allotedHours: (json['alloted_hours'] as num?)?.toDouble() ?? 4.0,
      dueTime: json['due_time']?.toString(),
      startedAt: json['started_at']?.toString(),
      completedAt: json['completed_at']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? 'ASSIGNED',
      companyName: json['company_name']?.toString(),
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_ref': taskRef,
      if (buyerId != null) 'buyer_id': buyerId,
      'buyer_name': buyerName,
      'article_number': articleNumber,
      'article_name': articleName,
      'worker_id': workerId,
      'worker_name': workerName,
      if (workerPhone != null) 'worker_phone': workerPhone,
      'table_number': tableNumber,
      'pieces_to_cut': piecesToCut,
      'completed_pieces': completedPieces,
      'alloted_hours': allotedHours,
      if (dueTime != null) 'due_time': dueTime,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (notes != null) 'notes': notes,
      'status': status,
      if (companyName != null) 'company_name': companyName,
      'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }
}

class ManufacturingRouteOption {
  final String value;
  final String shortLabel;
  final String flowDescription;

  const ManufacturingRouteOption({
    required this.value,
    required this.shortLabel,
    required this.flowDescription,
  });
}

const List<ManufacturingRouteOption> allManufacturingRoutes = [
  ManufacturingRouteOption(
    value: 'PRINT_FIRST_THEN_EMBROIDERY',
    shortLabel: 'Print First -> Embroidery',
    flowDescription: 'Cutting -> Screen Print -> Embroidery -> Stitching',
  ),
  ManufacturingRouteOption(
    value: 'EMBROIDERY_FIRST_THEN_PRINT',
    shortLabel: 'Embroidery First -> Print',
    flowDescription: 'Cutting -> Embroidery -> Screen Print -> Stitching',
  ),
  ManufacturingRouteOption(
    value: 'ONLY_PRINTING',
    shortLabel: 'Printing Only',
    flowDescription: 'Cutting -> Screen Printing -> Stitching',
  ),
  ManufacturingRouteOption(
    value: 'ONLY_EMBROIDERY',
    shortLabel: 'Embroidery Only',
    flowDescription: 'Cutting -> Multi-Head Embroidery -> Stitching',
  ),
  ManufacturingRouteOption(
    value: 'NONE',
    shortLabel: 'Cut & Sew (No Print/Emb)',
    flowDescription: 'Direct cutting to stitching line',
  ),
];

// ==========================================
// LAY SHEET MODEL
// ==========================================
class LaySheet {
  final String id;
  final String layNumber;
  final String poNumber;
  final String brandName;
  final String styleRef;
  final String styleName;
  final String tableNumber;
  final List<String> fabricRollBarcodes;
  final String shellFabric;
  final int gsm;
  final int pliesCount;
  final double markerLengthMeters;
  final int totalCutPieces;
  final String ratioBreakdown;
  final double fabricWeightKg;
  final String cuttingMaster;
  final String status; // 'SPREADING', 'READY_FOR_CUT', 'CUT_IN_PROGRESS', 'CUT_COMPLETED', 'BUNDLED'
  final String createdAt;

  const LaySheet({
    required this.id,
    required this.layNumber,
    required this.poNumber,
    required this.brandName,
    required this.styleRef,
    required this.styleName,
    required this.tableNumber,
    required this.fabricRollBarcodes,
    required this.shellFabric,
    this.gsm = 380,
    required this.pliesCount,
    required this.markerLengthMeters,
    required this.totalCutPieces,
    required this.ratioBreakdown,
    this.fabricWeightKg = 45.0,
    this.cuttingMaster = 'In-House Cutting Master',
    this.status = 'SPREADING',
    required this.createdAt,
  });

  LaySheet copyWith({
    String? id,
    String? layNumber,
    String? poNumber,
    String? brandName,
    String? styleRef,
    String? styleName,
    String? tableNumber,
    List<String>? fabricRollBarcodes,
    String? shellFabric,
    int? gsm,
    int? pliesCount,
    double? markerLengthMeters,
    int? totalCutPieces,
    String? ratioBreakdown,
    double? fabricWeightKg,
    String? cuttingMaster,
    String? status,
    String? createdAt,
  }) {
    return LaySheet(
      id: id ?? this.id,
      layNumber: layNumber ?? this.layNumber,
      poNumber: poNumber ?? this.poNumber,
      brandName: brandName ?? this.brandName,
      styleRef: styleRef ?? this.styleRef,
      styleName: styleName ?? this.styleName,
      tableNumber: tableNumber ?? this.tableNumber,
      fabricRollBarcodes: fabricRollBarcodes ?? this.fabricRollBarcodes,
      shellFabric: shellFabric ?? this.shellFabric,
      gsm: gsm ?? this.gsm,
      pliesCount: pliesCount ?? this.pliesCount,
      markerLengthMeters: markerLengthMeters ?? this.markerLengthMeters,
      totalCutPieces: totalCutPieces ?? this.totalCutPieces,
      ratioBreakdown: ratioBreakdown ?? this.ratioBreakdown,
      fabricWeightKg: fabricWeightKg ?? this.fabricWeightKg,
      cuttingMaster: cuttingMaster ?? this.cuttingMaster,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory LaySheet.fromJson(Map<String, dynamic> json) {
    List<String> rollCodes = [];
    if (json['fabric_roll_barcodes'] is List) {
      rollCodes = (json['fabric_roll_barcodes'] as List).map((e) => e.toString()).toList();
    } else if (json['fabric_roll_barcodes'] is String) {
      rollCodes = (json['fabric_roll_barcodes'] as String).split(',').map((s) => s.trim()).toList();
    }

    return LaySheet(
      id: json['id']?.toString() ?? '',
      layNumber: json['lay_number']?.toString() ?? json['lay_sheet_number']?.toString() ?? 'LAY-NEW',
      poNumber: json['po_number']?.toString() ?? 'PO-PENDING',
      brandName: json['brand_name']?.toString() ?? 'Primary Factory',
      styleRef: json['style_ref']?.toString() ?? 'N/A',
      styleName: json['style_name']?.toString() ?? 'Standard Garment',
      tableNumber: json['table_number']?.toString() ?? json['cutting_table_id']?.toString() ?? 'Table 01',
      fabricRollBarcodes: rollCodes,
      shellFabric: json['shell_fabric']?.toString() ?? 'Standard Fabric',
      gsm: (json['gsm'] as num?)?.toInt() ?? 380,
      pliesCount: (json['plies_count'] as num?)?.toInt() ?? (json['total_plies'] as num?)?.toInt() ?? 80,
      markerLengthMeters: (json['marker_length_meters'] as num?)?.toDouble() ?? (json['marker_length_m'] as num?)?.toDouble() ?? 5.0,
      totalCutPieces: (json['total_cut_pieces'] as num?)?.toInt() ?? (json['expected_pieces'] as num?)?.toInt() ?? 1000,
      ratioBreakdown: json['ratio_breakdown']?.toString() ?? json['size_ratio_text']?.toString() ?? 'S:1, M:2, L:2, XL:1',
      fabricWeightKg: (json['fabric_weight_kg'] as num?)?.toDouble() ?? 45.0,
      cuttingMaster: json['cutting_master']?.toString() ?? 'In-House Cutting Master',
      status: json['status']?.toString() ?? 'SPREADING',
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lay_number': layNumber,
      'po_number': poNumber,
      'brand_name': brandName,
      'style_ref': styleRef,
      'style_name': styleName,
      'table_number': tableNumber,
      'fabric_roll_barcodes': fabricRollBarcodes,
      'shell_fabric': shellFabric,
      'gsm': gsm,
      'plies_count': pliesCount,
      'marker_length_meters': markerLengthMeters,
      'total_cut_pieces': totalCutPieces,
      'ratio_breakdown': ratioBreakdown,
      'fabric_weight_kg': fabricWeightKg,
      'cutting_master': cuttingMaster,
      'status': status,
      'created_at': createdAt,
    };
  }
}

// ==========================================
// CUT BUNDLE MODEL
// ==========================================
class CutBundle {
  final String id;
  final String bundleNumber;
  final String laySheetId;
  final String layNumber;
  final String poNumber;
  final String styleRef;
  final String styleName;
  final String color;
  final String size;
  final int plyRangeStart;
  final int plyRangeEnd;
  final int piecesCount;
  final String qrCode;
  final String destination; // '04_PRINTING', '05_EMBROIDERY', '06_SEWING'
  final String status; // 'GENERATED', 'BANDED', 'IN_TRANSIT', 'HANDOVER_CONFIRMED'
  final String createdAt;

  const CutBundle({
    required this.id,
    required this.bundleNumber,
    this.laySheetId = '',
    required this.layNumber,
    required this.poNumber,
    required this.styleRef,
    required this.styleName,
    required this.color,
    required this.size,
    required this.plyRangeStart,
    required this.plyRangeEnd,
    required this.piecesCount,
    required this.qrCode,
    this.destination = '06_SEWING',
    this.status = 'GENERATED',
    required this.createdAt,
  });

  CutBundle copyWith({
    String? id,
    String? bundleNumber,
    String? laySheetId,
    String? layNumber,
    String? poNumber,
    String? styleRef,
    String? styleName,
    String? color,
    String? size,
    int? plyRangeStart,
    int? plyRangeEnd,
    int? piecesCount,
    String? qrCode,
    String? destination,
    String? status,
    String? createdAt,
  }) {
    return CutBundle(
      id: id ?? this.id,
      bundleNumber: bundleNumber ?? this.bundleNumber,
      laySheetId: laySheetId ?? this.laySheetId,
      layNumber: layNumber ?? this.layNumber,
      poNumber: poNumber ?? this.poNumber,
      styleRef: styleRef ?? this.styleRef,
      styleName: styleName ?? this.styleName,
      color: color ?? this.color,
      size: size ?? this.size,
      plyRangeStart: plyRangeStart ?? this.plyRangeStart,
      plyRangeEnd: plyRangeEnd ?? this.plyRangeEnd,
      piecesCount: piecesCount ?? this.piecesCount,
      qrCode: qrCode ?? this.qrCode,
      destination: destination ?? this.destination,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CutBundle.fromJson(Map<String, dynamic> json) {
    return CutBundle(
      id: json['id']?.toString() ?? '',
      bundleNumber: json['bundle_number']?.toString() ?? json['bundle_barcode']?.toString() ?? 'BND-NEW',
      laySheetId: json['lay_sheet_id']?.toString() ?? '',
      layNumber: json['lay_number']?.toString() ?? 'LAY-SHEET',
      poNumber: json['po_number']?.toString() ?? 'PO-PENDING',
      styleRef: json['style_ref']?.toString() ?? 'N/A',
      styleName: json['style_name']?.toString() ?? 'Standard Garment',
      color: json['color']?.toString() ?? json['color_name']?.toString() ?? 'Navy',
      size: json['size']?.toString() ?? json['size_label']?.toString() ?? 'M',
      plyRangeStart: (json['ply_range_start'] as num?)?.toInt() ?? (json['start_ply_num'] as num?)?.toInt() ?? 1,
      plyRangeEnd: (json['ply_range_end'] as num?)?.toInt() ?? (json['end_ply_num'] as num?)?.toInt() ?? 25,
      piecesCount: (json['pieces_count'] as num?)?.toInt() ?? (json['piece_count'] as num?)?.toInt() ?? 25,
      qrCode: json['qr_code']?.toString() ?? json['bundle_barcode']?.toString() ?? 'BND-QR',
      destination: json['destination']?.toString() ?? json['current_division']?.toString() ?? '06_SEWING',
      status: json['status']?.toString() == 'CUT_COMPLETED' ? 'GENERATED' : (json['status']?.toString() ?? 'GENERATED'),
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bundle_number': bundleNumber,
      'lay_sheet_id': laySheetId,
      'lay_number': layNumber,
      'po_number': poNumber,
      'style_ref': styleRef,
      'style_name': styleName,
      'color': color,
      'size': size,
      'ply_range_start': plyRangeStart,
      'ply_range_end': plyRangeEnd,
      'pieces_count': piecesCount,
      'qr_code': qrCode,
      'destination': destination,
      'status': status,
      'created_at': createdAt,
    };
  }
}

// ==========================================
// CAD MARKER EFFICIENCY MODEL
// ==========================================
class MarkerEfficiency {
  final String id;
  final String markerName;
  final String markerRef;
  final String styleRef;
  final String styleName;
  final String cadSoftware;
  final double fabricWidthInches;
  final double markerLengthMeters;
  final double efficiencyPercent;
  final List<String> sizesIncluded;
  final String ratio;
  final String patternMaster;
  final String status;
  final String createdAt;

  const MarkerEfficiency({
    required this.id,
    required this.markerName,
    this.markerRef = '',
    required this.styleRef,
    this.styleName = 'Garment Style',
    this.cadSoftware = 'GERBER_ACCUMARK',
    this.fabricWidthInches = 60.0,
    this.markerLengthMeters = 5.4,
    this.efficiencyPercent = 89.6,
    this.sizesIncluded = const ['S', 'M', 'L', 'XL'],
    this.ratio = '1:2:2:1 (Ratio: 6)',
    this.patternMaster = 'R. Veerappan (Master Cutter)',
    this.status = 'CAD_APPROVED',
    required this.createdAt,
  });

  MarkerEfficiency copyWith({
    String? id,
    String? markerName,
    String? markerRef,
    String? styleRef,
    String? styleName,
    String? cadSoftware,
    double? fabricWidthInches,
    double? markerLengthMeters,
    double? efficiencyPercent,
    List<String>? sizesIncluded,
    String? ratio,
    String? patternMaster,
    String? status,
    String? createdAt,
  }) {
    return MarkerEfficiency(
      id: id ?? this.id,
      markerName: markerName ?? this.markerName,
      markerRef: markerRef ?? this.markerRef,
      styleRef: styleRef ?? this.styleRef,
      styleName: styleName ?? this.styleName,
      cadSoftware: cadSoftware ?? this.cadSoftware,
      fabricWidthInches: fabricWidthInches ?? this.fabricWidthInches,
      markerLengthMeters: markerLengthMeters ?? this.markerLengthMeters,
      efficiencyPercent: efficiencyPercent ?? this.efficiencyPercent,
      sizesIncluded: sizesIncluded ?? this.sizesIncluded,
      ratio: ratio ?? this.ratio,
      patternMaster: patternMaster ?? this.patternMaster,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory MarkerEfficiency.fromJson(Map<String, dynamic> json) {
    List<String> sizes = [];
    if (json['sizes_included'] is List) {
      sizes = (json['sizes_included'] as List).map((e) => e.toString()).toList();
    } else if (json['sizes_included'] is String) {
      sizes = (json['sizes_included'] as String).split(',').map((s) => s.trim()).toList();
    }

    return MarkerEfficiency(
      id: json['id']?.toString() ?? '',
      markerName: json['marker_name']?.toString() ?? json['marker_ref']?.toString() ?? 'MKR-CAD-01',
      markerRef: json['marker_ref']?.toString() ?? '',
      styleRef: json['style_ref']?.toString() ?? 'STY-01',
      styleName: json['style_name']?.toString() ?? 'Standard Garment',
      cadSoftware: json['cad_software']?.toString() ?? 'GERBER_ACCUMARK',
      fabricWidthInches: (json['fabric_width_inches'] as num?)?.toDouble() ?? 60.0,
      markerLengthMeters: (json['marker_length_meters'] as num?)?.toDouble() ?? 5.4,
      efficiencyPercent: (json['efficiency_percent'] as num?)?.toDouble() ?? 88.5,
      sizesIncluded: sizes.isNotEmpty ? sizes : ['S', 'M', 'L', 'XL'],
      ratio: json['ratio']?.toString() ?? '1:2:2:1 (Ratio: 6)',
      patternMaster: json['pattern_master']?.toString() ?? 'R. Veerappan (Master Cutter)',
      status: json['status']?.toString() ?? 'CAD_APPROVED',
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'marker_name': markerName,
      'marker_ref': markerRef,
      'style_ref': styleRef,
      'style_name': styleName,
      'cad_software': cadSoftware,
      'fabric_width_inches': fabricWidthInches,
      'marker_length_meters': markerLengthMeters,
      'efficiency_percent': efficiencyPercent,
      'sizes_included': sizesIncluded,
      'ratio': ratio,
      'pattern_master': patternMaster,
      'status': status,
      'created_at': createdAt,
    };
  }
}

// ==========================================
// CUTTING ORDER MODEL
// ==========================================
class CuttingOrder {
  final String id;
  final String orderNumber;
  final String buyerPo;
  final String buyerName;
  final String styleNumber;
  final String styleName;
  final String colorway;
  final int totalPieces;
  final int pliesPlanned;
  final double fabricMetersAllocated;
  final String tableAssigned;
  final String status; // 'QUEUED', 'SPREADING', 'CUTTING', 'INSPECTED', 'BUNDLED'
  final String priority; // 'NORMAL', 'HIGH', 'URGENT'
  final String scheduledStart;
  final String operatorLead;
  final String createdAt;

  const CuttingOrder({
    required this.id,
    required this.orderNumber,
    required this.buyerPo,
    required this.buyerName,
    required this.styleNumber,
    required this.styleName,
    required this.colorway,
    required this.totalPieces,
    required this.pliesPlanned,
    required this.fabricMetersAllocated,
    this.tableAssigned = 'Table 01 - Gerber Paragon HX',
    this.status = 'QUEUED',
    this.priority = 'HIGH',
    required this.scheduledStart,
    this.operatorLead = 'Cutting Master R. Veerappan',
    required this.createdAt,
  });

  CuttingOrder copyWith({
    String? id,
    String? orderNumber,
    String? buyerPo,
    String? buyerName,
    String? styleNumber,
    String? styleName,
    String? colorway,
    int? totalPieces,
    int? pliesPlanned,
    double? fabricMetersAllocated,
    String? tableAssigned,
    String? status,
    String? priority,
    String? scheduledStart,
    String? operatorLead,
    String? createdAt,
  }) {
    return CuttingOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      buyerPo: buyerPo ?? this.buyerPo,
      buyerName: buyerName ?? this.buyerName,
      styleNumber: styleNumber ?? this.styleNumber,
      styleName: styleName ?? this.styleName,
      colorway: colorway ?? this.colorway,
      totalPieces: totalPieces ?? this.totalPieces,
      pliesPlanned: pliesPlanned ?? this.pliesPlanned,
      fabricMetersAllocated: fabricMetersAllocated ?? this.fabricMetersAllocated,
      tableAssigned: tableAssigned ?? this.tableAssigned,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      operatorLead: operatorLead ?? this.operatorLead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CuttingOrder.fromJson(Map<String, dynamic> json) {
    return CuttingOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? 'CO-NEW',
      buyerPo: json['buyer_po']?.toString() ?? 'PO-PENDING',
      buyerName: json['buyer_name']?.toString() ?? 'Buyer',
      styleNumber: json['style_number']?.toString() ?? 'STY-01',
      styleName: json['style_name']?.toString() ?? 'Standard Garment',
      colorway: json['colorway']?.toString() ?? 'Standard',
      totalPieces: (json['total_pieces'] as num?)?.toInt() ?? 1000,
      pliesPlanned: (json['plies_planned'] as num?)?.toInt() ?? 80,
      fabricMetersAllocated: (json['fabric_meters_allocated'] as num?)?.toDouble() ?? 500.0,
      tableAssigned: json['table_assigned']?.toString() ?? 'Table 01 - Gerber Paragon HX',
      status: json['status']?.toString() ?? 'QUEUED',
      priority: json['priority']?.toString() ?? 'HIGH',
      scheduledStart: json['scheduled_start']?.toString() ?? '2026-09-25 08:00',
      operatorLead: json['operator_lead']?.toString() ?? 'Cutting Master R. Veerappan',
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'buyer_po': buyerPo,
      'buyer_name': buyerName,
      'style_number': styleNumber,
      'style_name': styleName,
      'colorway': colorway,
      'total_pieces': totalPieces,
      'plies_planned': pliesPlanned,
      'fabric_meters_allocated': fabricMetersAllocated,
      'table_assigned': tableAssigned,
      'status': status,
      'priority': priority,
      'scheduled_start': scheduledStart,
      'operator_lead': operatorLead,
      'created_at': createdAt,
    };
  }
}

// ==========================================
// STORE MATERIAL RECORD (RECEIPTS & ISSUES)
// ==========================================
class StoreChallanRecord {
  final String id;
  final String challanNumber;
  final String fromDivision;
  final String toDivision;
  final String articleNumber;
  final String buyerName;
  final String fabricType;
  final String color;
  final double quantity;
  final String unit;
  final int rollsCount;
  final double shortageQuantity;
  final String status; // 'PENDING', 'RECEIVED', 'ISSUED'
  final String receiverName;
  final String rackLocation;
  final String notes;
  final String createdAt;

  const StoreChallanRecord({
    required this.id,
    required this.challanNumber,
    required this.fromDivision,
    required this.toDivision,
    this.articleNumber = 'ART-01',
    this.buyerName = 'ZARA INTERNATIONAL',
    this.fabricType = '100% Cotton Fleece',
    this.color = 'Navy Blue',
    required this.quantity,
    this.unit = 'meters',
    this.rollsCount = 2,
    this.shortageQuantity = 0.0,
    this.status = 'PENDING',
    this.receiverName = '',
    this.rackLocation = 'FLOOR-STORE',
    this.notes = '',
    required this.createdAt,
  });

  StoreChallanRecord copyWith({
    String? id,
    String? challanNumber,
    String? fromDivision,
    String? toDivision,
    String? articleNumber,
    String? buyerName,
    String? fabricType,
    String? color,
    double? quantity,
    String? unit,
    int? rollsCount,
    double? shortageQuantity,
    String? status,
    String? receiverName,
    String? rackLocation,
    String? notes,
    String? createdAt,
  }) {
    return StoreChallanRecord(
      id: id ?? this.id,
      challanNumber: challanNumber ?? this.challanNumber,
      fromDivision: fromDivision ?? this.fromDivision,
      toDivision: toDivision ?? this.toDivision,
      articleNumber: articleNumber ?? this.articleNumber,
      buyerName: buyerName ?? this.buyerName,
      fabricType: fabricType ?? this.fabricType,
      color: color ?? this.color,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      rollsCount: rollsCount ?? this.rollsCount,
      shortageQuantity: shortageQuantity ?? this.shortageQuantity,
      status: status ?? this.status,
      receiverName: receiverName ?? this.receiverName,
      rackLocation: rackLocation ?? this.rackLocation,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory StoreChallanRecord.fromJson(Map<String, dynamic> json) {
    return StoreChallanRecord(
      id: json['id']?.toString() ?? '',
      challanNumber: json['challan_number']?.toString() ?? json['issue_number']?.toString() ?? 'CH-001',
      fromDivision: json['from_division']?.toString() ?? 'CENTRAL_STORE',
      toDivision: json['to_division']?.toString() ?? 'CUTTING',
      articleNumber: json['article_no']?.toString() ?? json['article_number']?.toString() ?? 'ART-01',
      buyerName: json['buyer_name']?.toString() ?? 'Direct Buyer',
      fabricType: json['fabric_type']?.toString() ?? '100% Combed Cotton',
      color: json['color']?.toString() ?? 'Navy',
      quantity: (json['quantity'] as num?)?.toDouble() ?? (json['received_quantity'] as num?)?.toDouble() ?? 500.0,
      unit: json['unit']?.toString() ?? 'meters',
      rollsCount: (json['rolls_count'] as num?)?.toInt() ?? 2,
      shortageQuantity: (json['shortage_quantity'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'PENDING',
      receiverName: json['receiver_name']?.toString() ?? '',
      rackLocation: json['rack_location']?.toString() ?? 'FLOOR-STORE',
      notes: json['notes']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challan_number': challanNumber,
      'from_division': fromDivision,
      'to_division': toDivision,
      'article_number': articleNumber,
      'buyer_name': buyerName,
      'fabric_type': fabricType,
      'color': color,
      'quantity': quantity,
      'unit': unit,
      'rolls_count': rollsCount,
      'shortage_quantity': shortageQuantity,
      'status': status,
      'receiver_name': receiverName,
      'rack_location': rackLocation,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}

// ==========================================
// NOTIFICATION MODEL
// ==========================================
class FloorNotification {
  final String id;
  final String title;
  final String message;
  final String timestamp;
  final bool isRead;
  final String type; // 'ORDER', 'MATERIAL', 'TASK', 'ALERT', 'AI'
  final String module;

  const FloorNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.type = 'TASK',
    this.module = 'cutting',
  });

  FloorNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? timestamp,
    bool? isRead,
    String? type,
    String? module,
  }) {
    return FloorNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      module: module ?? this.module,
    );
  }

  factory FloorNotification.fromJson(Map<String, dynamic> json) {
    return FloorNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? json['created_at']?.toString() ?? 'Just now',
      isRead: json['is_read'] == true || json['isRead'] == true,
      type: json['type']?.toString() ?? 'TASK',
      module: json['module']?.toString() ?? 'cutting',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'is_read': isRead,
      'type': type,
      'module': module,
    };
  }
}
