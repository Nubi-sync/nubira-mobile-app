import 'dart:convert';

class FabricAllocationItem {
  final String id;
  final String fabricType;
  final String color;
  final String supplierName;
  final double totalMeters;
  final int totalRolls;
  final double totalWeightKg;
  final String rackLocation;
  final String? notes;
  final String? bookedForArticle;
  final double bookedMeters;
  final double availableMeters;
  final int allocationPercentage;
  final String? articlePo;
  final String? buyerName;

  const FabricAllocationItem({
    required this.id,
    required this.fabricType,
    required this.color,
    required this.supplierName,
    required this.totalMeters,
    required this.totalRolls,
    required this.totalWeightKg,
    required this.rackLocation,
    this.notes,
    this.bookedForArticle,
    required this.bookedMeters,
    required this.availableMeters,
    required this.allocationPercentage,
    this.articlePo,
    this.buyerName,
  });

  FabricAllocationItem copyWith({
    String? bookedForArticle,
    bool clearBookedArticle = false,
    double? bookedMeters,
    double? availableMeters,
    int? allocationPercentage,
  }) {
    return FabricAllocationItem(
      id: id,
      fabricType: fabricType,
      color: color,
      supplierName: supplierName,
      totalMeters: totalMeters,
      totalRolls: totalRolls,
      totalWeightKg: totalWeightKg,
      rackLocation: rackLocation,
      notes: notes,
      bookedForArticle: clearBookedArticle ? null : (bookedForArticle ?? this.bookedForArticle),
      bookedMeters: bookedMeters ?? this.bookedMeters,
      availableMeters: availableMeters ?? this.availableMeters,
      allocationPercentage: allocationPercentage ?? this.allocationPercentage,
      articlePo: articlePo,
      buyerName: buyerName,
    );
  }
}

class TrimAllocationItem {
  final String id;
  final String itemName;
  final String category;
  final String unit;
  final int totalInStore;
  final String? assignedArticle;
  final int assignedQuantity;
  final int freeQuantity;
  final int allocationPercentage;
  final String? partyOrSupplier;
  final String? notes;

  const TrimAllocationItem({
    required this.id,
    required this.itemName,
    required this.category,
    required this.unit,
    required this.totalInStore,
    this.assignedArticle,
    required this.assignedQuantity,
    required this.freeQuantity,
    required this.allocationPercentage,
    this.partyOrSupplier,
    this.notes,
  });
}

class ActiveArticleOption {
  final String artNo;
  final String label;

  const ActiveArticleOption({
    required this.artNo,
    required this.label,
  });
}

class ParsedBomMaterial {
  final String component;
  final String item;
  final String consumption;
  final String placement;

  const ParsedBomMaterial({
    required this.component,
    required this.item,
    required this.consumption,
    required this.placement,
  });
}

class ParsedBomResult {
  final String cleanFabric;
  final List<ParsedBomMaterial> materials;

  const ParsedBomResult({
    required this.cleanFabric,
    required this.materials,
  });
}

String categorizeTrim(String name, [String? component]) {
  final combined = '$name ${component ?? ''}'.toLowerCase();
  if (combined.contains('label') || combined.contains('tag') || combined.contains('patch')) {
    return 'Labels & Tags';
  }
  if (combined.contains('button') ||
      combined.contains('snap') ||
      combined.contains('rivet') ||
      combined.contains('hook')) {
    return 'Buttons & Fasteners';
  }
  if (combined.contains('zip') || combined.contains('slider') || combined.contains('puller')) {
    return 'Zippers & Sliders';
  }
  if (combined.contains('thread') || combined.contains('yarn') || combined.contains('dori')) {
    return 'Sewing Threads';
  }
  if (combined.contains('polybag') ||
      combined.contains('box') ||
      combined.contains('carton') ||
      combined.contains('hanger')) {
    return 'Packaging';
  }
  if (combined.contains('tape') ||
      combined.contains('ribbon') ||
      combined.contains('elastic') ||
      combined.contains('cord')) {
    return 'Tapes & Elastics';
  }
  return 'Trims & Sundries';
}

