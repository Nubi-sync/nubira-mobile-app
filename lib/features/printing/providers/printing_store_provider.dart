import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// Printing Store Models (1:1 with Web Admin ModuleStoreDashboard)
// ============================================================================

class MaterialReceiptItem {
  final String id;
  final String? companyName;
  final String? issueId;
  final String divisionCode;
  final int receivedQuantity;
  final int shortageQuantity;
  final String unit;
  final String? receivedBy;
  final String? rackLocation;
  final String? notes;
  final String? receivedAt;
  final String? createdAt;
  final MaterialIssueItem? issue;

  const MaterialReceiptItem({
    required this.id,
    this.companyName,
    this.issueId,
    this.divisionCode = 'PRINTING',
    required this.receivedQuantity,
    this.shortageQuantity = 0,
    this.unit = 'pcs',
    this.receivedBy,
    this.rackLocation,
    this.notes,
    this.receivedAt,
    this.createdAt,
    this.issue,
  });

  factory MaterialReceiptItem.fromJson(Map<String, dynamic> json) {
    MaterialIssueItem? linkedIssue;
    if (json['issue'] is Map<String, dynamic>) {
      linkedIssue = MaterialIssueItem.fromJson(json['issue'] as Map<String, dynamic>);
    }

    return MaterialReceiptItem(
      id: json['id']?.toString() ?? '',
      companyName: json['company_name']?.toString(),
      issueId: json['issue_id']?.toString(),
      divisionCode: json['division_code']?.toString() ?? 'PRINTING',
      receivedQuantity: (json['received_quantity'] as num?)?.toInt() ?? 0,
      shortageQuantity: (json['shortage_quantity'] as num?)?.toInt() ?? 0,
      unit: json['unit']?.toString() ?? 'pcs',
      receivedBy: json['received_by']?.toString(),
      rackLocation: json['rack_location']?.toString(),
      notes: json['notes']?.toString(),
      receivedAt: json['received_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      issue: linkedIssue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_name': companyName,
      'issue_id': issueId,
      'division_code': divisionCode,
      'received_quantity': receivedQuantity,
      'shortage_quantity': shortageQuantity,
      'unit': unit,
      'received_by': receivedBy,
      'rack_location': rackLocation,
      'notes': notes,
      'received_at': receivedAt,
    };
  }
}

class MaterialIssueItem {
  final String id;
  final String? companyName;
  final String issueChallanNo;
  final String fromDivision;
  final String toDivision;
  final String? articleNo;
  final String? buyerName;
  final String? fabricType;
  final String? color;
  final int quantity;
  final String unit;
  final int rollsCount;
  final String? issuedBy;
  final String? receivedBy;
  final String status;
  final String? issueDate;
  final String? receivedDate;
  final String? notes;
  final String? createdAt;

  const MaterialIssueItem({
    required this.id,
    this.companyName,
    required this.issueChallanNo,
    required this.fromDivision,
    required this.toDivision,
    this.articleNo,
    this.buyerName,
    this.fabricType,
    this.color,
    required this.quantity,
    this.unit = 'pcs',
    this.rollsCount = 0,
    this.issuedBy,
    this.receivedBy,
    this.status = 'ISSUED',
    this.issueDate,
    this.receivedDate,
    this.notes,
    this.createdAt,
  });

  factory MaterialIssueItem.fromJson(Map<String, dynamic> json) {
    return MaterialIssueItem(
      id: json['id']?.toString() ?? '',
      companyName: json['company_name']?.toString(),
      issueChallanNo: json['issue_challan_no']?.toString() ?? '',
      fromDivision: json['from_division']?.toString() ?? 'STORE',
      toDivision: json['to_division']?.toString() ?? 'PRINTING',
      articleNo: json['article_no']?.toString(),
      buyerName: json['buyer_name']?.toString(),
      fabricType: json['fabric_type']?.toString(),
      color: json['color']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unit: json['unit']?.toString() ?? 'pcs',
      rollsCount: (json['rolls_count'] as num?)?.toInt() ?? 0,
      issuedBy: json['issued_by']?.toString(),
      receivedBy: json['received_by']?.toString(),
      status: json['status']?.toString() ?? 'ISSUED',
      issueDate: json['issue_date']?.toString(),
      receivedDate: json['received_date']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_name': companyName,
      'issue_challan_no': issueChallanNo,
      'from_division': fromDivision,
      'to_division': toDivision,
      'article_no': articleNo,
      'buyer_name': buyerName,
      'fabric_type': fabricType,
      'color': color,
      'quantity': quantity,
      'unit': unit,
      'rolls_count': rollsCount,
      'issued_by': issuedBy,
      'received_by': receivedBy,
      'status': status,
      'issue_date': issueDate,
      'received_date': receivedDate,
      'notes': notes,
    };
  }
}

// ============================================================================
// Printing Store State
// ============================================================================

class PrintingStoreState {
  final bool isLoading;
  final String? error;
  final List<MaterialReceiptItem> receipts;
  final List<MaterialIssueItem> issues;
  final List<MaterialIssueItem> pendingIssues;

