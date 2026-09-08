import 'package:flutter/material.dart';

/// Helper to map garment color/shade names to accurate hex colors
class ColorThemeHelper {
  static Color getColor(String colorName) {
    final c = colorName.trim().toUpperCase();
    if (c.contains('MUSHROOM') || c.contains('BEIGE') || c.contains('BROWN') || c.contains('ORANGE')) {
      return const Color(0xFFC2410C); // Warm Orange/Brown
    }
    if (c.contains('DUTCH') || c.contains('BLUE') || c.contains('NAVY') || c.contains('ROBIN') || c.contains('DUSK')) {
      return const Color(0xFF1D4ED8); // Vibrant Royal Blue
    }
    if (c.contains('SCUBA') || c.contains('GREEN') || c.contains('OLIVE') || c.contains('MINT') || c.contains('SEUBA')) {
      return const Color(0xFF047857); // Emerald / Forest Green
    }
    if (c.contains('RED') || c.contains('PINK') || c.contains('CHERRY') || c.contains('MAROON') || c.contains('ROSE')) {
      return const Color(0xFFBE123C); // Crimson / Rose Red
    }
    if (c.contains('BLACK') || c.contains('CHARCOAL') || c.contains('GREY') || c.contains('GRAY')) {
      return const Color(0xFF334155); // Slate / Charcoal
    }
    if (c.contains('YELLOW') || c.contains('MUSTARD') || c.contains('GOLD')) {
      return const Color(0xFFB45309); // Amber Gold
    }
    if (c.contains('PURPLE') || c.contains('VIOLET') || c.contains('LAVENDER')) {
      return const Color(0xFF7E22CE); // Purple / Violet
    }
    return const Color(0xFF332B6B); // Default Dark Indigo
  }

  static Color getBgLight(String colorName) {
    final c = colorName.trim().toUpperCase();
    if (c.contains('MUSHROOM') || c.contains('BEIGE') || c.contains('BROWN') || c.contains('ORANGE')) {
      return const Color(0xFFFFF7ED);
    }
    if (c.contains('DUTCH') || c.contains('BLUE') || c.contains('NAVY') || c.contains('ROBIN') || c.contains('DUSK')) {
      return const Color(0xFFEFF6FF);
    }
    if (c.contains('SCUBA') || c.contains('GREEN') || c.contains('OLIVE') || c.contains('MINT') || c.contains('SEUBA')) {
      return const Color(0xFFECFDF5);
    }
    if (c.contains('RED') || c.contains('PINK') || c.contains('CHERRY') || c.contains('MAROON') || c.contains('ROSE')) {
      return const Color(0xFFFFF1F2);
    }
    if (c.contains('BLACK') || c.contains('CHARCOAL') || c.contains('GREY') || c.contains('GRAY')) {
      return const Color(0xFFF8FAFC);
    }
    if (c.contains('YELLOW') || c.contains('MUSTARD') || c.contains('GOLD')) {
      return const Color(0xFFFFFBEB);
    }
    if (c.contains('PURPLE') || c.contains('VIOLET') || c.contains('LAVENDER')) {
      return const Color(0xFFFAF5FF);
    }
    return const Color(0xFFFAFAF8);
  }
}

/// Represents a single article line inside a Delivery Challan
class ChallanArticleLine {
  final String id;
  final String? allotmentId;
  final String artNo;
  final String? subArtNo;
  final String? patternNo;
  final String? description;
  final String colorPattern;
  final String sizeRange;
  final int sets;
  final int pcsPerSet;
  final int totalPcs;
  final int completedQty;
  final String? assignedLinemanId;
  final String? assignedLinemanName;
  final String? pictureUrl;
  final double stitchingRate;
  final String status; // 'PENDING' | 'IN_PROGRESS' | 'QC_PASSED' | 'DISPATCHED'

