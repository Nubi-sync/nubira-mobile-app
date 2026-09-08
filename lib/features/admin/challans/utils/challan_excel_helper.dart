import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';

class ParsedExcelArticleLine {
  final String artNo;
  final String? subArtNo;
  final String? colorPattern;
  final String? category;
  final String? product;
  final String? sizeRange;
  final int? orderQty;
  final int totalPcs;
  final String? linemanName;

  ParsedExcelArticleLine({
    required this.artNo,
    this.subArtNo,
    this.colorPattern,
    this.category,
    this.product,
    this.sizeRange,
    this.orderQty,
    required this.totalPcs,
    this.linemanName,
  });
}

class ParsedExcelChallan {
  final String? challanNo;
  final DateTime? challanDate;
  final String? brand;
  final String? fabricType;
  final DateTime? deliveryDate;
  final String? specialRemarks;
  final List<ParsedExcelArticleLine> articleLines;
  final int totalRowsCount;

  ParsedExcelChallan({
    this.challanNo,
    this.challanDate,
    this.brand,
    this.fabricType,
    this.deliveryDate,
    this.specialRemarks,
    required this.articleLines,
    required this.totalRowsCount,
  });
}

class ChallanExcelHelper {
  static const List<String> standardHeaders = [
    'DATE',
    'CHALLAN NO',
    'ART NO',
    'COLOUR',
    'CATEGORY',
    'PRODUCT',
    'SIZE',
    'ORDER QNTY',
    'CHALLAN QNTY',
    'LINEMAN',
    'QC CHECKER',
    'MENDING',
    'STATUS',
    'BRAND',
    'FABRIC TYPE',
    'EXPECTED DELIVERY DATE',
    'SPECIAL REMARKS',
  ];

  /// Generates and saves a clean 17-column Excel template matching Web Admin
  static Future<String?> generateAndDownloadTemplate(BuildContext context) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Delivery Challans';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Add headers
      sheet.appendRow(standardHeaders.map((h) => TextCellValue(h)).toList());

      // Encode bytes
      final fileBytes = excel.save();
      if (fileBytes == null) return null;

