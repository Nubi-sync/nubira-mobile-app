import 'dart:convert';

/// Represents a Delivery/Cutting Challan in the factory
class AdminChallan {
  final String id;
  final String challanNo;
  final String brand;
  final String? fabricType;
  final String? description;
  final int totalQty;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic>? rawMetadata;

  AdminChallan({
    required this.id,
    required this.challanNo,
    required this.brand,
    this.fabricType,
    this.description,
    this.totalQty = 0,
    this.status = 'PENDING',
    required this.createdAt,
    this.rawMetadata,
  });

  factory AdminChallan.fromJson(Map<String, dynamic> json) {
    int calculatedTotalQty = (json['total_qty'] as num?)?.toInt() ?? 0;
    String? articleDescription = json['description']?.toString();
    final rawNotes = json['notes']?.toString();

    // Parse JSON notes format if present
    if (rawNotes != null && rawNotes.trim().isNotEmpty) {
      if (rawNotes.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(rawNotes);
          if (decoded is Map) {
            if (decoded['article_lines'] is List) {
              final lines = decoded['article_lines'] as List;
              final artNumbers = <String>{};
              int linesTotalPcs = 0;
              for (var l in lines) {
                if (l is Map) {
                  final aNo = l['art_no']?.toString().trim();
                  if (aNo != null && aNo.isNotEmpty) {
                    artNumbers.add(aNo);
                  }
                  final pcs = int.tryParse(l['total_pcs']?.toString() ?? '0') ?? 0;
                  linesTotalPcs += pcs;
                }
              }
              if (artNumbers.isNotEmpty) {
                articleDescription = 'Art: ${artNumbers.join(', ')}';
              }
              if (linesTotalPcs > 0 && calculatedTotalQty == 0) {
                calculatedTotalQty = linesTotalPcs;
              }
            }

            final uNotes = decoded['user_notes']?.toString().trim();
            if (uNotes != null && uNotes.isNotEmpty) {
              if (articleDescription != null && articleDescription.isNotEmpty) {
                articleDescription = '$articleDescription • $uNotes';
              } else {
                articleDescription = uNotes;
              }
            }
          }
        } catch (_) {
          articleDescription = rawNotes;
        }
      } else {
        articleDescription = rawNotes;
      }
    }

    // Calculate total from associated allotments if available and needed
    if (json['allotments'] != null && json['allotments'] is List) {
      final alList = json['allotments'] as List;
      int sumQty = 0;
      for (var a in alList) {
        if (a is Map) {
          sumQty += (a['target_qty'] as num?)?.toInt() ?? 0;
          if (articleDescription == null || articleDescription.isEmpty) {
            if (a['articles'] != null && a['articles'] is Map) {
              final artNo = a['articles']['art_no']?.toString();
              if (artNo != null && artNo.isNotEmpty) {
                articleDescription = 'Art: #$artNo';
              }
            }
          }
        }
      }
      if (sumQty > 0 && calculatedTotalQty == 0) {
        calculatedTotalQty = sumQty;
      }
    }

    final rawBrand = json['brand']?.toString().trim();
    final brandStr = (rawBrand != null && rawBrand.isNotEmpty) ? rawBrand : 'OLLYPOP';