  const PrintingStoreState({
    this.isLoading = false,
    this.error,
    this.receipts = const [],
    this.issues = const [],
    this.pendingIssues = const [],
  });

  int get totalReceivedQty => receipts.fold(0, (sum, r) => sum + r.receivedQuantity);
  int get totalIssuedQty => issues.fold(0, (sum, i) => sum + i.quantity);
  int get pendingInwardsCount => pendingIssues.length;
  int get totalShortageQty => receipts.fold(0, (sum, r) => sum + r.shortageQuantity);

  PrintingStoreState copyWith({
    bool? isLoading,
    String? error,
    List<MaterialReceiptItem>? receipts,
    List<MaterialIssueItem>? issues,
    List<MaterialIssueItem>? pendingIssues,
  }) {
    return PrintingStoreState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      receipts: receipts ?? this.receipts,
      issues: issues ?? this.issues,
      pendingIssues: pendingIssues ?? this.pendingIssues,
    );
  }
}

// ============================================================================
// Printing Store Notifier
// ============================================================================

class PrintingStoreNotifier extends StateNotifier<PrintingStoreState> {
  PrintingStoreNotifier() : super(const PrintingStoreState()) {
    fetchStoreData();
  }

  // Canonical Web Admin defaults for Printing Floor Store (1:1 sync with Web)
  static final List<MaterialReceiptItem> _canonicalReceipts = [
    const MaterialReceiptItem(
      id: 'canon-rec-01',
      issueId: 'canon-iss-01',
      divisionCode: 'PRINTING',
      receivedQuantity: 2800,
      shortageQuantity: 0,
      unit: 'pcs',
      receivedBy: 'Kamal',
      rackLocation: 'PRINT-INTAKE-01',
      receivedAt: '2026-09-20T10:00:00.000Z',
      issue: MaterialIssueItem(
        id: 'canon-iss-01',
        issueChallanNo: 'ISS-2026-001002',
        fromDivision: 'CUTTING',
        toDivision: 'PRINTING',
        articleNo: 'DEMO-101-03',
        buyerName: 'Hollypop',
        fabricType: 'Cut Front Panels (Chest Graphic)',
        color: 'Olive Green',
        quantity: 2800,
        unit: 'pcs',
        status: 'RECEIVED',
        issueDate: '2026-09-20',
      ),
    ),
  ];

  static final List<MaterialIssueItem> _canonicalIssues = [
    const MaterialIssueItem(
      id: 'canon-out-01',
      issueChallanNo: 'ISS-2026-001003',
      fromDivision: 'PRINTING',
      toDivision: 'EMBROIDERY',
      articleNo: 'DEMO-101-03',
      buyerName: 'Hollypop',
      fabricType: 'Screen Printed Front Panels',
      color: 'Olive Green',
      quantity: 1300,
      unit: 'pcs',
      issuedBy: 'Store Supervisor',
      status: 'ISSUED',
      issueDate: '2026-09-21',
      notes: 'Plastisol cure verified at 160°C. Handoff to Embroidery line.',
    ),
  ];

  Future<void> fetchStoreData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final client = Supabase.instance.client;

      // 1. Fetch receipts for PRINTING division joined with issue details
      List<MaterialReceiptItem> fetchedReceipts = [];
      try {
        final recRes = await client
            .from('central_material_receipts')
            .select('*, issue:central_material_issues(*)')
            .eq('division_code', 'PRINTING')
            .order('received_at', ascending: false);

        if (recRes.isNotEmpty) {
          fetchedReceipts = (recRes as List).map((r) => MaterialReceiptItem.fromJson(Map<String, dynamic>.from(r as Map))).toList();
        }
      } catch (_) {}

      // 2. Fetch outward issues from PRINTING division
      List<MaterialIssueItem> fetchedIssues = [];
      try {
        final issRes = await client
            .from('central_material_issues')
            .select('*')
            .eq('from_division', 'PRINTING')
            .order('created_at', ascending: false);

        if (issRes.isNotEmpty) {
          fetchedIssues = (issRes as List).map((i) => MaterialIssueItem.fromJson(Map<String, dynamic>.from(i as Map))).toList();
        }
      } catch (_) {}

