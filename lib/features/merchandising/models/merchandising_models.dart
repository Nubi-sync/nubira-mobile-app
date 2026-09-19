
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
  });

  String get normalizedStatus {
    if (status.isEmpty || status == 'BOOKED') return 'IN_CUTTING';
    return status;
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
  final String gateName;
  final String targetDate;
  final String? actualDate;
  final String status;
  final String? delayReason;

  const TnaMilestone({
    required this.id,
    required this.orderId,
    required this.gateName,
    required this.targetDate,
    this.actualDate,
    this.status = 'ON_SCHEDULE',
    this.delayReason,
  });
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
  });
}
