import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'delhi_geo_fallback.dart';

const Map<String, String> _stateAliases = {
  'andaman and nicobar': 'andaman-and-nicobar-islands',
  'andaman and nicobar islands': 'andaman-and-nicobar-islands',
  'andhra pradesh': 'andhra-pradesh',
  'arunachal pradesh': 'arunachal-pradesh',
  'assam': 'assam',
  'bihar': 'bihar',
  'chandigarh': 'chandigarh',
  'chhattisgarh': 'chhattisgarh',
  'chattisgarh': 'chhattisgarh',
  'delhi': 'delhi',
  'new delhi': 'delhi',
  'nct of delhi': 'delhi',
  'national capital territory of delhi': 'delhi',
  'dadra and nagar haveli': 'dnh-and-dd',
  'daman and diu': 'dnh-and-dd',
  'dadra and nagar haveli and daman and diu': 'dnh-and-dd',
  'goa': 'goa',
  'gujarat': 'gujarat',
  'haryana': 'haryana',
  'himachal pradesh': 'himachal-pradesh',
  'jammu and kashmir': 'jammu-and-kashmir',
  'jharkhand': 'jharkhand',
  'karnataka': 'karnataka',
  'kerala': 'kerala',
  'ladakh': 'ladakh',
  'lakshadweep': 'lakshadweep',
  'madhya pradesh': 'madhya-pradesh',
  'maharashtra': 'maharashtra',
  'manipur': 'manipur',
  'meghalaya': 'meghalaya',
  'mizoram': 'mizoram',
  'nagaland': 'nagaland',
  'odisha': 'odisha',
  'orissa': 'odisha',
  'puducherry': 'puducherry',
  'pondicherry': 'puducherry',
  'punjab': 'punjab',
  'rajasthan': 'rajasthan',
  'sikkim': 'sikkim',
  'tamil nadu': 'tamil-nadu',
  'telangana': 'telangana',
  'tripura': 'tripura',
  'uttar pradesh': 'uttar-pradesh',
  'uttarakhand': 'uttarakhand',
  'uttaranchal': 'uttarakhand',
  'west bengal': 'west-bengal'
};

