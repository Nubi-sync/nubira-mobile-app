import 'package:flutter/foundation.dart';

@immutable
class ReadyGoodsWorker {
  final String id;
  final String workerName;
  final String phoneNumber;
  final String role; // 'CHECKER', 'ALTERATION_TAILOR', 'PACKER', 'BOTH'
  final String shift;
  final String skillLevel;
  final bool isActive;
  final int completedPieces;
  final String? companyName;
  final DateTime? createdAt;

  const ReadyGoodsWorker({
    required this.id,
    required this.workerName,
    this.phoneNumber = '',
    this.role = 'CHECKER',
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
        'worker_name': workerName,
        'phone_number': phoneNumber,
        'role': role,
        'shift': shift,
        'skill_level': skillLevel,
        'is_active': isActive,
        'completed_pieces': completedPieces,
        'company_name': companyName,
        'created_at': createdAt?.toIso8601String(),
      };

  factory ReadyGoodsWorker.fromJson(Map<String, dynamic> json) => ReadyGoodsWorker(
        id: json['id']?.toString() ?? '',
        workerName: (json['worker_name'] ?? json['workerName'] ?? 'Worker').toString(),
        phoneNumber: (json['phone_number'] ?? json['phoneNumber'] ?? '').toString(),
        role: (json['role'] ?? 'CHECKER').toString(),
        shift: (json['shift'] ?? 'SHIFT_1').toString(),
        skillLevel: (json['skill_level'] ?? json['skillLevel'] ?? 'Certified').toString(),
        isActive: json['is_active'] ?? json['isActive'] ?? true,
        completedPieces: (json['completed_pieces'] ?? json['completedPieces'] as num?)?.toInt() ?? 0,
        companyName: json['company_name'] ?? json['companyName'],
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      );
}

@immutable
class InspectionChecklist {
  final bool cuttingDoneRight;
  final bool printingDoneRight;
  final bool embroideryDoneRight;
  final bool washingDoneRight;
  final bool ironDoneRight;

  const InspectionChecklist({
    this.cuttingDoneRight = false,
    this.printingDoneRight = false,
    this.embroideryDoneRight = false,
    this.washingDoneRight = false,
    this.ironDoneRight = false,
  });

  InspectionChecklist copyWith({
    bool? cuttingDoneRight,
    bool? printingDoneRight,
    bool? embroideryDoneRight,
    bool? washingDoneRight,
    bool? ironDoneRight,
  }) {
    return InspectionChecklist(
      cuttingDoneRight: cuttingDoneRight ?? this.cuttingDoneRight,
      printingDoneRight: printingDoneRight ?? this.printingDoneRight,
      embroideryDoneRight: embroideryDoneRight ?? this.embroideryDoneRight,
      washingDoneRight: washingDoneRight ?? this.washingDoneRight,
      ironDoneRight: ironDoneRight ?? this.ironDoneRight,
    );
  }

  Map<String, dynamic> toJson() => {
        'cutting_done_right': cuttingDoneRight,
        'printing_done_right': printingDoneRight,
        'embroidery_done_right': embroideryDoneRight,
        'washing_done_right': washingDoneRight,
        'iron_done_right': ironDoneRight,
      };

  factory InspectionChecklist.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const InspectionChecklist();
    return InspectionChecklist(
      cuttingDoneRight: json['cutting_done_right'] == true,
      printingDoneRight: json['printing_done_right'] == true,
      embroideryDoneRight: json['embroidery_done_right'] == true,
      washingDoneRight: json['washing_done_right'] == true,
      ironDoneRight: json['iron_done_right'] == true,
    );
  }
}

@immutable
class FinishingInspectionTask {
  final String id;
  final String taskCode; // e.g. QC-7714-01
  final String orderNumber; // e.g. PO-7714
  final String buyer; // e.g. Urban Outfitters
  final String styleName; // e.g. French Terry Relaxed Hoodie
  final String color;
  final String size;
  final int piecesCount;
  final String washBatchRef; // e.g. WB-082 (Silicon Softener Wash)
  final String ironStationRef; // e.g. Steam Press Board 03
  final bool hasPrinting;
  final bool hasEmbroidery;
  final String printEmbSummary;
  final String status; // 'PENDING_CHECK', 'IN_CHECKING', 'REJECTED_TO_ALTERATION', 'PASSED_TO_PACKING', 'PACKED_IN_CARTON'
  final String priority; // 'NORMAL', 'RUSH', 'CRITICAL'
  final String? checkedByWorkerName;
  final String? checkedByWorkerId;
  final String? defectReason;
  final String? defectNotes;
  final String? defectStation;
  final InspectionChecklist checklist;
  final String? companyName;
  final DateTime createdAt;

