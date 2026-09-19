import 'dart:convert';

class ConceptColorwayModel {
  final String colorName;
  final String? photoFront;
  final String? photoBack;
  final String? status; // 'APPROVED' | 'REJECTED' | 'PENDING'
  final String? saVerdict; // 'APPROVED' | 'SAVED_FOR_LATER' | 'REJECTED' | 'PENDING'
  final String? saNotes;

  String get colorwayName => colorName;

  const ConceptColorwayModel({
    required this.colorName,
    this.photoFront,
    this.photoBack,
    this.status,
    this.saVerdict,
    this.saNotes,
  });

  ConceptColorwayModel copyWith({
    String? colorName,
    String? photoFront,
    String? photoBack,
    String? status,
    String? saVerdict,
    String? saNotes,
  }) {
    return ConceptColorwayModel(
      colorName: colorName ?? this.colorName,
      photoFront: photoFront ?? this.photoFront,
      photoBack: photoBack ?? this.photoBack,
      status: status ?? this.status,
      saVerdict: saVerdict ?? this.saVerdict,
      saNotes: saNotes ?? this.saNotes,
    );
  }

  factory ConceptColorwayModel.fromJson(Map<String, dynamic> json) {
    return ConceptColorwayModel(
      colorName: json['color_name'] as String? ?? 'Color',
      photoFront: json['photo_front'] as String?,
      photoBack: json['photo_back'] as String?,
      status: json['status'] as String?,
      saVerdict: json['sa_verdict'] as String?,
      saNotes: json['sa_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color_name': colorName,
      if (photoFront != null) 'photo_front': photoFront,
      if (photoBack != null) 'photo_back': photoBack,
      if (status != null) 'status': status,
      if (saVerdict != null) 'sa_verdict': saVerdict,
      if (saNotes != null) 'sa_notes': saNotes,
    };
  }
}

class DesignConceptItemModel {
  final int? conceptNumber;
  final String title;
  final String? notes;
  final String? artNumber;
  final String? status;
  final String? phVerdict;
  final String? phFeedback;
  final String? saVerdict;
  final String? saNotes;
  final List<ConceptColorwayModel>? colorways;

  int get safeConceptNumber => conceptNumber ?? 1;
  List<ConceptColorwayModel> get safeColorways => colorways ?? const <ConceptColorwayModel>[];

