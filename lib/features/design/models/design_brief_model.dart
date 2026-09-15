class DesignSubmissionModel {
  final String id;
  final String briefId;
  final String? designerMemberId;
  final String? designerName;
  final String photoUrl1;
  final String? photoUrl2;
  final String? designerNotes;
  final String phVerdict; // 'PENDING' | 'APPROVED' | 'REJECTED'
  final String? phFeedback;
  final String? saVerdict; // 'APPROVED' | 'SAVED_FOR_LATER' | 'REJECTED'
  final String? saNotes;
  final String submittedAt;
  final String? reviewedAt;

  const DesignSubmissionModel({
    required this.id,
    required this.briefId,
    this.designerMemberId,
    this.designerName,
    required this.photoUrl1,
    this.photoUrl2,
    this.designerNotes,
    required this.phVerdict,
    this.phFeedback,
    this.saVerdict,
    this.saNotes,
    required this.submittedAt,
    this.reviewedAt,
  });

  factory DesignSubmissionModel.fromJson(Map<String, dynamic> json) {
    return DesignSubmissionModel(
      id: json['id'] as String,
      briefId: json['brief_id'] as String,
      designerMemberId: json['designer_member_id'] as String?,
      designerName: json['designer_name'] as String?,
      photoUrl1: json['photo_url_1'] as String? ?? '',
      photoUrl2: json['photo_url_2'] as String?,
      designerNotes: json['designer_notes'] as String?,
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
  final int maxColors;
  final String? instructions;
  final String status; // 'ALLOCATED' | 'SUBMITTED' | 'PH_APPROVED' | 'PH_REJECTED' | 'SA_APPROVED' | 'SA_SAVED_FOR_LATER' | 'TECH_PACK_CREATED'
  final String companyName;
  final String createdAt;
  final String updatedAt;
  final DesignSubmissionModel? latestSubmission;

  const DesignBriefModel({
    required this.id,
    required this.phUserId,
    this.designerMemberId,
    this.designerName,
    this.designerEmail,
    required this.garmentType,
    required this.category,
    required this.maxColors,
    this.instructions,
    required this.status,
    required this.companyName,
    required this.createdAt,
    required this.updatedAt,
    this.latestSubmission,
  });

  factory DesignBriefModel.fromJson(Map<String, dynamic> json) {
    DesignSubmissionModel? sub;
    if (json['design_submissions'] != null && (json['design_submissions'] as List).isNotEmpty) {
      final list = json['design_submissions'] as List;
      final sorted = List<Map<String, dynamic>>.from(list);
      sorted.sort((a, b) => (b['submitted_at'] ?? '').compareTo(a['submitted_at'] ?? ''));
      sub = DesignSubmissionModel.fromJson(sorted.first);
    } else if (json['latest_submission'] != null) {
      sub = DesignSubmissionModel.fromJson(json['latest_submission'] as Map<String, dynamic>);
    }

    final teamMember = json['design_team_members'] as Map<String, dynamic>?;

    return DesignBriefModel(
      id: json['id'] as String,
      phUserId: json['ph_user_id'] as String? ?? '',
      designerMemberId: json['designer_member_id'] as String?,
      designerName: teamMember?['designer_name'] as String? ?? json['designer_name'] as String?,
      designerEmail: teamMember?['designer_email'] as String? ?? json['designer_email'] as String?,
      garmentType: json['garment_type'] as String? ?? 'T-Shirt',
      category: json['category'] as String? ?? 'Casual',
      maxColors: json['max_colors'] as int? ?? 3,
      instructions: json['instructions'] as String?,
      status: json['status'] as String? ?? 'ALLOCATED',
      companyName: json['company_name'] as String? ?? 'Nubira Creation',
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      latestSubmission: sub,
    );
  }
}
