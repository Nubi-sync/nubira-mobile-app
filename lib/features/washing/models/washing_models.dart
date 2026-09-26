import 'package:flutter/foundation.dart';

@immutable
class WashingWorker {
  final String id;
  final String workerName;
  final String phoneNumber;
  final String machineNumber;
  final String specialization;
  final String shift;
  final String status;
  final int completedPieces;
  final String? companyName;
  final DateTime? createdAt;

  const WashingWorker({
    required this.id,
    required this.workerName,
    required this.phoneNumber,
    this.machineNumber = 'Washer 01',
    this.specialization = 'Bio-Enzyme & Softening',
    this.shift = 'Morning (08:00 - 16:30)',
    this.status = 'AVAILABLE',
    this.completedPieces = 0,
    this.companyName,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'worker_name': workerName,
        'phone_number': phoneNumber,
        'table_number': machineNumber,
        'machine_number': machineNumber,
        'specialization': specialization,
        'shift': shift,
        'status': status,
        'completed_pieces': completedPieces,
        'company_name': companyName,
        'created_at': createdAt?.toIso8601String(),
      };

  factory WashingWorker.fromJson(Map<String, dynamic> json) => WashingWorker(
        id: json['id']?.toString() ?? '',
        workerName: json['worker_name']?.toString() ?? '',
        phoneNumber: json['phone_number']?.toString() ?? '',
        machineNumber: json['machine_number']?.toString() ?? json['table_number']?.toString() ?? 'Washer 01',
        specialization: json['specialization']?.toString() ?? 'Bio-Enzyme & Softening',
        shift: json['shift']?.toString() ?? 'Morning (08:00 - 16:30)',
        status: json['status']?.toString() ?? 'AVAILABLE',
        completedPieces: int.tryParse(json['completed_pieces']?.toString() ?? '0') ?? 0,
        companyName: json['company_name']?.toString(),
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      );
}

@immutable
class WashingBuyerContract {
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

  const WashingBuyerContract({
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

  factory WashingBuyerContract.fromJson(Map<String, dynamic> json) => WashingBuyerContract(
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
class WashingTaskAllocation {
  final String id;
  final String taskRef;
  final String buyerId;
  final String buyerName;
  final String articleNumber;
  final String workerId;
  final String workerName;
  final String workerPhone;
  final String machineNumber;
  final int piecesToWash;
  final int completedPieces;
  final String washRecipe;
  final String status; // ASSIGNED, IN_PROGRESS, WORKER_COMPLETED, VERIFIED_COMPLETED
  final String targetShift;
  final String notes;
  final DateTime createdAt;
  final DateTime? completedAt;

  const WashingTaskAllocation({
    required this.id,
    required this.taskRef,
    required this.buyerId,
    required this.buyerName,
    required this.articleNumber,
    required this.workerId,
    required this.workerName,
    this.workerPhone = '',
    this.machineNumber = 'Washer 01',
    required this.piecesToWash,
    this.completedPieces = 0,
    this.washRecipe = 'Bio-Enzyme Wash 55°C',
    this.status = 'ASSIGNED',
    this.targetShift = 'Shift A (08:00 - 16:30)',
    this.notes = '',
    required this.createdAt,
    this.completedAt,
  });

  WashingTaskAllocation copyWith({
    String? id,
    String? taskRef,
    String? buyerId,
    String? buyerName,
    String? articleNumber,
    String? workerId,
    String? workerName,
    String? workerPhone,
    String? machineNumber,
    int? piecesToWash,
    int? completedPieces,
    String? washRecipe,
    String? status,
    String? targetShift,
    String? notes,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return WashingTaskAllocation(
      id: id ?? this.id,
      taskRef: taskRef ?? this.taskRef,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      articleNumber: articleNumber ?? this.articleNumber,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      workerPhone: workerPhone ?? this.workerPhone,
      machineNumber: machineNumber ?? this.machineNumber,
      piecesToWash: piecesToWash ?? this.piecesToWash,
      completedPieces: completedPieces ?? this.completedPieces,
      washRecipe: washRecipe ?? this.washRecipe,
      status: status ?? this.status,
      targetShift: targetShift ?? this.targetShift,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'task_ref': taskRef,
        'buyer_id': buyerId,
        'buyer_name': buyerName,
        'article_number': articleNumber,
        'worker_id': workerId,
        'worker_name': workerName,
        'worker_phone': workerPhone,
        'table_number': machineNumber,
        'machine_number': machineNumber,
        'pieces_to_wash': piecesToWash,
        'completed_pieces': completedPieces,
        'wash_recipe': washRecipe,
        'status': status,
        'target_shift': targetShift,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  factory WashingTaskAllocation.fromJson(Map<String, dynamic> json) => WashingTaskAllocation(
        id: json['id']?.toString() ?? '',
        taskRef: json['task_ref']?.toString() ?? '',
        buyerId: json['buyer_id']?.toString() ?? '',
        buyerName: json['buyer_name']?.toString() ?? '',
        articleNumber: json['article_number']?.toString() ?? '',
        workerId: json['worker_id']?.toString() ?? '',
        workerName: json['worker_name']?.toString() ?? '',
        workerPhone: json['worker_phone']?.toString() ?? '',
        machineNumber: json['machine_number']?.toString() ?? json['table_number']?.toString() ?? 'Washer 01',
        piecesToWash: int.tryParse(json['pieces_to_wash']?.toString() ?? '0') ?? 0,
        completedPieces: int.tryParse(json['completed_pieces']?.toString() ?? '0') ?? 0,
        washRecipe: json['wash_recipe']?.toString() ?? 'Bio-Enzyme Wash 55°C',
        status: json['status']?.toString() ?? 'ASSIGNED',
        targetShift: json['target_shift']?.toString() ?? 'Shift A (08:00 - 16:30)',
        notes: json['notes']?.toString() ?? '',
        createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
        completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      );
}