      // Save to temporary / documents directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/delivery_challan_template.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF332B6B),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Template created successfully: delivery_challan_template.xlsx',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      return filePath;
    } catch (e) {
      debugPrint('Error generating excel template: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE11D48),
            content: Text('Failed to generate template: $e'),
          ),
        );
      }
      return null;
    }
  }

  /// Picks and parses an Excel file (.xlsx / .xls) for cutting/challan article lines
  static Future<ParsedExcelChallan?> pickAndParseExcel(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read selected Excel file.')),
          );
        }
        return null;
      }

      final excel = Excel.decodeBytes(bytes);

      String? detectedChallanNo;
      DateTime? detectedChallanDate;
      String? detectedBrand;
      String? detectedFabric;
      DateTime? detectedDeliveryDate;
      String? detectedRemarks;
      final List<ParsedExcelArticleLine> parsedLines = [];
      int totalRowsCount = 0;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.maxRows < 2) continue;

        // Extract header row
        final headerRow = sheet.rows.first
            .map((cell) => cell?.value?.toString().trim().toUpperCase() ?? '')
            .toList();

        int dateIdx = -1;
        int challanIdx = -1;
        int artIdx = -1;
        int colorIdx = -1;
        int catIdx = -1;
        int prodIdx = -1;
        int sizeIdx = -1;
        int orderQtyIdx = -1;
        int challanQtyIdx = -1;
        int linemanIdx = -1;
        int brandIdx = -1;
        int fabricIdx = -1;
        int expDateIdx = -1;
        int remarksIdx = -1;

        for (int i = 0; i < headerRow.length; i++) {
          final h = headerRow[i];
          if (h == 'DATE' || (h.contains('DATE') && !h.contains('EXP') && !h.contains('DELIV'))) dateIdx = i;
          if (h.contains('CHALLAN') || h.contains('CHALAN') || h.contains('CH_NO') || h.contains('LOT')) challanIdx = i;
          if (h.contains('ART') || h.contains('STYLE') || h.contains('ITEM')) artIdx = i;
          if (h.contains('COLOR') || h.contains('COLOUR') || h.contains('SHADE')) colorIdx = i;
          if (h.contains('CAT') || h.contains('CATEGORY')) catIdx = i;
          if (h.contains('PROD') || h.contains('PRODUCT') || h.contains('PATTERN')) prodIdx = i;
          if (h.contains('SIZE') || h.contains('RATIO')) sizeIdx = i;
          if (h.contains('ORDER') && (h.contains('QTY') || h.contains('QNTY'))) orderQtyIdx = i;
          if ((h.contains('CHALLAN') || h.contains('TOTAL') || h.contains('PCS')) && (h.contains('QTY') || h.contains('QNTY') || h.contains('PCS'))) challanQtyIdx = i;
          if (h.contains('LINEMAN') || h.contains('OPERATOR') || h.contains('LINE')) linemanIdx = i;
          if (h.contains('BRAND') || h.contains('PARTY') || h.contains('BUYER')) brandIdx = i;
          if (h.contains('FABRIC') || h.contains('CLOTH') || h.contains('MATERIAL')) fabricIdx = i;
          if (h.contains('EXP') || h.contains('DELIV')) expDateIdx = i;
          if (h.contains('REMARK') || h.contains('NOTE') || h.contains('DESC')) remarksIdx = i;
        }

        // Parse each data row
        for (int r = 1; r < sheet.rows.length; r++) {
          final row = sheet.rows[r];
          if (row.isEmpty) continue;

          String cellStr(int idx) {
            if (idx == -1 || idx >= row.length) return '';
            return row[idx]?.value?.toString().trim() ?? '';
          }

          final rawChallan = cellStr(challanIdx);
          final rawArt = cellStr(artIdx);
          final rawColor = cellStr(colorIdx);
          final rawCat = cellStr(catIdx);
          final rawProd = cellStr(prodIdx);
          final rawSize = cellStr(sizeIdx);
          final rawOrderQtyStr = cellStr(orderQtyIdx);
          final rawChallanQtyStr = cellStr(challanQtyIdx);
          final rawLineman = cellStr(linemanIdx);
          final rawBrand = cellStr(brandIdx);
          final rawFabric = cellStr(fabricIdx);
          final rawDateStr = cellStr(dateIdx);
          final rawExpDateStr = cellStr(expDateIdx);
          final rawRemarks = cellStr(remarksIdx);

          if (rawArt.isEmpty && rawChallan.isEmpty) continue;

          totalRowsCount++;

          // Capture header metadata from first non-empty occurrence
          if (detectedChallanNo == null && rawChallan.isNotEmpty) {
            detectedChallanNo = rawChallan.toUpperCase();
          }
          if (detectedBrand == null && rawBrand.isNotEmpty) {
            detectedBrand = rawBrand.toUpperCase();
          }
          if (detectedFabric == null && rawFabric.isNotEmpty) {
            detectedFabric = rawFabric;
          }
          if (detectedRemarks == null && rawRemarks.isNotEmpty) {
            detectedRemarks = rawRemarks;
          }
          if (detectedChallanDate == null && rawDateStr.isNotEmpty) {
            detectedChallanDate = DateTime.tryParse(rawDateStr);
          }
          if (detectedDeliveryDate == null && rawExpDateStr.isNotEmpty) {
            detectedDeliveryDate = DateTime.tryParse(rawExpDateStr);
          }

          final orderQtyNum = int.tryParse(rawOrderQtyStr.replaceAll(RegExp(r'[^0-9]'), ''));
          var challanQtyNum = int.tryParse(rawChallanQtyStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? (orderQtyNum ?? 0);
          if (challanQtyNum == 0 && orderQtyNum != null && orderQtyNum > 0) {
            challanQtyNum = orderQtyNum;
          }

          if (rawArt.isNotEmpty) {
            parsedLines.add(
              ParsedExcelArticleLine(
                artNo: rawArt.toUpperCase(),
                colorPattern: rawColor.isNotEmpty ? rawColor : '3 COLOUR',
                category: rawCat.isNotEmpty ? rawCat : null,
                product: rawProd.isNotEmpty ? rawProd : null,
                sizeRange: rawSize.isNotEmpty ? rawSize : 'Free Size',
                orderQty: orderQtyNum,
                totalPcs: challanQtyNum > 0 ? challanQtyNum : 10,
                linemanName: rawLineman.isNotEmpty ? rawLineman : null,
              ),
            );
          }
        }
      }

      if (parsedLines.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFE11D48),
              content: Text('No article lines found in the selected Excel sheet. Please check columns.'),
            ),
          );
        }
        return null;
      }

      return ParsedExcelChallan(
        challanNo: detectedChallanNo,
        challanDate: detectedChallanDate,
        brand: detectedBrand,
        fabricType: detectedFabric,
        deliveryDate: detectedDeliveryDate,
        specialRemarks: detectedRemarks,
        articleLines: parsedLines,
        totalRowsCount: totalRowsCount,
      );
    } catch (e) {
      debugPrint('Error parsing excel sheet: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE11D48),
            content: Text('Error parsing Excel: $e'),
          ),
        );
      }
      return null;
    }
  }
}
