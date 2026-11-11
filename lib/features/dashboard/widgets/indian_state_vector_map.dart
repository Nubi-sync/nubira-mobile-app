import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
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
final Map<String, ui.Image> _geoRasterCache = {};
final Set<String> _pendingRasterKeys = {};

final RegExp _svgCmdRegex = RegExp(r'([MLZmlz])([^MLZmlz]*)');
final RegExp _svgSepRegex = RegExp(r'[\s,]+');

class _SvgCommand {
  final int type; // 0 = M, 1 = L, 2 = Z
  final Float64List coords;

  const _SvgCommand(this.type, this.coords);
}

class _ParsedDistrict {
  final String name;
  final List<_SvgCommand> commands;

  const _ParsedDistrict(this.name, this.commands);
}

class _ParsedGeoPayload {
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
  final List<_ParsedDistrict> districts;

  const _ParsedGeoPayload({
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

List<_SvgCommand> _parseSvgCommands(String d) {
  final commands = <_SvgCommand>[];
  for (final match in _svgCmdRegex.allMatches(d)) {
    final cmd = match.group(1);
    if (cmd == 'Z' || cmd == 'z') {
      commands.add(_SvgCommand(2, Float64List(0)));
      continue;
    }

    final argsStr = match.group(2)?.trim() ?? '';
    if (argsStr.isEmpty) continue;

    final rawNumbers = argsStr.split(_svgSepRegex);
    final numbers = <double>[];
    for (final s in rawNumbers) {
      final n = double.tryParse(s);
      if (n != null) numbers.add(n);
    }
    if (numbers.isEmpty) continue;

    final type = (cmd == 'M' || cmd == 'm') ? 0 : 1;
    commands.add(_SvgCommand(type, Float64List.fromList(numbers)));
  }
  return commands;
}

Path _buildPathFromCommands(List<_SvgCommand> commands) {
  final path = Path();
  for (final cmd in commands) {
    if (cmd.type == 2) {
      path.close();
      continue;
    }
    final coords = cmd.coords;
    if (cmd.type == 0) {
      if (coords.length >= 2) {
        path.moveTo(coords[0], coords[1]);
        for (int i = 2; i + 1 < coords.length; i += 2) {
          path.lineTo(coords[i], coords[i + 1]);
        }
      }
    } else {
      for (int i = 0; i + 1 < coords.length; i += 2) {
        path.lineTo(coords[i], coords[i + 1]);
      }
    }
  }
  return path;
}

_ParsedGeoPayload _parseGeoJsonPayload(String jsonStr, String fallbackSlug) {
  final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
  final bounds = data['bounds'] as Map<String, dynamic>? ?? {};
  final rawDistricts = (data['districts'] as List<dynamic>?) ?? [];
  final parsedDistricts = <_ParsedDistrict>[];

  for (final item in rawDistricts) {
    final name = item['name']?.toString() ?? '';
    final d = item['d']?.toString() ?? '';
    if (d.isNotEmpty) {
      parsedDistricts.add(_ParsedDistrict(name, _parseSvgCommands(d)));
    }
  }

  return _ParsedGeoPayload(
    state: data['state']?.toString() ?? 'Delhi',
    slug: data['slug']?.toString() ?? fallbackSlug,
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
}

Path parseSvgPath(String d) => _buildPathFromCommands(_parseSvgCommands(d));

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
        final rawJson = jsonStr;
        final parsed = kIsWeb
            ? _parseGeoJsonPayload(rawJson, slug)
            : await Isolate.run(() => _parseGeoJsonPayload(rawJson, slug));

        final parsedDistricts = <StateDistrictData>[
          for (final item in parsed.districts)
            StateDistrictData(
              name: item.name,
              path: _buildPathFromCommands(item.commands),
            ),
        ];

        final parsedGeo = StateGeoData(
          state: parsed.state,
          slug: parsed.slug,
          width: parsed.width,
          height: parsed.height,
          minLon: parsed.minLon,
          maxLon: parsed.maxLon,
          minLat: parsed.minLat,
          maxLat: parsed.maxLat,
          k: parsed.k,
          scale: parsed.scale,
          pad: parsed.pad,
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

  void _ensureRasterized(StateGeoData geo, Size logicalSize, double dpr, String cacheKey) {
    if (_geoRasterCache.containsKey(cacheKey) || _pendingRasterKeys.contains(cacheKey)) {
      return;
    }
    if (logicalSize.width <= 0 || logicalSize.height <= 0) return;

    _pendingRasterKeys.add(cacheKey);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final pixelW = math.max(1, (logicalSize.width * dpr).round());
        final pixelH = math.max(1, (logicalSize.height * dpr).round());
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.scale(dpr, dpr);
        _paintDistrictLayers(canvas, logicalSize, geo);
        final picture = recorder.endRecording();
        final image = await picture.toImage(pixelW, pixelH);
        picture.dispose();

        if (_geoRasterCache.length >= 4) {
          final oldestKey = _geoRasterCache.keys.first;
          final evicted = _geoRasterCache.remove(oldestKey);
          if (evicted != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => evicted.dispose());
          }
        }
        _geoRasterCache[cacheKey] = image;
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint('[IndianStateVectorMap] Raster cache error: $e');
      } finally {
        _pendingRasterKeys.remove(cacheKey);
      }
    });
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
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                              ? constraints.maxWidth
                              : 320.0;
                          const height = 340.0;
                          final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
                          final cacheKey = '${_geo!.slug}_${width.round()}x340_${dpr.toStringAsFixed(2)}';
                          final cachedImage = _geoRasterCache[cacheKey];
                          if (cachedImage == null) {
                            _ensureRasterized(_geo!, Size(width, height), dpr, cacheKey);
                          }
                          return RepaintBoundary(
                            child: CustomPaint(
                              size: Size(width, height),
                              isComplex: true,
                              willChange: false,
                              painter: StateVectorMapPainter(
                                geo: _geo!,
                                pin: _calculatePin(_geo!),
                                cachedImage: cachedImage,
                              ),
                            ),
                          );
                        },
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

({double scale, double offsetX, double offsetY}) _computeMapTransform(Size size, StateGeoData geo) {
  final scaleX = size.width / geo.width;
  final scaleY = size.height / geo.height;
  final scale = math.min(scaleX, scaleY);
  return (
    scale: scale,
    offsetX: (size.width - geo.width * scale) / 2,
    offsetY: (size.height - geo.height * scale) / 2,
  );
}

void _paintDistrictLayers(Canvas canvas, Size size, StateGeoData geo) {
  if (geo.width <= 0 || geo.height <= 0) return;

  final t = _computeMapTransform(size, geo);
  canvas.save();
  canvas.translate(t.offsetX, t.offsetY);
  canvas.scale(t.scale, t.scale);

  // Layer 1: thick black stroke for outer boundary
  final outerBorderPaint = Paint()
    ..color = const Color(0xFF0B1220)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2 / t.scale
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
    ..strokeWidth = 0.7 / t.scale
    ..strokeJoin = StrokeJoin.round;

  for (final d in geo.districts) {
    canvas.drawPath(d.path, fillPaint);
    canvas.drawPath(d.path, innerBorderPaint);
  }

  canvas.restore();
}

class StateVectorMapPainter extends CustomPainter {
  final StateGeoData geo;
  final Offset? pin;
  final ui.Image? cachedImage;

  StateVectorMapPainter({required this.geo, this.pin, this.cachedImage});

  @override
  void paint(Canvas canvas, Size size) {
    if (geo.width <= 0 || geo.height <= 0) return;

    if (cachedImage != null) {
      final src = Rect.fromLTWH(0, 0, cachedImage!.width.toDouble(), cachedImage!.height.toDouble());
      final dst = Offset.zero & size;
      canvas.drawImageRect(cachedImage!, src, dst, Paint()..filterQuality = FilterQuality.low);
    } else {
      _paintDistrictLayers(canvas, size, geo);
    }

    // Layer 3: Location pin (deep blue with crisp white border)
    if (pin != null) {
      final t = _computeMapTransform(size, geo);
      canvas.save();
      canvas.translate(t.offsetX, t.offsetY);
      canvas.scale(t.scale, t.scale);

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
          ..strokeWidth = 2.0 / t.scale,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant StateVectorMapPainter oldDelegate) {
    return oldDelegate.geo != geo ||
        oldDelegate.pin != pin ||
        oldDelegate.cachedImage != cachedImage;
  }
}

