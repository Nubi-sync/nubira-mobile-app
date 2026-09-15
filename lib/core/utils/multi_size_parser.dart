// lib/core/utils/multi_size_parser.dart
// Universal Multi-Size & Safety Buffer Parsing Utility for Flutter MES
// Mirroring enterprise-grade Garment MES logic for Trims, Accessories & Labels

class MultiSizeParseResult {
  final bool isMultiSize;
  final String cleanName;
  final List<String> sizes;
  final String? detectedPattern;

  const MultiSizeParseResult({
    required this.isMultiSize,
    required this.cleanName,
    required this.sizes,
    this.detectedPattern,
  });
}

class SizeBreakdownItem {
  final String size;
  final int qty;

  const SizeBreakdownItem({
    required this.size,
    required this.qty,
  });

  Map<String, dynamic> toMap() => {
    'size': size,
    'qty': qty,
  };
}

class SizeBreakdownResult {
  final bool isMultiSize;
  final List<String> sizes;
  final List<SizeBreakdownItem> sizeBreakdown;
  final int baseQty;
  final int bufferQty;
  final String cleanName;

  const SizeBreakdownResult({
    required this.isMultiSize,
    required this.sizes,
    required this.sizeBreakdown,
    required this.baseQty,
    required this.bufferQty,
    required this.cleanName,
  });
}

class MultiSizeParser {
  // Standard Alpha size order in Garment Manufacturing
  static const List<String> knownAlphaOrder = [
    'XXXS', 'XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '2XL', '3XL', '4XL', '5XL'
  ];

  /// Expand a size range like "XS-S" or "22-26" or "28-34"
  static List<String>? expandRange(String start, String end) {
    final numStart = int.tryParse(start);
    final numEnd = int.tryParse(end);

    if (numStart != null && numEnd != null && numStart < numEnd) {
      // Step is usually 2 in apparel e.g. 22, 24, 26 or 28, 30, 32, 34
      final diff = numEnd - numStart;
      final step = (diff % 2 == 0) ? 2 : 1;
      final result = <String>[];
      for (int n = numStart; n <= numEnd; n += step) {
        result.add(n.toString());
      }
      return result;
    }

    final alphaStartIdx = knownAlphaOrder.indexOf(start.toUpperCase());
    final alphaEndIdx = knownAlphaOrder.indexOf(end.toUpperCase());

    if (alphaStartIdx != -1 && alphaEndIdx != -1 && alphaStartIdx < alphaEndIdx) {
      return knownAlphaOrder.sublist(alphaStartIdx, alphaEndIdx + 1);
    }

    return null;
  }

  /// Extract clean tokens from a candidate string e.g. "XS,S", "M,L,XL,XXL", "22,24,26", "28-34"
  static List<String> extractTokens(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];

    // Check for range with hyphen e.g. "XS-S" or "22-26"
    final rangeRegex = RegExp(r'^([A-Za-z0-9]+)\s*-\s*([A-Za-z0-9]+)$');
    final match = rangeRegex.firstMatch(trimmed);
    if (match != null) {
      final expanded = expandRange(match.group(1)!, match.group(2)!);
      if (expanded != null && expanded.length > 1) return expanded;
      return [match.group(1)!.toUpperCase(), match.group(2)!.toUpperCase()];
    }

    // Split by comma, slash, or whitespace
    return trimmed
        .split(RegExp(r'[,/\s]+'))
        .map((t) => t.trim().toUpperCase())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Validate whether a list of tokens looks like a genuine size set
  static bool isValidSizeTokenList(List<String> tokens) {
    if (tokens.length < 2) return false;

    final allNumeric = tokens.every((t) => RegExp(r'^\d{2}$').hasMatch(t));
    if (allNumeric) {
      final nums = tokens.map((t) => int.parse(t)).toList();
      final inRange = nums.every((n) => n >= 14 && n <= 50);
      if (inRange) return true;
    }

    final allAlpha = tokens.every((t) => knownAlphaOrder.contains(t));
    if (allAlpha) return true;

    return tokens.every((t) => knownAlphaOrder.contains(t) || RegExp(r'^\d{2}$').hasMatch(t));
  }


