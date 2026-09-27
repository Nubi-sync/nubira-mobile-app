import 'package:flutter/foundation.dart';

@immutable
class ReadyGoodsWorker {
  final String id;
  final String workerName;
  final String phoneNumber;
  final String role; // 'Quality Auditor', 'Alteration Tailor', 'Polybag & Tagging Incharge', 'Master Carton Packer'
  final String shift;
  final String skillLevel; // 'Master', 'Senior', 'Certified'
  final bool isActive;
  final int completedPieces;
  final String? companyName;
  final DateTime? createdAt;

  const ReadyGoodsWorker({
    required this.id,
    required this.workerName,
    required this.phoneNumber,
    this.role = 'Quality Auditor (AQL Specialist)',
    this.shift = 'SHIFT_1',
    this.skillLevel = 'Certified',
    this.isActive = true,
    this.completedPieces = 0,
    this.companyName,
    this.createdAt,
  });

  ReadyGoodsWorker copyWith({
    String? id,
    String? workerName,
    String? phoneNumber,
    String? role,
    String? shift,
    String? skillLevel,
    bool? isActive,
    int? completedPieces,
    String? companyName,
    DateTime? createdAt,
  }) {
    return ReadyGoodsWorker(
      id: id ?? this.id,
      workerName: workerName ?? this.workerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      shift: shift ?? this.shift,
      skillLevel: skillLevel ?? this.skillLevel,
      isActive: isActive ?? this.isActive,
      completedPieces: completedPieces ?? this.completedPieces,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workerName': workerName,
        'phoneNumber': phoneNumber,
        'role': role,
        'shift': shift,
        'skillLevel': skillLevel,
        'isActive': isActive,
        'completedPieces': completedPieces,
        'companyName': companyName,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory ReadyGoodsWorker.fromJson(Map<String, dynamic> json) => ReadyGoodsWorker(
        id: json['id'] as String,
        workerName: json['workerName'] as String,
        phoneNumber: json['phoneNumber'] as String? ?? '',
        role: json['role'] as String? ?? 'Quality Auditor',
        shift: json['shift'] as String? ?? 'SHIFT_1',
        skillLevel: json['skillLevel'] as String? ?? 'Certified',
        isActive: json['isActive'] as bool? ?? true,
        completedPieces: (json['completedPieces'] as num?)?.toInt() ?? 0,
        companyName: json['companyName'] as String?,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      );
}

@immutable
class FinishingInspectionTask {
  final String id;
  final String taskRef;
  final String lotNumber;
  final String orderNumber;
  final String styleName;
  final String color;
  final String buyer;
  final String stage; // 'POST_WASH', 'POST_IRON', 'POST_PRINT', 'POST_EMBROIDERY', 'CUTTING_AUDIT'
  final int piecesCount;
  final int passedPieces;
  final int alterationPieces;
  final String? checkerName;
  final String status; // 'PENDING_CHECK', 'IN_CHECKING', 'REJECTED_TO_ALTERATION', 'PASSED_TO_PACKING', 'PACKED_IN_CARTON'
  final String priority; // 'NORMAL', 'RUSH', 'CRITICAL'
  final String? defectCategory;
  final String? defectRemarks;
  final String? companyName;
  final DateTime createdAt;

  const FinishingInspectionTask({
    required this.id,
    required this.taskRef,
    required this.lotNumber,
    required this.orderNumber,
    required this.styleName,
    this.color = 'Standard',
    required this.buyer,
    this.stage = 'POST_IRON',
    required this.piecesCount,
    this.passedPieces = 0,
    this.alterationPieces = 0,
    this.checkerName,
    this.status = 'PENDING_CHECK',
    this.priority = 'NORMAL',
    this.defectCategory,
    this.defectRemarks,
    this.companyName,
    required this.createdAt,
  });

  FinishingInspectionTask copyWith({
    String? id,
    String? taskRef,
    String? lotNumber,
    String? orderNumber,
    String? styleName,
    String? color,
    String? buyer,
    String? stage,
    int? piecesCount,
    int? passedPieces,
    int? alterationPieces,
    String? checkerName,
    String? status,
    String? priority,
    String? defectCategory,
    String? defectRemarks,
    String? companyName,
    DateTime? createdAt,
  }) {
    return FinishingInspectionTask(
      id: id ?? this.id,
      taskRef: taskRef ?? this.taskRef,
      lotNumber: lotNumber ?? this.lotNumber,
      orderNumber: orderNumber ?? this.orderNumber,
      styleName: styleName ?? this.styleName,
      color: color ?? this.color,
      buyer: buyer ?? this.buyer,
      stage: stage ?? this.stage,
      piecesCount: piecesCount ?? this.piecesCount,
      passedPieces: passedPieces ?? this.passedPieces,
      alterationPieces: alterationPieces ?? this.alterationPieces,
      checkerName: checkerName ?? this.checkerName,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      defectCategory: defectCategory ?? this.defectCategory,
      defectRemarks: defectRemarks ?? this.defectRemarks,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskRef': taskRef,
        'lotNumber': lotNumber,
        'orderNumber': orderNumber,
        'styleName': styleName,
        'color': color,
        'buyer': buyer,
        'stage': stage,
        'piecesCount': piecesCount,
        'passedPieces': passedPieces,
        'alterationPieces': alterationPieces,
        'checkerName': checkerName,
        'status': status,
        'priority': priority,
        'defectCategory': defectCategory,
        'defectRemarks': defectRemarks,
        'companyName': companyName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FinishingInspectionTask.fromJson(Map<String, dynamic> json) => FinishingInspectionTask(
        id: json['id'] as String,
        taskRef: json['taskRef'] as String? ?? 'QC-101',
        lotNumber: json['lotNumber'] as String? ?? 'LOT-001',
        orderNumber: json['orderNumber'] as String? ?? 'PO-7700',
        styleName: json['styleName'] as String? ?? 'Garment Style',
        color: json['color'] as String? ?? 'Standard',
        buyer: json['buyer'] as String? ?? 'Direct Buyer',
        stage: json['stage'] as String? ?? 'POST_IRON',
        piecesCount: (json['piecesCount'] as num?)?.toInt() ?? 0,
        passedPieces: (json['passedPieces'] as num?)?.toInt() ?? 0,
        alterationPieces: (json['alterationPieces'] as num?)?.toInt() ?? 0,
        checkerName: json['checkerName'] as String?,
        status: json['status'] as String? ?? 'PENDING_CHECK',
        priority: json['priority'] as String? ?? 'NORMAL',
        defectCategory: json['defectCategory'] as String?,
        defectRemarks: json['defectRemarks'] as String?,
        companyName: json['companyName'] as String?,
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      );
}

@immutable
class ReadyGoodsCarton {
  final String id;
  final String cartonNumber;
  final String orderNumber;
  final String buyer;
  final String styleName;
  final String color;
  final int totalPieces;
  final double measuredWeightKg;
  final double expectedWeightKg;
  final String status; // 'PACKED', 'AQL_PASSED', 'QUARANTINED', 'SHIPPED'
  final String godownBay; // 'BAY_3', 'BAY_4', 'BAY_5'
  final String sealedBy;
  final String? companyName;
  final DateTime createdAt;

  const ReadyGoodsCarton({
    required this.id,
    required this.cartonNumber,
    required this.orderNumber,
    required this.buyer,
    required this.styleName,
    this.color = 'Standard',
    required this.totalPieces,
    required this.measuredWeightKg,
    this.expectedWeightKg = 12.5,
    this.status = 'PACKED',
    this.godownBay = 'BAY_3',
    required this.sealedBy,
    this.companyName,
    required this.createdAt,
  });

  ReadyGoodsCarton copyWith({
    String? id,
    String? cartonNumber,
    String? orderNumber,
    String? buyer,
    String? styleName,
    String? color,
    int? totalPieces,
    double? measuredWeightKg,
    double? expectedWeightKg,
    String? status,
    String? godownBay,
    String? sealedBy,
    String? companyName,
    DateTime? createdAt,
  }) {
    return ReadyGoodsCarton(
      id: id ?? this.id,
      cartonNumber: cartonNumber ?? this.cartonNumber,
      orderNumber: orderNumber ?? this.orderNumber,
      buyer: buyer ?? this.buyer,
      styleName: styleName ?? this.styleName,
      color: color ?? this.color,
      totalPieces: totalPieces ?? this.totalPieces,
      measuredWeightKg: measuredWeightKg ?? this.measuredWeightKg,
      expectedWeightKg: expectedWeightKg ?? this.expectedWeightKg,
      status: status ?? this.status,
      godownBay: godownBay ?? this.godownBay,
      sealedBy: sealedBy ?? this.sealedBy,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cartonNumber': cartonNumber,
        'orderNumber': orderNumber,
        'buyer': buyer,
        'styleName': styleName,
        'color': color,
        'totalPieces': totalPieces,
        'measuredWeightKg': measuredWeightKg,
        'expectedWeightKg': expectedWeightKg,
        'status': status,
        'godownBay': godownBay,
        'sealedBy': sealedBy,
        'companyName': companyName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReadyGoodsCarton.fromJson(Map<String, dynamic> json) => ReadyGoodsCarton(
        id: json['id'] as String,
        cartonNumber: json['cartonNumber'] as String,
        orderNumber: json['orderNumber'] as String? ?? 'PO-7700',
        buyer: json['buyer'] as String? ?? 'Buyer',
        styleName: json['styleName'] as String? ?? 'Style',
        color: json['color'] as String? ?? 'Standard',
        totalPieces: (json['totalPieces'] as num?)?.toInt() ?? 0,
        measuredWeightKg: (json['measuredWeightKg'] as num?)?.toDouble() ?? 0.0,
        expectedWeightKg: (json['expectedWeightKg'] as num?)?.toDouble() ?? 12.5,
        status: json['status'] as String? ?? 'PACKED',
        godownBay: json['godownBay'] as String? ?? 'BAY_3',
        sealedBy: json['sealedBy'] as String? ?? 'Packer',
        companyName: json['companyName'] as String?,
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      );
}

@immutable
class AqlAuditRecord {
  final String id;
  final String auditNumber;
  final String orderNumber;
  final String cartonNumber;
  final String inspectorName;
  final int sampleSize;
  final int criticalDefects;
  final int majorDefects;
  final int minorDefects;
  final String decision; // 'PASS', 'RE_AUDIT', 'REJECT_QUARANTINE'
  final String remarks;
  final String? companyName;
  final DateTime auditDate;

  const AqlAuditRecord({
    required this.id,
    required this.auditNumber,
    required this.orderNumber,
    required this.cartonNumber,
    required this.inspectorName,
    this.sampleSize = 32,
    this.criticalDefects = 0,
    this.majorDefects = 0,
    this.minorDefects = 0,
    this.decision = 'PASS',
    this.remarks = 'Passed ISO 2859-1 AQL 2.5 standard',
    this.companyName,
    required this.auditDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'auditNumber': auditNumber,
        'orderNumber': orderNumber,
        'cartonNumber': cartonNumber,
        'inspectorName': inspectorName,
        'sampleSize': sampleSize,
        'criticalDefects': criticalDefects,
        'majorDefects': majorDefects,
        'minorDefects': minorDefects,
        'decision': decision,
        'remarks': remarks,
        'companyName': companyName,
        'auditDate': auditDate.toIso8601String(),
      };

  factory AqlAuditRecord.fromJson(Map<String, dynamic> json) => AqlAuditRecord(
        id: json['id'] as String,
        auditNumber: json['auditNumber'] as String,
        orderNumber: json['orderNumber'] as String? ?? '',
        cartonNumber: json['cartonNumber'] as String? ?? '',
        inspectorName: json['inspectorName'] as String? ?? 'Auditor',
        sampleSize: (json['sampleSize'] as num?)?.toInt() ?? 32,
        criticalDefects: (json['criticalDefects'] as num?)?.toInt() ?? 0,
        majorDefects: (json['majorDefects'] as num?)?.toInt() ?? 0,
        minorDefects: (json['minorDefects'] as num?)?.toInt() ?? 0,
        decision: json['decision'] as String? ?? 'PASS',
        remarks: json['remarks'] as String? ?? '',
        companyName: json['companyName'] as String?,
        auditDate: json['auditDate'] != null ? DateTime.parse(json['auditDate']) : DateTime.now(),
      );
}

@immutable
class ReadyGoodsBuyer {
  final String id;
  final String buyerName;
  final String buyerCode;
  final int contractedVolume;
  final String linkedArticleNumber;
  final String linkedArticleName;

  const ReadyGoodsBuyer({
    required this.id,
    required this.buyerName,
    required this.buyerCode,
    this.contractedVolume = 5000,
    this.linkedArticleNumber = 'PO-7715',
    this.linkedArticleName = 'Export Garment Style',
  });
}
