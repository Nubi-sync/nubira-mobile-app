import 'package:flutter/foundation.dart';

@immutable
class CentralFabricInventoryModel {
  final String id;
  final String companyName;
  final String fabricType;
  final String color;
  final String? supplierName;
  final double totalMeters;
  final double totalWeightKg;
  final int totalRolls;
  final String rackLocation;
  final String? bookedForArticle;
  final double bookedMeters;
  final double availableMeters;
  final String? notes;
  final String createdAt;

  const CentralFabricInventoryModel({
    required this.id,
    required this.companyName,
    required this.fabricType,
    required this.color,
    this.supplierName,
    required this.totalMeters,
    required this.totalWeightKg,
    required this.totalRolls,
    required this.rackLocation,
    this.bookedForArticle,
    required this.bookedMeters,
    required this.availableMeters,
    this.notes,
    required this.createdAt,
  });

  factory CentralFabricInventoryModel.fromJson(Map<String, dynamic> json) {
    final total = (json['total_meters'] as num?)?.toDouble() ?? 0.0;
    final booked = (json['booked_meters'] as num?)?.toDouble() ?? 0.0;
    final available = (json['available_meters'] as num?)?.toDouble() ?? (total - booked > 0 ? total - booked : 0.0);

    return CentralFabricInventoryModel(
      id: json['id']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      fabricType: json['fabric_type']?.toString() ?? 'Standard Fabric',
      color: json['color']?.toString() ?? 'Natural',
      supplierName: json['supplier_name']?.toString(),
      totalMeters: total,
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble() ?? 0.0,
      totalRolls: (json['total_rolls'] as num?)?.toInt() ?? 0,
      rackLocation: json['rack_location']?.toString() ?? 'BAY_1_RACK_01',
      bookedForArticle: json['booked_for_article']?.toString(),
      bookedMeters: booked,
      availableMeters: available,
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

@immutable
class CentralMaterialIssueModel {
  final String id;
  final String issueChallanNo;
  final String fromDivision;
  final String toDivision;
  final String? articleNo;
  final String? buyerName;
  final String? fabricType;
  final String? color;
  final double quantity;
  final String unit;
  final int rollsCount;
  final String status;
  final String issueDate;
  final String? notes;
  final String? issuedBy;

  const CentralMaterialIssueModel({
    required this.id,
    required this.issueChallanNo,
    required this.fromDivision,
    required this.toDivision,
    this.articleNo,
    this.buyerName,
    this.fabricType,
    this.color,
    required this.quantity,
    required this.unit,
    required this.rollsCount,
    required this.status,
    required this.issueDate,
    this.notes,
    this.issuedBy,
  });

  factory CentralMaterialIssueModel.fromJson(Map<String, dynamic> json) {
    return CentralMaterialIssueModel(
      id: json['id']?.toString() ?? '',
      issueChallanNo: json['issue_challan_no']?.toString() ?? 'ISS-CHALLAN',
      fromDivision: json['from_division']?.toString() ?? 'STORE',
      toDivision: json['to_division']?.toString() ?? 'CUTTING',
      articleNo: json['article_no']?.toString(),
      buyerName: json['buyer_name']?.toString(),
      fabricType: json['fabric_type']?.toString(),
      color: json['color']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'meters',
      rollsCount: (json['rolls_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'ISSUED',
      issueDate: json['issue_date']?.toString() ?? '',
      notes: json['notes']?.toString(),
      issuedBy: json['issued_by']?.toString(),
    );
  }
}

@immutable
class CentralMaterialReceiptModel {
  final String id;
  final String issueId;
  final String divisionCode;
  final double receivedQuantity;
  final double shortageQuantity;
  final String unit;
  final String? receivedBy;
  final String? rackLocation;
  final String receiptDate;

  const CentralMaterialReceiptModel({
    required this.id,
    required this.issueId,
    required this.divisionCode,
    required this.receivedQuantity,
    required this.shortageQuantity,
    required this.unit,
    this.receivedBy,
    this.rackLocation,
    required this.receiptDate,
  });

  factory CentralMaterialReceiptModel.fromJson(Map<String, dynamic> json) {
    return CentralMaterialReceiptModel(
      id: json['id']?.toString() ?? '',
      issueId: json['issue_id']?.toString() ?? '',
      divisionCode: json['division_code']?.toString() ?? '',
      receivedQuantity: (json['received_quantity'] as num?)?.toDouble() ?? 0.0,
      shortageQuantity: (json['shortage_quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'meters',
      receivedBy: json['received_by']?.toString(),
      rackLocation: json['rack_location']?.toString(),
      receiptDate: json['received_at']?.toString() ?? json['receipt_date']?.toString() ?? json['created_at']?.toString() ?? '',
    );
  }
}

@immutable
class TruckInwardModel {
  final String id;
  final String grnNo;
  final String partyName;
  final String? articleNo;
  final String? garmentType;
  final String? challanNo;
  final String? truckNo;
  final String inwardDate;
  final int totalItems;
  final String status;
  final String? notes;

  const TruckInwardModel({
    required this.id,
    required this.grnNo,
    required this.partyName,
    this.articleNo,
    this.garmentType,
    this.challanNo,
    this.truckNo,
    required this.inwardDate,
    required this.totalItems,
    required this.status,
    this.notes,
  });

  factory TruckInwardModel.fromJson(Map<String, dynamic> json) {
    return TruckInwardModel(
      id: json['id']?.toString() ?? '',
      grnNo: json['grn_no']?.toString() ?? (json['challan_no'] != null ? 'GRN-${json['challan_no']}' : 'GRN-INWARD'),
      partyName: json['party_name']?.toString() ?? 'Supplier Delivery',
      articleNo: json['article_no']?.toString(),
      garmentType: json['garment_type']?.toString(),
      challanNo: json['challan_no']?.toString(),
      truckNo: json['truck_no']?.toString(),
      inwardDate: json['inward_date']?.toString() ?? '',
      totalItems: (json['total_items'] as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? 'VERIFIED',
      notes: json['notes']?.toString(),
    );
  }
}
