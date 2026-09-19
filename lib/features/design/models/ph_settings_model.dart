class BodyPartCodeModel {
  final String id;
  final String? phUserId;
  final String? companyName;
  final String code;
  final String bodyPartName;
  final int sortOrder;
  final String? createdAt;

  const BodyPartCodeModel({
    required this.id,
    this.phUserId,
    this.companyName,
    required this.code,
    required this.bodyPartName,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory BodyPartCodeModel.fromJson(Map<String, dynamic> json) {
    return BodyPartCodeModel(
      id: json['id'] as String? ?? '',
      phUserId: json['ph_user_id'] as String?,
      companyName: json['company_name'] as String?,
      code: (json['code'] as String? ?? '').trim().toUpperCase(),
      bodyPartName: (json['body_part_name'] as String? ?? '').trim(),
      sortOrder: (json['sort_order'] is int ? json['sort_order'] : int.tryParse(json['sort_order']?.toString() ?? '')) ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (phUserId != null) 'ph_user_id': phUserId,
      if (companyName != null) 'company_name': companyName,
      'code': code,
      'body_part_name': bodyPartName,
      'sort_order': sortOrder,
    };
  }
}

class BOMComponentCodeModel {
  final String id;
  final String? phUserId;
  final String? companyName;
  final String componentType;
  final String componentSpec;
  final String? code;
  final int sortOrder;
  final String? createdAt;

  const BOMComponentCodeModel({
    required this.id,
    this.phUserId,
    this.companyName,
    required this.componentType,
    required this.componentSpec,
    this.code,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory BOMComponentCodeModel.fromJson(Map<String, dynamic> json) {
    return BOMComponentCodeModel(
      id: json['id'] as String? ?? '',
      phUserId: json['ph_user_id'] as String?,
      companyName: json['company_name'] as String?,
      componentType: (json['component_type'] as String? ?? 'BUTTON').trim().toUpperCase(),
      componentSpec: (json['component_spec'] as String? ?? '').trim(),
      code: (json['code'] as String?)?.trim().toUpperCase(),
      sortOrder: (json['sort_order'] is int ? json['sort_order'] : int.tryParse(json['sort_order']?.toString() ?? '')) ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (phUserId != null) 'ph_user_id': phUserId,
      if (companyName != null) 'company_name': companyName,
      'component_type': componentType,
      'component_spec': componentSpec,
      if (code != null) 'code': code,
      'sort_order': sortOrder,
    };
  }
}

class GarmentTemplateBodyPartModel {
  final String code;
  final String name;
  final double defaultTolerance;
  final double defaultGradeStep;

  const GarmentTemplateBodyPartModel({
    required this.code,
    required this.name,
    this.defaultTolerance = 1.0,
    this.defaultGradeStep = 2.0,
  });

  factory GarmentTemplateBodyPartModel.fromJson(Map<String, dynamic> json) {
    return GarmentTemplateBodyPartModel(
      code: (json['code'] as String? ?? '').trim().toUpperCase(),
      name: (json['name'] as String? ?? '').trim(),
      defaultTolerance: (json['default_tolerance'] is num ? (json['default_tolerance'] as num).toDouble() : double.tryParse(json['default_tolerance']?.toString() ?? '')) ?? 1.0,
      defaultGradeStep: (json['default_grade_step'] is num ? (json['default_grade_step'] as num).toDouble() : double.tryParse(json['default_grade_step']?.toString() ?? '')) ?? 2.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'default_tolerance': defaultTolerance,
      'default_grade_step': defaultGradeStep,
    };
  }
}

class GarmentTemplateModel {
  final String id;
  final String garmentType;
  final List<GarmentTemplateBodyPartModel> bodyParts;
  final List<dynamic> bomDefaults;
  final bool isSystemTemplate;
  final String? phUserId;
  final String? companyName;
  final String? createdAt;

  const GarmentTemplateModel({
    required this.id,
    required this.garmentType,
    this.bodyParts = const [],
    this.bomDefaults = const [],
    this.isSystemTemplate = false,
    this.phUserId,
    this.companyName,
    this.createdAt,
  });

  factory GarmentTemplateModel.fromJson(Map<String, dynamic> json) {
    List<GarmentTemplateBodyPartModel> parsedParts = [];
    if (json['body_parts'] is List) {
      parsedParts = (json['body_parts'] as List)
          .whereType<Map>()
          .map((m) => GarmentTemplateBodyPartModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return GarmentTemplateModel(
      id: json['id'] as String? ?? '',
      garmentType: (json['garment_type'] as String? ?? '').trim(),
      bodyParts: parsedParts,
      bomDefaults: json['bom_defaults'] as List? ?? [],
      isSystemTemplate: json['is_system_template'] == true,
      phUserId: json['ph_user_id'] as String?,
      companyName: json['company_name'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'garment_type': garmentType,
      'body_parts': bodyParts.map((p) => p.toJson()).toList(),
      'bom_defaults': bomDefaults,
      'is_system_template': isSystemTemplate,
      if (phUserId != null) 'ph_user_id': phUserId,
      if (companyName != null) 'company_name': companyName,
    };
  }
}