  ChallanArticleLine({
    required this.id,
    this.allotmentId,
    required this.artNo,
    this.subArtNo,
    this.patternNo,
    this.description,
    required this.colorPattern,
    required this.sizeRange,
    this.sets = 1,
    this.pcsPerSet = 9,
    required this.totalPcs,
    this.completedQty = 0,
    this.assignedLinemanId,
    this.assignedLinemanName,
    this.pictureUrl,
    this.stitchingRate = 20.0,
    this.status = 'PENDING',
  });

  String get fullArtCode {
    if (subArtNo != null && subArtNo!.isNotEmpty) {
      return '$artNo$subArtNo';
    }
    return artNo;
  }

  factory ChallanArticleLine.fromJson(Map<String, dynamic> json) {
    final linePcs = (json['total_pcs'] as num?)?.toInt() ??
        (((json['sets'] as num?)?.toInt() ?? 1) * ((json['pcs_per_set'] as num?)?.toInt() ?? 9));
    final lineSets = (json['sets'] as num?)?.toInt() ?? 1;
    final lineRatio = (json['pcs_per_set'] as num?)?.toInt() ?? 9;

    return ChallanArticleLine(
      id: json['id']?.toString() ?? '',
      allotmentId: json['allotment_id']?.toString(),
      artNo: json['art_no']?.toString().trim().toUpperCase() ?? 'Style',
      subArtNo: json['sub_art_no']?.toString().trim().toUpperCase(),
      patternNo: json['pattern_no']?.toString(),
      description: json['description']?.toString(),
      colorPattern: json['color_pattern']?.toString().trim() ?? 'Standard',
      sizeRange: json['size_range']?.toString().trim() ?? 'Free Size',
      sets: lineSets,
      pcsPerSet: lineRatio,
      totalPcs: linePcs,
      completedQty: (json['completed_qty'] as num?)?.toInt() ?? 0,
      assignedLinemanId: json['assigned_lineman_id']?.toString(),
      assignedLinemanName: json['assigned_lineman_name']?.toString() ?? json['lineman_name']?.toString(),
      pictureUrl: json['picture_url']?.toString(),
      stitchingRate: (json['stitching_rate'] as num?)?.toDouble() ?? 20.0,
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'allotment_id': allotmentId,
      'art_no': artNo,
      'sub_art_no': subArtNo,
      'pattern_no': patternNo,
      'description': description,
      'color_pattern': colorPattern,
      'size_range': sizeRange,
      'sets': sets,
      'pcs_per_set': pcsPerSet,
      'total_pcs': totalPcs,
      'completed_qty': completedQty,
      'assigned_lineman_id': assignedLinemanId,
      'assigned_lineman_name': assignedLinemanName,
      'picture_url': pictureUrl,
      'stitching_rate': stitchingRate,
      'status': status,
    };
  }
}

/// Represents a BOM Fabric / Raw Material Lot item
class ChallanBomItem {
  final String? id;
  final String materialType; // 'FABRIC' | 'RIB' | 'BUTTON' | 'LABEL' | 'ACCESSORY'
  final String itemName;
  final String? lotNo;
  final String? requiredQty;
  final String status;

  ChallanBomItem({
    this.id,
    required this.materialType,
    required this.itemName,
    this.lotNo,
    this.requiredQty,
    this.status = 'PENDING',
  });

  factory ChallanBomItem.fromJson(Map<String, dynamic> json) {
    return ChallanBomItem(
      id: json['id']?.toString(),
      materialType: json['material_type']?.toString() ?? 'FABRIC',
      itemName: json['item_name']?.toString() ?? 'Main Fabric',
      lotNo: json['lot_no']?.toString(),
      requiredQty: json['required_qty']?.toString(),
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'material_type': materialType,
      'item_name': itemName,
      'lot_no': lotNo,
      'required_qty': requiredQty,
      'status': status,
    };
  }
}

/// Represents a dynamic computed continuous sewing color line (matching Web)
class ColorLineGroup {
  final String colorName;
  final Color themeColor;
  final Color bgLight;
  final int totalPcs;
  final Map<String, int> sizeBreakdown;
  final String? assignedLinemanId;
  final String? assignedLinemanName;

