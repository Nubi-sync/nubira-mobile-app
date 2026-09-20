import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/lineman_dashboard.dart';
import 'features/dashboard/qc_dashboard.dart';
import 'features/dashboard/store_dashboard.dart';
import 'features/dashboard/dispatch_dashboard.dart';
import 'features/dashboard/production_manager_dashboard.dart';
import 'features/dashboard/mending_dashboard.dart';
import 'features/design/screens/designer_dashboard_screen.dart';
import 'features/modules/screens/enterprise_workspace_hub_screen.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://nnhzqvdmkarpwtkzjnra.supabase.co',
    publishableKey: 'sb_publishable_WRZgkU7XhqbK3HSGRFMfDQ_o2JLnTMF',
  );

  runApp(
    const ProviderScope(
      child: NubiraApp(),
    ),
  );
}

// Global Supabase client
final supabase = Supabase.instance.client;

class NubiraApp extends StatelessWidget {
  const NubiraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zigza',
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.steel),
        ),
      );
    }

    if (authState.isAuthenticated && authState.userRole != null) {
      final roleUpper = authState.userRole!.toUpperCase();

      // Direct routing for specialized shop-floor operators and department roles
      switch (roleUpper) {
        case 'STORE':
        case 'STORE_SUPERVISOR':
        case 'GODOWN':
          return const StoreDashboard();
        case 'DISPATCH':
        case 'LOGISTICS':
          return const DispatchDashboard();
        case 'PRODUCTION_MANAGER':
          return const ProductionManagerDashboard();
        case 'PRODUCTION':
        case 'QC':
        case 'AQL_INSPECTOR':
          return const QcDashboard();
        case 'MENDING':
        case 'ALTERATION':
        case 'REPAIR_TAILOR':
          return const MendingDashboard();
        case 'DESIGNER':
          return const DesignerDashboardScreen();
        case 'LINEMAN':
        case 'STITCHING_SUPERVISOR':
        case 'STITCHING':
          return const LinemanDashboard();
      }

      // Multi-access enterprise hub for admins, company heads, and multi-division management
      if (authState.isMultiDivisionUser ||
          roleUpper == 'ADMIN' ||
          roleUpper == 'SUPERADMIN' ||
          roleUpper == 'PLATFORM_SUPERADMIN' ||
          roleUpper == 'DEPARTMENT_HEAD') {
        return const EnterpriseWorkspaceHubScreen();
      }

      return const LinemanDashboard();
    }

    return const LoginScreen();
  }
}

