import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../../main.dart';

class QcDashboard extends ConsumerStatefulWidget {
  const QcDashboard({super.key});

  @override
  ConsumerState<QcDashboard> createState() => _QcDashboardState();
}

class _QcDashboardState extends ConsumerState<QcDashboard> {
  // Named Constants for Tunable Thresholds
  static const double passRateHighThreshold = 90.0;
  static const double passRateMediumThreshold = 75.0;
  static const double mendingRateAlertThreshold = 0.10; // 10%

  bool _isLoading = true;

  int _totalReceivedToday = 0;
  int _totalCheckedToday = 0;
  int _totalPassedToday = 0;
  int _totalInMendingToday = 0;
  int _totalPackedToday = 0;

  List<dynamic> _linemen = [];
  List<dynamic> _articles = [];
  List<dynamic> _allotments = [];
  List<dynamic> _allotmentMaterials = [];
  List<dynamic> _allotmentVariants = [];
  List<dynamic> _workerAssignments = [];
  List<dynamic> _activeMendingList = [];
  List<dynamic> _recentQcLogs = [];

  final List<Map<String, String>> _defectTypes = [
    {'key': 'NONE', 'label': 'No Defect (Clean)'},
    {'key': 'STITCHING_ERROR', 'label': 'Stitching / Skip Seam'},
    {'key': 'FABRIC_STAIN', 'label': 'Fabric Stain / Oil'},
    {'key': 'SIZING_ISSUE', 'label': 'Sizing / Fit Issue'},
    {'key': 'MEASUREMENT_OFF', 'label': 'Measurement Off'},
    {'key': 'FABRIC_CUT', 'label': 'Fabric Cut / Hole'},
    {'key': 'COLOR_SHADING', 'label': 'Color Shading'},
    {'key': 'OTHER', 'label': 'Other Minor Issue'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchQcData();
  }

  // TODO: Read explicit shift-assignment from user profile when shift model is added to schema
  String _getShiftName() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 14) {
      return 'Morning shift';
    } else if (hour >= 14 && hour < 22) {
      return 'Evening shift';
    } else {
      return 'Night shift';
    }
  }

  Future<void> _fetchQcData() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final linemenRes = await supabase
          .from('profiles')
          .select('id, username')
          .eq('role', 'LINEMAN')
          .eq('is_active', true)
          .order('username');

      // Fetch active allotments
      List<dynamic> allotmentsRes = [];
      try {
        allotmentsRes = await supabase
            .from('allotments')
            .select('id, challan_id, article_id, lineman_id, status');
      } catch (e) {
        debugPrint('Allotments fetch error: $e');
      }

      // Fetch allotment variants
      List<dynamic> variantsRes = [];
      try {
        variantsRes = await supabase
            .from('allotment_variants')
            .select('id, allotment_id, color, size, quantity');
      } catch (e) {
        debugPrint('Allotment variants fetch error: $e');
      }

      // Fetch worker assignments
      List<dynamic> workerAssRes = [];
      try {
        workerAssRes = await supabase
            .from('worker_assignments')
            .select('id, allotment_id, article_id, lineman_id, color, size');
      } catch (e) {
        debugPrint('Worker assignments fetch error: $e');
      }

      // Fetch allotment materials containing lineman and article metadata in notes
      List<dynamic> materialsRes = [];
      try {
        materialsRes = await supabase
            .from('allotment_materials')
            .select('id, allotment_id, item_name, required_qty, notes');
      } catch (e) {
        debugPrint('Allotment materials fetch error: $e');
      }

      final articlesRes = await supabase
          .from('articles')
          .select('id, art_no, description')
          .eq('is_active', true)
          .order('art_no');

      final logsRes = await supabase
          .from('qc_logs')
          .select('''
            id,
            article_id,
            stage,
            from_lineman_id,
            qty_received,
            qty_passed,
            qty_rejected,
            defect_type,
            remarks,
            color,
            size,
            mending_returned_qty,
            mending_scrap_qty,
            mending_status,
            bundle_size,
            total_bundles,
            sent_to_store,
            entry_date,
            created_at,
            lineman:profiles!qc_logs_from_lineman_id_fkey ( username ),
            article:articles ( art_no, description )
          ''')
          .eq('entry_date', today)
          .order('created_at', ascending: false);

      int rec = 0;
      int checked = 0;
      int passed = 0;
      int inMending = 0;
      int packed = 0;

      final List<dynamic> activeMending = [];

      for (var log in logsRes) {
        final stage = log['stage'] as String? ?? '';
        final qRec = (log['qty_received'] as int?) ?? 0;
        final qPass = (log['qty_passed'] as int?) ?? 0;
        final qRej = (log['qty_rejected'] as int?) ?? 0;
        final mendRet = (log['mending_returned_qty'] as int?) ?? 0;
        final mendStatus = log['mending_status'] as String? ?? 'NONE';
        final bSize = (log['bundle_size'] as int?) ?? 0;
        final tBundles = (log['total_bundles'] as int?) ?? 0;

        if (stage == 'RECEIVING') {
          rec += qRec;
        } else if (stage == 'CHECKING') {
          checked += (qPass + qRej);
          passed += qPass;
          if (qRej > 0) {
            if (mendStatus == 'REPAIR_COMPLETED') {
              passed += mendRet;
            } else {
              inMending += qRej;
              activeMending.add(log);
            }
          }
        } else if (stage == 'MENDING') {
          if (mendStatus == 'REPAIR_COMPLETED') {
            passed += mendRet;
          } else {
            inMending += qRej;
            activeMending.add(log);
          }
        } else if (stage == 'BULKING') {
          packed += (bSize * tBundles);
        }
      }

      if (mounted) {
        setState(() {
          _linemen = linemenRes;
          _articles = articlesRes;
          _allotments = allotmentsRes;
          _allotmentMaterials = materialsRes;
          _allotmentVariants = variantsRes;
          _workerAssignments = workerAssRes;
          _recentQcLogs = logsRes;
          _activeMendingList = activeMending;
          _totalReceivedToday = rec;
          _totalCheckedToday = checked;
          _totalPassedToday = passed;
          _totalInMendingToday = inMending;
          _totalPackedToday = packed;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading QC data: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  
  String _getCleanArticleDescription(String? desc) {
    if (desc == null || desc.trim().isEmpty) return '';
    return desc.replaceAll(RegExp(r'\s*\[.*\]'), '').trim();
  }




  // ==========================================
  // HELPER: GET MATCHING ALLOTMENT IDS FOR LINEMAN & ARTICLE
  // ==========================================
  Set<String> _getMatchingAllotmentIds(String? articleId, String? linemanId) {
    final Set<String> matching = {};

    // Find lineman username and article art_no for cross-metadata matching (100% type safe)
    String? linemanUsername;
    if (linemanId != null) {
      for (var l in _linemen) {
        if (l['id']?.toString() == linemanId) {
          linemanUsername = l['username']?.toString().toLowerCase().trim();
          break;
        }
      }
    }

    String? articleArtNo;
    if (articleId != null) {
      for (var a in _articles) {
        if (a['id']?.toString() == articleId) {
          articleArtNo = a['art_no']?.toString().trim();
          break;
        }
      }
    }

    // 1. From allotment materials JSON notes (supports lineman_id and lineman_name)
    for (var m in _allotmentMaterials) {
      try {
        final notes = m['notes']?.toString() ?? '';
        if (notes.startsWith('{')) {
          final map = jsonDecode(notes);
          final lId = map['lineman_id']?.toString() ?? '';
          final lName = map['lineman_name']?.toString().toLowerCase().trim() ?? '';
          final artId = map['article_id']?.toString() ?? '';
          final aNo = map['art_no']?.toString().trim() ?? '';

          final lmMatches = linemanId == null ||
              (lId.isNotEmpty && lId == linemanId) ||
              (linemanUsername != null && lName.isNotEmpty && lName == linemanUsername);

          final artMatches = articleId == null ||
              (artId.isNotEmpty && artId == articleId) ||
              (articleArtNo != null && aNo.isNotEmpty && aNo == articleArtNo) ||
              (artId.isEmpty && aNo.isEmpty); // Include materials belonging to this lineman's lot

          if (lmMatches && artMatches) {
            final aId = m['allotment_id']?.toString() ?? '';
            if (aId.isNotEmpty) matching.add(aId);
          }
        }
      } catch (_) {}
    }

    // 2. From allotments table
    for (var a in _allotments) {
      final artId = a['article_id']?.toString() ?? '';
      final lId = a['lineman_id']?.toString() ?? '';
      if ((articleId == null || artId == articleId) && (linemanId == null || lId == linemanId)) {
        final aId = a['id']?.toString() ?? '';
        if (aId.isNotEmpty) matching.add(aId);
      }
    }

    // 3. From worker assignments
    for (var w in _workerAssignments) {
      final artId = w['article_id']?.toString() ?? '';
      final lId = w['lineman_id']?.toString() ?? '';
      if ((articleId == null || artId == articleId || artId.isEmpty) && (linemanId == null || lId == linemanId)) {
        final aId = w['allotment_id']?.toString() ?? '';
        if (aId.isNotEmpty) matching.add(aId);
      }
    }

    return matching;
  }

  // ==========================================
  // HELPER: GET ARTICLES ASSIGNED TO LINEMAN
  // ==========================================
  List<dynamic> _getArticlesForLineman(String? linemanId) {
    if (linemanId == null) return _articles;

    final Set<String> assignedArticleIds = {};

    // 1. Check from allotment materials metadata (notes json)
    for (var m in _allotmentMaterials) {
      try {
        final notes = m['notes']?.toString() ?? '';
        if (notes.startsWith('{')) {
          final map = jsonDecode(notes);
          if (map['lineman_id']?.toString() == linemanId) {
            final artId = map['article_id']?.toString() ?? '';
            if (artId.isNotEmpty) {
              assignedArticleIds.add(artId);
            }
          }
        }
      } catch (_) {}
    }

    // 2. Check from allotments table
    for (var a in _allotments) {
      if (a['lineman_id']?.toString() == linemanId) {
        final artId = a['article_id']?.toString() ?? '';
        if (artId.isNotEmpty) {
          assignedArticleIds.add(artId);
        }
      }
    }

    // 3. Check from worker assignments
    for (var w in _workerAssignments) {
      if (w['lineman_id']?.toString() == linemanId) {
        final artId = w['article_id']?.toString() ?? '';
        if (artId.isNotEmpty) {
          assignedArticleIds.add(artId);
        }
      }
    }

    // If lineman has assigned articles, return ONLY those assigned styles
    if (assignedArticleIds.isNotEmpty) {
      final filtered = _articles.where((art) => assignedArticleIds.contains(art['id']?.toString())).toList();
      if (filtered.isNotEmpty) return filtered;
    }

    return _articles;
  }

  // ==========================================
  // HELPER: GET DYNAMIC COLORS FOR ARTICLE & LINEMAN
  // ==========================================
  List<String> _getColorsForArticle(String? articleId, {String? linemanId}) {
    if (articleId == null) return ['Navy Blue', 'Black', 'White', 'Melange Grey', 'Olive Green', 'Maroon'];

    final Set<String> colors = {};
    final matchingAllotmentIds = _getMatchingAllotmentIds(articleId, linemanId);

    // 1. Strict match from allotment_variants
    for (var v in _allotmentVariants) {
      final aId = v['allotment_id']?.toString() ?? '';
      if (matchingAllotmentIds.contains(aId)) {
        final c = v['color']?.toString().trim();
        if (c != null && c.isNotEmpty && c.toLowerCase() != 'standard' && c.toLowerCase() != 'default') {
          colors.add(c);
        }
      }
    }

    // 2. Worker assignments
    for (var w in _workerAssignments) {
      final artId = w['article_id']?.toString() ?? '';
      final lId = w['lineman_id']?.toString() ?? '';
      if ((artId == articleId || artId.isEmpty) && (linemanId == null || lId == linemanId)) {
        final c = w['color']?.toString().trim();
        if (c != null && c.isNotEmpty && c.toLowerCase() != 'standard' && c.toLowerCase() != 'default') {
          colors.add(c);
        }
      }
    }

    // 3. Fallback to all active variants for this article
    if (colors.isEmpty) {
      final allMatchingArt = _getMatchingAllotmentIds(articleId, null);
      for (var v in _allotmentVariants) {
        final aId = v['allotment_id']?.toString() ?? '';
        if (allMatchingArt.contains(aId)) {
          final c = v['color']?.toString().trim();
          if (c != null && c.isNotEmpty && c.toLowerCase() != 'standard' && c.toLowerCase() != 'default') {
            colors.add(c);
          }
        }
      }
    }

    // 4. Default palette
    if (colors.isEmpty) {
      return ['Navy Blue', 'Black', 'White', 'Melange Grey', 'Olive Green', 'Maroon'];
    }

    return colors.toList();
  }

  // ==========================================
  // HELPER: GET DYNAMIC SIZES FOR ARTICLE, COLOR & LINEMAN
  // ==========================================
  List<String> _getSizesForArticle(String? articleId, String? selectedColor, {String? linemanId}) {
    if (articleId == null) return ['S', 'M', 'L', 'XL', 'XXL'];

    final Set<String> sizes = {};
    final matchingAllotmentIds = _getMatchingAllotmentIds(articleId, linemanId);

    // 1. Strict match from allotment_variants
    for (var v in _allotmentVariants) {
      final aId = v['allotment_id']?.toString() ?? '';
      if (matchingAllotmentIds.contains(aId)) {
        final c = v['color']?.toString().trim();
        if (selectedColor == null || selectedColor.isEmpty || (c != null && c.toLowerCase() == selectedColor.toLowerCase())) {
          final s = v['size']?.toString().trim();
          if (s != null && s.isNotEmpty && s.toLowerCase() != 'standard') {
            sizes.add(s);
          }
        }
      }
    }

    // 2. Check worker assignments
    for (var w in _workerAssignments) {
      final artId = w['article_id']?.toString() ?? '';
      final lId = w['lineman_id']?.toString() ?? '';
      if ((artId == articleId || artId.isEmpty) && (linemanId == null || lId == linemanId)) {
        final c = w['color']?.toString().trim();
        if (selectedColor == null || selectedColor.isEmpty || (c != null && c.toLowerCase() == selectedColor.toLowerCase())) {
          final s = w['size']?.toString().trim();
          if (s != null && s.isNotEmpty && s.toLowerCase() != 'standard') {
            sizes.add(s);
          }
        }
      }
    }

    // 3. Fallback to all variants for this article
    if (sizes.isEmpty) {
      final allMatchingArt = _getMatchingAllotmentIds(articleId, null);
      for (var v in _allotmentVariants) {
        final aId = v['allotment_id']?.toString() ?? '';
        if (allMatchingArt.contains(aId)) {
          final c = v['color']?.toString().trim();
          if (selectedColor == null || selectedColor.isEmpty || (c != null && c.toLowerCase() == selectedColor.toLowerCase())) {
            final s = v['size']?.toString().trim();
            if (s != null && s.isNotEmpty && s.toLowerCase() != 'standard') {
              sizes.add(s);
            }
          }
        }
      }
    }

    // 4. Fallback to standard sizes
    if (sizes.isEmpty) {
      return ['S', 'M', 'L', 'XL', 'XXL'];
    }

    return sizes.toList();
  }

    void _showDailyReceivingModal() {
    String? selectedLinemanId = _linemen.isNotEmpty ? _linemen.first['id'] : null;
    final initialArticles = _getArticlesForLineman(selectedLinemanId);
    String? selectedArticleId = initialArticles.isNotEmpty ? initialArticles.first['id'] : (_articles.isNotEmpty ? _articles.first['id'] : null);

    String? selectedColor;
    String? selectedSize;

    final qtyController = TextEditingController();
    final remarksController = TextEditingController();

    String? linemanError;
    String? articleError;
    String? colorError;
    String? sizeError;
    String? qtyError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // 1. Cascading: Get articles assigned to this specific Lineman
          final availableArticles = _getArticlesForLineman(selectedLinemanId);
          if (selectedArticleId == null || !availableArticles.any((a) => a['id'] == selectedArticleId)) {
            selectedArticleId = availableArticles.isNotEmpty ? availableArticles.first['id'] : null;
          }

          // 2. Cascading: Get colors assigned to this Lineman + Article
          final availableColors = _getColorsForArticle(selectedArticleId, linemanId: selectedLinemanId);
          final displayColors = availableColors.isNotEmpty ? availableColors : <String>['Navy Blue', 'Black', 'White', 'Melange Grey', 'Olive Green', 'Maroon'];
          if (selectedColor == null || !displayColors.contains(selectedColor)) {
            selectedColor = displayColors.first;
          }

          // 3. Cascading: Get sizes assigned to this Lineman + Article + Color
          final availableSizes = _getSizesForArticle(selectedArticleId, selectedColor, linemanId: selectedLinemanId);
          final displaySizes = availableSizes.isNotEmpty ? availableSizes : <String>['S', 'M', 'L', 'XL', 'XXL'];
          if (selectedSize == null || !displaySizes.contains(selectedSize)) {
            selectedSize = displaySizes.first;
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModalHeader(
                      title: 'Daily Receiving (Line Handover)',
                      subtitle: 'Receive stitched bundles from sewing line',
                      icon: Icons.move_to_inbox_outlined,
                      onClose: () => Navigator.pop(ctx),
                    ),
                    const Divider(height: 1, color: AppTheme.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. FROM LINEMAN FIELD
                          _buildFieldLabel(icon: Icons.person_outline_rounded, label: 'From Lineman (Sewing Line)', isRequired: true),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: linemanError != null ? AppTheme.redMist : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: linemanError != null ? AppTheme.red : AppTheme.border,
                                width: 1.0,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedLinemanId,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSoft, size: 20),
                                hint: Text('Select lineman', style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint)),
                                items: _linemen.map((lm) => DropdownMenuItem<String>(
                                  value: lm['id'],
                                  child: Text(lm['username'], style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.ink)),
                                )).toList(),
                                onChanged: (v) {
                                  setModalState(() {
                                    selectedLinemanId = v;
                                    final filteredArts = _getArticlesForLineman(v);
                                    selectedArticleId = filteredArts.isNotEmpty ? filteredArts.first['id'] : null;
                                    selectedColor = null;
                                    selectedSize = null;
                                    linemanError = null;
                                  });
                                },
                              ),
                            ),
                          ),
                          if (linemanError != null) _buildInlineError(linemanError!),

                          const SizedBox(height: 14),

                          // 2. ARTICLE (STYLE #) FIELD
                          _buildFieldLabel(icon: Icons.checkroom_outlined, label: 'Article (Style #)', isRequired: true),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: articleError != null ? AppTheme.redMist : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: articleError != null ? AppTheme.red : AppTheme.border,
                                width: 1.0,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedArticleId,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSoft, size: 20),
                                hint: Text('Select article', style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint)),
                                items: availableArticles.map((art) => DropdownMenuItem<String>(
                                  value: art['id'],
                                  child: Text('${art['art_no']} (${_getCleanArticleDescription(art['description'])})', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.ink)),
                                )).toList(),
                                onChanged: (v) {
                                  setModalState(() {
                                    selectedArticleId = v;
                                    selectedColor = null;
                                    selectedSize = null;
                                    articleError = null;
                                  });
                                },
                              ),
                            ),
                          ),
                          if (articleError != null) _buildInlineError(articleError!),

                          const SizedBox(height: 14),

                          // 3. COLOR & SIZE DROPDOWNS
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // COLOR DROPDOWN
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel(icon: Icons.palette_outlined, label: 'Color / Shade', isRequired: true),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: colorError != null ? AppTheme.redMist : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: colorError != null ? AppTheme.red : AppTheme.border,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedColor,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSoft, size: 18),
                                          items: displayColors.map((c) => DropdownMenuItem<String>(
                                            value: c,
                                            child: Text(c, style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.ink)),
                                          )).toList(),
                                          onChanged: (v) {
                                            setModalState(() {
                                              selectedColor = v;
                                              selectedSize = null;
                                              colorError = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    if (colorError != null) _buildInlineError(colorError!),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // SIZE DROPDOWN
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel(icon: Icons.straighten_rounded, label: 'Size', isRequired: true),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: sizeError != null ? AppTheme.redMist : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: sizeError != null ? AppTheme.red : AppTheme.border,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedSize,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSoft, size: 18),
                                          items: displaySizes.map((s) => DropdownMenuItem<String>(
                                            value: s,
                                            child: Text(s, style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.ink)),
                                          )).toList(),
                                          onChanged: (v) {
                                            setModalState(() {
                                              selectedSize = v;
                                              sizeError = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    if (sizeError != null) _buildInlineError(sizeError!),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // 4. QUANTITY RECEIVED FIELD
                          _buildFieldLabel(icon: Icons.tag_rounded, label: 'Quantity Received (Pieces)', isRequired: true),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: qtyError != null ? AppTheme.redMist : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: qtyError != null ? AppTheme.red : AppTheme.border,
                                width: 1.0,
                              ),
                            ),
                            child: TextField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.ink),
                              decoration: InputDecoration(
                                hintText: 'e.g. 500',
                                hintStyle: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint),
                                prefixIcon: const Icon(Icons.tag_rounded, color: AppTheme.steel, size: 18),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: InputBorder.none,
                              ),
                              onChanged: (_) {
                                if (qtyError != null) setModalState(() => qtyError = null);
                              },
                            ),
                          ),
                          if (qtyError != null) _buildInlineError(qtyError!),

                          const SizedBox(height: 14),

                          // 5. REMARKS FIELD
                          _buildFieldLabel(icon: Icons.notes_rounded, label: 'Bundle Batch Notes / Remarks', isRequired: false),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: TextField(
                              controller: remarksController,
                              maxLines: 2,
                              style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.ink),
                              decoration: InputDecoration(
                                hintText: 'e.g. Lot 1, front placket ready',
                                hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkFaint),
                                contentPadding: const EdgeInsets.all(12),
                                border: InputBorder.none,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ACTION BUTTONS (SUBMIT + CANCEL)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      setModalState(() {
                                        linemanError = selectedLinemanId == null ? 'Select a lineman' : null;
                                        articleError = selectedArticleId == null ? 'Select an article' : null;
                                        colorError = (selectedColor == null || selectedColor!.isEmpty) ? 'Color required' : null;
                                        sizeError = (selectedSize == null || selectedSize!.isEmpty) ? 'Size required' : null;
                                        final parsed = int.tryParse(qtyController.text.trim());
                                        qtyError = (parsed == null || parsed <= 0) ? 'Enter valid qty (> 0)' : null;
                                      });

                                      if (linemanError != null || articleError != null || colorError != null || sizeError != null || qtyError != null) {
                                        return;
                                      }

                                      final qty = int.parse(qtyController.text.trim());
                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      Navigator.pop(ctx);
                                      try {
                                        await supabase.from('qc_logs').insert({
                                          'stage': 'RECEIVING',
                                          'from_lineman_id': selectedLinemanId,
                                          'article_id': selectedArticleId,
                                          'color': selectedColor,
                                          'size': selectedSize,
                                          'qty_received': qty,
                                          'remarks': remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
                                          'entry_date': DateTime.now().toIso8601String().split('T')[0],
                                        });

                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text('Received $qty pcs into QC Queue!'),
                                            backgroundColor: AppTheme.steel,
                                          ),
                                        );
                                        _fetchQcData();
                                      } catch (e) {
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.move_to_inbox_outlined, size: 18),
                                    label: Text(
                                      'Receive Pieces & Add to QC Queue',
                                      style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.steel,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 48,
                                width: 88,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.border),
                                    foregroundColor: AppTheme.inkSoft,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text('Cancel', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // HELPER: MODAL SHEET HEADER WITH CROSS BUTTON
  // ==========================================
  Widget _buildModalHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onClose,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.steelMist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(icon, color: AppTheme.steel, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                        color: AppTheme.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.bg,
                  side: const BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER: FIELD LABEL WITH 14px ICON & HIGH-CONTRAST TYPOGRAPHY
  // ==========================================
  Widget _buildFieldLabel({
    required IconData icon,
    required String label,
    required bool isRequired,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.steel),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: GoogleFonts.publicSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.red,
            ),
          )
        else
          Text(
            ' (optional)',
            style: GoogleFonts.publicSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.inkFaint,
            ),
          ),
      ],
    );
  }

  // ==========================================
  // HELPER: INLINE ERROR MESSAGE
  // ==========================================
  Widget _buildInlineError(String errorText) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 13, color: AppTheme.red),
          const SizedBox(width: 4),
          Text(
            errorText,
            style: GoogleFonts.publicSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.red,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODAL 2: CHECKING (QC)
  // ==========================================
  void _showCheckingModal() {
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;
    String? selectedLinemanId = _linemen.isNotEmpty ? _linemen.first['id'] : null;
    String? selectedColor;
    String? selectedSize;

    final passedController = TextEditingController();
    final rejectedController = TextEditingController(text: '0');
    final remarksController = TextEditingController();
    String selectedDefect = 'NONE';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final availableColors = _getColorsForArticle(selectedArticleId);
          final displayColors = availableColors.isNotEmpty ? availableColors : <String>['Standard'];
          if (selectedColor == null || !displayColors.contains(selectedColor)) {
            selectedColor = displayColors.first;
          }

          final availableSizes = _getSizesForArticle(selectedArticleId, selectedColor);
          final displaySizes = availableSizes.isNotEmpty ? availableSizes : <String>['Standard'];
          if (selectedSize == null || !displaySizes.contains(selectedSize)) {
            selectedSize = displaySizes.first;
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModalHeader(
                      title: 'Quality Inspection (Checking)',
                      subtitle: 'Inspect pieces, record pass & defect counts',
                      icon: Icons.fact_check_outlined,
                      onClose: () => Navigator.pop(ctx),
                    ),
                    const Divider(height: 1, color: AppTheme.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Article (Style #)
                          _buildFieldLabel(icon: Icons.checkroom_outlined, label: 'Article (Style #)', isRequired: true),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedArticleId,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSoft, size: 20),
                                items: _articles.map((art) => DropdownMenuItem<String>(
                                  value: art['id'],
                                  child: Text('${art['art_no']} (${_getCleanArticleDescription(art['description'])})', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.ink)),
                                )).toList(),
                                onChanged: (v) => setModalState(() {
                                  selectedArticleId = v;
                                  selectedColor = null;
                                  selectedSize = null;
                                }),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Sewing Line / Lineman Responsible
                          _buildFieldLabel(icon: Icons.person_outline_rounded, label: 'Sewing Line / Lineman Responsible', isRequired: false),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedLinemanId,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSoft, size: 20),
                                hint: Text('Select lineman', style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint)),
                                items: _linemen.map((lm) => DropdownMenuItem<String>(
                                  value: lm['id'],
                                  child: Text(lm['username'], style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.ink)),
                                )).toList(),
                                onChanged: (v) => setModalState(() => selectedLinemanId = v),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // DYNAMIC COLOR & SIZE DROPDOWNS
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel(icon: Icons.palette_outlined, label: 'Color / Shade', isRequired: false),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedColor,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSoft, size: 18),
                                          items: displayColors.map((c) => DropdownMenuItem<String>(
                                            value: c,
                                            child: Text(c, style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.ink)),
                                          )).toList(),
                                          onChanged: (v) {
                                            setModalState(() {
                                              selectedColor = v;
                                              selectedSize = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel(icon: Icons.straighten_rounded, label: 'Size', isRequired: false),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedSize,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSoft, size: 18),
                                          items: displaySizes.map((s) => DropdownMenuItem<String>(
                                            value: s,
                                            child: Text(s, style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.ink)),
                                          )).toList(),
                                          onChanged: (v) {
                                            setModalState(() {
                                              selectedSize = v;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // PASSED & DEFECT COUNTS
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel(icon: Icons.check_circle_outline_rounded, label: 'Passed (OK Pieces)', isRequired: true),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: TextField(
                                        controller: passedController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.ink),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. 95',
                                          hintStyle: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint),
                                          prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.steel, size: 18),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel(icon: Icons.cancel_outlined, label: 'Defect / Rejected', isRequired: true),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: TextField(
                                        controller: rejectedController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.ink),
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          hintStyle: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint),
                                          prefixIcon: const Icon(Icons.cancel_outlined, color: AppTheme.red, size: 18),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // PRIMARY DEFECT CATEGORY
                          _buildFieldLabel(icon: Icons.report_problem_outlined, label: 'Primary Defect Category', isRequired: false),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedDefect,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSoft, size: 20),
                                items: _defectTypes.map((dt) => DropdownMenuItem<String>(
                                  value: dt['key'],
                                  child: Text(dt['label']!, style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.ink)),
                                )).toList(),
                                onChanged: (v) => setModalState(() => selectedDefect = v ?? 'NONE'),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ACTION BUTTONS (SUBMIT + CANCEL)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final pQty = int.tryParse(passedController.text) ?? 0;
                                      final rQty = int.tryParse(rejectedController.text) ?? 0;
                                      if (selectedArticleId == null || (pQty == 0 && rQty == 0)) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter valid Passed or Defect counts.')));
                                        return;
                                      }

                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      Navigator.pop(ctx);
                                      try {
                                        await supabase.from('qc_logs').insert({
                                          'stage': 'CHECKING',
                                          'article_id': selectedArticleId,
                                          'from_lineman_id': selectedLinemanId,
                                          'color': selectedColor,
                                          'size': selectedSize,
                                          'qty_passed': pQty,
                                          'qty_rejected': rQty,
                                          'defect_type': selectedDefect,
                                          'mending_status': rQty > 0 ? 'WITH_LINEMAN_FOR_REPAIR' : 'NONE',
                                          'remarks': remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
                                          'entry_date': DateTime.now().toIso8601String().split('T')[0],
                                        });

                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text('Logged inspection: $pQty Passed, $rQty Defect'),
                                            backgroundColor: AppTheme.steel,
                                          ),
                                        );
                                        _fetchQcData();
                                      } catch (e) {
                                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red));
                                      }
                                    },
                                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                                    label: Text(
                                      'Save QC Inspection Entry',
                                      style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.steel,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 48,
                                width: 88,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.border),
                                    foregroundColor: AppTheme.inkSoft,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text('Cancel', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // MODAL 3: MENDING & REPAIR
  // ==========================================
  void _showMendingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildModalHeader(
                    title: 'Mending & Repair Tracking',
                    subtitle: 'Track pieces sent to sewing line for correction',
                    icon: Icons.handyman_outlined,
                    onClose: () => Navigator.pop(ctx),
                  ),
                  const Divider(height: 1, color: AppTheme.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_activeMendingList.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.steelMist,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.check_circle_outline_rounded, size: 24, color: AppTheme.steel),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No active mending bundles with linemen right now.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'All inspected pieces are either passed or cleared.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Text(
                            'Active Alteration Bundles (${_activeMendingList.length})',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.inkSoft),
                          ),
                          const SizedBox(height: 10),
                          ..._activeMendingList.map((item) {
                            final lm = item['lineman']?['username'] ?? 'Lineman';
                            final art = item['article']?['art_no'] ?? '-';
                            final rej = item['qty_rejected'] ?? 0;
                            final def = item['defect_type'] ?? 'Defect';
                            final color = item['color'] as String? ?? '';
                            final size = item['size'] as String? ?? '';
                            final variantStr = (color.isNotEmpty || size.isNotEmpty) ? ' • $color ($size)' : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Art: $art$variantStr',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppTheme.ink,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.steelMist,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Text(
                                          '$rej pcs',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.steel,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'With: $lm  |  Defect: $def',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      color: AppTheme.inkSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 42,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                                        Navigator.pop(ctx);
                                        try {
                                          await supabase.from('qc_logs').update({
                                            'mending_status': 'REPAIR_COMPLETED',
                                            'mending_returned_qty': rej,
                                          }).eq('id', item['id']);

                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Received $rej repaired pcs into Passed!'),
                                              backgroundColor: AppTheme.steel,
                                            ),
                                          );
                                          _fetchQcData();
                                        } catch (e) {
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                      label: const Text('Receive Fixed & Add to Passed'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.steel,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MODAL 4: BULKING & PACKING
  // ==========================================
  void _showBulkingModal() {
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;
    final colorController = TextEditingController(text: 'Navy Blue');
    final sizeController = TextEditingController(text: 'L');
    final bundleSizeController = TextEditingController(text: '10');
    final totalBundlesController = TextEditingController(text: '1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bSize = int.tryParse(bundleSizeController.text) ?? 0;
          final tBundles = int.tryParse(totalBundlesController.text) ?? 0;
          final totalPacked = bSize * tBundles;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModalHeader(
                      title: 'Bulking & Master Packing',
                      subtitle: 'Pack verified pieces into store-ready bundles',
                      icon: Icons.inventory_2_outlined,
                      onClose: () => Navigator.pop(ctx),
                    ),
                    const Divider(height: 1, color: AppTheme.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel(icon: Icons.checkroom_outlined, label: 'Article (Style #)', isRequired: true),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedArticleId,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSoft, size: 20),
                                items: _articles.map((art) => DropdownMenuItem<String>(
                                  value: art['id'],
                                  child: Text('${art['art_no']} (${_getCleanArticleDescription(art['description'])})', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.ink)),
                                )).toList(),
                                onChanged: (v) => setModalState(() => selectedArticleId = v),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel(icon: Icons.unarchive_outlined, label: 'Bundle Pack Size', isRequired: true),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: TextField(
                                        controller: bundleSizeController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.ink),
                                        onChanged: (_) => setModalState(() {}),
                                        decoration: InputDecoration(
                                          hintText: '10',
                                          hintStyle: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel(icon: Icons.layers_outlined, label: 'Total Bundles Created', isRequired: true),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: TextField(
                                        controller: totalBundlesController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.ink),
                                        onChanged: (_) => setModalState(() {}),
                                        decoration: InputDecoration(
                                          hintText: '2',
                                          hintStyle: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.steelMist,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Packed Quantity:',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.steel),
                                ),
                                Text(
                                  '$totalPacked pcs',
                                  style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.steel),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      if (selectedArticleId == null || totalPacked <= 0) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter valid bundle counts.')));
                                        return;
                                      }

                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      Navigator.pop(ctx);
                                      try {
                                        final todayStr = DateTime.now().toIso8601String().split('T')[0];

                                        await supabase.from('qc_logs').insert({
                                          'stage': 'BULKING',
                                          'article_id': selectedArticleId,
                                          'color': colorController.text.trim(),
                                          'size': sizeController.text.trim(),
                                          'bundle_size': bSize,
                                          'total_bundles': tBundles,
                                          'qty_passed': totalPacked,
                                          'sent_to_store': true,
                                          'entry_date': todayStr,
                                        });

                                        await supabase.from('store_transactions').insert({
                                          'type': 'INWARD',
                                          'article_id': selectedArticleId,
                                          'quantity': totalPacked,
                                          'party_name': 'QC Finishing Handover',
                                          'entry_date': todayStr,
                                        });

                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text('Transferred $totalPacked pcs ($tBundles bundles) to Store Godown!'),
                                            backgroundColor: AppTheme.steel,
                                          ),
                                        );
                                        _fetchQcData();
                                      } catch (e) {
                                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red));
                                      }
                                    },
                                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                                    label: Text(
                                      'Transfer $totalPacked pcs to Store Godown',
                                      style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.steel,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 48,
                                width: 88,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.border),
                                    foregroundColor: AppTheme.inkSoft,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text('Cancel', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Computed derived metrics
    final double? passRate = _totalCheckedToday > 0
        ? ((_totalPassedToday / _totalCheckedToday) * 100).clamp(0.0, 100.0)
        : null;

    final double mendingRate = _totalCheckedToday > 0
        ? (_totalInMendingToday / _totalCheckedToday)
        : 0.0;

    final bool isMendingAlert = mendingRate > mendingRateAlertThreshold;

    // Daily Receiving Queue (pieces received that need inspection)
    final int pendingReceivingCount = (_totalReceivedToday - _totalCheckedToday).clamp(0, 9999);
    final int pendingMendingCount = _totalInMendingToday;

    final user = supabase.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ??
        user?.email?.split('@')[0] ??
        'QC Inspector';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 18,
        backgroundColor: AppTheme.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Welcome, $userName',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: -0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const _WavingHandIcon(size: 20),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'QC & Finishing Shift',
              style: GoogleFonts.publicSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.inkSoft,
              ),
            ),
          ],
        ),
        actions: [
          // Live Sync / Refresh button
          Tooltip(
            message: 'Resync QC Data',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _fetchQcData,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_rounded, size: 16, color: AppTheme.steel),
                    const SizedBox(width: 5),
                    Text(
                      'Sync',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.steel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Clean Logout button
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppTheme.inkSoft, size: 18),
              tooltip: 'Logout',
              padding: EdgeInsets.zero,
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                }
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.steel))
          : RefreshIndicator(
              color: AppTheme.steel,
              onRefresh: _fetchQcData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ====================================================
                    // 1. SOLID STEEL SUMMARY CARD (LIGHT-THEME BRAND CARD)
                    // ====================================================
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.steel,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.steelDark.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_getShiftName()} · QC summary',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Finishing & Inspection Floor',
                                      style: GoogleFonts.publicSans(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 11.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildPassRateBadge(passRate),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _buildSummaryStat('Received', '$_totalReceivedToday', Icons.move_to_inbox_outlined, isHighlighted: false),
                              _buildSummaryStat('Checked', '$_totalCheckedToday', Icons.fact_check_outlined, isHighlighted: false),
                              _buildSummaryStat('Passed', '$_totalPassedToday', Icons.verified_outlined, isHighlighted: false),
                              _buildSummaryStat('Mending', '$_totalInMendingToday', Icons.handyman_outlined, isHighlighted: isMendingAlert),
                              _buildSummaryStat('Packed', '$_totalPackedToday', Icons.inventory_2_outlined, isHighlighted: false),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ====================================================
                    // 2. QUICK ACTION MODULES (UNIFIED BRAND THEMING)
                    // ====================================================
                    Text(
                      'Quick action modules',
                      style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: [
                        // Module 1: Daily receiving
                        _buildActionCard(
                          title: 'Daily receiving',
                          subtitle: 'Receive from lineman',
                          icon: Icons.move_to_inbox_outlined,
                          iconColor: AppTheme.steel,
                          iconBgColor: AppTheme.steelMist,
                          pendingBadgeCount: pendingReceivingCount > 0 ? pendingReceivingCount : null,
                          badgeColor: AppTheme.steel,
                          borderColor: AppTheme.border,
                          onTap: _showDailyReceivingModal,
                        ),
                        // Module 2: Checking (QC)
                        _buildActionCard(
                          title: 'Checking (QC)',
                          subtitle: 'Inspect & pass/reject',
                          icon: Icons.fact_check_outlined,
                          iconColor: AppTheme.steel,
                          iconBgColor: AppTheme.steelMist,
                          borderColor: AppTheme.border,
                          onTap: _showCheckingModal,
                        ),
                        // Module 3: Mending & repair
                        _buildActionCard(
                          title: 'Mending & repair',
                          subtitle: 'Return to lineman',
                          icon: Icons.handyman_outlined,
                          iconColor: AppTheme.steel,
                          iconBgColor: AppTheme.steelMist,
                          pendingBadgeCount: pendingMendingCount > 0 ? pendingMendingCount : null,
                          badgeColor: AppTheme.steel,
                          borderColor: AppTheme.border,
                          onTap: _showMendingModal,
                        ),
                        // Module 4: Bulking & packing
                        _buildActionCard(
                          title: 'Bulking & packing',
                          subtitle: 'Pack & send to store',
                          icon: Icons.inventory_2_outlined,
                          iconColor: AppTheme.steel,
                          iconBgColor: AppTheme.steelMist,
                          borderColor: AppTheme.border,
                          onTap: _showBulkingModal,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ====================================================
                    // 3. RECENT QC ACTIVITY FEED (REAL CONDITIONAL RENDER)
                    // ====================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent QC activity feed',
                          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.ink),
                        ),
                        Text(
                          '${_recentQcLogs.length} logs',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: AppTheme.inkFaint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_recentQcLogs.isEmpty)
                      _buildEmptyActivityFeed()
                    else
                      ..._recentQcLogs.map((log) => _buildPopulatedLogCard(log)),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ==========================================
  // SUMMARY STAT ITEM
  // ==========================================
  Widget _buildSummaryStat(String label, String value, IconData icon, {required bool isHighlighted}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.publicSans(
            color: Colors.white.withValues(alpha: isHighlighted ? 0.95 : 0.8),
            fontSize: 11,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );

    if (isHighlighted) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: content,
        ),
      );
    }

    return Expanded(child: content);
  }

  // ==========================================
  // CONTEXTUAL PASS RATE BADGE
  // ==========================================
  Widget _buildPassRateBadge(double? passRate) {
    if (passRate == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          'Pass: —',
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

    Color badgeBg;
    if (passRate >= passRateHighThreshold) {
      badgeBg = AppTheme.green;
    } else if (passRate >= passRateMediumThreshold) {
      badgeBg = AppTheme.amber;
    } else {
      badgeBg = AppTheme.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        'Pass: ${passRate.toStringAsFixed(1)}%',
        style: GoogleFonts.jetBrainsMono(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  // ==========================================
  // ACTION MODULE CARD (MIN 44x44 TAP TARGET)
  // ==========================================
  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required Color borderColor,
    int? pendingBadgeCount,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: AppTheme.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.inkSoft,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              if (pendingBadgeCount != null && pendingBadgeCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? AppTheme.steel,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$pendingBadgeCount',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // EMPTY STATE: DASHED BORDER CARD
  // ==========================================
  Widget _buildEmptyActivityFeed() {
    return _DashedBorderCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.steelMist,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.assignment_outlined, size: 22, color: AppTheme.steel),
          ),
          const SizedBox(height: 12),
          Text(
            'No QC inspections logged today',
            style: GoogleFonts.publicSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap one of the action cards above to begin.',
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 11,
              color: AppTheme.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // POPULATED ACTIVITY CARD
  // ==========================================
  Widget _buildPopulatedLogCard(dynamic log) {
    final stage = log['stage'] as String? ?? 'QC';
    final artNo = log['article']?['art_no'] ?? '-';
    final qPass = log['qty_passed'] ?? 0;
    final qRej = log['qty_rejected'] ?? 0;

    final isReject = (stage == 'CHECKING' && qRej > 0) || (stage == 'MENDING');

    String descriptionText;
    if (stage == 'RECEIVING') {
      descriptionText = '$artNo · Received ${log['qty_received']} pcs from line';
    } else if (stage == 'CHECKING') {
      if (qRej > 0) {
        descriptionText = '$artNo · Flagged $qRej pcs for mending (${log['defect_type'] ?? 'Defect'})';
      } else {
        descriptionText = '$artNo · $qPass pcs passed inspection';
      }
    } else if (stage == 'MENDING') {
      final status = log['mending_status'] ?? '';
      if (status == 'REPAIR_COMPLETED') {
        descriptionText = '$artNo · ${log['mending_returned_qty']} pcs repaired & passed';
      } else {
        descriptionText = '$artNo · Sent ${log['qty_rejected']} pcs to lineman for repair';
      }
    } else if (stage == 'BULKING') {
      final bSize = log['bundle_size'] ?? 0;
      final tBundles = log['total_bundles'] ?? 0;
      descriptionText = '$artNo · Packed ${bSize * tBundles} pcs to store godown';
    } else {
      descriptionText = '$artNo · QC Log Entry';
    }

    String timeStr = '-';
    if (log['created_at'] != null) {
      try {
        final dt = DateTime.parse(log['created_at']).toLocal();
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        timeStr = '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
      } catch (_) {
        timeStr = '-';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isReject ? Icons.close_rounded : Icons.check_rounded,
            size: 16,
            color: isReject ? AppTheme.red : AppTheme.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              descriptionText,
              style: GoogleFonts.publicSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: AppTheme.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// DASHED BORDER CARD CONTAINER (EMPTY STATE)
// ==========================================
class _DashedBorderCard extends StatelessWidget {
  final Widget child;
  const _DashedBorderCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppTheme.border,
        strokeWidth: 1.2,
        dashWidth: 5,
        dashSpace: 4,
        radius: 12,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length) ? dashWidth : metric.length - distance;
        dashedPath.addPath(metric.extractPath(distance, distance + length), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// ANIMATED WAVING HAND ICON
// ==========================================
class _WavingHandIcon extends StatefulWidget {
  final double size;
  const _WavingHandIcon({this.size = 20});

  @override
  State<_WavingHandIcon> createState() => _WavingHandIconState();
}

class _WavingHandIconState extends State<_WavingHandIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _waveAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.26).chain(CurveTween(curve: Curves.easeOut)), weight: 12),
      TweenSequenceItem(tween: Tween(begin: -0.26, end: 0.22).chain(CurveTween(curve: Curves.easeInOut)), weight: 16),
      TweenSequenceItem(tween: Tween(begin: 0.22, end: -0.22).chain(CurveTween(curve: Curves.easeInOut)), weight: 16),
      TweenSequenceItem(tween: Tween(begin: -0.22, end: 0.16).chain(CurveTween(curve: Curves.easeInOut)), weight: 14),
      TweenSequenceItem(tween: Tween(begin: 0.16, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 12),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 30),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveAnim,
      builder: (context, child) {
        return Transform.rotate(
          angle: _waveAnim.value,
          alignment: const Alignment(0.4, 0.9),
          child: child,
        );
      },
      child: Icon(
        Icons.waving_hand_outlined,
        color: AppTheme.steel,
        size: widget.size,
      ),
    );
  }
}