  ColorLineGroup({
    required this.colorName,
    required this.themeColor,
    required this.bgLight,
    required this.totalPcs,
    required this.sizeBreakdown,
    this.assignedLinemanId,
    this.assignedLinemanName,
  });

  bool get isAssigned =>
      assignedLinemanId != null &&
      assignedLinemanId!.isNotEmpty &&
      assignedLinemanName != null &&
      !assignedLinemanName!.toLowerCase().contains('unassigned');
}

/// Full hierarchical Delivery Challan / Production Order (matching Web)
class ChallanGroupedOrder {
  final String id;
  final String challanNo;
  final String challanDate;
  final String brand;
  final String? deliveryDate;
  final String? fabricType;
  final bool sampleGiven;
  final String notes;
  final int totalSets;
  final int totalPcs;
  final String status; // 'PENDING' | 'PARTIALLY_ALLOTTED' | 'IN_PROGRESS' | 'QC_PASSED' | 'DISPATCHED'
  final List<ChallanBomItem> bomDetails;
  final List<ChallanArticleLine> articles;
  final DateTime createdAt;

  ChallanGroupedOrder({
    required this.id,
    required this.challanNo,
    required this.challanDate,
    required this.brand,
    this.deliveryDate,
    this.fabricType,
    this.sampleGiven = false,
    this.notes = '',
    this.totalSets = 0,
    this.totalPcs = 0,
    this.status = 'PENDING',
    this.bomDetails = const [],
    this.articles = const [],
    required this.createdAt,
  });

  int get masterStylesCount {
    final baseArts = articles.map((a) => a.artNo).toSet();
    return baseArts.length;
  }

  bool get isAllotted => status != 'PENDING';

  /// Compute Color Lines breakdown matching the Web algorithm
  List<ColorLineGroup> get colorLines {
    final Map<String, Map<String, int>> colorSizeMap = {};
    final Map<String, String?> linemanIdMap = {};
    final Map<String, String?> linemanNameMap = {};

    for (var art in articles) {
      final rawColor = art.colorPattern.trim().toUpperCase();
      final sizeTier = art.sizeRange;
      final totalPcs = art.totalPcs;

      List<String> colorList = [];
      if (rawColor == '3 COLOUR' || rawColor == '3 COLOR' || rawColor == 'ALL') {
        colorList = ['MUSHROOM', 'DUTCH BLUE', 'SCUBA'];
      } else if (rawColor.contains(',')) {
        colorList = rawColor.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      } else {
        colorList = [rawColor.isNotEmpty ? rawColor : 'STANDARD'];
      }

      final pcsPerColor = colorList.isNotEmpty ? (totalPcs / colorList.length).round() : totalPcs;

      for (var cName in colorList) {
        colorSizeMap.putIfAbsent(cName, () => {});
        colorSizeMap[cName]![sizeTier] = (colorSizeMap[cName]![sizeTier] ?? 0) + pcsPerColor;

        if (art.assignedLinemanId != null && art.assignedLinemanId!.isNotEmpty) {
          linemanIdMap[cName] = art.assignedLinemanId;
          linemanNameMap[cName] = art.assignedLinemanName;
        }
      }
    }

    final List<ColorLineGroup> result = [];
    colorSizeMap.forEach((cName, sizeMap) {
      final totalForColor = sizeMap.values.fold(0, (sum, val) => sum + val);
      if (totalForColor > 0) {
        result.add(
          ColorLineGroup(
            colorName: cName,
            themeColor: ColorThemeHelper.getColor(cName),
            bgLight: ColorThemeHelper.getBgLight(cName),
            totalPcs: totalForColor,
            sizeBreakdown: sizeMap,
            assignedLinemanId: linemanIdMap[cName],
            assignedLinemanName: linemanNameMap[cName],
          ),
        );
      }
    });

    return result;
  }
}
