import 'dart:convert';
import 'package:flutter/material.dart';

class ParsedBomMaterial {
  final String componentType;
  final String itemName;
  final String specification;
  final String consumption;
  final String placement;

  const ParsedBomMaterial({
    required this.componentType,
    required this.itemName,
    this.specification = '',
    required this.consumption,
    required this.placement,
  });
}

class ParsedFabricResult {
  final String cleanFabric;
  final String? targetCutDate;
  final List<ParsedBomMaterial> materials;

  const ParsedFabricResult({
    required this.cleanFabric,
    this.targetCutDate,
    this.materials = const [],
  });
}

/// Strips `[BOM_JSON: ...]`, `[TARGET_CUT_DATE: ...]`, and `[INSTRUCTIONS: ...]`
/// metadata tags from `fabric_composition`, matching web `parseFabricAndBOM`.
ParsedFabricResult parseFabricAndBom(String? rawFabric) {
  if (rawFabric == null || rawFabric.trim().isEmpty) {
    return const ParsedFabricResult(
      cleanFabric: '100% Combed Cotton Single Jersey',
      materials: [],
    );
  }

  var text = rawFabric;
  String? targetCutDate;
  List<ParsedBomMaterial> materials = [];

  final bomMatch = RegExp(r'\[BOM_JSON:\s*(\[[\s\S]*?\])\]', caseSensitive: false).firstMatch(text);
  if (bomMatch != null && bomMatch.group(1) != null) {
    try {
      final decoded = jsonDecode(bomMatch.group(1)!);
      if (decoded is List) {
        materials = decoded.whereType<Map>().map((m) {
          final cons = m['consumption']?.toString().trim() ?? '';
          return ParsedBomMaterial(
            componentType: (m['component_type'] ?? m['type'] ?? 'Trim / Material').toString(),
            itemName: (m['item_name'] ?? m['name'] ?? '-').toString(),
            specification: (m['specification'] ?? '').toString(),
            consumption: cons.isNotEmpty ? '$cons pcs / unit' : '-',
            placement: (m['placement'] ?? '-').toString(),
          );
        }).toList();
      }
    } catch (_) {}
    text = text.replaceAll(RegExp(r'\[BOM_JSON:\s*\[[\s\S]*?\]\]\s*', caseSensitive: false), '');
  }

  final cutMatch = RegExp(r'\[TARGET_CUT_DATE:\s*([\s\S]*?)\]', caseSensitive: false).firstMatch(text);
  if (cutMatch != null && cutMatch.group(1) != null) {
    targetCutDate = cutMatch.group(1)!.trim();
    text = text.replaceAll(RegExp(r'\[TARGET_CUT_DATE:\s*[\s\S]*?\]\s*', caseSensitive: false), '');
  }

  text = text.replaceAll(RegExp(r'\[INSTRUCTIONS:\s*[\s\S]*?\]\s*', caseSensitive: false), '');
  final cleanFabric = text.trim().isEmpty ? '100% Combed Cotton Single Jersey' : text.trim();

  return ParsedFabricResult(
    cleanFabric: cleanFabric,
    targetCutDate: targetCutDate,
    materials: materials,
  );
}

