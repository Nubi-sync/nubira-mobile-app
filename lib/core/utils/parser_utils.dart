// lib/core/utils/parser_utils.dart

/// Safe parsing utilities to prevent runtime type cast crashes across all dashboards and modals.
class ParserUtils {
  /// Safely extracts an integer quantity from any dynamic type (int, num, String, units like "1500 pcs", etc.)
  static int parseQty(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final clean = val.trim();
      if (clean.isEmpty) return fallback;
      final direct = int.tryParse(clean);
      if (direct != null) return direct;
      final d = double.tryParse(clean);
      if (d != null) return d.toInt();
      final match = RegExp(r'(\d+)').firstMatch(clean);
      if (match != null) {
        return int.tryParse(match.group(1)!) ?? fallback;
      }
    }
    return fallback;
  }

  /// Safely extracts a double value from any dynamic type (double, int, num, String like "45.50", "₹120.00", etc.)
  static double parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.trim();
      if (clean.isEmpty) return fallback;
      final direct = double.tryParse(clean);
      if (direct != null) return direct;
      final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(clean);
      if (match != null) {
        return double.tryParse(match.group(1)!) ?? fallback;
      }
    }
    return fallback;
  }

  /// Safely extracts a String from any dynamic type
  static String parseString(dynamic val, [String fallback = '']) {
    if (val == null) return fallback;
    return val.toString();
  }

  /// Safely converts a dynamic object to a String-keyed Map
  static Map<String, dynamic> parseMap(dynamic val) {
    if (val == null) return {};
    if (val is Map<String, dynamic>) return val;
    if (val is Map) return Map<String, dynamic>.from(val);
    return {};
  }

  /// Safely converts a dynamic object to a List
  static List<dynamic> parseList(dynamic val) {
    if (val == null) return [];
    if (val is List) return val;
    return [];
  }
}

/// Shorthand top-level functions for easy importing & clean syntax
int parseQty(dynamic val, [int fallback = 0]) => ParserUtils.parseQty(val, fallback);
double parseDouble(dynamic val, [double fallback = 0.0]) => ParserUtils.parseDouble(val, fallback);
String parseString(dynamic val, [String fallback = '']) => ParserUtils.parseString(val, fallback);
Map<String, dynamic> parseMap(dynamic val) => ParserUtils.parseMap(val);
List<dynamic> parseList(dynamic val) => ParserUtils.parseList(val);