  static MultiSizeParseResult parseMultiSizeTokens(String itemName, [String? sizeLabel]) {
    final rawItem = itemName.trim();
    final rawSize = (sizeLabel ?? '').trim();

    // 1. Check if sizeLabel itself contains multi-size tokens
    if (rawSize.isNotEmpty) {
      final tokensFromSize = extractTokens(rawSize);
      if (isValidSizeTokenList(tokensFromSize)) {
        return MultiSizeParseResult(
          isMultiSize: true,
          cleanName: rawItem,
          sizes: tokensFromSize,
          detectedPattern: rawSize,
        );
      }
    }

    // 2. Check for parentheses at end or inside itemName: e.g. "BODY- ... LABLE(M,L,XL,XXL)"
    final parenRegex = RegExp(r'\(([^)]+)\)$');
    final parenMatch = parenRegex.firstMatch(rawItem) ?? RegExp(r'\(([^)]+)\)').firstMatch(rawItem);
    if (parenMatch != null) {
      final inside = parenMatch.group(1)!;
      final tokens = extractTokens(inside);
      if (isValidSizeTokenList(tokens)) {
        final clean = rawItem.replaceFirst(parenMatch.group(0)!, '').trim();
        return MultiSizeParseResult(
          isMultiSize: true,
          cleanName: clean,
          sizes: tokens,
          detectedPattern: inside,
        );
      }
    }

    // 3. Check for comma/slash lists at end of itemName e.g. "LABLE 22,24,26" or "PANT- 28,30,32,34"
    final endListRegex = RegExp(r'(?:[\s\-_:])([A-Za-z0-9]+(?:[,/][A-Za-z0-9]+)+)$');
    final endListMatch = endListRegex.firstMatch(rawItem);
    if (endListMatch != null) {
      final candidate = endListMatch.group(1)!;
      final tokens = extractTokens(candidate);
      if (isValidSizeTokenList(tokens)) {
        final clean = rawItem.substring(0, endListMatch.start).trim();
        return MultiSizeParseResult(
          isMultiSize: true,
          cleanName: clean.isEmpty ? rawItem : clean,
          sizes: tokens,
          detectedPattern: candidate,
        );
      }
    }

    // Single size fallback or regular item
    return MultiSizeParseResult(
      isMultiSize: false,
      cleanName: rawItem,
      sizes: rawSize.isNotEmpty ? [rawSize.toUpperCase()] : const [],
    );
  }

  /// Calculate the Size Breakdown Matrix & Safety Buffer Reserve
  static ({List<SizeBreakdownItem> sizeBreakdown, int baseQty, int bufferQty}) calculateSizeBreakdown(
    int totalQty,
    List<String> sizes, [
    int? targetQty,
  ]) {
    final qty = totalQty < 0 ? 0 : totalQty;
    if (sizes.isEmpty) {
      return (sizeBreakdown: <SizeBreakdownItem>[], baseQty: qty, bufferQty: 0);
    }

    final count = sizes.length;
    int baseQuota = qty;
    int buffer = 0;

    if (targetQty != null && targetQty > 0 && qty > targetQty) {
      baseQuota = targetQty;
      buffer = qty - targetQty;
    } else {
      final remainder = qty % count;
      if (remainder > 0) {
        baseQuota = qty - remainder;
        buffer = remainder;
      } else {
        baseQuota = qty;
        buffer = 0;
      }
    }

    final perSize = (baseQuota / count).floor();
    final breakdown = sizes.map((size) => SizeBreakdownItem(size: size, qty: perSize)).toList();

    return (sizeBreakdown: breakdown, baseQty: baseQuota, bufferQty: buffer);
  }

  /// High-level helper to parse an item and get its complete breakdown
  static SizeBreakdownResult getDetailedItemBreakdown(
    String itemName,
    int totalQty, [
    String? sizeLabel,
    int? targetQty,
  ]) {
    final parsed = parseMultiSizeTokens(itemName, sizeLabel);
    if (!parsed.isMultiSize || parsed.sizes.isEmpty) {
      return SizeBreakdownResult(
        isMultiSize: false,
        sizes: parsed.sizes,
        sizeBreakdown: parsed.sizes.isNotEmpty
            ? [SizeBreakdownItem(size: parsed.sizes.first, qty: totalQty)]
            : const [],
        baseQty: totalQty,
        bufferQty: 0,
        cleanName: parsed.cleanName,
      );
    }

    final calc = calculateSizeBreakdown(totalQty, parsed.sizes, targetQty);
    return SizeBreakdownResult(
      isMultiSize: true,
      sizes: parsed.sizes,
      sizeBreakdown: calc.sizeBreakdown,
      baseQty: calc.baseQty,
      bufferQty: calc.bufferQty,
      cleanName: parsed.cleanName,
    );
  }
}
