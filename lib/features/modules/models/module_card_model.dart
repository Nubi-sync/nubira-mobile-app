import 'package:flutter/material.dart';

class ModuleCardData {
  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final String statusText;
  final IconData icon;
  final String route;
  final List<String> features;

  const ModuleCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.statusText,
    required this.icon,
    required this.route,
    required this.features,
  });
}

const List<ModuleCardData> allEnterpriseModules = [
  ModuleCardData(
    id: 'design',
    title: 'Design & Tech-Pack Studio',
    subtitle: 'CAD sketches, tech-pack specs, sample iterations, and fabric grading approvals.',
    badge: 'CREATIVE STUDIO',
    statusText: 'SAMPLE DEVELOPMENT',
    icon: Icons.palette_outlined,
    route: '/design',
    features: ['Tech-Pack Spec Sheets', 'CAD Sampling Approvals', 'Size & Fit Grading Matrix'],
  ),
  ModuleCardData(
    id: 'merchandising',
    title: 'Merchandising & Sourcing',
    subtitle: 'Buyer PO allocation, BOM costing, trim procurement, and shipment schedules.',
    badge: 'BUYER & SOURCING',
    statusText: 'COMMERCIAL OPS',
    icon: Icons.work_outline,
    route: '/merchandising',
    features: ['Buyer PO & BOM Costing', 'Trim Procurement Ledger', 'Production Milestone Gantt'],
  ),
  ModuleCardData(
    id: 'cutting',
    title: 'Cutting & Lay Floor',
    subtitle: 'Fabric roll lay planning, marker efficiency, auto-cutters, and bundle generation.',
    badge: 'CUTTING DIVISION',
    statusText: 'LAY EXECUTION',
    icon: Icons.content_cut_outlined,
    route: '/cutting',
    features: ['Lay Sheet & Marker Ratio', 'Fabric Roll Consumption', 'Bundle QR Ticket Generation'],
  ),
  ModuleCardData(
    id: 'printing',
    title: 'Screen & Digital Printing',
    subtitle: 'Screen print tables, industrial DTG curing, and strike-off color approvals.',
    badge: 'SURFACE ART',
    statusText: 'PRINT DIVISION',
    icon: Icons.print_outlined,
    route: '/printing',
    features: ['Screen Table Lots', 'Strike-Off Approvals', 'DTG & Sublimation Flow'],
  ),
  ModuleCardData(
    id: 'embroidery',
    title: 'Multi-Head Embroidery',
    subtitle: 'Multi-head computerized machines, punch digitizing, and stitch billing.',
    badge: 'THREAD ART',
    statusText: 'EMBROIDERY UNIT',
    icon: Icons.auto_awesome_outlined,
    route: '/embroidery',
    features: ['Multi-Head Machine Runs', 'Punch File Library', 'Stitch Rate Billing'],
  ),
  ModuleCardData(
    id: 'stitching-sewing',
    title: 'Stitching & Sewing Floor',
    subtitle: 'Live cutting lots, lineman bundle allocations, 3-stage QC, and store sync.',
    badge: 'SEWING FLOOR',
    statusText: 'FLOOR EXECUTION',
    icon: Icons.layers_outlined,
    route: '/stitching-sewing',
    features: ['Live Cutting Challans', 'Lineman Bundle Allocations', '3-Stage QC & Store Sync'],
  ),
  ModuleCardData(
    id: 'washing',
    title: 'Industrial Washing',
    subtitle: 'Garment enzyme wash, silicon softeners, and liquor ratio batch tracking.',
    badge: 'WET PROCESSING',
    statusText: 'WASH FLOOR',
    icon: Icons.waves_outlined,
    route: '/washing',
    features: ['Enzyme & Silicone Cycles', 'Batch Liquor Tracker', 'Hydro & Tumbler Logs'],
  ),
  ModuleCardData(
    id: 'iron',
    title: 'Ironing & Steam Pressing',
    subtitle: 'Industrial steam irons, vacuum pressing boards, temperature checks, and inline finishing.',
    badge: 'FINISHING UNIT',
    statusText: 'STEAM PRESSING',
    icon: Icons.local_fire_department_outlined,
    route: '/iron',
    features: ['Steam Vacuum Tables', 'Inline Finish Inspection', 'Ironing Piece-Rate Logs'],
  ),
  ModuleCardData(
    id: 'ready-goods',
    title: 'Ready Goods & Packing',
    subtitle: 'AQL 2.5 final inspection, barcode hangtags, polybag sealing, and carton packaging.',
    badge: 'FINAL PACKING',
    statusText: 'CARTON READY',
    icon: Icons.inventory_2_outlined,
    route: '/ready-goods',
    features: ['AQL Final Audit', 'Hangtag & Polybag Packing', 'Master Carton Manifest'],
  ),
  ModuleCardData(
    id: 'alter',
    title: 'Alteration & Rework',
    subtitle: 'Defect categorization, seam rework, broken stitch alterations, and re-inspection logs.',
    badge: 'REWORK CLINIC',
    statusText: 'QUALITY RECOVERY',
    icon: Icons.build_outlined,
    route: '/alter',
    features: ['Defect Root-Cause Tagging', 'Line-Wise Rework Queue', 'Post-Repair AQL Clearance'],
  ),
  ModuleCardData(
    id: 'store',
    title: 'Central Store & Godown',
    subtitle: 'Raw fabric rolls, trims inventory, cutting challan issue, and finished carton storage.',
    badge: 'CENTRAL GODOWN',
    statusText: 'STORE OPS',
    icon: Icons.storefront_outlined,
    route: '/store',
    features: ['Raw Material & Trim Godown', 'Cutting Challan Issues', 'Finished Carton Stock Ledger'],
  ),
  ModuleCardData(
    id: 'dispatch',
    title: 'Dispatch & Delivery Logistics',
    subtitle: 'Delivery challans, physical counting audits, transport vehicle assignments, and gate-out passes.',
    badge: 'LOGISTICS GATE',
    statusText: 'GATE DISPATCH',
    icon: Icons.local_shipping_outlined,
    route: '/dispatch',
    features: ['Pre-Loading Counting Audit', 'GST Delivery Challans', 'Factory Gate-Out Authorization'],
  ),
];
