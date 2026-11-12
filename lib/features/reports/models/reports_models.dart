class ReportKpis {
  final int totalProduced;
  final double producedTrendPct;
  final double qcPassRate;
  final double qcPassTrendPct;
  final int netWarehouseStock;
  final double warehouseTrendPct;
  final int totalDispatched;
  final double dispatchTrendPct;

  const ReportKpis({
    this.totalProduced = 0,
    this.producedTrendPct = 0,
    this.qcPassRate = 100.0,
    this.qcPassTrendPct = 0,
    this.netWarehouseStock = 0,
    this.warehouseTrendPct = 0,
    this.totalDispatched = 0,
    this.dispatchTrendPct = 0,
  });
}

class ProductionTrendPoint {
  final String date;
  final String label;
  final int pieces;

  const ProductionTrendPoint({
    required this.date,
    required this.label,
    required this.pieces,
  });
}

class QcTrendPoint {
  final String date;
  final String label;
  final int passed;
  final int rejected;
  final double passRate;

  const QcTrendPoint({
    required this.date,
    required this.label,
    required this.passed,
    required this.rejected,
    required this.passRate,
  });
}

class ArticleWorkerOperation {
  final String id;
  final String division;
  final String divisionRoute;
  final String workerName;
  final String? workerPhone;
  final String operation;
  final String workstation;
  final int targetPcs;
  final int completedPcs;
  final int rejectedPcs;
  final String status;
  final String? timestamp;

  const ArticleWorkerOperation({
    required this.id,
    required this.division,
    required this.divisionRoute,
    required this.workerName,
    this.workerPhone,
    required this.operation,
    required this.workstation,
    required this.targetPcs,
    required this.completedPcs,
    required this.rejectedPcs,
    required this.status,
    this.timestamp,
  });
}

class ArticleReportRow {
  final String id;
  final String artNo;
  final String description;
  final String buyerName;
  final String poNumber;
  final int targetPcs;
  final int cutPcs;
  final int printEmbPcs;
  final int stitchedPcs;
  final int washedPcs;
  final int ironedPcs;
  final int qcPassedPcs;
  final int qcFailedPcs;
  final double qcRejectRatePct;
  final int godownPcs;
  final int dispatchedPcs;
  final int progressPct;
  final String stageStatus;
  final List<ArticleWorkerOperation> operations;

  const ArticleReportRow({
    required this.id,
    required this.artNo,
    required this.description,
    required this.buyerName,
    required this.poNumber,
    required this.targetPcs,
    required this.cutPcs,
    required this.printEmbPcs,
    required this.stitchedPcs,
    required this.washedPcs,
    required this.ironedPcs,
    required this.qcPassedPcs,
    required this.qcFailedPcs,
    required this.qcRejectRatePct,
    required this.godownPcs,
    required this.dispatchedPcs,
    required this.progressPct,
    required this.stageStatus,
    required this.operations,
  });
}

class WorkerPieceLedgerItem {
  final String id;
  final String workerName;
  final String? workerPhone;
  final String role;
  final String division;
  final String divisionRoute;
  final String articleNo;
  final String articleName;
  final String? buyerName;
  final String operationName;
  final String workstationRef;
  final int targetPieces;
  final int completedPieces;
  final int rejectedPieces;
  final String status;
  final String date;

  const WorkerPieceLedgerItem({
    required this.id,
    required this.workerName,
    this.workerPhone,
    required this.role,
    required this.division,
    required this.divisionRoute,
    required this.articleNo,
    required this.articleName,
    this.buyerName,
    required this.operationName,
    required this.workstationRef,
    required this.targetPieces,
    required this.completedPieces,
    required this.rejectedPieces,
    required this.status,
    required this.date,
  });
}

class DivisionScorePoint {
  final String division;
  final String divisionRoute;
  final int score;
  final String metricLabel;
  final int workerCount;
  final int totalOutput;

  const DivisionScorePoint({
    required this.division,
    required this.divisionRoute,
    required this.score,
    required this.metricLabel,
    required this.workerCount,
    required this.totalOutput,
  });
}

class BuyerFulfillmentItem {
  final String poNumber;
  final String buyerName;
  final String orderDate;
  final String deliveryDate;
  final int targetPieces;
  final int deliveredPieces;
  final int godownPieces;
  final List<String> challanNumbers;
  final int percent;
  final bool isOverdue;
  final String status;

  const BuyerFulfillmentItem({
    required this.poNumber,
    required this.buyerName,
    required this.orderDate,
    required this.deliveryDate,
    required this.targetPieces,
    required this.deliveredPieces,
    required this.godownPieces,
    required this.challanNumbers,
    required this.percent,
    required this.isOverdue,
    required this.status,
  });
}

class ReportsData {
  final String companyName;
  final List<String> allowedDivisions;
  final ReportKpis kpis;
  final List<ProductionTrendPoint> productionTrend;
  final int dailyAverage;
  final List<QcTrendPoint> qcTrend;
  final List<ArticleReportRow> articlesReport;
  final List<WorkerPieceLedgerItem> workerLedger;
  final List<DivisionScorePoint> divisionComparison;
  final List<BuyerFulfillmentItem> buyerFulfillments;
  final String generatedAt;

  const ReportsData({
    this.companyName = 'Apparel Factory',
    this.allowedDivisions = const [],
    this.kpis = const ReportKpis(),
    this.productionTrend = const [],
    this.dailyAverage = 0,
    this.qcTrend = const [],
    this.articlesReport = const [],
    this.workerLedger = const [],
    this.divisionComparison = const [],
    this.buyerFulfillments = const [],
    this.generatedAt = 'Just now',
  });
}

