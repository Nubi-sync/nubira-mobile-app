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
    subtitle: 'Create tech packs, style specs, sample reviews, and design approvals.',
    badge: 'DESIGN STUDIO',
    statusText: 'SAMPLE DEVELOPMENT',
    icon: Icons.palette_outlined,
    route: '/design',
    features: ['Tech Packs & Style Specs', 'Sample Approvals & Colors'],
  ),
  ModuleCardData(
    id: 'merchandising',
    title: 'Merchandising & Sourcing',
    subtitle: 'Manage buyer purchase orders, style costing, fabric needs, and delivery dates.',
    badge: 'MERCHANDISING',
    statusText: 'COMMERCIAL OPS',
    icon: Icons.work_outline,
    route: '/merchandising',
    features: ['Buyer Purchase Orders', 'Fabric & Trim Costing'],
  ),
  ModuleCardData(
    id: 'cutting',
    title: 'Cutting & Lay Floor',
    subtitle: 'Plan fabric lays, cut order lots, print bundle tags, and issue cutting challans.',
    badge: 'CUTTING UNIT',
    statusText: 'LAY EXECUTION',
    icon: Icons.content_cut_outlined,
    route: '/cutting',
    features: ['Lay Planning & Roll Usage', 'Bundle Tags & Cut Challans'],
  ),
  ModuleCardData(
    id: 'printing',
    title: 'Screen & Digital Printing',
    subtitle: 'Track print lot orders, sample strike-off approvals, table runs, and daily output.',
    badge: 'PRINTING UNIT',
    statusText: 'PRINT DIVISION',
    icon: Icons.print_outlined,
    route: '/printing',
    features: ['Sample Strike-Off Approvals', 'Print Production & Quality'],
  ),
  ModuleCardData(
    id: 'embroidery',
    title: 'Multi-Head Embroidery',
    subtitle: 'Manage embroidery design files, machine running status, stitch counts, and daily lot output.',
    badge: 'EMBROIDERY UNIT',
    statusText: 'EMBROIDERY UNIT',
    icon: Icons.auto_awesome_outlined,
    route: '/embroidery',
    features: ['Punch Files & Stitch Count', 'Machine Production Logs'],
  ),
  ModuleCardData(
    id: 'stitching-sewing',
    title: 'Stitching & Sewing Floor',
    subtitle: 'Track sewing lines, bundle issues to tailors, hourly targets, and line checking.',
    badge: 'SEWING FLOOR',
    statusText: 'FLOOR EXECUTION',
    icon: Icons.layers_outlined,
    route: '/stitching-sewing',
    features: ['Sewing Lines & Bundle Issue', 'Hourly Output & End-Line QC'],
  ),
  ModuleCardData(
    id: 'washing',
    title: 'Industrial Washing',
    subtitle: 'Manage garment washing recipes, machine loads, batch timings, and wash quality.',
    badge: 'WASHING UNIT',
    statusText: 'WASH FLOOR',
    icon: Icons.waves_outlined,
    route: '/washing',
    features: ['Wash Batches & Recipes', 'Lot Inward & Outward Status'],
  ),
  ModuleCardData(
    id: 'iron',
    title: 'Ironing & Steam Pressing',
    subtitle: 'Track steam iron tables, operator pressing counts, wrinkle checks, and transfer to packing.',
    badge: 'IRONING & FINISHING',
    statusText: 'STEAM PRESSING',
    icon: Icons.local_fire_department_outlined,
    route: '/iron',
    features: ['Table Pressing Counts', 'Finishing & Press Inspection'],
  ),
  ModuleCardData(
    id: 'ready-goods',
    title: 'Quality Clinic & Export Packing',
    subtitle: '100% final garment checking, alteration repairs, polybag tagging, and carton packing.',
    badge: 'QUALITY & PACKING',
    statusText: 'FINAL CLEARANCE',
    icon: Icons.all_inbox_rounded,
    route: '/ready-goods',
    features: ['Final Inspection & Alterations', 'Polybag & Carton Packing'],
  ),
  ModuleCardData(
    id: 'store',
    title: 'Central Store & Godown',
    subtitle: 'Track fabric rolls, trims inventory, material issue to floor, and stock levels.',
    badge: 'CENTRAL STORE',
    statusText: 'STORE OPS',
    icon: Icons.storefront_outlined,
    route: '/store',
    features: ['Fabric Rolls & Trims Stock', 'Material Issues & Challans'],
  ),
  ModuleCardData(
    id: 'dispatch',
    title: 'Dispatch & Delivery Logistics',
    subtitle: 'Generate delivery challans, verify carton counts, assign vehicles, and print gate passes.',
    badge: 'DISPATCH & GATE',
    statusText: 'GATE DISPATCH',
    icon: Icons.local_shipping_outlined,
    route: '/dispatch',
    features: ['Delivery Challans & Invoices', 'Carton Count & Gate Passes'],
  ),
];
