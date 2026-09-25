
class ColorSizeMatrixItem {
  final String color;
  final Map<String, int> sizes;
  final int total;

  const ColorSizeMatrixItem({
    required this.color,
    required this.sizes,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
        'color': color,
        'sizes': sizes,
        'total': total,
      };

  factory ColorSizeMatrixItem.fromJson(Map<String, dynamic> json) {
    final rawSizes = json['sizes'] as Map<String, dynamic>? ?? {};
    final sizes = rawSizes.map((k, v) => MapEntry(k, (v as num).toInt()));
    return ColorSizeMatrixItem(
      color: json['color'] as String? ?? 'Standard',
      sizes: sizes,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class MerchandisingOrder {
  final String id;
  final String poNumber;
  final String brandName;
  final String styleRef;
  final String styleName;
  final String? techPackId;
  final int totalQuantity;
  final String currency;
  final double unitFobPrice;
  final double totalContractValue;
  final String exFactoryDate;
  final String status;
  final List<ColorSizeMatrixItem> colorMatrix;
  final String createdAt;
  final String embellishmentSequence;
  final List<dynamic> bomMaterials;
  final String fabricComposition;
  final int targetGsm;
  final String? buyerCode;
  final String? buyerId;
  final String? cadFrontUrl;
  final String? cadBackUrl;
  final String? companyName;

  const MerchandisingOrder({
    required this.id,
    required this.poNumber,
    required this.brandName,
    required this.styleRef,
    required this.styleName,
    this.techPackId,
    required this.totalQuantity,
    this.currency = 'INR',
    required this.unitFobPrice,
    required this.totalContractValue,
    required this.exFactoryDate,
    this.status = 'IN_CUTTING',
    this.colorMatrix = const [],
    required this.createdAt,
    this.embellishmentSequence = 'NONE',
    this.bomMaterials = const [],
    this.fabricComposition = '100% Combed Cotton',
    this.targetGsm = 180,
    this.buyerCode,
    this.buyerId,
    this.cadFrontUrl,
    this.cadBackUrl,
    this.companyName,
  });

  String get normalizedStatus {
    final s = status.toUpperCase().trim();
    if (s.isEmpty || s == 'BOOKED' || s == 'CONFIRMED' || s == 'PENDING_COSTING' || s == 'PENDING') {
      return 'IN_CUTTING';
    }
    return s;
  }

  String get statusLabel {
    switch (normalizedStatus) {
      case 'IN_CUTTING':
        return 'In Cutting';
      case 'IN_PRINTING':
        return 'In Printing';
      case 'IN_EMBROIDERY':
        return 'In Embroidery';
      case 'IN_SEWING':
        return 'In Sewing';
      case 'IRON':
        return 'Iron';
      case 'WASHING':
        return 'Washing';
      case 'ALTER':
        return 'Alter';
      case 'DISPATCHED':
        return 'Dispatched';
      case 'COMPLETED':
        return 'Completed';
      case 'CLOSED':
        return 'Closed';
      default:
        return normalizedStatus.replaceAll('_', ' ');
    }
  }

  String get routeLabel {
    switch (embellishmentSequence) {
      case 'NONE':
        return 'Cut & Sew';
      case 'ONLY_PRINTING':
        return 'Printing';
      case 'ONLY_EMBROIDERY':
        return 'Embroidery';
      case 'EMBROIDERY_FIRST_THEN_PRINT':
        return 'Emb → Print';
      case 'PRINT_FIRST_THEN_EMBROIDERY':
        return 'Print → Emb';
      default:
        return embellishmentSequence.isNotEmpty ? embellishmentSequence : 'Standard Flow';
    }
  }
}

class ActiveBuyer {
  final String id;
  final String buyerName;
  final String buyerCode;
  final String? brandName;
  final String? contactPerson;
  final String? contactEmail;
  final int contractedVolume;
  final double pricePerPiece;
  final double totalContractValue;
  final String currency;
  final String? linkedArticleId;
  final String? linkedArticleNumber;
  final String? linkedArticleName;
  final String status;
  final String? createdAt;

  final String? targetSeason;
  final String? notes;
  final String? updatedAt;
  final String? companyName;

  const ActiveBuyer({
    required this.id,
    required this.buyerName,
    required this.buyerCode,
    this.brandName,
    this.contactPerson,
    this.contactEmail,
    required this.contractedVolume,
    this.pricePerPiece = 12.5,
    this.totalContractValue = 0,
    this.currency = 'INR',
    this.targetSeason,
    this.linkedArticleId,
    this.linkedArticleNumber,
    this.linkedArticleName,
    this.status = 'ACTIVE',
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.companyName,
  });

  ActiveBuyer copyWith({
    String? id,
    String? buyerName,
    String? buyerCode,
    String? brandName,
    String? contactPerson,
    String? contactEmail,
    int? contractedVolume,
    double? pricePerPiece,
    double? totalContractValue,
    String? currency,
    String? targetSeason,
    String? linkedArticleId,
    String? linkedArticleNumber,
    String? linkedArticleName,
    String? status,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? companyName,
  }) {
    return ActiveBuyer(
      id: id ?? this.id,
      buyerName: buyerName ?? this.buyerName,
      buyerCode: buyerCode ?? this.buyerCode,
      brandName: brandName ?? this.brandName,
      contactPerson: contactPerson ?? this.contactPerson,
      contactEmail: contactEmail ?? this.contactEmail,
      contractedVolume: contractedVolume ?? this.contractedVolume,
      pricePerPiece: pricePerPiece ?? this.pricePerPiece,
      totalContractValue: totalContractValue ?? this.totalContractValue,
      currency: currency ?? this.currency,
      targetSeason: targetSeason ?? this.targetSeason,
      linkedArticleId: linkedArticleId ?? this.linkedArticleId,
      linkedArticleNumber: linkedArticleNumber ?? this.linkedArticleNumber,
      linkedArticleName: linkedArticleName ?? this.linkedArticleName,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      companyName: companyName ?? this.companyName,
    );
  }

  factory ActiveBuyer.fromJson(Map<String, dynamic> json) {
    final vol = (json['contracted_volume'] as num?)?.toInt() ?? 0;
    final price = (json['price_per_piece'] as num?)?.toDouble() ?? 12.5;
    return ActiveBuyer(
      id: json['id']?.toString() ?? '',
      buyerName: json['buyer_name'] as String? ?? 'Direct Buyer',
      buyerCode: json['buyer_code'] as String? ?? 'BUYER',
      brandName: json['brand_name'] as String?,
      contactPerson: json['contact_person'] as String?,
      contactEmail: json['contact_email'] as String?,
      contractedVolume: vol,
      pricePerPiece: price,
      totalContractValue: (json['total_contract_value'] as num?)?.toDouble() ?? (vol * price),
      currency: json['currency'] as String? ?? 'INR',
      targetSeason: json['target_season'] as String?,
      linkedArticleId: json['linked_article_id']?.toString(),
      linkedArticleNumber: json['linked_article_number'] as String?,
      linkedArticleName: json['linked_article_name'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      notes: json['notes'] as String?,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      companyName: json['company_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buyer_name': buyerName,
      'buyer_code': buyerCode,
      if (brandName != null) 'brand_name': brandName,
      if (contactPerson != null) 'contact_person': contactPerson,
      if (contactEmail != null) 'contact_email': contactEmail,
      'contracted_volume': contractedVolume,
      'price_per_piece': pricePerPiece,
      'total_contract_value': totalContractValue,
      'currency': currency,
      if (targetSeason != null) 'target_season': targetSeason,
      if (linkedArticleId != null) 'linked_article_id': linkedArticleId,
      if (linkedArticleNumber != null) 'linked_article_number': linkedArticleNumber,
      if (linkedArticleName != null) 'linked_article_name': linkedArticleName,
      'status': status,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (companyName != null) 'company_name': companyName,
    };
  }
}

class StageMetrics {
  final int inPending;
  final int inCutting;
  final int inPrinting;
  final int inEmbroidery;
  final int inSewing;
  final int iron;
  final int washing;
  final int alter;

  const StageMetrics({
    this.inPending = 0,
    this.inCutting = 0,
    this.inPrinting = 0,
    this.inEmbroidery = 0,
    this.inSewing = 0,
    this.iron = 0,
    this.washing = 0,
    this.alter = 0,
  });
}

class TnaMilestone {
  final String id;
  final String orderId;
  final String poNumber;
  final String styleRef;
  final String gateName;
  final String targetDate;
  final String? actualDate;
  final String status;
  final String? delayReason;
  final String? mitigationNotes;
  final int sortOrder;

  const TnaMilestone({
    required this.id,
    required this.orderId,
    this.poNumber = 'N/A',
    this.styleRef = 'Standard Style',
    required this.gateName,
    required this.targetDate,
    this.actualDate,
    this.status = 'ON_SCHEDULE',
    this.delayReason,
    this.mitigationNotes,
    this.sortOrder = 1,
  });

  String get milestoneName => gateName.replaceAll('_', ' ');

  String get plannedDate => targetDate;

  bool get isCompleted => status.toUpperCase() == 'COMPLETED' || status.toUpperCase() == 'CLEARED';
  bool get isDelayed => status.toUpperCase() == 'DELAYED';
  bool get isEscalated => status.toUpperCase() == 'ESCALATED';

  TnaMilestone copyWith({
    String? id,
    String? orderId,
    String? poNumber,
    String? styleRef,
    String? gateName,
    String? targetDate,
    String? actualDate,
    String? status,
    String? delayReason,
    String? mitigationNotes,
    int? sortOrder,
  }) {
    return TnaMilestone(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      poNumber: poNumber ?? this.poNumber,
      styleRef: styleRef ?? this.styleRef,
      gateName: gateName ?? this.gateName,
      targetDate: targetDate ?? this.targetDate,
      actualDate: actualDate ?? this.actualDate,
      status: status ?? this.status,
      delayReason: delayReason ?? this.delayReason,
      mitigationNotes: mitigationNotes ?? this.mitigationNotes,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory TnaMilestone.fromJson(Map<String, dynamic> json) {
    return TnaMilestone(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      poNumber: json['po_number']?.toString() ?? 'N/A',
      styleRef: json['style_ref']?.toString() ?? 'Standard Style',
      gateName: json['gate_name']?.toString() ?? json['milestone_name']?.toString() ?? 'GATE',
      targetDate: json['target_date']?.toString() ?? json['planned_date']?.toString() ?? '',
      actualDate: json['actual_date']?.toString(),
      status: json['status']?.toString() ?? 'ON_SCHEDULE',
      delayReason: json['delay_reason']?.toString(),
      mitigationNotes: json['mitigation_notes']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'gate_name': gateName,
      'target_date': targetDate,
      if (actualDate != null) 'actual_date': actualDate,
      'status': status,
      if (delayReason != null) 'delay_reason': delayReason,
      if (mitigationNotes != null) 'mitigation_notes': mitigationNotes,
    };
  }
}

class ActivityItem {
  final String id;
  final String type;
  final String title;
  final String details;
  final String location;
  final String timestamp;
  final String relativeTime;

  const ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.details,
    required this.location,
    required this.timestamp,
    required this.relativeTime,
  });
}

class TechPackBomMaterial {
  final String componentType;
  final String itemName;
  final String consumption;
  final String placement;

  const TechPackBomMaterial({
    required this.componentType,
    required this.itemName,
    this.consumption = '1',
    this.placement = '',
  });

  factory TechPackBomMaterial.fromJson(Map<String, dynamic> json) {
    return TechPackBomMaterial(
      componentType: json['component_type']?.toString() ?? json['component']?.toString() ?? 'TRIM',
      itemName: json['item_name']?.toString() ?? json['desc']?.toString() ?? json['item_description']?.toString() ?? '',
      consumption: json['consumption']?.toString() ?? json['cons']?.toString() ?? '1',
      placement: json['placement']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'component_type': componentType,
    'item_name': itemName,
    'consumption': consumption,
    'placement': placement,
  };
}

class TechPackArticleItem {
  final String id;
  final String styleNumber;
  final String category;
  final String? brandName;
  final String? brandId;
  final String embellishmentSequence;
  final String fabricComposition;
  final int targetGsm;
  final String? cadFrontUrl;
  final String? cadBackUrl;
  final String? companyName;
  final List<TechPackBomMaterial>? _bomMaterials;

  List<TechPackBomMaterial> get bomMaterials => _bomMaterials ?? const [];

  const TechPackArticleItem({
    required this.id,
    required this.styleNumber,
    required this.category,
    this.brandName,
    this.brandId,
    this.embellishmentSequence = 'NONE',
    this.fabricComposition = '100% Cotton',
    this.targetGsm = 180,
    this.cadFrontUrl,
    this.cadBackUrl,
    this.companyName,
    List<TechPackBomMaterial>? bomMaterials,
  }) : _bomMaterials = bomMaterials ?? const [];
}