/// Avatar Initials Formatter matching web `getBuyerAvatarInitials`:
/// - 1 word: First + Last letter (e.g. Hollypop -> HP, Ollywood -> OD)
/// - 2+ words: First letter of first two words
String getBuyerAvatarInitials(String? name) {
  if (name == null || name.trim().isEmpty) return 'BY';
  final cleaned = name.replaceAll(RegExp(r'[^\w\s]'), '').trim();
  final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'BY';
  if (words.length == 1) {
    final w = words.first;
    if (w.length <= 1) return w.toUpperCase();
    return '${w[0]}${w[w.length - 1]}'.toUpperCase();
  }
  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

String formatEmbellishmentSequence(String? seq) {
  if (seq == null || seq.isEmpty || seq == 'NONE') {
    return 'No Embroidery, No Printing (Cut & Sew)';
  }
  switch (seq) {
    case 'ONLY_PRINTING':
      return 'Only Printing';
    case 'ONLY_EMBROIDERY':
      return 'Only Embroidery';
    case 'EMBROIDERY_FIRST_THEN_PRINT':
      return 'Embroidery First, Then Printing';
    case 'PRINT_FIRST_THEN_EMBROIDERY':
      return 'Printing First, Then Embroidery';
    default:
      return seq;
  }
}

class ModuleIconOption {
  final String name;
  final String label;
  final IconData icon;

  const ModuleIconOption({
    required this.name,
    required this.label,
    required this.icon,
  });
}

const List<ModuleIconOption> kAvailableModuleIcons = [
  ModuleIconOption(name: 'Layers', label: 'Assembly', icon: Icons.layers_outlined),
  ModuleIconOption(name: 'Scissors', label: 'Cutting', icon: Icons.content_cut_rounded),
  ModuleIconOption(name: 'Wrench', label: 'Mechanical', icon: Icons.build_outlined),
  ModuleIconOption(name: 'Boxes', label: 'Packaging', icon: Icons.inventory_2_outlined),
  ModuleIconOption(name: 'Sparkles', label: 'Detailing', icon: Icons.auto_awesome_outlined),
  ModuleIconOption(name: 'Printer', label: 'Printing', icon: Icons.print_outlined),
  ModuleIconOption(name: 'Flame', label: 'Heat/Iron', icon: Icons.local_fire_department_outlined),
  ModuleIconOption(name: 'Waves', label: 'Wash/Wet', icon: Icons.waves_rounded),
  ModuleIconOption(name: 'Store', label: 'Storage', icon: Icons.store_outlined),
  ModuleIconOption(name: 'Truck', label: 'Logistics', icon: Icons.local_shipping_outlined),
  ModuleIconOption(name: 'Palette', label: 'Design', icon: Icons.palette_outlined),
  ModuleIconOption(name: 'Briefcase', label: 'Commercial', icon: Icons.work_outline_rounded),
];

IconData iconDataForModuleIconName(String? iconName) {
  for (final opt in kAvailableModuleIcons) {
    if (opt.name.toLowerCase() == (iconName ?? '').trim().toLowerCase()) {
      return opt.icon;
    }
  }
  return Icons.layers_outlined;
}

class TechPackSpec {
  final String styleNumber;
  final String category;
  final String cadFrontUrl;
  final String cadBackUrl;
  final String fabricComposition;
  final int targetGsm;
  final String embellishmentSequence;
  final List<ParsedBomMaterial> bomMaterials;
  final String constructionNotes;

  const TechPackSpec({
    required this.styleNumber,
    required this.category,
    this.cadFrontUrl = '',
    this.cadBackUrl = '',
    required this.fabricComposition,
    this.targetGsm = 180,
    this.embellishmentSequence = 'ONLY_EMBROIDERY',
    this.bomMaterials = const [],
    this.constructionNotes = '',
  });
}

class ColorMatrixRow {
  final String color;
  final Map<String, int> sizes;
  final int total;

  const ColorMatrixRow({
    required this.color,
    required this.sizes,
    required this.total,
  });
}

class BuyerContractSpec {
  final String poNumber;
  final String buyerName;
  final double fobPrice;
  final String currency;
  final double totalContractValue;
  final String season;
  final String orderDate;
  final String deliveryDate;
  final String commercialStatus;
  final List<ColorMatrixRow> colorMatrix;

  const BuyerContractSpec({
    required this.poNumber,
    required this.buyerName,
    required this.fobPrice,
    this.currency = 'INR',
    required this.totalContractValue,
    this.season = 'SS 2026',
    this.orderDate = '',
    this.deliveryDate = '',
    this.commercialStatus = 'CONFIRMED',
    this.colorMatrix = const [],
  });
}

class LiveFloorReviewSpec {
  final int inPending;
  final int inCutting;
  final int inPrinting;
  final int inEmbroidery;
  final int inSewing;
  final int iron;
  final int washing;
  final int alter;

  const LiveFloorReviewSpec({
    this.inPending = 0,
    this.inCutting = 0,
    this.inPrinting = 0,
    this.inEmbroidery = 0,
    this.inSewing = 0,
    this.iron = 0,
    this.washing = 0,
    this.alter = 0,
  });
}

class BuyerArticleHistory {
  final String id;
  final String challanId;
  final String challanNo;
  final String contractDate;
  final String deliveryDate;
  final String fabricType;
  final bool sampleGiven;
  final String challanNotes;
  final String artNo;
  final String subArtNo;
  final String patternNo;
  final String category;
  final String product;
  final String description;
  final String colorPattern;
  final String sizeRange;
  final int assignedQty;
  final int deliveredQty;
  final int sets;
  final int pcsPerSet;
  final double? stitchingRate;
  final String assignedLinemanName;
  final String status; // 'PENDING' | 'IN_PRODUCTION' | 'QC_PASSED' | 'DELIVERED' | 'DISPATCHED'
  final String sourceType; // 'PRODUCTION_CHALLAN' | 'MERCHANDISING_PO'
  final String pictureUrl;
  final String createdAt;
  final TechPackSpec techPack;
  final BuyerContractSpec contract;
  final LiveFloorReviewSpec floorReview;

  const BuyerArticleHistory({
    required this.id,
    required this.challanId,
    required this.challanNo,
    required this.contractDate,
    this.deliveryDate = '',
    required this.fabricType,
    this.sampleGiven = false,
    this.challanNotes = '',
    required this.artNo,
    this.subArtNo = '',
    this.patternNo = '',
    this.category = '',
    this.product = '',
    this.description = '',
    this.colorPattern = 'Standard',
    this.sizeRange = 'Free Size',
    required this.assignedQty,
    this.deliveredQty = 0,
    this.sets = 1,
    this.pcsPerSet = 0,
    this.stitchingRate,
    this.assignedLinemanName = '',
    required this.status,
    required this.sourceType,
    this.pictureUrl = '',
    this.createdAt = '',
    required this.techPack,
    required this.contract,
    required this.floorReview,
  });
}

class BuyerItem {
  final String id;
  final String brandCode;
  final String brandName;
  final String contactPerson;
  final String phone;
  final String email;
  final String city;
  final String address;
  final String gstin;
  final String companyName;
  final bool isActive;
  final String createdAt;
  final int totalContractsCount;
  final int totalArticlesCount;
  final int totalAssignedPieces;
  final int totalDeliveredPieces;
  final int deliveryPercentage;
  final List<BuyerArticleHistory> articles;

  const BuyerItem({
    required this.id,
    required this.brandCode,
    required this.brandName,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.city = '',
    this.address = '',
    this.gstin = '',
    required this.companyName,
    this.isActive = true,
    this.createdAt = '',
    required this.totalContractsCount,
    required this.totalArticlesCount,
    required this.totalAssignedPieces,
    required this.totalDeliveredPieces,
    required this.deliveryPercentage,
    this.articles = const [],
  });
}

class AssignedVendorInfo {
  final String id;
  final String companyName;
  final String contactPerson;
  final String phone;
  final String notes;
  final bool isActive;
  final String? createdAt;

  const AssignedVendorInfo({
    required this.id,
    required this.companyName,
    required this.contactPerson,
    required this.phone,
    this.notes = '',
    this.isActive = true,
    this.createdAt,
  });
}

class ModuleVendorItem {
  final String id;
  final String moduleRoute;
  final String moduleCode;
  final String moduleName;
  final String defaultDesignation;
  final String iconName;
  final String description;
  final bool isCustom;
  final AssignedVendorInfo? assignedVendor;

  const ModuleVendorItem({
    required this.id,
    required this.moduleRoute,
    required this.moduleCode,
    required this.moduleName,
    required this.defaultDesignation,
    required this.iconName,
    required this.description,
    this.isCustom = false,
    this.assignedVendor,
  });

  ModuleVendorItem copyWith({
    AssignedVendorInfo? assignedVendor,
    bool clearVendor = false,
  }) {
    return ModuleVendorItem(
      id: id,
      moduleRoute: moduleRoute,
      moduleCode: moduleCode,
      moduleName: moduleName,
      defaultDesignation: defaultDesignation,
      iconName: iconName,
      description: description,
      isCustom: isCustom,
      assignedVendor: clearVendor ? null : (assignedVendor ?? this.assignedVendor),
    );
  }
}

class BuyersVendorsSummary {
  final int totalBuyers;
  final int activeBuyers;
  final int totalContracts;
  final int totalArticlesContracted;
  final int totalAssignedPieces;
  final int totalDeliveredPieces;
  final int overallDeliveryPercentage;
  final int assignedModulesCount;
  final int totalModulesCount;

  const BuyersVendorsSummary({
    this.totalBuyers = 0,
    this.activeBuyers = 0,
    this.totalContracts = 0,
    this.totalArticlesContracted = 0,
    this.totalAssignedPieces = 0,
    this.totalDeliveredPieces = 0,
    this.overallDeliveryPercentage = 0,
    this.assignedModulesCount = 0,
    this.totalModulesCount = 12,
  });
}
