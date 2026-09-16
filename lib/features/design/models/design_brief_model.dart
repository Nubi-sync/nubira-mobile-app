import 'dart:convert';

class ConceptColorwayModel {
  final String colorName;
  final String? photoFront;
  final String? photoBack;

  const ConceptColorwayModel({
    required this.colorName,
    this.photoFront,
    this.photoBack,
  });

  factory ConceptColorwayModel.fromJson(Map<String, dynamic> json) {
    return ConceptColorwayModel(
      colorName: json['color_name'] as String? ?? 'Color',
      photoFront: json['photo_front'] as String?,
      photoBack: json['photo_back'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color_name': colorName,
      if (photoFront != null) 'photo_front': photoFront,
      if (photoBack != null) 'photo_back': photoBack,
    };
  }
}

class DesignConceptItemModel {
  final int? conceptNumber;
  final String title;
  final String? notes;
  final List<ConceptColorwayModel>? colorways;

  int get safeConceptNumber => conceptNumber ?? 1;
  List<ConceptColorwayModel> get safeColorways => colorways ?? const <ConceptColorwayModel>[];

  const DesignConceptItemModel({
    this.conceptNumber = 1,
    required this.title,
    this.notes,
    this.colorways = const [],
  });

  factory DesignConceptItemModel.fromJson(Map<String, dynamic> json) {
    List<ConceptColorwayModel> cws = [];
    if (json['colorways'] != null && json['colorways'] is List) {
      cws = (json['colorways'] as List)
          .whereType<Map>()
          .map((c) => ConceptColorwayModel.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }
    final cnRaw = json['concept_number'];
    final cn = cnRaw is int ? cnRaw : (int.tryParse(cnRaw?.toString() ?? '') ?? 1);

    return DesignConceptItemModel(
      conceptNumber: cn,
      title: json['title'] as String? ?? 'Concept',
      notes: json['notes'] as String?,
      colorways: cws,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'concept_number': safeConceptNumber,
      'title': title,
      if (notes != null) 'notes': notes,
      'colorways': safeColorways.map((cw) => cw.toJson()).toList(),
    };
  }
}

class DesignSubmissionModel {
  final String id;
  final String briefId;
  final String? designerMemberId;
  final String? designerName;
  final String photoUrl1;
  final String? photoUrl2;
  final String? designerNotes;
  final String? cleanDesignerNotes;
  final List<DesignConceptItemModel>? concepts;
  final String phVerdict; // 'PENDING' | 'APPROVED' | 'REJECTED'
  final String? phFeedback;
  final String? saVerdict; // 'APPROVED' | 'SAVED_FOR_LATER' | 'REJECTED'
  final String? saNotes;
  final String submittedAt;
  final String? reviewedAt;

  List<DesignConceptItemModel> get safeConcepts => concepts ?? const <DesignConceptItemModel>[];

  const DesignSubmissionModel({
    required this.id,
    required this.briefId,
    this.designerMemberId,
    this.designerName,
    required this.photoUrl1,
    this.photoUrl2,
    this.designerNotes,
    this.cleanDesignerNotes,
    this.concepts = const [],
    required this.phVerdict,
    this.phFeedback,
    this.saVerdict,
    this.saNotes,
    required this.submittedAt,
    this.reviewedAt,
  });

  factory DesignSubmissionModel.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['designer_notes'] as String?;
    String? cleanNotes = rawNotes;
    List<DesignConceptItemModel> parsedConcepts = [];

