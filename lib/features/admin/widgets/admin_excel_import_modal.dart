import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';

class AdminExcelImportModal extends StatefulWidget {
  final VoidCallback onImportSuccess;

  const AdminExcelImportModal({
    super.key,
    required this.onImportSuccess,
  });

  @override
  State<AdminExcelImportModal> createState() => _AdminExcelImportModalState();
}

class _AdminExcelImportModalState extends State<AdminExcelImportModal> {
  bool _isLoading = false;
  String? _selectedFileName;
  int _parsedChallansCount = 0;
  int _parsedRowsCount = 0;
  String _statusMessage = 'Select an Excel (.xlsx / .xls) cutting or production sheet.';
  List<Map<String, dynamic>> _challansToInsert = [];

  Future<void> _pickAndParseExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      setState(() {
        _isLoading = true;
        _selectedFileName = result.files.first.name;
        _statusMessage = 'Parsing Excel sheet...';
      });

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Could not read file data.';
        });
        return;
      }

      final excel = Excel.decodeBytes(bytes);
      final Map<String, Map<String, dynamic>> groupedChallans = {};
      int totalRows = 0;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.maxRows < 2) continue;

        // Extract header row
        final headerRow = sheet.rows.first.map((cell) => cell?.value?.toString().trim().toUpperCase() ?? '').toList();
        
        int challanIdx = -1;
        int brandIdx = -1;
        int fabricIdx = -1;
        int qtyIdx = -1;
        int artIdx = -1;
        int descIdx = -1;
        int colorIdx = -1;
        int sizeIdx = -1;
        int linemanIdx = -1;

        for (int i = 0; i < headerRow.length; i++) {
          final h = headerRow[i];
          if (h.contains('CHALLAN') || h.contains('CHALAN') || h.contains('CH_NO') || h.contains('LOT')) challanIdx = i;
          if (h.contains('BRAND') || h.contains('PARTY') || h.contains('BUYER')) brandIdx = i;
          if (h.contains('FABRIC') || h.contains('CLOTH') || h.contains('MATERIAL')) fabricIdx = i;
          if (h.contains('QTY') || h.contains('QUANTITY') || h.contains('PCS') || h.contains('TOTAL')) qtyIdx = i;
          if (h.contains('ART') || h.contains('STYLE') || h.contains('ITEM')) artIdx = i;
          if (h.contains('DESC') || h.contains('REMARK') || h.contains('PRODUCT')) descIdx = i;
          if (h.contains('COLOR') || h.contains('COLOUR') || h.contains('SHADE')) colorIdx = i;
          if (h.contains('SIZE') || h.contains('RATIO')) sizeIdx = i;
          if (h.contains('LINEMAN') || h.contains('OPERATOR') || h.contains('LINE') || h.contains('SUPERVISOR')) linemanIdx = i;
        }

        // Parse data rows
        for (int r = 1; r < sheet.rows.length; r++) {
          final row = sheet.rows[r];
          if (row.isEmpty) continue;

          final rawChallan = challanIdx != -1 && challanIdx < row.length ? row[challanIdx]?.value?.toString().trim() : null;
          if (rawChallan == null || rawChallan.isEmpty) continue;

          totalRows++;
          final rawBrand = brandIdx != -1 && brandIdx < row.length ? row[brandIdx]?.value?.toString().trim() : 'OLLYPOP';
          final rawFabric = fabricIdx != -1 && fabricIdx < row.length ? row[fabricIdx]?.value?.toString().trim() : null;
          final rawQtyStr = qtyIdx != -1 && qtyIdx < row.length ? row[qtyIdx]?.value?.toString().trim() : '0';
          final rawQty = int.tryParse(rawQtyStr?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
          final rawArt = artIdx != -1 && artIdx < row.length ? row[artIdx]?.value?.toString().trim() : null;
          final rawDesc = descIdx != -1 && descIdx < row.length ? row[descIdx]?.value?.toString().trim() : null;
          final rawColor = colorIdx != -1 && colorIdx < row.length ? row[colorIdx]?.value?.toString().trim() : 'Standard';
          final rawSize = sizeIdx != -1 && sizeIdx < row.length ? row[sizeIdx]?.value?.toString().trim() : 'Free Size';
          final rawLineman = linemanIdx != -1 && linemanIdx < row.length ? row[linemanIdx]?.value?.toString().trim() : null;

          final key = '${rawChallan.toUpperCase()}-${(rawBrand == null || rawBrand.isEmpty) ? 'OLLYPOP' : rawBrand.toUpperCase()}';
          if (!groupedChallans.containsKey(key)) {
            groupedChallans[key] = {
              'challan_no': rawChallan.toUpperCase(),
              'brand': (rawBrand == null || rawBrand.isEmpty) ? 'OLLYPOP' : rawBrand.toUpperCase(),
              'fabric_type': rawFabric,
              'total_pcs': rawQty,
              'status': 'PENDING',
              'created_at': DateTime.now().toIso8601String(),
              '_lines': <Map<String, dynamic>>[],
            };
          } else {
            groupedChallans[key]!['total_pcs'] = (groupedChallans[key]!['total_pcs'] as int) + rawQty;
          }

          if (rawArt != null && rawArt.isNotEmpty) {
            (groupedChallans[key]!['_lines'] as List).add({
              'art_no': rawArt.toUpperCase(),
              'description': rawDesc ?? 'Art: $rawArt',
              'color_pattern': rawColor ?? 'Standard',
              'size_range': rawSize ?? 'Free Size',
              'total_pcs': rawQty,
              'lineman_name': rawLineman,
            });
          }
        }
      }

      // Format challans with JSON notes containing article lines
      final parsedList = groupedChallans.values.map((c) {
        final lines = (c['_lines'] as List?) ?? [];
        final totalPcs = c['total_pcs'] as int? ?? 0;
        return {
          'challan_no': c['challan_no'],
          'brand': c['brand'],
          'fabric_type': c['fabric_type'],
          'total_pcs': totalPcs,
          'total_sets': lines.isNotEmpty ? (totalPcs / 9).round() : 1,
          'status': 'IN_PROGRESS',
          'notes': jsonEncode({
            'user_notes': '',
            'article_lines': lines,
          }),
          '_raw_lines': lines,
          'created_at': c['created_at'],
        };
      }).toList();

      setState(() {
        _isLoading = false;
        _parsedChallansCount = parsedList.length;
        _parsedRowsCount = totalRows;
        _challansToInsert = parsedList;
        _statusMessage = 'Found $_parsedChallansCount unique challans ($_parsedRowsCount data lines). Ready to upload.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error parsing Excel: ${e.toString()}';
      });
    }
  }

  Future<void> _submitBulkImport() async {
    if (_challansToInsert.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Uploading ${_challansToInsert.length} challans & syncing allotments...';
    });

    try {
      // 1. Fetch active linemen profiles for auto-matching
      final profilesRes = await supabase.from('profiles').select('id, username').eq('is_active', true);
      final Map<String, String> profileMap = {};
      for (var p in (profilesRes as List)) {
        final un = p['username']?.toString().trim().toLowerCase();
        if (un != null && un.isNotEmpty) {
          profileMap[un] = p['id'].toString();
        }
      }

      int totalAllotmentsCreated = 0;

      for (var ch in _challansToInsert) {
        final rawLines = (ch['_raw_lines'] as List?) ?? [];
        final insertPayload = Map<String, dynamic>.from(ch)..remove('_raw_lines');

        // Insert or Upsert challan
        final challanRes = await supabase
            .from('challans')
            .upsert(insertPayload, onConflict: 'challan_no, brand')
            .select('id')
            .single();

        final challanId = challanRes['id']?.toString();
        if (challanId == null) continue;

        // 2. Process article lines & auto-allot matched linemen
        for (var line in rawLines) {
          final artNo = line['art_no']?.toString().trim().toUpperCase();
          if (artNo == null || artNo.isEmpty) continue;

          // Ensure article style exists in catalog
          final artRes = await supabase
              .from('articles')
              .select('id')
              .eq('art_no', artNo)
              .maybeSingle();

          String artId;
          if (artRes != null && artRes['id'] != null) {
            artId = artRes['id'].toString();
          } else {
            final newArt = await supabase.from('articles').insert({
              'art_no': artNo,
              'description': line['description'] ?? 'Art: $artNo',
              'stitching_rate': 20.0,
              'is_active': true,
            }).select('id').single();
            artId = newArt['id'].toString();
          }

          // Check for lineman match
          final lmName = line['lineman_name']?.toString().trim().toLowerCase();
          final matchedLinemanId = lmName != null && lmName.isNotEmpty ? profileMap[lmName] : null;

          if (matchedLinemanId != null) {
            final targetQty = (line['total_pcs'] as num?)?.toInt() ?? 0;

            final newAl = await supabase.from('allotments').insert({
              'challan_id': challanId,
              'article_id': artId,
              'lineman_id': matchedLinemanId,
              'target_qty': targetQty,
              'status': 'IN_PROGRESS',
              'qc_status': 'PENDING_STITCHING',
              'mending_status': 'PENDING_STITCHING',
              'allotment_date': DateTime.now().toIso8601String().substring(0, 10),
            }).select('id').single();

            if (newAl['id'] != null) {
              totalAllotmentsCreated++;
              final sizeList = (line['size_range']?.toString() ?? 'Free Size').split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              final perSizeQty = (targetQty / (sizeList.isEmpty ? 1 : sizeList.length)).round();

              for (var sz in (sizeList.isEmpty ? ['Free Size'] : sizeList)) {
                await supabase.from('allotment_variants').insert({
                  'allotment_id': newAl['id'],
                  'color': line['color_pattern']?.toString() ?? 'Standard',
                  'size': sz,
                  'quantity': perSizeQty,
                  'completed_qty': 0,
                });
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Successfully imported ${_challansToInsert.length} challans ($totalAllotmentsCreated auto-allotted)!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.green,
            content: Text(
              'Imported ${_challansToInsert.length} challans ($totalAllotmentsCreated auto-allotted to Linemen)!',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        );

        widget.onImportSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Import failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.steelMist,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.upload_file, color: AppTheme.steel, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Bulk Excel Import',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.inkSoft),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            'Upload factory cutting or delivery challan Excel sheets to auto-create challans.',
            style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.inkSoft),
          ),

          const SizedBox(height: 20),

          // File picker drop area
          InkWell(
            onTap: _isLoading ? null : _pickAndParseExcel,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedFileName != null ? AppTheme.steel : AppTheme.border,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFileName != null ? Icons.file_present_rounded : Icons.cloud_upload_outlined,
                    color: _selectedFileName != null ? AppTheme.steel : AppTheme.inkFaint,
                    size: 38,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedFileName ?? 'Tap to select Excel file',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedFileName != null ? AppTheme.steel : AppTheme.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusMessage,
                    style: GoogleFonts.publicSans(
                      fontSize: 11.5,
                      color: _statusMessage.contains('Error') ? AppTheme.red : AppTheme.inkSoft,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          if (_challansToInsert.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.greenMist,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ready to import $_parsedChallansCount challans into Supabase.',
                      style: GoogleFonts.publicSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action Button
          ElevatedButton(
            onPressed: (_isLoading || _challansToInsert.isEmpty) ? null : _submitBulkImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.steel,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    _challansToInsert.isNotEmpty
                        ? 'Confirm Import (${_challansToInsert.length} Challans)'
                        : 'Select File First',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
