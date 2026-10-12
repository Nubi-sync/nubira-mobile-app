import 'package:flutter/material.dart';

class GarmentOperationItem {
  final String name;
  final String machineCode; // 'OL', 'FL', 'LK', 'PREP'
  final String machineTitle;
  final String category; // 'UPPER', 'LOWER', 'COMBO'
  final bool isCombo;

  const GarmentOperationItem({
    required this.name,
    required this.machineCode,
    required this.machineTitle,
    required this.category,
    this.isCombo = false,
  });

  Color get color {
    if (isCombo) return const Color(0xFF4F46E5); // Indigo
    switch (machineCode) {
      case 'OL':
        return const Color(0xFF2563EB); // Blue
      case 'FL':
        return const Color(0xFFD97706); // Amber
      case 'LK':
        return const Color(0xFF059669); // Emerald
      case 'PREP':
        return const Color(0xFF7C3AED); // Purple
      default:
        return const Color(0xFF475569); // Slate
    }
  }

  IconData get icon {
    if (isCombo) return Icons.layers_rounded;
    switch (machineCode) {
      case 'OL':
        return Icons.tune_rounded;
      case 'FL':
        return Icons.view_headline_rounded;
      case 'LK':
        return Icons.lock_outline_rounded;
      case 'PREP':
        return Icons.content_cut_rounded;
      default:
        return Icons.precision_manufacturing_rounded;
    }
  }

  String get badgeText {
    return isCombo ? 'COMBO • $name' : '$machineCode • $name';
  }

