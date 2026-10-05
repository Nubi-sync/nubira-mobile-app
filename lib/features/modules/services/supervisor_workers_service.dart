import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    name: 'Merchandising & Sourcing',
    route: '/merchandising',
    defaultDesignation: 'Senior Merchandiser / Buyer Coordinator',
    iconName: 'Briefcase',
    description: 'Buyer purchase orders, trim BOM costing, supplier RFQs & T&A schedules',
  ),
  DivisionDef(
    id: 'div-03',
    code: '03',
    name: 'Fabric Central Warehouse',
    route: '/fabric-store',
    defaultDesignation: 'Fabric Godown In-charge / Quality Inspector',
    iconName: 'Store',
    description: 'Greige & dyed roll intake, shade sorting, GSM tests & shrinkage logs',
  ),
  DivisionDef(
    id: 'div-04',
    code: '04',
    name: 'Cutting & Marker Floor',
    route: '/cutting',
    defaultDesignation: 'Cutting Master / Spreading In-charge',
    iconName: 'Scissors',
    description: 'CAD nesting markers, lay sheets, fabric ply spreading & bundle tagging',
  ),
  DivisionDef(
    id: 'div-05',
    code: '05',
    name: 'Printing & Screen Craft',
    route: '/printing',
    defaultDesignation: 'Printing Floor Master / Ink Specialist',
    iconName: 'Printer',
    description: 'Screen preparation, pigment mixing, table printing & curing heat tunnels',
  ),
  DivisionDef(
    id: 'div-06',
    code: '06',
    name: 'Stitching & Sewing Lines',
    route: '/stitching-sewing',
    defaultDesignation: 'Sewing Floor Master / Line Supervisor',
    iconName: 'Layers',
    description: 'Line balancing, assembly stitching, daily tailor logs & bundle routing',
  ),
  DivisionDef(
    id: 'div-07',
    code: '07',
    name: 'Embroidery Automation',
    route: '/embroidery',
    defaultDesignation: 'Embroidery Tech Lead / DST Programmer',
    iconName: 'Sparkles',
    description: 'Multi-head embroidery frames, sequin punching, thread color setups',
  ),
  DivisionDef(
    id: 'div-08',
    code: '08',
    name: 'Industrial Washing & Dyeing',
    route: '/washing',
    defaultDesignation: 'Washing Plant In-charge / Chemical Master',
    iconName: 'Waves',
    description: 'Enzyme wash, stone wash, silicone softening, hydro & tumble drying',
  ),
  DivisionDef(
    id: 'div-09',
    code: '09',
    name: 'Ironing, Steam & Finishing',
    route: '/iron',
    defaultDesignation: 'Finishing Master / Pressing Supervisor',
    iconName: 'Flame',
    description: 'Vacuum steam pressing, wrinkle removal, measurement dimensional audits',
  ),
  DivisionDef(
    id: 'div-10',
    code: '10',
    name: 'Ready Goods Carton Packaging',
    route: '/ready-goods',
    defaultDesignation: 'Packaging Supervisor / Barcode In-charge',
    iconName: 'Boxes',
    description: 'Hangtags, price ticketing, polybag folding, master carton packing & ratio QC',
  ),
  DivisionDef(
    id: 'div-11',
    code: '11',
    name: 'Alteration & Mending Clinic',
    route: '/alter',
    defaultDesignation: 'Mending Supervisor / Rework Specialist',
    iconName: 'Wrench',
    description: 'Stitch repairs, oil stain cleaning, button restitching & rework cycle logs',
  ),
  DivisionDef(
    id: 'div-12',
    code: '12',
    name: 'Dispatch & Logistics Hub',
    route: '/dispatch',
    defaultDesignation: 'Logistics Manager / Gate Pass Officer',
    iconName: 'Truck',
    description: 'Delivery challans, container manifests, transporter dispatch & POD receipts',
  ),
];

class FloorWorkerItem {
  final String id;
  final String name;
  final String phone;
  final String departmentRoute;
  final String role;
  final String status;

