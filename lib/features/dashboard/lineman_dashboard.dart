import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../scanner/screens/camera_scanner_screen.dart';
import '../scanner/providers/sync_provider.dart';

class LinemanDashboard extends ConsumerWidget {
  const LinemanDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    ref.listen<SyncState>(syncProvider, (previous, next) {
      if (next.message != null && previous?.message != next.message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lineman Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Offline Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${syncState.pendingCount} Scans Pending', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: syncState.isSyncing || syncState.pendingCount == 0
                        ? null
                        : () => ref.read(syncProvider.notifier).syncOfflineData(),
                    icon: syncState.isSyncing 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                    label: const Text('Sync'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            const Text('Action:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScannerScreen(scanContext: 'RECEIVE')),
                );
              },
              icon: const Icon(Icons.download, size: 32, color: Colors.white),
              label: const Text('Receive Bundle', style: TextStyle(fontSize: 20, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScannerScreen(scanContext: 'ISSUE')),
                );
              },
              icon: const Icon(Icons.upload, size: 32, color: Colors.white),
              label: const Text('Issue Bundle', style: TextStyle(fontSize: 20, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
