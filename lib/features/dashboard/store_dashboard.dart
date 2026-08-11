import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';

class StoreDashboard extends ConsumerWidget {
  const StoreDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Ledger'),
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.store, size: 80, color: Colors.blueGrey),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Simulate Inward
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Inward Scanner...')));
              },
              icon: const Icon(Icons.login, size: 32, color: Colors.white),
              label: const Text('INWARD (Receive Stitched Goods)', style: TextStyle(fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Simulate Outward
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Outward Scanner...')));
              },
              icon: const Icon(Icons.logout, size: 32, color: Colors.white),
              label: const Text('OUTWARD (Dispatch Finished)', style: TextStyle(fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
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
