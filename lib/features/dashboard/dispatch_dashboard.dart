import 'package:flutter/material.dart';
import '../dispatch/screens/dispatch_logistics_hub_screen.dart';

export '../dispatch/screens/dispatch_logistics_hub_screen.dart';

class DispatchDashboard extends StatelessWidget {
  const DispatchDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const DispatchLogisticsHubScreen();
  }
}