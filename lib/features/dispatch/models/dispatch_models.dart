import 'package:flutter/foundation.dart';

@immutable
class ArticleOption {
  final String id;
  final String artNo;
  final String? description;

  const ArticleOption({
    required this.id,
    required this.artNo,
    this.description,
  });

  factory ArticleOption.fromJson(Map<String, dynamic> json) {
    return ArticleOption(
      id: json['id']?.toString() ?? '',
      artNo: json['art_no']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}

@immutable
class ChallanItemModel {
  final String id;
  final String articleId;
  final String? color;
  final String? size;
  final int quantity;
  final String? articleArtNo;
  final String? articleDescription;

  const ChallanItemModel({
    required this.id,
    required this.articleId,
    this.color,
    this.size,
    required this.quantity,
    this.articleArtNo,
    this.articleDescription,
  });

  factory ChallanItemModel.fromJson(Map<String, dynamic> json) {
    final articleMap = json['article'] as Map<String, dynamic>?;
    return ChallanItemModel(
      id: json['id']?.toString() ?? '',
      articleId: json['article_id']?.toString() ?? '',
      color: json['color']?.toString(),
      size: json['size']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      articleArtNo: articleMap?['art_no']?.toString(),
      articleDescription: articleMap?['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'article_id': articleId,
        'color': color,
        'size': size,
        'quantity': quantity,
      };
}

@immutable
class DeliveryChallanModel {
  final String id;
  final String challanNo;
  final String buyerName;
  final String? vendorId;
  final String? vendorName;
  final String? destination;
  final String? vehicleNo;
  final String? driverName;
  final String? driverPhone;
  final int totalPieces;
  final String deliveryDate;
  final String createdAt;
  final String status;
  final String? notes;
  final String? spotNotes;
  final String? billedToName;
  final String? billedToAddress;
  final String? billedToGstin;
  final String? shippingToName;
  final String? shippingToAddress;
  final List<ChallanItemModel> items;

  // Reconciliation fields
  final int cutQty;
  final int countedQty;
  final int dispatchedQty;
  final String reconciliationStatus; // 'MATCHED', 'DISCREPANCY', 'PENDING'
  final String reconciliationLabel;
  final int shortPcs;

  const DeliveryChallanModel({
    required this.id,
    required this.challanNo,
    required this.buyerName,
    this.vendorId,
    this.vendorName,
    this.destination,
    this.vehicleNo,
    this.driverName,
    this.driverPhone,
    required this.totalPieces,
    required this.deliveryDate,
    required this.createdAt,
    required this.status,
    this.notes,
    this.spotNotes,
    this.billedToName,
    this.billedToAddress,
    this.billedToGstin,
    this.shippingToName,
    this.shippingToAddress,
    this.items = const [],
    this.cutQty = 0,
    this.countedQty = 0,
    this.dispatchedQty = 0,
    this.reconciliationStatus = 'MATCHED',
    this.reconciliationLabel = 'Matches lot',
    this.shortPcs = 0,
  });

  factory DeliveryChallanModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['challan_items'] as List<dynamic>? ?? [];
    final itemsList = rawItems.map((e) => ChallanItemModel.fromJson(e as Map<String, dynamic>)).toList();

    return DeliveryChallanModel(
      id: json['id']?.toString() ?? '',
      challanNo: json['challan_no']?.toString() ?? '',
      buyerName: json['buyer_name']?.toString() ?? 'Direct Dispatch',
      vendorId: json['vendor_id']?.toString(),
      vendorName: json['vendor_name']?.toString(),
      destination: json['destination']?.toString(),
      vehicleNo: json['vehicle_no']?.toString(),
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      totalPieces: (json['total_pieces'] as num?)?.toInt() ?? 0,
      deliveryDate: json['delivery_date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      status: json['status']?.toString() ?? 'DISPATCHED',
      notes: json['notes']?.toString(),
      spotNotes: json['spot_notes']?.toString(),
      billedToName: json['billed_to_name']?.toString(),
      billedToAddress: json['billed_to_address']?.toString(),
      billedToGstin: json['billed_to_gstin']?.toString(),
      shippingToName: json['shipping_to_name']?.toString(),
      shippingToAddress: json['shipping_to_address']?.toString(),
      items: itemsList,
    );
  }

  DeliveryChallanModel copyWith({
    int? cutQty,
    int? countedQty,
    int? dispatchedQty,
    String? reconciliationStatus,
    String? reconciliationLabel,
    int? shortPcs,
    String? status,
  }) {
    return DeliveryChallanModel(
      id: id,
      challanNo: challanNo,
      buyerName: buyerName,
      vendorId: vendorId,
      vendorName: vendorName,
      destination: destination,
      vehicleNo: vehicleNo,
      driverName: driverName,
      driverPhone: driverPhone,
      totalPieces: totalPieces,
      deliveryDate: deliveryDate,
      createdAt: createdAt,
      status: status ?? this.status,
      notes: notes,
      spotNotes: spotNotes,
      billedToName: billedToName,
      billedToAddress: billedToAddress,
      billedToGstin: billedToGstin,
      shippingToName: shippingToName,
      shippingToAddress: shippingToAddress,
      items: items,
      cutQty: cutQty ?? this.cutQty,
      countedQty: countedQty ?? this.countedQty,
      dispatchedQty: dispatchedQty ?? this.dispatchedQty,
      reconciliationStatus: reconciliationStatus ?? this.reconciliationStatus,
      reconciliationLabel: reconciliationLabel ?? this.reconciliationLabel,
      shortPcs: shortPcs ?? this.shortPcs,
    );
  }
}

@immutable
class CountingReportModel {
  final String id;
  final String articleId;
  final String? color;
  final String? size;
  final int countedQty;
  final int expectedQty;
  final String? remarks;
  final String entryDate;
  final String createdAt;
  final String? articleArtNo;
  final String? articleDescription;

  const CountingReportModel({
    required this.id,
    required this.articleId,
    this.color,
    this.size,
    required this.countedQty,
    required this.expectedQty,
    this.remarks,
    required this.entryDate,
    required this.createdAt,
    this.articleArtNo,
    this.articleDescription,
  });

  factory CountingReportModel.fromJson(Map<String, dynamic> json) {
    final articleMap = json['article'] as Map<String, dynamic>?;
    return CountingReportModel(
      id: json['id']?.toString() ?? '',
      articleId: json['article_id']?.toString() ?? '',
      color: json['color']?.toString(),
      size: json['size']?.toString(),
      countedQty: (json['counted_qty'] as num?)?.toInt() ?? 0,
      expectedQty: (json['expected_qty'] as num?)?.toInt() ?? 0,
      remarks: json['remarks']?.toString(),
      entryDate: json['entry_date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      articleArtNo: articleMap?['art_no']?.toString(),
      articleDescription: articleMap?['description']?.toString(),
    );
  }
}

@immutable
class AllotmentModel {
  final String id;
  final String articleId;
  final int targetQty;
  final String? allotmentDate;
  final String? articleArtNo;

  const AllotmentModel({
    required this.id,
    required this.articleId,
    required this.targetQty,
    this.allotmentDate,
    this.articleArtNo,
  });

  factory AllotmentModel.fromJson(Map<String, dynamic> json) {
    final articleMap = json['article'] as Map<String, dynamic>?;
    return AllotmentModel(
      id: json['id']?.toString() ?? '',
      articleId: json['article_id']?.toString() ?? '',
      targetQty: (json['target_qty'] as num?)?.toInt() ?? 0,
      allotmentDate: json['allotment_date']?.toString(),
      articleArtNo: articleMap?['art_no']?.toString(),
    );
  }
}
