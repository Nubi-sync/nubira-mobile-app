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
