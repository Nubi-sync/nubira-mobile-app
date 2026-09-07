import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_drawer.dart';
import 'admin_dashboard_screen.dart';
import 'challan_hub_screen.dart';
import 'allotments_screen.dart';
import 'inventory_screen.dart';
import 'dispatch_screen.dart';

final GlobalKey<ScaffoldState> adminScaffoldKey = GlobalKey<ScaffoldState>();

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AdminDashboardScreen(),
    ChallanHubScreen(),
    AllotmentsScreen(),
    InventoryScreen(),
    DispatchScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: adminScaffoldKey,
      backgroundColor: AppTheme.bg,
      drawer: AdminDrawer(
        activeIndex: _currentIndex,
        onTabSelected: (index) {
          if (index < _screens.length) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.card,
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index == 5) {
              adminScaffoldKey.currentState?.openDrawer();
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          backgroundColor: AppTheme.card,
          indicatorColor: AppTheme.steelMist,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: AppTheme.inkSoft),
              selectedIcon: Icon(Icons.dashboard, color: AppTheme.steel),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.layers_outlined, color: AppTheme.inkSoft),
              selectedIcon: Icon(Icons.layers, color: AppTheme.steel),
              label: 'Challans',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined, color: AppTheme.inkSoft),
              selectedIcon: Icon(Icons.assignment, color: AppTheme.steel),
              label: 'Allotments',
            ),
            NavigationDestination(
              icon: Icon(Icons.warehouse_outlined, color: AppTheme.inkSoft),
              selectedIcon: Icon(Icons.warehouse, color: AppTheme.steel),
              label: 'Inventory',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined, color: AppTheme.inkSoft),
              selectedIcon: Icon(Icons.local_shipping, color: AppTheme.steel),
              label: 'Dispatch',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_rounded, color: AppTheme.inkSoft),
              selectedIcon: Icon(Icons.menu_open_rounded, color: AppTheme.steel),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