String? resolveStateSlug(String? name) {
  if (name == null || name.isEmpty) return null;
  final key = name
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (key.isEmpty) return null;
  if (_stateAliases.containsKey(key)) return _stateAliases[key];
  for (final entry in _stateAliases.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return null;
}

class StateDistrictData {
  final String name;
  final Path path;

  StateDistrictData({required this.name, required this.path});
}

class StateGeoData {
  final String state;
  final String slug;
  final double width;
  final double height;
  final double minLon;
  final double maxLon;
  final double minLat;
  final double maxLat;
  final double k;
  final double scale;
  final double pad;
  final List<StateDistrictData> districts;

  StateGeoData({
    required this.state,
    required this.slug,
    required this.width,
    required this.height,
    required this.minLon,
    required this.maxLon,
    required this.minLat,
    required this.maxLat,
    required this.k,
    required this.scale,
    required this.pad,
    required this.districts,
  });
}

final Map<String, StateGeoData> _geoCache = {};

Path parseSvgPath(String d) {
  final path = Path();
  final regExp = RegExp(r'([MLZmlz])([^MLZmlz]*)');
  final matches = regExp.allMatches(d);

  for (final match in matches) {
    final cmd = match.group(1);
    final argsStr = match.group(2)?.trim() ?? '';

    if (cmd == 'Z' || cmd == 'z') {
      path.close();
      continue;
    }

    if (argsStr.isEmpty) continue;

    final rawNumbers = argsStr.split(RegExp(r'[\s,]+'));
    final numbers = <double>[];
    for (final s in rawNumbers) {
      final n = double.tryParse(s);
      if (n != null) numbers.add(n);
    }

    if (cmd == 'M' || cmd == 'm') {
      if (numbers.length >= 2) {
        path.moveTo(numbers[0], numbers[1]);
        for (int i = 2; i + 1 < numbers.length; i += 2) {
          path.lineTo(numbers[i], numbers[i + 1]);
        }
      }
    } else if (cmd == 'L' || cmd == 'l') {
      for (int i = 0; i + 1 < numbers.length; i += 2) {
        path.lineTo(numbers[i], numbers[i + 1]);
      }
    }
  }

  return path;
}

class IndianStateVectorMapWidget extends StatefulWidget {
  final String stateName;
  final String cityName;
  final double? latitude;
  final double? longitude;

  const IndianStateVectorMapWidget({
    super.key,
    required this.stateName,
    required this.cityName,
    this.latitude,
    this.longitude,
  });

  @override
  State<IndianStateVectorMapWidget> createState() => _IndianStateVectorMapWidgetState();
}

class _IndianStateVectorMapWidgetState extends State<IndianStateVectorMapWidget> {
  StateGeoData? _geo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStateGeo();
  }

  @override
  void didUpdateWidget(covariant IndianStateVectorMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stateName != widget.stateName) {
      _loadStateGeo();
    }
  }

  Future<void> _loadStateGeo() async {
    final slug = resolveStateSlug(widget.stateName) ?? 'delhi';

    if (_geoCache.containsKey(slug)) {
      if (mounted) {
        setState(() {
          _geo = _geoCache[slug];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    String? jsonStr;
    try {
      jsonStr = await rootBundle.loadString('assets/geo/states/$slug.json');
    } catch (_) {
      // Fallback for immediate hot reload before full restart
      if (slug == 'delhi') {
        jsonStr = delhiGeoJsonString;
      }
    }

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        final bounds = data['bounds'] as Map<String, dynamic>? ?? {};

        final rawDistricts = (data['districts'] as List<dynamic>?) ?? [];
        final parsedDistricts = <StateDistrictData>[];

        for (final item in rawDistricts) {
          final name = item['name']?.toString() ?? '';
          final d = item['d']?.toString() ?? '';
          if (d.isNotEmpty) {
            parsedDistricts.add(StateDistrictData(
              name: name,
              path: parseSvgPath(d),
            ));
          }
        }

        final parsedGeo = StateGeoData(
          state: data['state']?.toString() ?? 'Delhi',
          slug: data['slug']?.toString() ?? slug,
          width: (data['width'] as num?)?.toDouble() ?? 933,
          height: (data['height'] as num?)?.toDouble() ?? 1000,
          minLon: (bounds['minLon'] as num?)?.toDouble() ?? 76.838,
          maxLon: (bounds['maxLon'] as num?)?.toDouble() ?? 77.347,
          minLat: (bounds['minLat'] as num?)?.toDouble() ?? 28.404,
          maxLat: (bounds['maxLat'] as num?)?.toDouble() ?? 28.883,
          k: (data['k'] as num?)?.toDouble() ?? 0.877,
          scale: (data['scale'] as num?)?.toDouble() ?? 2036.5,
          pad: (data['pad'] as num?)?.toDouble() ?? 12,
          districts: parsedDistricts,
        );

        _geoCache[slug] = parsedGeo;

        if (mounted) {
          setState(() {
            _geo = parsedGeo;
            _isLoading = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('[IndianStateVectorMap] Error parsing geo json: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Offset? _calculatePin(StateGeoData geo) {
    // Real coordinates from IP/GPS or defaults for Delhi
    final lat = widget.latitude ?? (geo.slug == 'delhi' ? 28.6139 : null);
    final lon = widget.longitude ?? (geo.slug == 'delhi' ? 77.2090 : null);

    if (lat != null && lon != null) {
      final x = geo.pad + (lon - geo.minLon) * geo.k * geo.scale;
      final y = geo.pad + (geo.maxLat - lat) * geo.scale;
      if (x >= 0 && x <= geo.width && y >= 0 && y <= geo.height) {
        return Offset(x, y);
      }
    }
    // Default visually central coordinate if outside bounds
    return Offset(geo.width * 0.62, geo.height * 0.52);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _geo?.state.isNotEmpty == true ? _geo!.state : (widget.stateName.isNotEmpty ? widget.stateName : 'Delhi');
    final displayCity = widget.cityName.isNotEmpty ? widget.cityName : 'New Delhi';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR CURRENT LOCATION',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayCity,
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (_geo != null && _geo!.districts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: Text(
                    '${_geo!.districts.length} ${_geo!.slug == "delhi" ? "wards" : "districts"}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Vector Map Box
          Container(
            height: 340,
            width: double.infinity,
            alignment: Alignment.center,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0B1220), strokeWidth: 2),
                  )
                : (_geo != null
                    ? CustomPaint(
                        size: const Size(double.infinity, 340),
                        painter: StateVectorMapPainter(
                          geo: _geo!,
                          pin: _calculatePin(_geo!),
                        ),
                      )
                    : Center(
                        child: Text(
                          'Map unavailable for this region.',
                          style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      )),
          ),
        ],
      ),
    );
  }
}

class StateVectorMapPainter extends CustomPainter {
  final StateGeoData geo;
  final Offset? pin;

  StateVectorMapPainter({required this.geo, this.pin});

  @override
  void paint(Canvas canvas, Size size) {
    if (geo.width <= 0 || geo.height <= 0) return;

    final scaleX = size.width / geo.width;
    final scaleY = size.height / geo.height;
    final scale = math.min(scaleX, scaleY);
    final offsetX = (size.width - geo.width * scale) / 2;
    final offsetY = (size.height - geo.height * scale) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);

    // Layer 1: thick black stroke for outer boundary
    final outerBorderPaint = Paint()
      ..color = const Color(0xFF0B1220)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 / scale
      ..strokeJoin = StrokeJoin.round;

    for (final d in geo.districts) {
      canvas.drawPath(d.path, outerBorderPaint);
    }

    // Layer 2: district white fill + thin internal political boundaries
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final innerBorderPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7 / scale
      ..strokeJoin = StrokeJoin.round;

    for (final d in geo.districts) {
      canvas.drawPath(d.path, fillPaint);
      canvas.drawPath(d.path, innerBorderPaint);
    }

    // Layer 3: Location pin (deep blue with crisp white border)
    if (pin != null) {
      final pinRadius = math.max(geo.width, geo.height) / 95;
      canvas.drawCircle(
        pin!,
        pinRadius,
        Paint()
          ..color = const Color(0xFF1D4ED8)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pin!,
        pinRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / scale,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StateVectorMapPainter oldDelegate) {
    return oldDelegate.geo != geo || oldDelegate.pin != pin;
  }
}