  const FloorWorkerItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.departmentRoute,
    required this.role,
    required this.status,
  });
}

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
      final authState = ref.read(authProvider);
      final tenant = authState.tenantProfile;
      final companyName = tenant?.companyName ?? 'Nubira Creation';
      final ownerEmail = tenant?.userEmail ?? '';

      final client = Supabase.instance.client;

      // 1. Fetch profiles for this company
      List<dynamic> rawProfiles = [];
      try {
        final res = await client
            .from('profiles')
            .select('*')
            .eq('company_name', companyName)
            .order('created_at', ascending: false);
        rawProfiles = (res as List<dynamic>?) ?? [];
      } catch (_) {}

      // 2. Fetch workers
      List<FloorWorkerItem> workers = [];
      try {
        final cuttingRes = await client.from('cutting_workers').select('*').limit(200);
        for (final w in (cuttingRes as List<dynamic>? ?? [])) {
          workers.add(FloorWorkerItem(
            id: w['id']?.toString() ?? '',
            name: w['worker_name']?.toString() ?? w['name']?.toString() ?? 'Worker',
            phone: w['phone_number']?.toString() ?? w['phone']?.toString() ?? '',
            departmentRoute: '/cutting',
            role: w['role']?.toString() ?? 'Knife Cutter',
            status: w['is_active'] == false ? 'INACTIVE' : 'ACTIVE',
          ));
        }
      } catch (_) {}

      try {
        final stitchRes = await client.from('stitching_workers').select('*').limit(200);
        for (final w in (stitchRes as List<dynamic>? ?? [])) {
          workers.add(FloorWorkerItem(
            id: w['id']?.toString() ?? '',
            name: w['worker_name']?.toString() ?? w['name']?.toString() ?? 'Worker',
            phone: w['phone_number']?.toString() ?? w['phone']?.toString() ?? '',
            departmentRoute: '/stitching-sewing',
            role: w['role']?.toString() ?? 'Tailor',
            status: w['is_active'] == false ? 'INACTIVE' : 'ACTIVE',
          ));
        }
      } catch (_) {}

      // Parse PMs and Heads
      final List<ProductionManagerItem> pms = [];
      final List<DepartmentHeadItem> heads = [];

      for (final p in rawProfiles) {
        final role = (p['role']?.toString() ?? '').toUpperCase();
        final isPM = role == 'PRODUCTION_MANAGER';
        final isHead = p['is_head'] == true || role == 'DEPARTMENT_HEAD';

        if (isPM) {
          pms.add(ProductionManagerItem(
            id: p['id']?.toString() ?? '',
            name: p['username']?.toString() ?? 'Production Manager',
            username: p['username']?.toString() ?? 'pm_user',
            phone: p['phone']?.toString() ?? '',
            email: p['email']?.toString(),
            isActive: p['is_active'] != false,
            createdAt: p['created_at']?.toString(),
          ));
        } else if (isHead) {
          final rawMods = p['allowed_modules'];
          final List<String> modules = rawMods is List ? rawMods.map((e) => e.toString()).toList() : [];

          heads.add(DepartmentHeadItem(
            id: p['id']?.toString() ?? '',
            displayName: p['username']?.toString() ?? 'Department Head',
            username: p['username']?.toString() ?? 'dept_head',
            email: p['email']?.toString() ?? '',
            role: role,
            designation: p['designation']?.toString() ?? 'Department In-charge',
            allowedModules: modules,
            isActive: p['is_active'] != false,
            phone: p['phone']?.toString() ?? '',
            createdAt: p['created_at']?.toString(),
          ));
        }
      }

      state = state.copyWith(
        companyName: companyName,
        ownerName: authState.cachedUsername ?? 'Company Owner',
        ownerEmail: ownerEmail,
        ownerPhone: tenant?.phone ?? '9876543210',
        productionManagers: pms,
        departmentHeads: heads,
        divisions: kAllDefaultDivisions,
        workers: workers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> toggleStaffStatus(String id, String type, bool currentStatus) async {
    try {
      final client = Supabase.instance.client;
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

  Future<bool> deleteStaff(String id, String type) async {
    try {
      final client = Supabase.instance.client;
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
  }) async {
    try {
      final client = Supabase.instance.client;
      final table = departmentRoute == '/cutting' ? 'cutting_workers' : 'stitching_workers';

      await client.from(table).insert({
        'worker_name': name,
        'phone_number': phone,
        'role': role,
        'is_active': true,
      });

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
