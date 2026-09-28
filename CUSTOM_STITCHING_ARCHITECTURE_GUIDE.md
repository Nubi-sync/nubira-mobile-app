# Android & Flutter Engineering Guide: Custom Stitching vs. Basic Stitching Architecture

> **Target Audience**: Mobile Application Team (Android / Flutter Devs)  
> **Topic**: Architectural separation between **Basic (Standard) Stitching** and the **Custom Deep Manufacturing Suite** for `aj@nubiracreation.com` / Custom Tier Tenants.  
> **Author**: Platform Architecture Team  
> **Status**: Production Reference Locked  

---

## 1. Context & Business Rationale

The platform supports two operational tiers for Division 06 (Stitching & Sewing):

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               STITCHING ARCHITECTURE MODES                             │
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│ 1. BASIC / STANDARD STITCHING             │ 2. CUSTOM DEEP MANUFACTURING SUITE         │
│ (Standard Plant Subscribers)              │ (aj@nubiracreation.com / Nubira Custom)    │
├───────────────────────────────────────────┼────────────────────────────────────────────┤
│ • Streamlined floor logging               │ • Complete 6-stage deep manufacturing flow │
│ • Simple worker task assignments          │ • Lineman machine balancing & daily logs   │
│ • Base module store (Inward / Outward)    │ • Mending handover & 3-stage QC audit      │
│ • 4 core navigation items                 │ • 14 deep sub-modules & ledgers            │
└───────────────────────────────────────────┴────────────────────────────────────────────┘
```

1. **Standard Mode (Basic Stitching)**: Designed for general garment factories that subscribe to the standard SaaS plan. It presents a simple, uncluttered UI focused on task lists, basic piece logging, and standard store handshakes.
2. **Custom Mode (`aj@nubiracreation.com` / Nubira Creation)**: Built specifically for enterprise-level operations that manage full style tech packs, article size-wise rates, lineman allotments, daily product registries, mending handovers, 3-stage QC inspections, Godown accessories, and direct dispatch challans.

---

## 2. How the Decision Logic Works (Implementation Details)

In the web backend and middleware, tenant identification dynamically resolves the UI mode using centralized tenant resolution.

### The Resolution Condition:
```typescript
const isCustomPlant = (
  isLegacyTenant ||
  tenant.subscriptionTier === 'CUSTOM' ||
  (tenant.companyName && tenant.companyName.toLowerCase().includes('nubira')) ||
  tenant.userEmail?.toLowerCase() === 'aj@nubiracreation.com' ||
  tenant.userEmail?.toLowerCase() === 'team.anga9@gmail.com' ||
  tenant.userEmail?.toLowerCase() === 'admin@zigza.in' ||
  tenant.userEmail?.toLowerCase().includes('nubira')
);
```

### Flutter / Dart Counterpart (Mobile App):
In `lib/core/services/tenant_resolver_service.dart` and `lib/features/auth/providers/auth_provider.dart`:
```dart
bool isCustomStitchingUser(String? userEmail, String? subscriptionTier, String? companyName) {
  final email = userEmail?.toLowerCase() ?? '';
  final company = companyName?.toLowerCase() ?? '';
  
  return subscriptionTier == 'CUSTOM' ||
      company.contains('nubira') ||
      email == 'aj@nubiracreation.com' ||
      email == 'team.anga9@gmail.com' ||
      email == 'admin@zigza.in' ||
      email.contains('nubira') ||
      email.startsWith('aj@');
}
```

---

## 3. Comparison: Basic vs. Custom Stitching Features

| Feature / Dimension | Basic (Standard) Stitching | Custom Stitching (`aj@nubiracreation.com`) |
| :--- | :--- | :--- |
| **Target Route** | `/stitching-sewing/dashboard` | `/stitching-sewing/dashboard` + 13 deep routes |
| **Side Navigation** | 4 Items: Dashboard, Notifications, Floor Store, AI | 14 Items across 4 distinct groups |
| **Supervisor Tooling** | Basic task allocation | Full **Supervisor Desk** (`/supervisor-desk`) |
| **Allotment Structure** | Simple `cutting_allocations` & `tasks` | Deep `allotments` + `allotment_variants` by Lineman |
| **Piece-Rate Wage Logic** | Flat worker piece counts | Size-wise rate matrix (`size_rates` JSONB in `articles`) |
| **Store & Godown** | Basic `ModuleStoreDashboard` | Full **Store Dashboard** + Godown accessories & truck logs |
| **Quality Control** | Simple status flag (Pass / Reject) | Multi-stage: Inline QC → End-of-line QC → Mending Re-loop |
| **Dispatch Integration** | Manual / standard ready goods handoff | Direct Gate Pass, Challan creation & Truck Dispatch |

---

## 4. Custom Mode Navigation Structure (For Android UI/Drawer)

When `isCustomStitchingUser == true`, the mobile app should present the full enterprise drawer / navigation hierarchy:

```
[ Section 1: Workspace Hub ]
  └── All Modules                 -> /modules (Enterprise Grid)

