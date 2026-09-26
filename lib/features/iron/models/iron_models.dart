import 'package:flutter/foundation.dart';

@immutable
class IronWorker {
  final String id;
  final String workerName;
  final String phoneNumber;
  final List<String> roles;
  final String role;
  final String assignedTable;
  final String shift;
  final bool isActive;
  final int completedPieces;
  final String? companyName;
  final DateTime? createdAt;

  const IronWorker({
    required this.id,
    required this.workerName,
    required this.phoneNumber,
    this.roles = const ['FINISHING_PRESSER'],
    this.role = 'Finishing Presser (Steam Table)',
    this.assignedTable = 'Table 01 (Vacuum Buck)',
    this.shift = 'SHIFT_1',
    this.isActive = true,
    this.completedPieces = 0,
    this.companyName,
    this.createdAt,
  });

  IronWorker copyWith({
    String? id,
    String? workerName,
    String? phoneNumber,
    List<String>? roles,
    String? role,
    String? assignedTable,
    String? shift,
    bool? isActive,
    int? completedPieces,
    String? companyName,
    DateTime? createdAt,
  }) {
    return IronWorker(
      id: id ?? this.id,
      workerName: workerName ?? this.workerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      roles: roles ?? this.roles,
      role: role ?? this.role,
      assignedTable: assignedTable ?? this.assignedTable,
      shift: shift ?? this.shift,
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
        'roles': roles,
        'role': role,
        'assigned_table': assignedTable,
        'shift': shift,
        'status': isActive ? 'ACTIVE' : 'INACTIVE',
        'is_active': isActive,
        'completed_pieces': completedPieces,
        'company_name': companyName,
        'created_at': createdAt?.toIso8601String(),
      };

  factory IronWorker.fromJson(Map<String, dynamic> json) {
    List<String> parsedRoles = ['FINISHING_PRESSER'];
    if (json['roles'] != null) {
      if (json['roles'] is List) {
        parsedRoles = (json['roles'] as List).map((e) => e.toString()).toList();
      } else if (json['roles'] is String) {
        parsedRoles = [json['roles'].toString()];
      }
    }
    return IronWorker(
      id: json['id']?.toString() ?? '',
      workerName: json['worker_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      roles: parsedRoles,
      role: json['role']?.toString() ?? 'Finishing Presser (Steam Table)',
      assignedTable: json['assigned_table']?.toString() ?? 'Table 01 (Vacuum Buck)',
      shift: json['shift']?.toString() ?? 'SHIFT_1',
      isActive: json['status'] == 'ACTIVE' || json['is_active'] == true,
      completedPieces: int.tryParse(json['completed_pieces']?.toString() ?? '0') ?? 0,
      companyName: json['company_name']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

@immutable
class IronBuyerContract {
  final String id;
  final String buyerName;
  final String buyerCode;
  final int contractedVolume;
  final double pricePerPiece;
  final double totalContractValue;
  final String linkedArticleNumber;
  final String linkedArticleName;
  final String status;
  final String? companyName;

  const IronBuyerContract({
    required this.id,
    required this.buyerName,
    required this.buyerCode,
    required this.contractedVolume,
    required this.pricePerPiece,
    required this.totalContractValue,
    required this.linkedArticleNumber,
    required this.linkedArticleName,
    this.status = 'LINKED',
    this.companyName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'buyer_name': buyerName,
        'buyer_code': buyerCode,
        'contracted_volume': contractedVolume,
        'price_per_piece': pricePerPiece,
        'total_contract_value': totalContractValue,
        'linked_article_number': linkedArticleNumber,
        'linked_article_name': linkedArticleName,
        'status': status,
        'company_name': companyName,
      };

  factory IronBuyerContract.fromJson(Map<String, dynamic> json) => IronBuyerContract(
        id: json['id']?.toString() ?? '',
        buyerName: json['buyer_name']?.toString() ?? '',
        buyerCode: json['buyer_code']?.toString() ?? '',
        contractedVolume: int.tryParse(json['contracted_volume']?.toString() ?? '0') ?? 0,
        pricePerPiece: double.tryParse(json['price_per_piece']?.toString() ?? '0.0') ?? 0.0,
        totalContractValue: double.tryParse(json['total_contract_value']?.toString() ?? '0.0') ?? 0.0,
        linkedArticleNumber: json['linked_article_number']?.toString() ?? '',
        linkedArticleName: json['linked_article_name']?.toString() ?? '',
        status: json['status']?.toString() ?? 'LINKED',
        companyName: json['company_name']?.toString(),
      );
}

@immutable
class IronTaskAllocation {
  final String id;
  final String taskRef;
  final String? cuttingAllocationId;
  final String? buyerId;
  final String buyerName;
  final String articleNumber;
  final String? articleName;
  final String? workerId;
  final String workerName;
  final String? workerPhone;
  final String machineTable;
  final int piecesToPress;
  final int completedPieces;
  final double allotedHours;
  final String shift;
  final int ironTempC;
  final String status; // PENDING, IN_PROGRESS, COMPLETED, VERIFIED_COMPLETED
  final String? companyName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const IronTaskAllocation({
    required this.id,
    required this.taskRef,
    this.cuttingAllocationId,
    this.buyerId,
    required this.buyerName,
    required this.articleNumber,
    this.articleName,
    this.workerId,
    required this.workerName,
    this.workerPhone,
    this.machineTable = 'Table 01 (Vacuum Buck)',
    required this.piecesToPress,
    this.completedPieces = 0,
    this.allotedHours = 4.0,
    this.shift = 'SHIFT_1',
    this.ironTempC = 150,
    this.status = 'PENDING',
    this.companyName,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  IronTaskAllocation copyWith({
    String? id,
    String? taskRef,
    String? cuttingAllocationId,
    String? buyerId,
    String? buyerName,
    String? articleNumber,
    String? articleName,
    String? workerId,
    String? workerName,
    String? workerPhone,
    String? machineTable,
    int? piecesToPress,
    int? completedPieces,
    double? allotedHours,
    String? shift,
    int? ironTempC,
    String? status,
    String? companyName,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return IronTaskAllocation(
      id: id ?? this.id,
      taskRef: taskRef ?? this.taskRef,
      cuttingAllocationId: cuttingAllocationId ?? this.cuttingAllocationId,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      articleNumber: articleNumber ?? this.articleNumber,
      articleName: articleName ?? this.articleName,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      workerPhone: workerPhone ?? this.workerPhone,
      machineTable: machineTable ?? this.machineTable,
      piecesToPress: piecesToPress ?? this.piecesToPress,
      completedPieces: completedPieces ?? this.completedPieces,
      allotedHours: allotedHours ?? this.allotedHours,
      shift: shift ?? this.shift,
      ironTempC: ironTempC ?? this.ironTempC,
      status: status ?? this.status,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'task_ref': taskRef,
        'cutting_allocation_id': cuttingAllocationId,
        'buyer_id': buyerId,
        'buyer_name': buyerName,
        'article_number': articleNumber,
        'article_name': articleName,
        'worker_id': workerId,
        'worker_name': workerName,
        'worker_phone': workerPhone,
        'machine_table': machineTable,
        'pieces_to_press': piecesToPress,
        'completed_pieces': completedPieces,
        'alloted_hours': allotedHours,
        'shift': shift,
        'iron_temp_c': ironTempC,
        'status': status,
        'company_name': companyName,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  factory IronTaskAllocation.fromJson(Map<String, dynamic> json) => IronTaskAllocation(
        id: json['id']?.toString() ?? '',
        taskRef: json['task_ref']?.toString() ?? '',
        cuttingAllocationId: json['cutting_allocation_id']?.toString(),
        buyerId: json['buyer_id']?.toString(),
        buyerName: json['buyer_name']?.toString() ?? 'Direct Buyer',
        articleNumber: json['article_number']?.toString() ?? '',
        articleName: json['article_name']?.toString(),
        workerId: json['worker_id']?.toString(),
        workerName: json['worker_name']?.toString() ?? 'Finishing Presser',
        workerPhone: json['worker_phone']?.toString(),
        machineTable: json['machine_table']?.toString() ?? 'Table 01 (Vacuum Buck)',
        piecesToPress: int.tryParse(json['pieces_to_press']?.toString() ?? '0') ?? 0,
        completedPieces: int.tryParse(json['completed_pieces']?.toString() ?? '0') ?? 0,
        allotedHours: double.tryParse(json['alloted_hours']?.toString() ?? '4.0') ?? 4.0,
        shift: json['shift']?.toString() ?? 'SHIFT_1',
        ironTempC: int.tryParse(json['iron_temp_c']?.toString() ?? '150') ?? 150,
        status: json['status']?.toString() ?? 'PENDING',
        companyName: json['company_name']?.toString(),
        createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
        updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
        completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      );
}
