/// Printing Floor Worker Model
class PrintingWorker {
  final String id;
  final String? workerUserId;
  final String workerName;
  final String phoneNumber;
  final String? workerEmail;
  final List<String> roles;
  final String role;
  final String shift;
  final String status;
  final int assignedPieces;
  final int completedPieces;
  final String? companyName;
  final String createdAt;
  final String? updatedAt;

  const PrintingWorker({
    required this.id,
    this.workerUserId,
    required this.workerName,
    required this.phoneNumber,
    this.workerEmail,
    this.roles = const ['SCREEN_PRINTER'],
    this.role = 'Screen Printer',
    this.shift = 'MORNING',
    this.status = 'ACTIVE',
    this.assignedPieces = 0,
    this.completedPieces = 0,
    this.companyName,
    required this.createdAt,
    this.updatedAt,
  });

  PrintingWorker copyWith({
    String? id,
    String? workerUserId,
    String? workerName,
    String? phoneNumber,
    String? workerEmail,
    List<String>? roles,
    String? role,
    String? shift,
    String? status,
    int? assignedPieces,
    int? completedPieces,
    String? companyName,
    String? createdAt,
    String? updatedAt,
  }) {
    return PrintingWorker(
      id: id ?? this.id,
      workerUserId: workerUserId ?? this.workerUserId,
      workerName: workerName ?? this.workerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      workerEmail: workerEmail ?? this.workerEmail,
      roles: roles ?? this.roles,
      role: role ?? this.role,
      shift: shift ?? this.shift,
      status: status ?? this.status,
      assignedPieces: assignedPieces ?? this.assignedPieces,
      completedPieces: completedPieces ?? this.completedPieces,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PrintingWorker.fromJson(Map<String, dynamic> json) {
    List<String> parsedRoles = [];
    if (json['roles'] is List) {
      parsedRoles = (json['roles'] as List).map((e) => e.toString()).toList();
    } else if (json['role'] != null) {
      parsedRoles = [json['role'].toString()];
    }
    if (parsedRoles.isEmpty) parsedRoles = ['SCREEN_PRINTER'];

    final roleLabel = json['role']?.toString() ??
        parsedRoles.map((r) => r.replaceAll('_', ' ')).join(', ');

    return PrintingWorker(
      id: json['id']?.toString() ?? '',
      workerUserId: json['worker_user_id']?.toString(),
      workerName: json['worker_name']?.toString() ?? 'Worker',
      phoneNumber: json['phone_number']?.toString() ?? '',
      workerEmail: json['worker_email']?.toString(),
      roles: parsedRoles,
      role: roleLabel,
      shift: json['shift']?.toString() ?? 'MORNING',
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
      'shift': shift,
      'status': status,
      'assigned_pieces': assignedPieces,
      'completed_pieces': completedPieces,
      if (companyName != null) 'company_name': companyName,
      'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }
}

/// Printing Task Allocation Model
class PrintingTaskAllocation {
  final String id;
  final String taskRef;
  final String? buyerId;
  final String buyerName;
  final String articleNumber;
  final String? articleName;
  final String? workerId;
  final String workerName;
  final String? workerPhone;
  final String tableNumber;
  final int piecesToPrint;
  final int completedPieces;
  final double allotedHours;
  final String? dueTime;
  final String? notes;
  final String status;
  final String? companyName;
  final String createdAt;
  final String? updatedAt;
  final String? completedAt;

  const PrintingTaskAllocation({
    required this.id,
    required this.taskRef,
    this.buyerId,
    required this.buyerName,
    required this.articleNumber,
    this.articleName,
    this.workerId,
    required this.workerName,
    this.workerPhone,
    this.tableNumber = 'Print Table 01',
    required this.piecesToPrint,
    this.completedPieces = 0,
    this.allotedHours = 4.0,
    this.dueTime,
    this.notes,
    this.status = 'ASSIGNED',
    this.companyName,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'VERIFIED_COMPLETED' || status == 'COMPLETED';
  bool get isWorkerCompleted => status == 'WORKER_COMPLETED';
  bool get isInProgress => status == 'IN_PROGRESS';

  PrintingTaskAllocation copyWith({
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
    int? piecesToPrint,
    int? completedPieces,
    double? allotedHours,
    String? dueTime,
    String? notes,
    String? status,
    String? companyName,
    String? createdAt,
    String? updatedAt,
    String? completedAt,
  }) {
    return PrintingTaskAllocation(
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
      piecesToPrint: piecesToPrint ?? this.piecesToPrint,
      completedPieces: completedPieces ?? this.completedPieces,
      allotedHours: allotedHours ?? this.allotedHours,
      dueTime: dueTime ?? this.dueTime,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory PrintingTaskAllocation.fromJson(Map<String, dynamic> json) {
    return PrintingTaskAllocation(
      id: json['id']?.toString() ?? '',
      taskRef: json['task_ref']?.toString() ?? 'PRN-001',
      buyerId: json['buyer_id']?.toString(),
      buyerName: json['buyer_name']?.toString() ?? 'Direct Buyer',
      articleNumber: json['article_number']?.toString() ?? 'ART-STD',
      articleName: json['article_name']?.toString(),
      workerId: json['worker_id']?.toString(),
      workerName: json['worker_name']?.toString() ?? 'Operator',
      workerPhone: json['worker_phone']?.toString(),
      tableNumber: json['table_number']?.toString() ?? 'Print Table 01',
      piecesToPrint: (json['pieces_to_print'] as num?)?.toInt() ?? (json['pieces_to_cut'] as num?)?.toInt() ?? 0,
      completedPieces: (json['completed_pieces'] as num?)?.toInt() ?? 0,
      allotedHours: (json['alloted_hours'] as num?)?.toDouble() ?? 4.0,
      dueTime: json['due_time']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? 'ASSIGNED',
      companyName: json['company_name']?.toString(),
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at']?.toString(),
      completedAt: json['completed_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_ref': taskRef,
      if (buyerId != null) 'buyer_id': buyerId,
      'buyer_name': buyerName,
      'article_number': articleNumber,
      if (articleName != null) 'article_name': articleName,
      if (workerId != null) 'worker_id': workerId,
      'worker_name': workerName,
      if (workerPhone != null) 'worker_phone': workerPhone,
      'table_number': tableNumber,
      'pieces_to_print': piecesToPrint,
      'completed_pieces': completedPieces,
      'alloted_hours': allotedHours,
      if (dueTime != null) 'due_time': dueTime,
      if (notes != null) 'notes': notes,
      'status': status,
      if (companyName != null) 'company_name': companyName,
      'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
    };
  }
}

/// Active Buyer Contract Model for Printing Division
class PrintingBuyerContract {
  final String id;
  final String buyerName;
  final String buyerCode;
  final int contractedVolume;
  final double pricePerPiece;
  final double totalContractValue;
  final String? linkedArticleNumber;
  final String? linkedArticleName;
  final String embellishmentSequence;
  final String status;
  final String? companyName;

  const PrintingBuyerContract({
    required this.id,
    required this.buyerName,
    required this.buyerCode,
    required this.contractedVolume,
    this.pricePerPiece = 12.5,
    this.totalContractValue = 0,
    this.linkedArticleNumber,
    this.linkedArticleName,
    this.embellishmentSequence = 'PRINT_FIRST_THEN_EMBROIDERY',
    this.status = 'ACTIVE',
    this.companyName,
  });

  factory PrintingBuyerContract.fromJson(Map<String, dynamic> json) {
    final qty = (json['contracted_volume'] as num?)?.toInt() ?? 0;
    final price = (json['price_per_piece'] as num?)?.toDouble() ?? 12.5;

    return PrintingBuyerContract(
      id: json['id']?.toString() ?? '',
      buyerName: json['buyer_name']?.toString() ?? json['brand_name']?.toString() ?? 'Direct Buyer',
      buyerCode: json['buyer_code']?.toString() ?? 'DIR',
      contractedVolume: qty,
      pricePerPiece: price,
      totalContractValue: (json['total_contract_value'] as num?)?.toDouble() ?? (qty * price),
      linkedArticleNumber: json['linked_article_number']?.toString() ?? json['style_ref']?.toString(),
      linkedArticleName: json['linked_article_name']?.toString() ?? json['style_name']?.toString(),
      embellishmentSequence: json['embellishment_sequence']?.toString() ?? 'PRINT_FIRST_THEN_EMBROIDERY',
      status: json['status']?.toString() ?? 'ACTIVE',
      companyName: json['company_name']?.toString(),
    );
  }
}

/// Strike Off Test Approval State
class StrikeOffApproval {
  final String status; // APPROVED, PENDING, REJECTED, IN_LAB_TESTING
  final String labRemarks;
  final String auditorName;
  final String approvedAt;
  final double deltaE;
  final double washFastnessRating;

  const StrikeOffApproval({
    this.status = 'APPROVED',
    this.labRemarks = 'Lab color fastness & swatch shade sign-off',
    this.auditorName = 'Buyer Technical QA',
    this.approvedAt = '2026-09-20T00:00:00.000Z',
    this.deltaE = 0.38,
    this.washFastnessRating = 4.5,
  });

  bool get isApproved => status.toUpperCase() == 'APPROVED';

  StrikeOffApproval copyWith({
    String? status,
    String? labRemarks,
    String? auditorName,
    String? approvedAt,
    double? deltaE,
    double? washFastnessRating,
  }) {
    return StrikeOffApproval(
      status: status ?? this.status,
      labRemarks: labRemarks ?? this.labRemarks,
      auditorName: auditorName ?? this.auditorName,
      approvedAt: approvedAt ?? this.approvedAt,
      deltaE: deltaE ?? this.deltaE,
      washFastnessRating: washFastnessRating ?? this.washFastnessRating,
    );
  }

  factory StrikeOffApproval.fromJson(Map<String, dynamic> json) {
    return StrikeOffApproval(
      status: json['status']?.toString() ?? 'APPROVED',
      labRemarks: json['lab_remarks']?.toString() ?? 'Lab color fastness & swatch shade sign-off',
      auditorName: json['auditor_name']?.toString() ?? 'Buyer Technical QA',
      approvedAt: json['approved_at']?.toString() ?? DateTime.now().toIso8601String(),
      deltaE: (json['delta_e'] as num?)?.toDouble() ?? 0.38,
      washFastnessRating: (json['wash_fastness_rating'] as num?)?.toDouble() ?? 4.5,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'lab_remarks': labRemarks,
    'auditor_name': auditorName,
    'approved_at': approvedAt,
    'delta_e': deltaE,
    'wash_fastness_rating': washFastnessRating,
  };
}

/// Manufacturing Route Option
class PrintingManufacturingRouteOption {
  final String key;
  final String shortLabel;
  final String fullFlow;
  final String stepIndicator;
  final String sourceDepartment;
  final bool isPrintingActive;

  const PrintingManufacturingRouteOption({
    required this.key,
    required this.shortLabel,
    required this.fullFlow,
    required this.stepIndicator,
    required this.sourceDepartment,
    this.isPrintingActive = true,
  });
}

const List<PrintingManufacturingRouteOption> kPrintingRouteOptions = [
  PrintingManufacturingRouteOption(
    key: 'PRINT_FIRST_THEN_EMBROIDERY',
    shortLabel: 'Cutting → Printing → Embroidery',
    fullFlow: 'Raw fabric is cut, screen/digital printed first, then sent to embroidery before stitching assembly.',
    stepIndicator: 'Step 1: Cutting → Printing',
    sourceDepartment: 'Cutting Floor',
    isPrintingActive: true,
  ),
  PrintingManufacturingRouteOption(
    key: 'EMBROIDERY_FIRST_THEN_PRINT',
    shortLabel: 'Cutting → Embroidery → Printing',
    fullFlow: 'Raw fabric is cut, embroidered first, then transferred to print studio for surface finishing.',
    stepIndicator: 'Step 2: Embroidery → Printing',
    sourceDepartment: 'Embroidery Studio',
    isPrintingActive: true,
  ),
  PrintingManufacturingRouteOption(
    key: 'PRINTING_ONLY',
    shortLabel: 'Cutting → Printing → Stitching',
    fullFlow: 'Direct print sequence bypassing embroidery studio completely.',
    stepIndicator: 'Step 1: Cutting → Printing',
    sourceDepartment: 'Cutting Floor',
    isPrintingActive: true,
  ),
  PrintingManufacturingRouteOption(
    key: 'EMBROIDERY_ONLY',
    shortLabel: 'Cutting → Embroidery → Stitching',
    fullFlow: 'Direct embroidery sequence (Printing bypassed for this style).',
    stepIndicator: 'Bypassed in this Style',
    sourceDepartment: 'N/A',
    isPrintingActive: false,
  ),
  PrintingManufacturingRouteOption(
    key: 'DIRECT_SEWING_NO_EMBELLISHMENT',
    shortLabel: 'Cutting → Stitching Line',
    fullFlow: 'Solid garments without embellishment (All print and embroidery bypassed).',
    stepIndicator: 'Bypassed in this Style',
    sourceDepartment: 'N/A',
    isPrintingActive: false,
  ),
];
