import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/scanner/providers/sync_provider.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // In a real implementation, we'd initialize the SyncNotifier or a standalone SyncService here
      // and call the API to flush the SQLite queue.
      print("Background Task running: $task");
      // Simulate sync
      // await syncOfflineDataBackground(); 
    } catch (err) {
      print("Background Task failed: $err");
      return Future.value(false);
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Workmanager().initialize(
    callbackDispatcher, 
    isInDebugMode: true 
  );

  Workmanager().registerPeriodicTask(
    "1", 
    "offlineSyncTask", 
    frequency: const Duration(minutes: 15),
  );

  runApp(
    const ProviderScope(
      child: NubiraApp(),
    ),
  );
}

class NubiraApp extends StatelessWidget {
  const NubiraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nubira Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
