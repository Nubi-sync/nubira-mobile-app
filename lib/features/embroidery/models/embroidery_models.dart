/// Embroidery Floor Worker Model
class EmbroideryWorker {
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

  const EmbroideryWorker({
    required this.id,
    this.workerUserId,
    required this.workerName,
    required this.phoneNumber,
    this.workerEmail,
    this.roles = const ['EMBROIDERY_OPERATOR'],
    this.role = 'Multi-Head Machine Operator',
    this.shift = 'MORNING',
    this.status = 'ACTIVE',
    this.assignedPieces = 0,
    this.completedPieces = 0,
    this.companyName,
    required this.createdAt,
    this.updatedAt,
  });

  EmbroideryWorker copyWith({
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
    return EmbroideryWorker(
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

  factory EmbroideryWorker.fromJson(Map<String, dynamic> json) {
    List<String> parsedRoles = [];
    if (json['roles'] is List) {
      parsedRoles = (json['roles'] as List).map((e) => e.toString()).toList();
    } else if (json['role'] != null) {
      parsedRoles = [json['role'].toString()];
    }
    if (parsedRoles.isEmpty) parsedRoles = ['EMBROIDERY_OPERATOR'];

    final roleLabel = json['role']?.toString() ??
        parsedRoles.map((r) => r.replaceAll('_', ' ')).join(', ');

    return EmbroideryWorker(
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

/// Embroidery Task Allocation Model
class EmbroideryTaskAllocation {
  final String id;
  final String taskRef;
  final String? buyerId;
  final String buyerName;
  final String articleNumber;
  final String? articleName;
  final String? workerId;
  final String workerName;
  final String? workerPhone;
  final String tableNumber; // Machine Station e.g., "Machine 01 (Tajima 20-Head)"
  final int piecesToEmbroider;
  final int completedPieces;
  final double allotedHours;
  final String? dueTime;
  final String? notes;
  final String status;
  final String? companyName;
  final String createdAt;
  final String? updatedAt;
  final String? completedAt;

  const EmbroideryTaskAllocation({
    required this.id,
    required this.taskRef,
    this.buyerId,
    required this.buyerName,
    required this.articleNumber,
    this.articleName,
    this.workerId,
    required this.workerName,
    this.workerPhone,
    this.tableNumber = 'Machine 01 (Tajima 20-Head)',
    required this.piecesToEmbroider,
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

  EmbroideryTaskAllocation copyWith({
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
    int? piecesToEmbroider,
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
    return EmbroideryTaskAllocation(
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
      piecesToEmbroider: piecesToEmbroider ?? this.piecesToEmbroider,
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

  factory EmbroideryTaskAllocation.fromJson(Map<String, dynamic> json) {
    return EmbroideryTaskAllocation(
      id: json['id']?.toString() ?? '',
      taskRef: json['task_ref']?.toString() ?? '',
      buyerId: json['buyer_id']?.toString(),
      buyerName: json['buyer_name']?.toString() ?? 'Direct Buyer',
      articleNumber: json['article_number']?.toString() ?? 'EMB-ART',
      articleName: json['article_name']?.toString(),
      workerId: json['worker_id']?.toString(),
      workerName: json['worker_name']?.toString() ?? 'Operator',
      workerPhone: json['worker_phone']?.toString(),
      tableNumber: json['table_number']?.toString() ?? json['machine_number']?.toString() ?? 'Machine 01 (Tajima 20-Head)',
      piecesToEmbroider: (json['pieces_to_embroider'] as num?)?.toInt() ?? (json['pieces_to_cut'] as num?)?.toInt() ?? 0,
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
      'pieces_to_embroider': piecesToEmbroider,
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

/// Embroidery Buyer Contract Representation
class EmbroideryBuyerContract {
  final String id;
  final String buyerName;
  final String? buyerCode;
  final int contractedVolume;
  final double pricePerPiece;
  final double totalContractValue;
  final String currency;
  final String? linkedArticleId;
  final String? linkedArticleNumber;
  final String? linkedArticleName;
  final String embellishmentSequence; // 'PRINT_FIRST_THEN_EMBROIDERY' | 'EMBROIDERY_FIRST_THEN_PRINT' | 'EMBROIDERY_ONLY' | 'PRINT_ONLY'
  final String status;
  final String? companyName;
  final int completedCutPieces;
  final int completedPrintingPieces;
  final String? createdAt;

  const EmbroideryBuyerContract({
    required this.id,
    required this.buyerName,
    this.buyerCode,
    this.contractedVolume = 0,
    this.pricePerPiece = 0.0,
    this.totalContractValue = 0.0,
    this.currency = 'INR',
    this.linkedArticleId,
    this.linkedArticleNumber,
    this.linkedArticleName,
    this.embellishmentSequence = 'PRINT_FIRST_THEN_EMBROIDERY',
    this.status = 'LINKED',
    this.companyName,
    this.completedCutPieces = 0,
    this.completedPrintingPieces = 0,
    this.createdAt,
  });

  EmbroideryBuyerContract copyWith({
    String? id,
    String? buyerName,
    String? buyerCode,
    int? contractedVolume,
    double? pricePerPiece,
    double? totalContractValue,
    String? currency,
    String? linkedArticleId,
    String? linkedArticleNumber,
    String? linkedArticleName,
    String? embellishmentSequence,
    String? status,
    String? companyName,
    int? completedCutPieces,
    int? completedPrintingPieces,
    String? createdAt,
  }) {
    return EmbroideryBuyerContract(
      id: id ?? this.id,
      buyerName: buyerName ?? this.buyerName,
      buyerCode: buyerCode ?? this.buyerCode,
      contractedVolume: contractedVolume ?? this.contractedVolume,
      pricePerPiece: pricePerPiece ?? this.pricePerPiece,
      totalContractValue: totalContractValue ?? this.totalContractValue,
      currency: currency ?? this.currency,
      linkedArticleId: linkedArticleId ?? this.linkedArticleId,
      linkedArticleNumber: linkedArticleNumber ?? this.linkedArticleNumber,
      linkedArticleName: linkedArticleName ?? this.linkedArticleName,
      embellishmentSequence: embellishmentSequence ?? this.embellishmentSequence,
      status: status ?? this.status,
      companyName: companyName ?? this.companyName,
      completedCutPieces: completedCutPieces ?? this.completedCutPieces,
      completedPrintingPieces: completedPrintingPieces ?? this.completedPrintingPieces,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory EmbroideryBuyerContract.fromJson(Map<String, dynamic> json) {
    return EmbroideryBuyerContract(
      id: json['id']?.toString() ?? '',
      buyerName: json['buyer_name']?.toString() ?? json['brand_name']?.toString() ?? 'Direct Buyer',
      buyerCode: json['buyer_code']?.toString(),
      contractedVolume: (json['contracted_volume'] as num?)?.toInt() ?? (json['total_quantity'] as num?)?.toInt() ?? 0,
      pricePerPiece: (json['price_per_piece'] as num?)?.toDouble() ?? (json['unit_fob_price'] as num?)?.toDouble() ?? 0.0,
      totalContractValue: (json['total_contract_value'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      linkedArticleId: json['linked_article_id']?.toString() ?? json['tech_pack_id']?.toString(),
      linkedArticleNumber: json['linked_article_number']?.toString() ?? json['style_ref']?.toString(),
      linkedArticleName: json['linked_article_name']?.toString() ?? json['style_name']?.toString(),
      embellishmentSequence: json['embellishment_sequence']?.toString() ?? 'PRINT_FIRST_THEN_EMBROIDERY',
      status: json['status']?.toString() ?? 'LINKED',
      companyName: json['company_name']?.toString(),
      completedCutPieces: (json['completed_cut_pieces'] as num?)?.toInt() ?? 0,
      completedPrintingPieces: (json['completed_printing_pieces'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buyer_name': buyerName,
      if (buyerCode != null) 'buyer_code': buyerCode,
      'contracted_volume': contractedVolume,
      'price_per_piece': pricePerPiece,
      'total_contract_value': totalContractValue,
      'currency': currency,
      if (linkedArticleId != null) 'linked_article_id': linkedArticleId,
      if (linkedArticleNumber != null) 'linked_article_number': linkedArticleNumber,
      if (linkedArticleName != null) 'linked_article_name': linkedArticleName,
      'embellishment_sequence': embellishmentSequence,
      'status': status,
      if (companyName != null) 'company_name': companyName,
      'completed_cut_pieces': completedCutPieces,
      'completed_printing_pieces': completedPrintingPieces,
      if (createdAt != null) 'created_at': createdAt,
    };
  }
}

/// Embroidery Route Calculation Details
class EmbroideryRouteDetails {
  final String route;
  final String shortLabel;
  final String sourceDepartment;
  final String targetDepartment;
  final int sourceCompletedPieces;
  final int inHandPieces;
  final String badgeLabel;
  final String stepText;
  final bool isActive;

  const EmbroideryRouteDetails({
    required this.route,
    required this.shortLabel,
    required this.sourceDepartment,
    required this.targetDepartment,
    required this.sourceCompletedPieces,
    required this.inHandPieces,
    required this.badgeLabel,
    required this.stepText,
    required this.isActive,
  });
}