  // Master List containing all 38 Single Operations + 16 Combo Packages
  static const List<GarmentOperationItem> allGarmentOperations = [
    // =========================================================================
    // 1. SINGLE OPERATIONS - A. T-SHIRT & UPPER GARMENTS
    // =========================================================================
    // Overlock (OL)
    GarmentOperationItem(name: 'Shoulder Attach', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'UPPER'),
    GarmentOperationItem(name: 'One Shoulder', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'UPPER'),
    GarmentOperationItem(name: 'Shoulder Box False', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'UPPER'),
    GarmentOperationItem(name: 'Neck Rib Attach', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'UPPER'),
    GarmentOperationItem(name: 'Sleeve Attach', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'UPPER'),
    GarmentOperationItem(name: 'Side Attach with Wash Care', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'UPPER'),

    // Flatlock (FL)
    GarmentOperationItem(name: 'Bottom Hem', machineCode: 'FL', machineTitle: 'Flatlock (FL)', category: 'UPPER'),
    GarmentOperationItem(name: 'Sleeve Hem (Open)', machineCode: 'FL', machineTitle: 'Flatlock (FL)', category: 'UPPER'),
    GarmentOperationItem(name: 'Neck Chap', machineCode: 'FL', machineTitle: 'Flatlock (FL)', category: 'UPPER'),
    GarmentOperationItem(name: 'Neck Folding', machineCode: 'FL', machineTitle: 'Flatlock (FL)', category: 'UPPER'),

    // Lockstitch (LK)
    GarmentOperationItem(name: 'Neck Rib Joint', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'UPPER'),
    GarmentOperationItem(name: 'Neck Tape', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'UPPER'),
    GarmentOperationItem(name: 'Twill Tape', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'UPPER'),
    GarmentOperationItem(name: 'Neck Label', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'UPPER'),
    GarmentOperationItem(name: 'Sleeve Taki', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'UPPER'),
    GarmentOperationItem(name: 'Bottom Patch', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'UPPER'),
    GarmentOperationItem(name: 'Shoulder Box', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'UPPER'),

    // =========================================================================
    // 1. SINGLE OPERATIONS - B. PANTS, LOWER & GENERAL OPERATIONS
    // =========================================================================
    // Overlock (OL)
    GarmentOperationItem(name: 'Front Rise', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'LOWER'),
    GarmentOperationItem(name: 'Back Rise', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'LOWER'),
    GarmentOperationItem(name: 'Outseam Attach', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'LOWER'),
    GarmentOperationItem(name: 'Inseam Attach', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'LOWER'),
    GarmentOperationItem(name: 'Koli Attach', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'LOWER'),
    GarmentOperationItem(name: 'Waist False', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'LOWER'),
    GarmentOperationItem(name: 'Elastic Attach', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'LOWER'),

    // Flatlock (FL)
    GarmentOperationItem(name: 'Leg Folding', machineCode: 'FL', machineTitle: 'Flatlock (FL)', category: 'LOWER'),
    GarmentOperationItem(name: 'Leg Hemming', machineCode: 'FL', machineTitle: 'Flatlock (FL)', category: 'LOWER'),
    GarmentOperationItem(name: 'Elastic Chap', machineCode: 'FL', machineTitle: 'Flatlock (FL)', category: 'LOWER'),

    // Lockstitch (LK)
    GarmentOperationItem(name: 'Label Attach', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'LOWER'),
    GarmentOperationItem(name: 'Elastic Takki', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'LOWER'),
    GarmentOperationItem(name: 'Elastic Takki Dipper', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'LOWER'),
    GarmentOperationItem(name: 'Leg Folding Taki', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'LOWER'),
    GarmentOperationItem(name: 'Dori Takki', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'LOWER'),
    GarmentOperationItem(name: 'Waist Chap (3 Times)', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'LOWER'),

    // Prep / Other (PREP)
    GarmentOperationItem(name: 'Rib Cutting', machineCode: 'PREP', machineTitle: 'Prep / Other', category: 'LOWER'),
    GarmentOperationItem(name: 'Panel Joint', machineCode: 'PREP', machineTitle: 'Prep / Other', category: 'LOWER'),
    GarmentOperationItem(name: 'Holling', machineCode: 'PREP', machineTitle: 'Prep / Other', category: 'LOWER'),

    // =========================================================================
    // 2. COMBO & COMPLETE PACKAGES (BUNDLE OPERATIONS)
    // =========================================================================
    // Overlock (OL) Combos
    GarmentOperationItem(name: 'Sleeve + Side', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Complete Pant (2 Part, Without Elastic)', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Complete Without Inseam', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Complete Without Side', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Complete Without Elastic', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Complete Without Neck', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Complete Without Shoulder', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Complete Without Box False', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'OL Complete', machineCode: 'OL', machineTitle: 'Overlock (OL)', category: 'COMBO', isCombo: true),

    // Lockstitch (LK) Combos
    GarmentOperationItem(name: 'Shoulder Box + Rib', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Neck Patti with Sleeve Takki', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Neck Patti Patch Label', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Neck Patti with Takki', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Shoulder Box Without Patch', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'Shoulder Box with Twill Tape', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'COMBO', isCombo: true),
    GarmentOperationItem(name: 'LK Without Inseam Takki', machineCode: 'LK', machineTitle: 'Lockstitch (LK)', category: 'COMBO', isCombo: true),
  ];

  // Helper to resolve an operation from notes string
  static GarmentOperationItem? parseFromNotes(String notes) {
    if (notes.isEmpty) return null;
    
    // Check structured pattern [MACHINE | OP_NAME] or [OP_NAME]
    final structuredMatch = RegExp(r'\[(?:OVERLOCK|FLATLOCK|LOCKING|PREP|FIVE_THREAD)\s*\|\s*(.*?)\]').firstMatch(notes);
    if (structuredMatch != null && structuredMatch.group(1) != null) {
      final target = structuredMatch.group(1)!.trim();
      return allGarmentOperations.firstWhere(
        (o) => o.badgeText == target || o.name == target || target.endsWith(o.name),
        orElse: () => GarmentOperationItem(
          name: target,
          machineCode: 'OL',
          machineTitle: 'Operation',
          category: 'UPPER',
        ),
      );
    }

    // Direct name lookup
    for (var op in allGarmentOperations) {
      if (notes.contains(op.badgeText) || notes.contains(op.name)) {
        return op;
      }
    }
    return null;
  }
}