String formatTrimDisplayName(String itemName, [String? componentType]) {
  final item = itemName.trim();
  final comp = (componentType ?? '').trim();

  if (comp.isEmpty) return item.isNotEmpty ? item : 'Trim Item';
  if (item.isEmpty) return comp;

  String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  final compLower = comp.toLowerCase();
  final itemLower = item.toLowerCase();

  if (compLower.contains('button') && !itemLower.contains('button')) {
    return '${cap(item)} Buttons';
  }
  if (compLower.contains('zip') && !itemLower.contains('zip')) {
    return '${cap(item)} Zipper';
  }
  if (compLower.contains('label') && !itemLower.contains('label')) {
    return '${cap(item)} (Label)';
  }
  if (compLower.contains('ribbon') && !itemLower.contains('ribbon')) {
    return '${cap(item)} (Ribbon)';
  }

  if (itemLower == compLower) return item;
  return '${cap(item)} ($comp)';
}

/// Parses `[BOM_JSON: [...]]` using balanced bracket matching (aligned with Web `parseBOMFromFabric`).
ParsedBomResult parseBOMFromFabric(String raw) {
  if (raw.trim().isEmpty) {
    return const ParsedBomResult(cleanFabric: '', materials: []);
  }

  final markerMatch = RegExp(r'\[BOM_JSON\s*:', caseSensitive: false).firstMatch(raw);
  final List<ParsedBomMaterial> materials = [];

  if (markerMatch != null) {
    int arrayStart = markerMatch.end;
    while (arrayStart < raw.length && raw[arrayStart].trim().isEmpty) {
      arrayStart++;
    }
    if (arrayStart < raw.length && raw[arrayStart] == '[') {
      int depth = 0;
      bool inString = false;
      bool escaped = false;
      int arrayEnd = -1;

      for (int i = arrayStart; i < raw.length; i++) {
        final ch = raw[i];
        if (escaped) {
          escaped = false;
          continue;
        }
        if (inString) {
          if (ch == r'\') {
            escaped = true;
          } else if (ch == '"') {
            inString = false;
          }
          continue;
        }
        if (ch == '"') {
          inString = true;
        } else if (ch == '[') {
          depth++;
        } else if (ch == ']') {
          depth--;
          if (depth == 0) {
            arrayEnd = i;
            break;
          }
        }
      }

      if (arrayEnd != -1) {
        try {
          final jsonStr = raw.substring(arrayStart, arrayEnd + 1);
          final dynamic decoded = jsonDecode(jsonStr);
          if (decoded is List) {
            for (final entry in decoded) {
              if (entry is Map) {
                final m = Map<String, dynamic>.from(entry);
                final comp = (m['component_type'] ?? m['item_name'] ?? 'Material').toString();
                final item = (m['item_name'] ?? m['specification'] ?? m['component_type'] ?? 'Trim').toString();
                final cons = m['consumption'] != null ? m['consumption'].toString() : '1';
                final place = (m['placement'] ?? 'Standard').toString();
                materials.add(ParsedBomMaterial(
                  component: comp,
                  item: item,
                  consumption: cons,
                  placement: place,
                ));
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  final clean = raw
      .replaceAll(RegExp(r'\[BOM_JSON:\s*\[[\s\S]*?\]\]'), '')
      .replaceAll(RegExp(r'\[TARGET_CUT_DATE:\s*[^\]]+\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\[INSTRUCTIONS:\s*[^\]]+\]', caseSensitive: false), '')
      .trim();

  return ParsedBomResult(cleanFabric: clean, materials: materials);
}

String getStoreAvatarInitials(String? name) {
  if (name == null || name.trim().isEmpty) return 'FS';
  final cleaned = name.replaceAll(RegExp(r'[^\w\s]'), '').trim();
  final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'FS';
  if (words.length == 1) {
    final w = words.first;
    if (w.length <= 1) return w.toUpperCase();
    return (w[0] + w[w.length - 1]).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