  const FinishingInspectionTask({
    required this.id,
    required this.taskCode,
    required this.orderNumber,
    required this.buyer,
    required this.styleName,
    this.color = 'Standard',
    this.size = 'M',
    required this.piecesCount,
    this.washBatchRef = 'WB-082 (Silicon Wash)',
    this.ironStationRef = 'Vacuum Press Table 01',
    this.hasPrinting = false,
    this.hasEmbroidery = false,
    this.printEmbSummary = 'Standard Finishing',
    this.status = 'PENDING_CHECK',
    this.priority = 'NORMAL',
    this.checkedByWorkerName,
    this.checkedByWorkerId,
    this.defectReason,
    this.defectNotes,
    this.defectStation,
    this.checklist = const InspectionChecklist(),
    this.companyName,
    required this.createdAt,
  });

  FinishingInspectionTask copyWith({
    String? id,
    String? taskCode,
    String? orderNumber,
    String? buyer,
    String? styleName,
    String? color,
    String? size,
    int? piecesCount,
    String? washBatchRef,
    String? ironStationRef,
    bool? hasPrinting,
    bool? hasEmbroidery,
    String? printEmbSummary,
    String? status,
    String? priority,
    String? checkedByWorkerName,
    String? checkedByWorkerId,
    String? defectReason,
    String? defectNotes,
    String? defectStation,
    InspectionChecklist? checklist,
    String? companyName,
    DateTime? createdAt,
  }) {
    return FinishingInspectionTask(
      id: id ?? this.id,
      taskCode: taskCode ?? this.taskCode,
      orderNumber: orderNumber ?? this.orderNumber,
      buyer: buyer ?? this.buyer,
      styleName: styleName ?? this.styleName,
      color: color ?? this.color,
      size: size ?? this.size,
      piecesCount: piecesCount ?? this.piecesCount,
      washBatchRef: washBatchRef ?? this.washBatchRef,
      ironStationRef: ironStationRef ?? this.ironStationRef,
      hasPrinting: hasPrinting ?? this.hasPrinting,
      hasEmbroidery: hasEmbroidery ?? this.hasEmbroidery,
      printEmbSummary: printEmbSummary ?? this.printEmbSummary,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      checkedByWorkerName: checkedByWorkerName ?? this.checkedByWorkerName,
      checkedByWorkerId: checkedByWorkerId ?? this.checkedByWorkerId,
      defectReason: defectReason ?? this.defectReason,
      defectNotes: defectNotes ?? this.defectNotes,
      defectStation: defectStation ?? this.defectStation,
      checklist: checklist ?? this.checklist,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'task_code': taskCode,
        'order_number': orderNumber,
        'buyer': buyer,
        'style_name': styleName,
        'color': color,
        'size': size,
        'pieces_count': piecesCount,
        'wash_batch_ref': washBatchRef,
        'iron_station_ref': ironStationRef,
        'has_printing': hasPrinting,
        'has_embroidery': hasEmbroidery,
        'print_emb_summary': printEmbSummary,
        'status': status,
        'priority': priority,
        'checked_by_worker_name': checkedByWorkerName,
        'checked_by_worker_id': checkedByWorkerId,
        'defect_reason': defectReason,
        'defect_notes': defectNotes,
        'defect_station': defectStation,
        'checklist': checklist.toJson(),
        'company_name': companyName,
        'created_at': createdAt.toIso8601String(),
      };

  factory FinishingInspectionTask.fromJson(Map<String, dynamic> json) => FinishingInspectionTask(
        id: json['id']?.toString() ?? '',
        taskCode: (json['task_code'] ?? json['taskRef'] ?? 'QC-101').toString(),
        orderNumber: (json['order_number'] ?? json['orderNumber'] ?? 'PO-7700').toString(),
        buyer: (json['buyer'] ?? 'Buyer').toString(),
        styleName: (json['style_name'] ?? json['styleName'] ?? 'Style').toString(),
        color: (json['color'] ?? 'Standard').toString(),
        size: (json['size'] ?? 'M').toString(),
        piecesCount: (json['pieces_count'] ?? json['piecesCount'] as num?)?.toInt() ?? 0,
        washBatchRef: (json['wash_batch_ref'] ?? 'WB-082 (Silicon Wash)').toString(),
        ironStationRef: (json['iron_station_ref'] ?? 'Vacuum Press Table 01').toString(),
        hasPrinting: json['has_printing'] == true,
        hasEmbroidery: json['has_embroidery'] == true,
        printEmbSummary: (json['print_emb_summary'] ?? 'Standard Finishing').toString(),
        status: (json['status'] ?? 'PENDING_CHECK').toString(),
        priority: (json['priority'] ?? 'NORMAL').toString(),
        checkedByWorkerName: json['checked_by_worker_name']?.toString(),
        checkedByWorkerId: json['checked_by_worker_id']?.toString(),
        defectReason: json['defect_reason']?.toString(),
        defectNotes: json['defect_notes']?.toString(),
        defectStation: json['defect_station']?.toString(),
        checklist: InspectionChecklist.fromJson(json['checklist'] as Map<String, dynamic>?),
        companyName: json['company_name']?.toString(),
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
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