[ Section 2: Sewing Floor Operations ]
  ├── Master Floor Dashboard      -> /stitching-sewing/dashboard
  ├── Notifications & Alerts      -> /stitching-sewing/notifications
  ├── Supervisor Desk             -> /stitching-sewing/supervisor-desk
  ├── Store Dashboard             -> /stitching-sewing/store
  └── Zigza AI Floor Copilot      -> /stitching-sewing/zigza-ai

[ Section 3: Production Execution ]
  ├── Production Chart & Orders   -> /stitching-sewing/production-orders
  ├── Target Allotments           -> /stitching-sewing/allotments
  ├── Godown & Inventory          -> /stitching-sewing/inventory
  └── Dispatch & Challans         -> /dispatch

[ Section 4: Factory Management ]
  ├── Division Profile            -> /stitching-sewing/profile
  ├── Brands & Vendors            -> /stitching-sewing/vendors
  ├── Employee Roster & Wages     -> /stitching-sewing/employees
  ├── Articles & Style Tech Packs -> /stitching-sewing/articles
  └── Reports & Analytics         -> /stitching-sewing/reports
```

When `isCustomStitchingUser == false`, render the **Standard Streamlined Drawer**:
```
[ Section 1: Workspace Hub ]
  └── All Modules                 -> /modules

[ Section 2: Sewing Operations ]
  ├── Floor Dashboard             -> /stitching-sewing/dashboard
  ├── Notifications               -> /stitching-sewing/notifications
  ├── Floor Store (Bundles)       -> /stitching-sewing/store
  └── Zigza AI                    -> /stitching-sewing/zigza-ai

[ Section 3: Account ]
  └── Division Profile            -> /stitching-sewing/profile
```

---

## 5. Database Schema & API Payload Differences

### 1. Master Articles (`articles` table)
* **Basic Mode**: Reads `id`, `art_no`, `description`.
* **Custom Mode**: Reads `id`, `art_no`, `description`, `stitching_rate`, `size_rates` (JSON mapping e.g., `{"S": 12.5, "M": 12.5, "L": 14.0, "XL": 15.0}`).

### 2. Allotments & Bundle Tracking (`allotments` table)
* **Custom Mode** includes comprehensive tracking columns:
  * `challan_id` (FK to `challans`)
  * `lineman_id` (FK to `profiles`)
  * `target_qty`
  * `mending_status`, `mending_total_counted`, `mending_supervisor_name`
  * `handed_to_mending_by`, `handed_to_mending_at`
  * `qc_status`, `qc_total_passed`, `qc_total_alter`
  * `handed_to_qc_by`, `handed_to_qc_at`

### 3. Daily Floor Logging (`daily_product` & `worker_assignments`)
* `daily_product`: Tracks exact hourly/daily piece production logs by article, lineman, and shift.
* `worker_assignments`: Direct operator-to-machine mapping for wage ledgers.

### 4. Godown & Store Transactions (`store_transactions` & `accessories_inventory`)
* Tracks thread cones, buttons, zipper lots, labels, and issue slips directly attached to the sewing floor.

---

## 6. Android Implementation Checklist for the Mobile Team

1. [ ] **Centralized Flag**: Ensure `AuthNotifier` / `TenantResolverService` exposes `bool get isCustomPlant` or `bool get isCustomStitching`.
2. [ ] **Conditional Dashboard Routing**:
   * If `isCustomPlant == true` → Navigate to `ProductionManagerDashboardScreen` / `LinemanDashboardScreen` with full allotment controls.
   * If `isCustomPlant == false` → Navigate to standard `BasicStitchingFloorScreen`.
3. [ ] **Store Dashboard Routing**:
   * If `isCustomPlant == true` → Full `StoreDashboardScreen` (Material receipts, trims, Godown transactions).
   * If `isCustomPlant == false` → Streamlined `ModuleStoreScreen` (Simple incoming bundle receipt).
4. [ ] **Error Handling & Fallback**:
   * Always provide null-checks on `size_rates` and `stitching_rate` (defaulting to standard base rate if size JSON is absent).
5. [ ] **Offline Caching**:
   * Custom mode caches `allotments`, `articles`, and `challans` locally using Hive / SQLite so line supervisors can log piece entries during factory Wi-Fi drops.

---

## 7. Key Contacts & Reference Code

* **Web Source Files**:
  * [AdminSidebar.tsx](file:///c:/Users/shaws/NubiSync/nubira-web-admin/src/components/layout/AdminSidebar.tsx#L534-L603)
  * [src/app/stitching-sewing/dashboard/page.tsx](file:///c:/Users/shaws/NubiSync/nubira-web-admin/src/app/stitching-sewing/dashboard/page.tsx#L60-L105)
  * [src/app/stitching-sewing/store/page.tsx](file:///c:/Users/shaws/NubiSync/nubira-web-admin/src/app/stitching-sewing/store/page.tsx#L31-L70)
* **Mobile Source Files**:
  * [lib/core/services/tenant_resolver_service.dart](file:///c:/Users/shaws/NubiSync/nubira-mobile-app/lib/core/services/tenant_resolver_service.dart#L245-L255)
  * [lib/features/modules/screens/enterprise_workspace_hub_screen.dart](file:///c:/Users/shaws/NubiSync/nubira-mobile-app/lib/features/modules/screens/enterprise_workspace_hub_screen.dart#L120-L135)