    if (json['concepts'] != null && json['concepts'] is List) {
      parsedConcepts = (json['concepts'] as List)
          .whereType<Map>()
          .map((c) => DesignConceptItemModel.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    } else if (rawNotes != null && rawNotes.contains('[CONCEPTS_JSON:')) {
      try {
        final match = RegExp(r'\[CONCEPTS_JSON:\s*(\[.*?\])\]', dotAll: true).firstMatch(rawNotes);
        if (match != null) {
          final jsonStr = match.group(1);
          if (jsonStr != null) {
            final dynamic decoded = jsonDecode(jsonStr);
            if (decoded is List) {
              parsedConcepts = decoded
                  .whereType<Map>()
                  .map((c) => DesignConceptItemModel.fromJson(Map<String, dynamic>.from(c)))
                  .toList();
            }
          }
          cleanNotes = rawNotes.replaceAll(RegExp(r'\[CONCEPTS_JSON:\s*(\[.*?\])\]', dotAll: true), '').trim();
          if (cleanNotes.isEmpty) cleanNotes = null;
        }
      } catch (_) {}
    }

    String p1 = json['photo_url_1'] as String? ?? '';
    String? p2 = json['photo_url_2'] as String?;

    if (p1.isEmpty && parsedConcepts.isNotEmpty) {
      for (final c in parsedConcepts) {
        for (final cw in c.safeColorways) {
          if (p1.isEmpty && cw.photoFront != null && cw.photoFront!.isNotEmpty) {
            p1 = cw.photoFront!;
          }
          if (p2 == null && cw.photoBack != null && cw.photoBack!.isNotEmpty) {
            p2 = cw.photoBack;
          }
          if (p1.isNotEmpty && p2 != null) break;
        }
        if (p1.isNotEmpty && p2 != null) break;
      }
    }

    return DesignSubmissionModel(
      id: json['id'] as String? ?? '',
      briefId: json['brief_id'] as String? ?? '',
      designerMemberId: json['designer_member_id'] as String?,
      designerName: json['designer_name'] as String?,
      photoUrl1: p1,
      photoUrl2: p2,
      designerNotes: rawNotes,
      cleanDesignerNotes: cleanNotes,
      concepts: parsedConcepts,
      phVerdict: (json['ph_verdict'] as String?) ?? 'PENDING',
      phFeedback: json['ph_feedback'] as String?,
      saVerdict: json['sa_verdict'] as String?,
      saNotes: json['sa_notes'] as String?,
      submittedAt: json['submitted_at'] as String? ?? DateTime.now().toIso8601String(),
      reviewedAt: json['reviewed_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brief_id': briefId,
      'designer_member_id': designerMemberId,
      'photo_url_1': photoUrl1,
      'photo_url_2': photoUrl2,
      'designer_notes': designerNotes,
      'ph_verdict': phVerdict,
      'ph_feedback': phFeedback,
      'sa_verdict': saVerdict,
      'sa_notes': saNotes,
      'submitted_at': submittedAt,
      'reviewed_at': reviewedAt,
    };
  }
}

class DesignBriefModel {
  final String id;
  final String phUserId;
  final String? designerMemberId;
  final String? designerName;
  final String? designerEmail;
  final String garmentType;
  final String category;
  final int? targetDesigns;
  final int? maxColors;
  final List<String> targetColors;
  final String? instructions;
  final String status; // 'ALLOCATED' | 'SUBMITTED' | 'PH_APPROVED' | 'PH_REJECTED' | 'SA_APPROVED' | 'SA_SAVED_FOR_LATER' | 'TECH_PACK_CREATED'
  final String companyName;
  final String createdAt;
  final String updatedAt;
  final DesignSubmissionModel? latestSubmission;

  int get safeTargetDesigns => (targetDesigns != null && targetDesigns! > 0) ? targetDesigns! : 1;
  int get safeMaxColors => (maxColors != null && maxColors! > 0) ? maxColors! : 3;

  const DesignBriefModel({
    required this.id,
    required this.phUserId,
    this.designerMemberId,
    this.designerName,
    this.designerEmail,
    required this.garmentType,
    required this.category,
    this.targetDesigns = 1,
    this.maxColors = 3,
    this.targetColors = const [],
    this.instructions,
    required this.status,
    required this.companyName,
    required this.createdAt,
    required this.updatedAt,
    this.latestSubmission,
  });

  factory DesignBriefModel.fromJson(Map<String, dynamic> json) {
    DesignSubmissionModel? sub;
    if (json['design_submissions'] != null && json['design_submissions'] is List) {
      final list = (json['design_submissions'] as List).whereType<Map>().toList();
      if (list.isNotEmpty) {
        final sorted = list.map((m) => Map<String, dynamic>.from(m)).toList();
        sorted.sort((a, b) => (b['submitted_at']?.toString() ?? '').compareTo(a['submitted_at']?.toString() ?? ''));
        sub = DesignSubmissionModel.fromJson(sorted.first);
      }
    } else if (json['latest_submission'] != null && json['latest_submission'] is Map) {
      sub = DesignSubmissionModel.fromJson(Map<String, dynamic>.from(json['latest_submission'] as Map));
    }

    final teamMember = json['design_team_members'] is Map ? json['design_team_members'] as Map : null;

    List<String> colorsList = [];
    if (json['target_colors'] != null && json['target_colors'] is List) {
      colorsList = (json['target_colors'] as List).map((e) => e.toString()).toList();
    }

    final tdRaw = json['target_designs'];
    final td = tdRaw is int ? tdRaw : (int.tryParse(tdRaw?.toString() ?? '') ?? 1);

    final mcRaw = json['max_colors'];
    final mc = mcRaw is int ? mcRaw : (int.tryParse(mcRaw?.toString() ?? '') ?? 3);

    return DesignBriefModel(
      id: json['id'] as String? ?? '',
      phUserId: json['ph_user_id'] as String? ?? '',
      designerMemberId: json['designer_member_id'] as String?,
      designerName: teamMember?['designer_name'] as String? ?? json['designer_name'] as String?,
      designerEmail: teamMember?['designer_email'] as String? ?? json['designer_email'] as String?,
      garmentType: json['garment_type'] as String? ?? 'T-Shirt',
      category: json['category'] as String? ?? 'Casual',
      targetDesigns: td,
      maxColors: mc,
      targetColors: colorsList,
      instructions: json['instructions'] as String?,
      status: json['status'] as String? ?? 'ALLOCATED',
      companyName: json['company_name'] as String? ?? 'Nubira Creation',
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      latestSubmission: sub,
    );
  }
}
