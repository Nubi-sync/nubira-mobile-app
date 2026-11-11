import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/tenant_resolver_service.dart';
import '../../auth/providers/auth_provider.dart';

class ProductionManagerItem {
  final String id;
  final String name;
  final String username;
  final String phone;
  final String? email;
  final bool isActive;
  final String? createdAt;

  const ProductionManagerItem({
    required this.id,
    required this.name,
    required this.username,
    required this.phone,
    this.email,
    required this.isActive,
    this.createdAt,
  });

  ProductionManagerItem copyWith({
    String? id,
    String? name,
    String? username,
    String? phone,
    String? email,
    bool? isActive,
    String? createdAt,
  }) {
    return ProductionManagerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DepartmentHeadItem {
  final String id;
  final String displayName;
  final String username;
  final String email;
  final String role;
  final String designation;
  final List<String> allowedModules;
  final bool isActive;
  final String phone;
  final String? phone2;
  final String? createdAt;

  const DepartmentHeadItem({
    required this.id,
    required this.displayName,
    required this.username,
    required this.email,
    required this.role,
    required this.designation,
    required this.allowedModules,
    required this.isActive,
    required this.phone,
    this.phone2,
    this.createdAt,
  });

  DepartmentHeadItem copyWith({
    String? id,
    String? displayName,
    String? username,
    String? email,
    String? role,
    String? designation,
    List<String>? allowedModules,
    bool? isActive,
    String? phone,
    String? phone2,
    String? createdAt,
  }) {
    return DepartmentHeadItem(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      designation: designation ?? this.designation,
      allowedModules: allowedModules ?? this.allowedModules,
      isActive: isActive ?? this.isActive,
      phone: phone ?? this.phone,
      phone2: phone2 ?? this.phone2,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DivisionDef {
  final String id;
  final String code;
  final String name;
  final String route;
  final String defaultDesignation;
  final String iconName;
  final String description;

  const DivisionDef({
    required this.id,
    required this.code,
    required this.name,
    required this.route,
    required this.defaultDesignation,
    required this.iconName,
    required this.description,
  });

  IconData get icon {
    switch (iconName) {
      case 'Palette':
        return Icons.palette_outlined;
      case 'Briefcase':
        return Icons.business_center_outlined;
      case 'Store':
        return Icons.storefront_outlined;
      case 'Scissors':
        return Icons.content_cut_rounded;
      case 'Printer':
        return Icons.print_outlined;
      case 'Layers':
        return Icons.layers_outlined;
      case 'Sparkles':
        return Icons.auto_awesome_outlined;
      case 'Waves':
        return Icons.waves_outlined;
      case 'Flame':
        return Icons.local_fire_department_outlined;
      case 'Boxes':
        return Icons.inventory_2_outlined;
      case 'Wrench':
        return Icons.build_outlined;
      case 'Truck':
        return Icons.local_shipping_outlined;
      default:
        return Icons.apartment_outlined;
    }
  }
}

typedef DepartmentHeadCatalogDef = DivisionDef;
const List<DivisionDef> kDepartmentHeadsCatalog = kAllDefaultDivisions;

const List<DivisionDef> kAllDefaultDivisions = [
  DivisionDef(
    id: 'div-01',
    code: '01',
    name: 'Design & Tech-Pack Studio',
    route: '/design',
    defaultDesignation: 'Design Studio Head / CAD Master',
    iconName: 'Palette',
    description: 'CAD sketches, tech-pack specs, sample iterations & grading approvals',
  ),
  DivisionDef(
    id: 'div-02',
    code: '02',
    name: 'Merchandising & Sourcing Desk',
    route: '/merchandising',
    defaultDesignation: 'Senior Merchandiser / Sourcing Head',
    iconName: 'Briefcase',
    description: 'Buyer PO allocation, BOM costing, trim procurement & shipment schedules',
  ),
  DivisionDef(
    id: 'div-03',
    code: '03',
    name: 'Cutting Floor & Spreading CAD',
    route: '/cutting',
    defaultDesignation: 'Cutting Master / Cutting Floor Head',
    iconName: 'Scissors',
    description: 'Fabric roll lay planning, marker efficiency, auto-cutters & bundle tickets',
  ),
  DivisionDef(
    id: 'div-04',
    code: '04',
    name: 'Screen & Digital Printing Studio',
    route: '/printing',
    defaultDesignation: 'Printing Master / Print Unit Head',
    iconName: 'Printer',
    description: 'Screen print tables, industrial DTG curing & strike-off color approvals',
  ),
  DivisionDef(
    id: 'div-05',
    code: '05',
    name: 'Multi-Head Embroidery Studio',
    route: '/embroidery',
    defaultDesignation: 'Embroidery Master / Unit Head',
    iconName: 'Sparkles',
    description: 'Multi-head computerized machines, punch digitizing & stitch billing',
  ),
  DivisionDef(
    id: 'div-06',
    code: '06',
    name: 'Stitching & Sewing Lines',
    route: '/stitching-sewing',
    defaultDesignation: 'Production Manager / Sewing Floor Head',
    iconName: 'Layers',
    description: 'Live cutting lots, lineman bundle allocations, 3-stage QC & store sync',
  ),
  DivisionDef(
    id: 'div-07',
    code: '07',
    name: 'Industrial Washing & Dyeing',
    route: '/washing',
    defaultDesignation: 'Washing Master / Wet Processing Head',
    iconName: 'Waves',
    description: 'Garment enzyme wash, silicon softeners & liquor ratio batch tracking',
  ),
  DivisionDef(
    id: 'div-08',
    code: '08',
    name: 'Steam Pressing & Ironing Floor',
    route: '/iron',
    defaultDesignation: 'Finishing & Ironing Incharge',
    iconName: 'Flame',
    description: 'Industrial steam irons, vacuum pressing boards & inline finish inspection',
  ),
  DivisionDef(
    id: 'div-09',
    code: '09',
    name: 'Ready Goods & Carton Packing',
    route: '/ready-goods',
    defaultDesignation: 'Quality Assurance Head / AQL Manager',
    iconName: 'Boxes',
    description: 'AQL 2.5 final inspection, barcode hangtags, polybag sealing & cartons',
  ),
  DivisionDef(
    id: 'div-10',
    code: '10',
    name: 'Alteration & Reclamation Clinic',
    route: '/alter',
    defaultDesignation: 'Alteration Incharge / Rework Master',
    iconName: 'Wrench',
    description: 'Defect categorization, seam rework, broken stitch alterations & re-inspection',
  ),
  DivisionDef(
    id: 'div-11',
    code: '11',
    name: 'Central Store Godown & Vault',
    route: '/store',
    defaultDesignation: 'Store Manager / Chief Godown Keeper',
    iconName: 'Store',
    description: 'Raw fabric rolls, trims inventory, cutting challan issue & finished carton storage',
  ),
  DivisionDef(
    id: 'div-12',
    code: '12',
    name: 'Dispatch & Delivery Logistics',
    route: '/dispatch',
    defaultDesignation: 'Dispatch Manager / Logistics Head',
    iconName: 'Truck',
    description: 'Delivery challans, physical counting audits, vehicle gate-out & logistics passes',
  ),
];

class FloorWorkerItem {
  final String id;
  final String name;
  final String phone;
  final String departmentRoute;
  final String role;
  final String shift;
  final String status;

  const FloorWorkerItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.departmentRoute,
    required this.role,
    this.shift = 'General',
    required this.status,
  });

  FloorWorkerItem copyWith({
    String? id,
    String? name,
    String? phone,
    String? departmentRoute,
    String? role,
    String? shift,
    String? status,
  }) {
    return FloorWorkerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      departmentRoute: departmentRoute ?? this.departmentRoute,
      role: role ?? this.role,
      shift: shift ?? this.shift,
      status: status ?? this.status,
    );
  }
}

class _DivisionWorkerConfig {
  final String table;
  final String roleField;
  final String nameField;
  final String phoneField;
  final String defaultRole;

  const _DivisionWorkerConfig({
    required this.table,
    required this.roleField,
    required this.nameField,
    required this.phoneField,
    required this.defaultRole,
  });
}

// Strictly matches Web Admin DIVISION_WORKER_MAP in access-control/actions.ts
const Map<String, _DivisionWorkerConfig> _kDivisionWorkerMap = {
  '/cutting': _DivisionWorkerConfig(
    table: 'cutting_workers',
    roleField: 'role',
    nameField: 'worker_name',
    phoneField: 'phone_number',
    defaultRole: 'Knife Cutter',
  ),
  '/stitching-sewing': _DivisionWorkerConfig(
    table: 'stitching_workers',
    roleField: 'role',
    nameField: 'worker_name',
    phoneField: 'phone_number',
    defaultRole: 'Tailor',
  ),
  '/printing': _DivisionWorkerConfig(
    table: 'printing_workers',
    roleField: 'role',
    nameField: 'worker_name',
    phoneField: 'phone_number',
    defaultRole: 'Screen Printer',
  ),
  '/embroidery': _DivisionWorkerConfig(
    table: 'embroidery_workers',
    roleField: 'role',
    nameField: 'worker_name',
    phoneField: 'phone_number',
    defaultRole: 'Machine Operator',
  ),
  '/washing': _DivisionWorkerConfig(
    table: 'washing_workers',
    roleField: 'role',
    nameField: 'worker_name',
    phoneField: 'phone_number',
    defaultRole: 'Washer',
  ),
  '/iron': _DivisionWorkerConfig(
    table: 'iron_workers',
    roleField: 'role',
    nameField: 'worker_name',
    phoneField: 'phone_number',
    defaultRole: 'Ironer',
  ),
  '/design': _DivisionWorkerConfig(
    table: 'design_team_members',
    roleField: 'role',
    nameField: 'name',
    phoneField: 'phone_number',
    defaultRole: 'Designer',
  ),
};

class SupervisorWorkersState {
  final String companyName;
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final List<ProductionManagerItem> productionManagers;
  final List<DepartmentHeadItem> departmentHeads;
  final List<DivisionDef> divisions;
  final List<FloorWorkerItem> workers;
  final bool isLoading;
  final String? error;

  const SupervisorWorkersState({
    required this.companyName,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.productionManagers,
    required this.departmentHeads,
    required this.divisions,
    required this.workers,
    this.isLoading = false,
    this.error,
  });

  factory SupervisorWorkersState.initial() => const SupervisorWorkersState(
        companyName: 'Nubira Creation',
        ownerName: 'Company Owner',
        ownerEmail: '',
        ownerPhone: '9876543210',
        productionManagers: [],
        departmentHeads: [],
        divisions: kAllDefaultDivisions,
        workers: [],
        isLoading: true,
      );

  SupervisorWorkersState copyWith({
    String? companyName,
    String? ownerName,
    String? ownerEmail,
    String? ownerPhone,
    List<ProductionManagerItem>? productionManagers,
    List<DepartmentHeadItem>? departmentHeads,
    List<DivisionDef>? divisions,
    List<FloorWorkerItem>? workers,
    bool? isLoading,
    String? error,
  }) {
    return SupervisorWorkersState(
      companyName: companyName ?? this.companyName,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      productionManagers: productionManagers ?? this.productionManagers,
      departmentHeads: departmentHeads ?? this.departmentHeads,
      divisions: divisions ?? this.divisions,
      workers: workers ?? this.workers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SupervisorWorkersNotifier extends StateNotifier<SupervisorWorkersState> {
  final Ref ref;

  SupervisorWorkersNotifier(this.ref) : super(SupervisorWorkersState.initial()) {
    fetchData();
  }

  Future<void> fetchData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = Supabase.instance.client;
      final authState = ref.read(authProvider);
      final currentUser = client.auth.currentUser;
      final tenant = authState.tenantProfile ??
          (currentUser != null
              ? await TenantResolverService.resolveUserTenant(currentUser)
              : null);

      final companyName = (tenant?.companyName ?? 'Nubira Creation').trim();
      final normCompany = companyName.toLowerCase().trim();
      final ownerEmail = (tenant?.userEmail ?? currentUser?.email ?? '').trim();
      final normOwnerEmail = ownerEmail.toLowerCase();
      final roleUpper = (tenant?.role ?? authState.userRole ?? '').toUpperCase();
      final isOwnerCaller = (tenant?.isSuperAdmin == true) ||
          roleUpper == 'SUPERADMIN' ||
          roleUpper == 'ADMIN' ||
          roleUpper == 'PLATFORM_SUPERADMIN' ||
          normOwnerEmail == 'admin@zigza.in' ||
          normOwnerEmail == 'team.anga9@gmail.com' ||
          normOwnerEmail == 'aj@nubiracreation.com';
      final isPlatformSuperAdmin =
          (tenant?.isPlatformAdmin == true) || normOwnerEmail == 'admin@zigza.in';

      // 1. Resolve configured / purchased divisions first (Strictly matching Web Admin)
      List<String> allowedRoutes = [];
      if (!isPlatformSuperAdmin &&
          tenant != null &&
          tenant.allowedDivisions.isNotEmpty &&
          !tenant.allowedDivisions.contains('/platform-admin')) {
        allowedRoutes = List<String>.from(tenant.allowedDivisions);
      } else if (!isPlatformSuperAdmin &&
          authState.allowedDivisions.isNotEmpty &&
          !authState.allowedDivisions.contains('/platform-admin')) {
        allowedRoutes = List<String>.from(authState.allowedDivisions);
      }

      if (allowedRoutes.isEmpty && !isPlatformSuperAdmin && ownerEmail.isNotEmpty) {
        try {
          final factoryRes = await client
              .from('platform_tenant_factories')
              .select('allowed_divisions')
              .or('admin_email.ilike.$ownerEmail,company_name.ilike.$companyName')
              .limit(1)
              .maybeSingle();
          if (factoryRes != null && factoryRes['allowed_divisions'] is List) {
            allowedRoutes =
                (factoryRes['allowed_divisions'] as List).map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }

      bool isRouteAllowed(String route) {
        if (isPlatformSuperAdmin || allowedRoutes.isEmpty) return true;
        if (allowedRoutes.contains('/platform-admin') || allowedRoutes.contains('*')) {
          return true;
        }
        if (allowedRoutes.contains(route)) return true;
        if ((route == '/fabric-store' || route == '/store') &&
            (allowedRoutes.contains('/fabric-store') || allowedRoutes.contains('/store'))) {
          return true;
        }
        if ((route == '/stitching' || route == '/stitching-sewing') &&
            (allowedRoutes.contains('/stitching') || allowedRoutes.contains('/stitching-sewing'))) {
          return true;
        }
        return false;
      }

      final List<DivisionDef> resolvedDivisions =
          (isPlatformSuperAdmin ||
                  allowedRoutes.isEmpty ||
                  allowedRoutes.contains('/platform-admin'))
              ? kAllDefaultDivisions
              : kAllDefaultDivisions.where((d) => isRouteAllowed(d.route)).toList();
      final List<DivisionDef> activeDivisions =
          resolvedDivisions.isNotEmpty ? resolvedDivisions : kAllDefaultDivisions;
      final Set<String> activeRouteSet = activeDivisions.map((d) => d.route).toSet();

      // 2. Fetch Company Profiles & Floor Workers across purchased divisions in parallel
      List<dynamic> rawProfiles = [];
      final Map<String, List<FloorWorkerItem>> workersByRoute = {};

      final List<Future<void>> fetches = [
        () async {
          try {
            var query = client.from('profiles').select('*');
            if (companyName.isNotEmpty) {
              query = query.ilike('company_name', '%$companyName%');
            }
            final res = await query.order('created_at', ascending: false);
            final rows = (res as List<dynamic>?) ?? [];
            rawProfiles = rows.where((p) {
              final pComp = (p['company_name']?.toString() ?? '').toLowerCase().trim();
              return pComp == normCompany;
            }).toList();
          } catch (_) {}
        }(),
      ];

      for (final entry in _kDivisionWorkerMap.entries) {
        final route = entry.key;
        final config = entry.value;
        if (!activeRouteSet.contains(route)) continue;

        fetches.add(() async {
          final List<FloorWorkerItem> divWorkers = [];
          try {
            var query = client.from(config.table).select('*');
            if (companyName.isNotEmpty) {
              query = query.ilike('company_name', '%$companyName%');
            }
            final res = await query.order('created_at', ascending: false);
            for (final w in (res as List<dynamic>? ?? [])) {
              final rowComp = (w['company_name']?.toString() ?? '').toLowerCase().trim();
              if (rowComp != normCompany) continue;

              final candidateName = w[config.nameField]?.toString().trim() ?? '';
              final fallbackDesigner = w['designer_name']?.toString().trim() ?? '';
              final fallbackWorker = w['worker_name']?.toString().trim() ?? '';
              final fallbackGeneric = w['name']?.toString().trim() ?? '';
              final name = candidateName.isNotEmpty
                  ? candidateName
                  : (fallbackDesigner.isNotEmpty
                      ? fallbackDesigner
                      : (fallbackWorker.isNotEmpty
                          ? fallbackWorker
                          : (fallbackGeneric.isNotEmpty
                              ? fallbackGeneric
                              : 'Shop Floor Worker')));

              final candidatePhone = w[config.phoneField]?.toString().trim() ?? '';
              final fallbackDesignerPhone = w['designer_phone']?.toString().trim() ?? '';
              final fallbackPhone = w['phone']?.toString().trim() ?? '';
              final phone = candidatePhone.isNotEmpty
                  ? candidatePhone
                  : (fallbackDesignerPhone.isNotEmpty ? fallbackDesignerPhone : fallbackPhone);

              final candidateRole = w[config.roleField]?.toString().trim() ?? '';
              final role = candidateRole.isNotEmpty ? candidateRole : config.defaultRole;

              final candidateShift = w['shift']?.toString().trim() ?? '';
              final shift = candidateShift.isNotEmpty ? candidateShift : 'General';

              final rawStatus = w['status']?.toString().trim() ?? '';
              final status = rawStatus.isNotEmpty
                  ? rawStatus.toUpperCase()
                  : (w['is_active'] == false ? 'INACTIVE' : 'ACTIVE');

              divWorkers.add(FloorWorkerItem(
                id: w['id']?.toString() ?? '',
                name: name,
                phone: phone,
                departmentRoute: route,
                role: role,
                shift: shift,
                status: status,
              ));
            }
          } catch (_) {}
          workersByRoute[route] = divWorkers;
        }());
      }

      await Future.wait(fetches);

      final List<FloorWorkerItem> workers = [];
      for (final div in activeDivisions) {
        final list = workersByRoute[div.route];
        if (list != null) workers.addAll(list);
      }

      // 3. Parse PMs and Department Heads (strictly matching Web Admin rules)
      final List<ProductionManagerItem> pms = [];
      final List<DepartmentHeadItem> heads = [];

      for (final p in rawProfiles) {
        final profileId = p['id']?.toString() ?? '';
        if (currentUser != null && profileId == currentUser.id && isOwnerCaller) {
          continue;
        }

        final role = (p['role']?.toString() ?? '').toUpperCase();
        final isPM = role == 'PRODUCTION_MANAGER';
        final isHead = p['is_head'] == true || role == 'DEPARTMENT_HEAD';

        if (isPM) {
          pms.add(ProductionManagerItem(
            id: profileId,
            name: p['username']?.toString() ?? 'Production Manager',
            username: p['username']?.toString() ?? 'pm_user',
            phone: p['phone']?.toString() ?? '',
            email: p['email']?.toString(),
            isActive: p['is_active'] != false,
            createdAt: p['created_at']?.toString(),
          ));
        } else if (isHead) {
          final rawMods = p['allowed_modules'];
          final List<String> modules =
              rawMods is List ? rawMods.map((e) => e.toString()).toList() : [];

          final rawPhone = p['phone']?.toString() ?? '';
          String primaryPhone = rawPhone.trim();
          String? secondaryPhone;
          if (rawPhone.contains('/')) {
            final parts = rawPhone
                .split('/')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            primaryPhone = parts.isNotEmpty ? parts[0] : '';
            if (parts.length > 1) secondaryPhone = parts[1];
          }

          heads.add(DepartmentHeadItem(
            id: profileId,
            displayName: p['username']?.toString() ?? 'Department Head',
            username: p['username']?.toString() ?? 'dept_head',
            email: p['email']?.toString() ?? '',
            role: role,
            designation: p['designation']?.toString() ?? 'Department In-charge',
            allowedModules: modules,
            isActive: p['is_active'] != false,
            phone: primaryPhone,
            phone2: secondaryPhone,
            createdAt: p['created_at']?.toString(),
          ));
        }
      }

      final resolvedOwnerName =
          (tenant?.adminDisplayName != null && tenant!.adminDisplayName.trim().isNotEmpty)
              ? tenant.adminDisplayName.trim()
              : ((authState.cachedUsername != null && !authState.cachedUsername!.contains('@'))
                  ? authState.cachedUsername!
                  : 'Company Owner');

      final resolvedOwnerPhone =
          (tenant?.phone != null && tenant!.phone.trim().isNotEmpty)
              ? tenant.phone.trim()
              : '';

      state = state.copyWith(
        companyName: companyName,
        ownerName: resolvedOwnerName,
        ownerEmail: ownerEmail,
        ownerPhone: resolvedOwnerPhone,
        productionManagers: pms,
        departmentHeads: heads,
        divisions: activeDivisions,
        workers: workers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> toggleStaffStatus(
    String id,
    String type,
    bool currentStatus, {
    String? divisionRoute,
  }) async {
    try {
      final client = Supabase.instance.client;
      if (type == 'WORKER') {
        final config = divisionRoute != null ? _kDivisionWorkerMap[divisionRoute] : null;
        if (config == null) return false;
        final nextStatus = currentStatus ? 'INACTIVE' : 'ACTIVE';
        await client.from(config.table).update({'status': nextStatus}).eq('id', id);
        state = state.copyWith(
          workers: state.workers
              .map((w) => w.id == id ? w.copyWith(status: nextStatus) : w)
              .toList(),
        );
        return true;
      }

      await client.from('profiles').update({'is_active': !currentStatus}).eq('id', id);

      if (type == 'PRODUCTION_MANAGER') {
        state = state.copyWith(
          productionManagers: state.productionManagers.map((pm) => pm.id == id ? pm.copyWith(isActive: !currentStatus) : pm).toList(),
        );
      } else if (type == 'DEPARTMENT_HEAD') {
        state = state.copyWith(
          departmentHeads: state.departmentHeads.map((h) => h.id == id ? h.copyWith(isActive: !currentStatus) : h).toList(),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteStaff(String id, String type, {String? divisionRoute}) async {
    try {
      final client = Supabase.instance.client;
      if (type == 'WORKER') {
        final config = divisionRoute != null ? _kDivisionWorkerMap[divisionRoute] : null;
        if (config == null) return false;
        await client.from(config.table).delete().eq('id', id);
        state = state.copyWith(
          workers: state.workers.filter((w) => w.id != id).toList(),
        );
        return true;
      }

      await client.from('profiles').delete().eq('id', id);

      if (type == 'PRODUCTION_MANAGER') {
        state = state.copyWith(
          productionManagers: state.productionManagers.filter((pm) => pm.id != id).toList(),
        );
      } else if (type == 'DEPARTMENT_HEAD') {
        state = state.copyWith(
          departmentHeads: state.departmentHeads.filter((h) => h.id != id).toList(),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addWorker({
    required String name,
    required String phone,
    required String departmentRoute,
    required String role,
    String shift = 'General',
  }) async {
    try {
      final client = Supabase.instance.client;
      final config = _kDivisionWorkerMap[departmentRoute];
      if (config == null) return false;

      final authState = ref.read(authProvider);
      final companyName = state.companyName.trim().isNotEmpty
          ? state.companyName.trim()
          : (authState.tenantProfile?.companyName ?? 'Nubira Creation').trim();

      final rawDigits = phone.replaceAll(RegExp(r'\D'), '');
      final cleanPhone = rawDigits.length >= 10
          ? rawDigits.substring(rawDigits.length - 10)
          : rawDigits;
      final cleanName = name.trim();
      final effectiveRole = role.trim().isNotEmpty ? role.trim() : config.defaultRole;
      final effectiveShift = shift.trim().isNotEmpty ? shift.trim() : 'General';

      if (departmentRoute == '/design') {
        await client.from(config.table).insert({
          if (client.auth.currentUser?.id != null) 'ph_user_id': client.auth.currentUser!.id,
          'designer_name': cleanName,
          'phone_number': cleanPhone,
          'designer_phone': cleanPhone,
          'company_name': companyName,
          'status': 'ACTIVE',
        });
      } else {
        final payload = <String, dynamic>{
          config.nameField: cleanName,
          config.phoneField: cleanPhone,
          config.roleField: effectiveRole,
          'shift': effectiveShift,
          'company_name': companyName,
          'status': 'ACTIVE',
        };
        try {
          await client.from(config.table).insert(payload);
        } catch (insertErr) {
          // Some floor tables (e.g. legacy cutting_workers) may not have a shift column
          if (insertErr.toString().toLowerCase().contains('shift')) {
            payload.remove('shift');
            await client.from(config.table).insert(payload);
          } else {
            rethrow;
          }
        }
      }

      await fetchData();
      return true;
    } catch (_) {
      return false;
    }
  }
}

extension _ListFilter<T> on List<T> {
  List<T> filter(bool Function(T) test) {
    return where(test).toList();
  }
}

final supervisorWorkersProvider = StateNotifierProvider<SupervisorWorkersNotifier, SupervisorWorkersState>(
  (ref) => SupervisorWorkersNotifier(ref),
);