  const DesignConceptItemModel({
    this.conceptNumber = 1,
    required this.title,
    this.notes,
    this.artNumber,
    this.status,
    this.phVerdict,
    this.phFeedback,
    this.saVerdict,
    this.saNotes,
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
      artNumber: json['art_number'] as String?,
      status: json['status'] as String?,
      phVerdict: json['ph_verdict'] as String?,
      phFeedback: json['ph_feedback'] as String?,
      saVerdict: json['sa_verdict'] as String?,
      saNotes: json['sa_notes'] as String?,
      colorways: cws,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'concept_number': safeConceptNumber,
      'title': title,
      if (notes != null) 'notes': notes,
      if (artNumber != null) 'art_number': artNumber,
      if (status != null) 'status': status,
      if (phVerdict != null) 'ph_verdict': phVerdict,
      if (phFeedback != null) 'ph_feedback': phFeedback,
      if (saVerdict != null) 'sa_verdict': saVerdict,
      if (saNotes != null) 'sa_notes': saNotes,
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

class BriefDesignConceptRequirementModel {
  final int conceptNumber;
  final String? artNumber;
  final String? categoryStyle;
  final List<String> colors;
  final String? notes;

  const BriefDesignConceptRequirementModel({
    required this.conceptNumber,
    this.artNumber,
    this.categoryStyle,
    this.colors = const [],
    this.notes,
  });

  factory BriefDesignConceptRequirementModel.fromJson(Map<String, dynamic> json) {
    List<String> cols = [];
    if (json['colors'] != null && json['colors'] is List) {
      cols = (json['colors'] as List).map((c) => c.toString()).toList();
    }
    final cnRaw = json['concept_number'];
    final cn = cnRaw is int ? cnRaw : (int.tryParse(cnRaw?.toString() ?? '') ?? 1);
    return BriefDesignConceptRequirementModel(
      conceptNumber: cn,
      artNumber: json['art_number'] as String?,
      categoryStyle: json['category_style'] as String?,
      colors: cols,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'concept_number': conceptNumber,
      if (artNumber != null) 'art_number': artNumber,
      if (categoryStyle != null) 'category_style': categoryStyle,
      'colors': colors,
      if (notes != null) 'notes': notes,
    };
  }
}

class DesignBriefModel {
  final String id;
  final String phUserId;
  final String? designerMemberId;
  final String? designerName;
  final String? designerEmail;
  final String? designerPhone;
  final String garmentType;
  final String category;
  final int? targetDesigns;
  final int? maxColors;
  final List<String> targetColors;
  final String? instructions;
  final List<BriefDesignConceptRequirementModel>? designConceptsBrief;
  final String status; // 'ALLOCATED' | 'SUBMITTED' | 'PH_APPROVED' | 'PH_REJECTED' | 'SA_APPROVED' | 'SA_SAVED_FOR_LATER' | 'TECH_PACK_CREATED'
  final String companyName;
  final String createdAt;
  final String updatedAt;
  final DesignSubmissionModel? latestSubmission;

  List<BriefDesignConceptRequirementModel> get safeDesignConceptsBrief => designConceptsBrief ?? const <BriefDesignConceptRequirementModel>[];

  int get safeTargetDesigns => (targetDesigns != null && targetDesigns! > 0) ? targetDesigns! : (safeDesignConceptsBrief.isNotEmpty ? safeDesignConceptsBrief.length : 1);
  int get safeMaxColors => (maxColors != null && maxColors! > 0) ? maxColors! : 3;

  String get briefCode {
    if (id.isEmpty) return 'BRF-NEW';
    final cleanId = id.replaceAll('-', '');
    final suffix = cleanId.length >= 6 ? cleanId.substring(0, 6).toUpperCase() : cleanId.toUpperCase();
    return 'BRF-$suffix';
  }

  List<String> get safeColorways {
    if (targetColors.isNotEmpty) return targetColors;
    if (safeDesignConceptsBrief.isNotEmpty) {
      final set = <String>{};
      for (final c in safeDesignConceptsBrief) {
        for (final col in c.colors) {
          if (col.trim().isNotEmpty) set.add(col.trim());
        }
      }
      if (set.isNotEmpty) return set.toList();
    }
    if (instructions != null && instructions!.contains('[COLORS:')) {
      final match = RegExp(r'\[COLORS:\s*(.*?)\]').firstMatch(instructions!);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }
    return const [];
  }

  String get cleanInstructions {
    if (instructions == null) return '';
    return instructions!
        .replaceAll(RegExp(r'\[CONCEPTS_BRIEF:\s*\[[\s\S]*?\]\]\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[COLORS:\s*.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[TARGET:\s*.*?\]', caseSensitive: false), '')
        .trim();
  }

  List<DesignSubmissionModel> get submissions => latestSubmission != null ? [latestSubmission!] : const [];

  const DesignBriefModel({
    required this.id,
    required this.phUserId,
    this.designerMemberId,
    this.designerName,
    this.designerEmail,
    this.designerPhone,
    required this.garmentType,
    required this.category,
    this.targetDesigns = 1,
    this.maxColors = 3,
    this.targetColors = const [],
    this.instructions,
    this.designConceptsBrief = const [],
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

    final rawInst = json['instructions'] as String?;
    List<BriefDesignConceptRequirementModel> conceptsBrief = [];
    if (rawInst != null && rawInst.contains('[CONCEPTS_BRIEF:')) {
      try {
        final match = RegExp(r'\[CONCEPTS_BRIEF:\s*(\[[\s\S]*?\])\]', caseSensitive: false).firstMatch(rawInst);
        if (match != null && match.group(1) != null) {
          final dynamic decoded = jsonDecode(match.group(1)!);
          if (decoded is List) {
            conceptsBrief = decoded
                .whereType<Map>()
                .map((m) => BriefDesignConceptRequirementModel.fromJson(Map<String, dynamic>.from(m)))
                .toList();
          }
        }
      } catch (_) {}
    }

    List<String> colorsList = [];
    if (json['target_colors'] != null && json['target_colors'] is List) {
      colorsList = (json['target_colors'] as List).map((e) => e.toString()).toList();
    } else if (conceptsBrief.isNotEmpty) {
      final set = <String>{};
      for (final c in conceptsBrief) {
        for (final col in c.colors) {
          if (col.trim().isNotEmpty) set.add(col.trim());
        }
      }
      colorsList = set.toList();
    } else if (rawInst != null && rawInst.contains('[COLORS:')) {
      final match = RegExp(r'\[COLORS:\s*(.*?)\]').firstMatch(rawInst);
      if (match != null && match.group(1) != null) {
        colorsList = match.group(1)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    int td = conceptsBrief.isNotEmpty ? conceptsBrief.length : 1;
    final tdRaw = json['target_designs'] ?? json['num_designs'];
    if (tdRaw != null) {
      td = tdRaw is int ? tdRaw : (int.tryParse(tdRaw.toString()) ?? td);
    } else if (rawInst != null && rawInst.contains('[TARGET:')) {
      final match = RegExp(r'\[TARGET:\s*(\d+)\s*(?:Designs)?\]', caseSensitive: false).firstMatch(rawInst);
      if (match != null && match.group(1) != null) {
        td = int.tryParse(match.group(1)!) ?? td;
      }
    }

    final mcRaw = json['max_colors'];
    final mc = mcRaw is int ? mcRaw : (int.tryParse(mcRaw?.toString() ?? '') ?? (colorsList.isNotEmpty ? colorsList.length : 3));

    return DesignBriefModel(
      id: json['id'] as String? ?? '',
      phUserId: json['ph_user_id'] as String? ?? '',
      designerMemberId: json['designer_member_id'] as String?,
      designerName: teamMember?['designer_name'] as String? ?? json['designer_name'] as String?,
      designerEmail: teamMember?['designer_email'] as String? ?? json['designer_email'] as String?,
      designerPhone: teamMember?['phone_number'] as String? ?? teamMember?['designer_phone'] as String? ?? json['designer_phone'] as String?,
      garmentType: json['garment_type'] as String? ?? 'T-Shirt',
      category: json['category'] as String? ?? 'Casual',
      targetDesigns: td,
      maxColors: mc,
      targetColors: colorsList,
      instructions: rawInst,
      designConceptsBrief: conceptsBrief,
      status: json['status'] as String? ?? 'ALLOCATED',
      companyName: json['company_name'] as String? ?? 'Nubira Creation',
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      latestSubmission: sub,
    );
  }
}

class DesignTeamMemberModel {
  final String id;
  final String? phUserId;
  final String? designerUserId;
  final String designerName;
  final String? designerEmail;
  final String? phoneNumber;
  final String? designerPhone;
  final String? username;
  final String status;
  final String? companyName;
  final String createdAt;
  final String? updatedAt;

  const DesignTeamMemberModel({
    required this.id,
    this.phUserId,
    this.designerUserId,
    required this.designerName,
    this.designerEmail,
    this.phoneNumber,
    this.designerPhone,
    this.username,
    this.status = 'ACTIVE',
    this.companyName,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  String get safeUsername {
    if (username != null && username!.trim().isNotEmpty) {
      return username!.trim();
    }
    final nameSlug = designerName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').split('_').first;
    final compSlug = (companyName ?? 'nubira').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').split('_').first;
    return '${nameSlug}_$compSlug';
  }

  String get safePhone {
    if (phoneNumber != null && phoneNumber!.trim().isNotEmpty) {
      return phoneNumber!.trim();
    }
    if (designerPhone != null && designerPhone!.trim().isNotEmpty) {
      return designerPhone!.trim();
    }
    if (designerEmail != null && designerEmail!.contains('@designer.nubira.local')) {
      final p = designerEmail!.split('@')[0];
      if (RegExp(r'^\d{10}$').hasMatch(p)) return p;
    }
    return '—';
  }

  String get initials {
    final clean = designerName.trim();
    if (clean.isEmpty) return 'D';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      final str = parts.first;
      return (str.length >= 2 ? str.substring(0, 2) : str).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory DesignTeamMemberModel.fromJson(Map<String, dynamic> json) {
    final rawPhone = json['phone_number'] as String? ?? json['designer_phone'] as String?;
    final email = json['designer_email'] as String?;
    String? phone = rawPhone;
    if ((phone == null || phone.isEmpty) && email != null && email.contains('@designer.nubira.local')) {
      final p = email.split('@')[0];
      if (RegExp(r'^\d{10}$').hasMatch(p)) {
        phone = p;
      }
    }

    return DesignTeamMemberModel(
      id: json['id'] as String? ?? '',
      phUserId: json['ph_user_id'] as String?,
      designerUserId: json['designer_user_id'] as String?,
      designerName: json['designer_name'] as String? ?? 'Designer',
      designerEmail: email,
      phoneNumber: phone,
      designerPhone: rawPhone,
      username: json['username'] as String?,
      status: (json['status'] as String?)?.toUpperCase() ?? 'ACTIVE',
      companyName: json['company_name'] as String?,
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ph_user_id': phUserId,
      'designer_user_id': designerUserId,
      'designer_name': designerName,
      'designer_email': designerEmail,
      'phone_number': phoneNumber,
      'designer_phone': designerPhone,
      'username': username,
      'status': status,
      'company_name': companyName,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  DesignTeamMemberModel copyWith({
    String? id,
    String? phUserId,
    String? designerUserId,
    String? designerName,
    String? designerEmail,
    String? phoneNumber,
    String? designerPhone,
    String? username,
    String? status,
    String? companyName,
    String? createdAt,
    String? updatedAt,
  }) {
    return DesignTeamMemberModel(
      id: id ?? this.id,
      phUserId: phUserId ?? this.phUserId,
      designerUserId: designerUserId ?? this.designerUserId,
      designerName: designerName ?? this.designerName,
      designerEmail: designerEmail ?? this.designerEmail,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      designerPhone: designerPhone ?? this.designerPhone,
      username: username ?? this.username,
      status: status ?? this.status,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TechPackBomItemModel {
  final String id;
  final String componentType;
  final String itemName;
  final String specification;
  final String consumption;
  final String placement;

  const TechPackBomItemModel({
    required this.id,
    required this.componentType,
    required this.itemName,
    this.specification = '',
    this.consumption = '1',
    this.placement = '',
  });

  factory TechPackBomItemModel.fromJson(Map<String, dynamic> json) {
    return TechPackBomItemModel(
      id: json['id']?.toString() ?? '',
      componentType: json['component_type']?.toString() ?? 'TRIM',
      itemName: json['item_name']?.toString() ?? '',
      specification: json['specification']?.toString() ?? '',
      consumption: json['consumption']?.toString() ?? '1',
      placement: json['placement']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'component_type': componentType,
    'item_name': itemName,
    'specification': specification,
    'consumption': consumption,
    'placement': placement,
  };
}

class TechPackSummaryModel {
  final String id;
  final String styleNumber;
  final String styleName;
  final String category;
  final String brandName;
  final String baseSize;
  final String sizeSystem;
  final String fabricComposition;
  final int targetGsm;
  final String embellishmentSequence;
  final int spi;
  final String seamClass;
  final String? cadFrontUrl;
  final String? cadBackUrl;
  final String status;
  final int version;
  final String? targetCutDate;
  final String saVerdict;
  final String companyName;
  final String createdAt;
  final List<TechPackBomItemModel> bomItems;

  String get techPackCode => styleNumber;

  String get cleanFabricComposition {
    final cleaned = fabricComposition
        .replaceAll(RegExp(r'\[BOM_JSON:\s*\[[\s\S]*?\]\]\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[INSTRUCTIONS:\s*[\s\S]*?\]\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[TARGET_CUT_DATE:\s*[\s\S]*?\]\s*', caseSensitive: false), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : '100% Cotton';
  }

  String get cleanInstructions {
    final match = RegExp(r'\[INSTRUCTIONS:\s*([\s\S]*?)\]', caseSensitive: false).firstMatch(fabricComposition);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return '';
  }

  const TechPackSummaryModel({
    required this.id,
    required this.styleNumber,
    required this.styleName,
    required this.category,
    required this.brandName,
    required this.baseSize,
    this.sizeSystem = 'ALPHA_ADULT',
    required this.fabricComposition,
    required this.targetGsm,
    this.embellishmentSequence = 'NONE',
    required this.spi,
    required this.seamClass,
    this.cadFrontUrl,
    this.cadBackUrl,
    required this.status,
    this.version = 1,
    this.targetCutDate,
    this.saVerdict = 'APPROVED',
    this.companyName = 'Nubira Creation',
    required this.createdAt,
    this.bomItems = const [],
  });

  factory TechPackSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawFab = json['fabric_composition'] as String? ?? '100% Cotton';
    List<TechPackBomItemModel> parsedBoms = [];

    if (rawFab.contains('[BOM_JSON:')) {
      try {
        final match = RegExp(r'\[BOM_JSON:\s*(\[[\s\S]*?\])\]', caseSensitive: false).firstMatch(rawFab);
        if (match != null && match.group(1) != null) {
          final dynamic decoded = jsonDecode(match.group(1)!);
          if (decoded is List) {
            for (final m in decoded) {
              if (m is Map) {
                try {
                  parsedBoms.add(TechPackBomItemModel.fromJson(Map<String, dynamic>.from(m)));
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}
    }

    String cutDate = json['target_cut_date'] as String? ?? '';
    if (cutDate.isEmpty && rawFab.contains('[TARGET_CUT_DATE:')) {
      final cutMatch = RegExp(r'\[TARGET_CUT_DATE:\s*([\s\S]*?)\]', caseSensitive: false).firstMatch(rawFab);
      if (cutMatch != null && cutMatch.group(1) != null) {
        cutDate = cutMatch.group(1)!.trim();
      }
    }
    if (cutDate.isEmpty) {
      final created = DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
      cutDate = created.add(const Duration(days: 14)).toIso8601String().split('T').first;
    }

    String mapCategoryToUI(String cat) {
      final norm = cat.toUpperCase();
      if (norm.contains('HOODIE')) return 'Hoodie';
      if (norm.contains('TSHIRT') || norm.contains('T-SHIRT') || norm.contains('TEE')) return 'T-Shirt';
      if (norm.contains('POLO')) return 'Polo';
      if (norm.contains('JOGGER')) return 'Jogger';
      if (norm.contains('JACKET')) return 'Jacket';
      if (norm.contains('ROMPER')) return 'Kids Romper';
      if (norm.contains('SUIT')) return 'Suit';
      if (norm.contains('PANT')) return 'Pant';
      if (norm.contains('ETHNIC')) return 'Ethnic';
      if (norm.isNotEmpty) {
        return norm.substring(0, 1) + norm.substring(1).toLowerCase();
      }
      return 'T-Shirt';
    }

    final rawCat = json['category'] as String? ?? 'T-Shirt';
    final uiCategory = mapCategoryToUI(rawCat);
    final stNo = json['style_number'] as String? ?? 'ST-101';
    final rawName = json['style_name'] as String?;
    final resolvedName = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : '${rawCat.toUpperCase()} Style $stNo';

    String brandVal = 'Inhouse';
    if (json['brands'] is Map && json['brands']['brand_name'] != null) {
      brandVal = json['brands']['brand_name'].toString();
    } else if (json['brands'] is List && (json['brands'] as List).isNotEmpty) {
      final first = (json['brands'] as List).first;
      if (first is Map && first['brand_name'] != null) {
        brandVal = first['brand_name'].toString();
      }
    } else if (json['brand_name'] != null && json['brand_name'].toString().isNotEmpty) {
      brandVal = json['brand_name'].toString();
    }

    int parseNum(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        return int.tryParse(v) ?? (double.tryParse(v)?.toInt() ?? fallback);
      }
      return fallback;
    }

    final rawStatus = json['status'] as String?;
    final resolvedStatus = (rawStatus == null || rawStatus == 'DRAFT' || rawStatus.isEmpty)
        ? 'APPROVED_BULK'
        : rawStatus;

    return TechPackSummaryModel(
      id: json['id'] as String? ?? '',
      styleNumber: stNo,
      styleName: resolvedName,
      category: uiCategory,
      brandName: brandVal,
      baseSize: json['base_size'] as String? ?? 'M',
      sizeSystem: json['size_system'] as String? ?? 'ALPHA_ADULT',
      fabricComposition: rawFab,
      targetGsm: parseNum(json['target_gsm'], 240),
      embellishmentSequence: json['embellishment_sequence'] as String? ?? 'NONE',
      spi: parseNum(json['spi'], 12),
      seamClass: json['seam_class'] as String? ?? 'ISO 4915 Class 401 (Chainstitch)',
      cadFrontUrl: json['cad_front_url'] as String?,
      cadBackUrl: json['cad_back_url'] as String?,
      status: resolvedStatus,
      version: parseNum(json['version'], 1),
      targetCutDate: cutDate,
      saVerdict: json['sa_verdict'] as String? ?? 'APPROVED',
      companyName: json['company_name'] as String? ?? 'Nubira Creation',
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      bomItems: parsedBoms,
    );
  }
}