      // 3. Fetch pending inwards destined for PRINTING (status != 'RECEIVED')
      List<MaterialIssueItem> fetchedPending = [];
      try {
        final pendRes = await client
            .from('central_material_issues')
            .select('*')
            .eq('to_division', 'PRINTING')
            .neq('status', 'RECEIVED')
            .order('created_at', ascending: false);

        if (pendRes.isNotEmpty) {
          fetchedPending = (pendRes as List).map((p) => MaterialIssueItem.fromJson(Map<String, dynamic>.from(p as Map))).toList();
        }
      } catch (_) {}

      // Fallback matching Web 1:1 if database has no records yet
      final finalReceipts = fetchedReceipts.isNotEmpty ? fetchedReceipts : _canonicalReceipts;
      final finalIssues = fetchedIssues.isNotEmpty ? fetchedIssues : _canonicalIssues;

      state = state.copyWith(
        isLoading: false,
        receipts: finalReceipts,
        issues: finalIssues,
        pendingIssues: fetchedPending,
      );
    } catch (err) {
      state = state.copyWith(
        isLoading: false,
        receipts: _canonicalReceipts,
        issues: _canonicalIssues,
        pendingIssues: [],
        error: err.toString(),
      );
    }
  }

  Future<bool> createIssueChallan({
    required String toDivision,
    String? articleNo,
    String? buyerName,
    String? fabricType,
    String? color,
    required int quantity,
    String unit = 'pcs',
    int rollsCount = 0,
    String? notes,
    String? companyName,
  }) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final issuerName = user?.userMetadata?['full_name'] ?? 'Store Supervisor';
      final challanNo = 'ISS-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final payload = {
        'issue_challan_no': challanNo,
        'from_division': 'PRINTING',
        'to_division': toDivision.toUpperCase(),
        'article_no': articleNo?.trim().isEmpty == true ? null : articleNo?.trim(),
        'buyer_name': buyerName?.trim().isEmpty == true ? null : buyerName?.trim(),
        'fabric_type': fabricType?.trim().isEmpty == true ? null : fabricType?.trim(),
        'color': color?.trim().isEmpty == true ? null : color?.trim(),
        'quantity': quantity,
        'unit': unit,
        'rolls_count': rollsCount,
        'issued_by': issuerName,
        'status': 'ISSUED',
        'issue_date': DateTime.now().toIso8601String().split('T')[0],
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        if (companyName != null && companyName.isNotEmpty) 'company_name': companyName,
      };

      try {
        final res = await client.from('central_material_issues').insert(payload).select().single();
        final newItem = MaterialIssueItem.fromJson(res);
        state = state.copyWith(issues: [newItem, ...state.issues]);
      } catch (_) {
        // Local state update
        final newItem = MaterialIssueItem(
          id: 'local-${DateTime.now().millisecondsSinceEpoch}',
          issueChallanNo: challanNo,
          fromDivision: 'PRINTING',
          toDivision: toDivision.toUpperCase(),
          articleNo: articleNo,
          buyerName: buyerName,
          fabricType: fabricType,
          color: color,
          quantity: quantity,
          unit: unit,
          rollsCount: rollsCount,
          issuedBy: issuerName,
          status: 'ISSUED',
          issueDate: DateTime.now().toIso8601String().split('T')[0],
          notes: notes,
        );
        state = state.copyWith(issues: [newItem, ...state.issues]);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> acknowledgeMaterialReceipt({
    required String issueId,
    required int receivedQuantity,
    int shortageQuantity = 0,
    String unit = 'pcs',
    String? receivedBy,
    String? rackLocation,
    String? notes,
  }) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final receiver = receivedBy ?? user?.userMetadata?['full_name'] ?? 'Floor Manager';

      final payload = {
        'issue_id': issueId,
        'division_code': 'PRINTING',
        'received_quantity': receivedQuantity,
        'shortage_quantity': shortageQuantity,
        'unit': unit,
        'received_by': receiver,
        'rack_location': rackLocation ?? 'PRINT-INTAKE-01',
        'notes': notes,
        'received_at': DateTime.now().toIso8601String(),
      };

      try {
        await client.from('central_material_receipts').insert(payload);
        await client.from('central_material_issues').update({
          'status': 'RECEIVED',
          'received_by': receiver,
          'received_date': DateTime.now().toIso8601String().split('T')[0],
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', issueId);
      } catch (_) {}

      await fetchStoreData();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// Provider definition
final printingStoreProvider = StateNotifierProvider<PrintingStoreNotifier, PrintingStoreState>((ref) {
  return PrintingStoreNotifier();
});