    return AdminChallan(
      id: json['id']?.toString() ?? '',
      challanNo: json['challan_no']?.toString() ?? 'N/A',
      brand: brandStr,
      fabricType: json['fabric_type']?.toString(),
      description: articleDescription,
      totalQty: calculatedTotalQty,
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      rawMetadata: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challan_no': challanNo,
      'brand': brand,
      'fabric_type': fabricType,
      'description': description,
      'total_qty': totalQty,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Represents an Allotment assigned to a Lineman / Floor
class AdminAllotment {
  final String id;
  final String? challanId;
  final String? linemanId;
  final String? linemanName;
  final String? articleId;
  final String? articleNo;
  final String? articleDescription;
  final String? challanNo;
  final String? brand;
  final String? fabricType;
  final int targetQty;
  final String status;
  final String? allotmentDate;
  final String? mendingStatus;
  final int? mendingTotalCounted;
  final String? qcStatus;
  final int? qcTotalPassed;
  final int? qcTotalAlter;
  final DateTime createdAt;
  final List<AdminAllotmentVariant> variants;

  AdminAllotment({
    required this.id,
    this.challanId,
    this.linemanId,
    this.linemanName,
    this.articleId,
    this.articleNo,
    this.articleDescription,
    this.challanNo,
    this.brand,
    this.fabricType,
    this.targetQty = 0,
    this.status = 'PENDING',
    this.allotmentDate,
    this.mendingStatus,
    this.mendingTotalCounted,
    this.qcStatus,
    this.qcTotalPassed,
    this.qcTotalAlter,
    required this.createdAt,
    this.variants = const [],
  });

  factory AdminAllotment.fromJson(Map<String, dynamic> json) {
    // Lineman profile
    String? linemanName;
    if (json['profiles'] != null) {
      if (json['profiles'] is Map) {
        linemanName = json['profiles']['username']?.toString();
      } else if (json['profiles'] is List && (json['profiles'] as List).isNotEmpty) {
        linemanName = (json['profiles'] as List).first['username']?.toString();
      }
    }

    // Article info
    String? artNo;
    String? artDesc;
    if (json['articles'] != null && json['articles'] is Map) {
      artNo = json['articles']['art_no']?.toString();
      artDesc = json['articles']['description']?.toString();
    }

    // Challan info
    String? chNo;
    String? brand;
    String? fabric;
    if (json['challans'] != null && json['challans'] is Map) {
      chNo = json['challans']['challan_no']?.toString();
      brand = json['challans']['brand']?.toString();
      fabric = json['challans']['fabric_type']?.toString();
    }

    return AdminAllotment(
      id: json['id']?.toString() ?? '',
      challanId: json['challan_id']?.toString(),
      linemanId: json['lineman_id']?.toString(),
      linemanName: linemanName,
      articleId: json['article_id']?.toString(),
      articleNo: artNo,
      articleDescription: artDesc,
      challanNo: chNo,
      brand: brand,
      fabricType: fabric,
      targetQty: (json['target_qty'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      allotmentDate: json['allotment_date']?.toString(),
      mendingStatus: json['mending_status']?.toString(),
      mendingTotalCounted: (json['mending_total_counted'] as num?)?.toInt(),
      qcStatus: json['qc_status']?.toString(),
      qcTotalPassed: (json['qc_total_passed'] as num?)?.toInt(),
      qcTotalAlter: (json['qc_total_alter'] as num?)?.toInt(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Represents size/color variant of an allotment
class AdminAllotmentVariant {
  final String id;
  final String allotmentId;
  final String size;
  final String color;
  final int quantity;

  AdminAllotmentVariant({
    required this.id,
    required this.allotmentId,
    required this.size,
    required this.color,
    required this.quantity,
  });

  factory AdminAllotmentVariant.fromJson(Map<String, dynamic> json) {
    return AdminAllotmentVariant(
      id: json['id']?.toString() ?? '',
      allotmentId: json['allotment_id']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Represents an Article / Style Code
class AdminArticle {
  final String id;
  final String artNo;
  final String? description;
  final double stitchingRate;
  final Map<String, dynamic>? sizeRates;
  final bool isActive;
  final DateTime createdAt;

  AdminArticle({
    required this.id,
    required this.artNo,
    this.description,
    this.stitchingRate = 0.0,
    this.sizeRates,
    this.isActive = true,
    required this.createdAt,
  });

  factory AdminArticle.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedRates;
    if (json['size_rates'] != null) {
      if (json['size_rates'] is Map) {
        parsedRates = Map<String, dynamic>.from(json['size_rates']);
      } else if (json['size_rates'] is String) {
        try {
          parsedRates = jsonDecode(json['size_rates'] as String);
        } catch (_) {}
      }
    }

    return AdminArticle(
      id: json['id']?.toString() ?? '',
      artNo: json['art_no']?.toString() ?? 'N/A',
      description: json['description']?.toString(),
      stitchingRate: (json['stitching_rate'] as num?)?.toDouble() ?? 0.0,
      sizeRates: parsedRates,
      isActive: json['is_active'] == null ? true : (json['is_active'] as bool),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Represents a Factory Staff / Supervisor Profile
class AdminEmployee {
  final String id;
  final String username;
  final String role;
  final bool isActive;
  final DateTime createdAt;

  AdminEmployee({
    required this.id,
    required this.username,
    required this.role,
    this.isActive = true,
    required this.createdAt,
  });

  factory AdminEmployee.fromJson(Map<String, dynamic> json) {
    return AdminEmployee(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Staff',
      role: json['role']?.toString().toUpperCase() ?? 'STAFF',
      isActive: json['is_active'] == null ? true : (json['is_active'] as bool),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Represents a Godown / Store Transaction (GRN or Outward)
class AdminStoreEntry {
  final String id;
  final String type; // INWARD or OUTWARD
  final int quantity;
  final String? color;
  final String? size;
  final String? partyName;
  final String? challanNo;
  final String? articleNo;
  final String? entryDate;
  final DateTime createdAt;

  AdminStoreEntry({
    required this.id,
    required this.type,
    required this.quantity,
    this.color,
    this.size,
    this.partyName,
    this.challanNo,
    this.articleNo,
    this.entryDate,
    required this.createdAt,
  });

  factory AdminStoreEntry.fromJson(Map<String, dynamic> json) {
    String? artNo;
    if (json['article'] != null && json['article'] is Map) {
      artNo = json['article']['art_no']?.toString();
    } else if (json['articles'] != null && json['articles'] is Map) {
      artNo = json['articles']['art_no']?.toString();
    }

    return AdminStoreEntry(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString().toUpperCase() ?? 'INWARD',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      color: json['color']?.toString(),
      size: json['size']?.toString(),
      partyName: json['party_name']?.toString(),
      challanNo: json['challan_no']?.toString(),
      articleNo: artNo,
      entryDate: json['entry_date']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Represents a Dispatch Order / Carton Delivery
class AdminDispatchEntry {
  final String id;
  final String challanNo;
  final String? buyerName;
  final int totalPieces;
  final String status;
  final DateTime createdAt;

  AdminDispatchEntry({
    required this.id,
    required this.challanNo,
    this.buyerName,
    required this.totalPieces,
    this.status = 'PENDING',
    required this.createdAt,
  });

  factory AdminDispatchEntry.fromJson(Map<String, dynamic> json) {
    return AdminDispatchEntry(
      id: json['id']?.toString() ?? '',
      challanNo: json['challan_no']?.toString() ?? 'N/A',
      buyerName: json['buyer_name']?.toString(),
      totalPieces: (json['total_pieces'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Aggregated Factory Health KPIs
class AdminFactoryKpi {
  final int totalChallans;
  final int totalAllotments;
  final int activeArticles;
  final int activeEmployees;
  final int todayProductionQty;
  final int todayQcPassedQty;
  final int todayQcAlterQty;
  final int totalStoreInwardQty;
  final int totalDispatchedQty;
  final List<AdminAllotment> recentAllotments;
  final List<AdminChallan> recentChallans;
  final List<AdminStoreEntry> recentStoreEntries;
  final List<AdminDispatchEntry> recentDispatches;

  AdminFactoryKpi({
    this.totalChallans = 0,
    this.totalAllotments = 0,
    this.activeArticles = 0,
    this.activeEmployees = 0,
    this.todayProductionQty = 0,
    this.todayQcPassedQty = 0,
    this.todayQcAlterQty = 0,
    this.totalStoreInwardQty = 0,
    this.totalDispatchedQty = 0,
    this.recentAllotments = const [],
    this.recentChallans = const [],
    this.recentStoreEntries = const [],
    this.recentDispatches = const [],
  });
}
