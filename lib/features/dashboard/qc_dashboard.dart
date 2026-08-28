import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/connectivity_indicator.dart';
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
  List<dynamic> _allotmentVariants = [];
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

      // Fetch allotment variants with article reference
      List<dynamic> variantsRes = [];
      try {
        variantsRes = await supabase
            .from('allotment_variants')
            .select('id, allotment_id, color, size, quantity, allotments(article_id, lineman_id, status)');
      } catch (e) {
        debugPrint('Allotment variants fetch error: $e');
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
          _allotmentVariants = variantsRes;
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


  List<String> _getAllotmentIdsForArticle(String? articleId) {
    if (articleId == null) return [];
    try {
      final art = _articles.firstWhere((a) => a['id'] == articleId, orElse: () => null);
      if (art == null) return [];
      final desc = (art['description'] as String?) ?? '';
      final match = RegExp(r'\[(.*?)\]').firstMatch(desc);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.split(',').map((s) => s.trim()).toList();
      }
    } catch (_) {}
    return [];
  }

  // ==========================================
  // HELPER: GET DYNAMIC COLORS FOR ARTICLE (FROM ADMIN ALLOTMENT)
  // ==========================================
  List<String> _getColorsForArticle(String? articleId) {
    if (articleId == null) return [];
    final allotmentIds = _getAllotmentIdsForArticle(articleId);

    final matching = _allotmentVariants.where((v) {
      // Check 1: direct allotment_id match
      if (allotmentIds.contains(v['allotment_id'])) return true;
      // Check 2: join match if present
      final aId = v['allotments'] != null ? v['allotments']['article_id'] : (v['allotment'] != null ? v['allotment']['article_id'] : null);
      return aId == articleId;
    }).toList();

    final Set<String> colors = {};
    for (var v in matching) {
      final c = v['color'] as String?;
      if (c != null && c.trim().isNotEmpty) {
        colors.add(c.trim());
      }
    }

    // Fallback to existing QC logs if variants were not logged
    if (colors.isEmpty) {
      for (var log in _recentQcLogs) {
        if (log['article_id'] == articleId) {
          final c = log['color'] as String?;
          if (c != null && c.trim().isNotEmpty && c != 'Standard') {
            colors.add(c.trim());
          }
        }
      }
    }

    return colors.toList();
  }

  // ==========================================
  // HELPER: GET DYNAMIC SIZES FOR ARTICLE & COLOR
  // ==========================================
  List<String> _getSizesForArticle(String? articleId, String? selectedColor) {
    if (articleId == null) return [];
    final allotmentIds = _getAllotmentIdsForArticle(articleId);

    final matching = _allotmentVariants.where((v) {
      final matchesArticle = allotmentIds.contains(v['allotment_id']) ||
          (v['allotments'] != null ? v['allotments']['article_id'] == articleId : false) ||
          (v['allotment'] != null ? v['allotment']['article_id'] == articleId : false);
      if (!matchesArticle && allotmentIds.isNotEmpty) return false;

      if (selectedColor != null && selectedColor.trim().isNotEmpty) {
        final c = v['color'] as String?;
        return c != null && c.toLowerCase().trim() == selectedColor.toLowerCase().trim();
      }
      return true;
    }).toList();

    final Set<String> sizes = {};
    for (var v in matching) {
      final s = v['size'] as String?;
      if (s != null && s.trim().isNotEmpty) {
        sizes.add(s.trim());
      }
    }

    // Fallback to QC logs
    if (sizes.isEmpty) {
      for (var log in _recentQcLogs) {
        if (log['article_id'] == articleId) {
          if (selectedColor == null || log['color'] == selectedColor) {
            final s = log['size'] as String?;
            if (s != null && s.trim().isNotEmpty && s != 'Standard') {
              sizes.add(s.trim());
            }
          }
        }
      }
    }

    return sizes.toList();
  }


    void _showDailyReceivingModal() {
    String? selectedLinemanId = _linemen.isNotEmpty ? _linemen.first['id'] : null;
    String? selectedArticleId = _articles.isNotEmpty ? _articles.first['id'] : null;

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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // Dynamically fetch colors and sizes configured by Admin for this article
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
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.move_to_inbox_rounded, color: AppTheme.steel, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Receiving (Line Handover)',
                              style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink),
                            ),
                            Text(
                              'Receive stitched bundles from sewing line',
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 1. FROM LINEMAN FIELD
                  _buildFieldLabel(icon: Icons.person_outline_rounded, label: 'From Lineman (Sewing Line)', isRequired: true),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: linemanError != null ? AppTheme.redMist : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: linemanError != null
                            ? AppTheme.red
                            : (selectedLinemanId != null ? AppTheme.green : AppTheme.border),
                        width: linemanError != null ? 1.2 : 1.0,
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
                            linemanError = null;
                          });
                        },
                      ),
                    ),
                  ),
                  if (linemanError != null) _buildInlineError(linemanError!),

                  const SizedBox(height: 14),

                  // 2. ARTICLE (STYLE #) FIELD
                  _buildFieldLabel(icon: Icons.checkroom_rounded, label: 'Article (Style #)', isRequired: true),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: articleError != null ? AppTheme.redMist : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: articleError != null
                            ? AppTheme.red
                            : (selectedArticleId != null ? AppTheme.green : AppTheme.border),
                        width: articleError != null ? 1.2 : 1.0,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedArticleId,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSoft, size: 20),
                        hint: Text('Select article', style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint)),
                        items: _articles.map((art) => DropdownMenuItem<String>(
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

                  // 3. COLOR & SIZE DROPDOWNS (DYNAMIC FROM ADMIN ALLOTMENTS)
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
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: colorError != null
                                      ? AppTheme.red
                                      : (selectedColor != null ? AppTheme.green : AppTheme.border),
                                  width: colorError != null ? 1.2 : 1.0,
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
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: sizeError != null
                                      ? AppTheme.red
                                      : (selectedSize != null ? AppTheme.green : AppTheme.border),
                                  width: sizeError != null ? 1.2 : 1.0,
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
                    decoration: BoxDecoration(
                      color: qtyError != null ? AppTheme.redMist : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: qtyError != null ? AppTheme.red : AppTheme.border,
                        width: qtyError != null ? 1.2 : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.ink),
                      decoration: InputDecoration(
                        hintText: 'e.g. 500',
                        hintStyle: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkFaint),
                        prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.steel, size: 18),
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
                      borderRadius: BorderRadius.circular(9),
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

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
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
                              backgroundColor: AppTheme.green,
                            ),
                          );
                          _fetchQcData();
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
                          );
                        }
                      },
                      icon: const Icon(Icons.move_to_inbox_rounded, size: 18),
                      label: const Text('Receive Pieces & Add to QC Queue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.steel,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


    // ==========================================
  // HELPER: FIELD LABEL WITH 13px ICON & REQUIRED ASTERISK
  // ==========================================
  Widget _buildFieldLabel({
    required IconData icon,
    required String label,
    required bool isRequired,
  }) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.steel),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.inkSoft,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: GoogleFonts.publicSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.red,
            ),
          )
        else
          Text(
            ' (optional)',
            style: GoogleFonts.publicSans(
              fontSize: 11,
              fontWeight: FontWeight.w400,
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
              fontSize: 10.5,
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppTheme.greenMist, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.fact_check_rounded, color: AppTheme.green, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Quality Inspection (Checking)', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                            Text('Inspect pieces, record pass & defect counts', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Text('Article (Style #)', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedArticleId,
                        isExpanded: true,
                        items: _articles.map((art) => DropdownMenuItem<String>(value: art['id'], child: Text('${art['art_no']} (${_getCleanArticleDescription(art['description'])})', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13.5)))).toList(),
                        onChanged: (v) => setModalState(() {
                          selectedArticleId = v;
                          selectedColor = null;
                          selectedSize = null;
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text('Sewing Line / Lineman Responsible', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedLinemanId,
                        isExpanded: true,
                        items: _linemen.map((lm) => DropdownMenuItem<String>(value: lm['id'], child: Text(lm['username'], style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13.5)))).toList(),
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
                                borderRadius: BorderRadius.circular(9),
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
                                borderRadius: BorderRadius.circular(9),
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

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Passed (OK Pieces)', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.green)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: passedController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(hintText: 'e.g. 95', prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.green, size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Defect / Rejected', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.red)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: rejectedController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(hintText: '0', prefixIcon: const Icon(Icons.cancel_outlined, color: AppTheme.red, size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text('Primary Defect Category', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedDefect,
                        isExpanded: true,
                        items: _defectTypes.map((dt) => DropdownMenuItem<String>(value: dt['key'], child: Text(dt['label']!, style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13.5)))).toList(),
                        onChanged: (v) => setModalState(() => selectedDefect = v ?? 'NONE'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
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
                            SnackBar(content: Text('Logged inspection: $pQty Passed, $rQty Defect'), backgroundColor: AppTheme.green),
                          );
                          _fetchQcData();
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red));
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Save QC Inspection Entry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.amberMist, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.build_rounded, color: AppTheme.amber, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mending & Repair Tracking',
                            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          ),
                          Text(
                            'Track pieces sent to sewing line for correction',
                            style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (_activeMendingList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 28, color: AppTheme.green),
                        const SizedBox(height: 8),
                        Text(
                          'No active mending bundles with linemen right now.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.inkSoft),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Text(
                    'Active Alteration Bundles (${_activeMendingList.length})',
                    style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.inkSoft),
                  ),
                  const SizedBox(height: 8),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
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
                                  fontSize: 13.5,
                                  color: AppTheme.ink,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.amberMist,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '$rej pcs',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'With: $lm  |  Defect: $def',
                            style: GoogleFonts.publicSans(
                              fontSize: 11.5,
                              color: AppTheme.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 38,
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
                                      backgroundColor: AppTheme.green,
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
                                backgroundColor: AppTheme.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bSize = int.tryParse(bundleSizeController.text) ?? 0;
          final tBundles = int.tryParse(totalBundlesController.text) ?? 0;
          final totalPacked = bSize * tBundles;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.inventory_2_rounded, color: AppTheme.steel, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bulking & Master Packing', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                            Text('Pack verified pieces into store-ready bundles', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Text('Article (Style #)', style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedArticleId,
                        isExpanded: true,
                        items: _articles.map((art) => DropdownMenuItem<String>(value: art['id'], child: Text('${art['art_no']} (${_getCleanArticleDescription(art['description'])})', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 13.5)))).toList(),
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
                            Text('Bundle Pack Size', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: bundleSizeController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(hintText: '10', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Bundles Created', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: totalBundlesController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(hintText: '2', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppTheme.steelMist, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.steelTint)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Packed Quantity:', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: AppTheme.steelDark)),
                        Text('$totalPacked pcs', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.steelDark)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
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
                              backgroundColor: AppTheme.green,
                            ),
                          );
                          _fetchQcData();
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red));
                        }
                      },
                      icon: const Icon(Icons.inventory_2_rounded, size: 18),
                      label: Text('Transfer $totalPacked pcs to Store Godown'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.steel, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ],
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

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Production QC',
              style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.ink),
            ),
            const SizedBox(width: 8),
            const ConnectivityIndicator(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              }
            },
          ),
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
                              _buildSummaryStat('Received', '$_totalReceivedToday', Icons.move_to_inbox_rounded, isHighlighted: false),
                              _buildSummaryStat('Checked', '$_totalCheckedToday', Icons.fact_check_rounded, isHighlighted: false),
                              _buildSummaryStat('Passed', '$_totalPassedToday', Icons.check_circle_rounded, isHighlighted: false),
                              _buildSummaryStat('Mending', '$_totalInMendingToday', Icons.build_rounded, isHighlighted: isMendingAlert),
                              _buildSummaryStat('Packed', '$_totalPackedToday', Icons.inventory_2_rounded, isHighlighted: false),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ====================================================
                    // 2. QUICK ACTION MODULES (SEMANTIC COLORS & BADGES)
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
                        // Module 1: Daily receiving (Steel neutral)
                        _buildActionCard(
                          title: 'Daily receiving',
                          subtitle: 'Receive from lineman',
                          icon: Icons.move_to_inbox_rounded,
                          iconColor: AppTheme.steel,
                          iconBgColor: AppTheme.steelMist,
                          pendingBadgeCount: pendingReceivingCount > 0 ? pendingReceivingCount : null,
                          badgeColor: AppTheme.steel,
                          borderColor: AppTheme.border,
                          onTap: _showDailyReceivingModal,
                        ),
                        // Module 2: Checking (QC) (Green inspection)
                        _buildActionCard(
                          title: 'Checking (QC)',
                          subtitle: 'Inspect & pass/reject',
                          icon: Icons.fact_check_rounded,
                          iconColor: AppTheme.green,
                          iconBgColor: AppTheme.greenMist,
                          borderColor: AppTheme.border,
                          onTap: _showCheckingModal,
                        ),
                        // Module 3: Mending & repair (Amber attention queue)
                        _buildActionCard(
                          title: 'Mending & repair',
                          subtitle: 'Return to lineman',
                          icon: Icons.build_rounded,
                          iconColor: AppTheme.amber,
                          iconBgColor: AppTheme.amberMist,
                          pendingBadgeCount: pendingMendingCount > 0 ? pendingMendingCount : null,
                          badgeColor: AppTheme.amber,
                          borderColor: (pendingMendingCount > 0 || isMendingAlert) ? AppTheme.amber : AppTheme.border,
                          onTap: _showMendingModal,
                        ),
                        // Module 4: Bulking & packing (Steel neutral)
                        _buildActionCard(
                          title: 'Bulking & packing',
                          subtitle: 'Pack & send to store',
                          icon: Icons.inventory_2_rounded,
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
        Icon(icon, color: Colors.white, size: 17),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.publicSans(
            color: Colors.white.withValues(alpha: isHighlighted ? 0.95 : 0.75),
            fontSize: 10,
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
          padding: const EdgeInsets.all(14),
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft),
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
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? AppTheme.steel,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$pendingBadgeCount',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
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
