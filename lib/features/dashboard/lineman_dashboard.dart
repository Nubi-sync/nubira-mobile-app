import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../scanner/screens/camera_scanner_screen.dart';
import '../scanner/providers/sync_provider.dart';
import '../../core/theme/app_theme.dart';

class LinemanDashboard extends ConsumerWidget {
  const LinemanDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    ref.listen<SyncState>(syncProvider, (previous, next) {
      if (next.message != null && previous?.message != next.message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message!),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.textDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Lineman Area'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Greeting
              Text(
                'Welcome back,',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready for Production?',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),

              // Sync Status Card
              _buildSyncCard(context, ref, syncState),
              const SizedBox(height: 40),

              // Action Label
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),

              // Action Cards Grid
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      title: 'Receive\nBundle',
                      icon: Icons.arrow_downward_rounded,
                      color: AppTheme.successGreen,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CameraScannerScreen(scanContext: 'RECEIVE')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      title: 'Issue\nBundle',
                      icon: Icons.arrow_upward_rounded,
                      color: AppTheme.primaryBlue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CameraScannerScreen(scanContext: 'ISSUE')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncCard(BuildContext context, WidgetRef ref, SyncState syncState) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: syncState.pendingCount > 0 
                  ? Colors.orange.shade50 
                  : AppTheme.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              syncState.pendingCount > 0 ? Icons.cloud_upload_rounded : Icons.cloud_done_rounded,
              color: syncState.pendingCount > 0 ? Colors.orange.shade700 : AppTheme.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Queue',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${syncState.pendingCount} scans pending',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: syncState.pendingCount > 0 ? Colors.orange.shade700 : AppTheme.textMuted,
                    fontWeight: syncState.pendingCount > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (syncState.pendingCount > 0)
            ElevatedButton(
              onPressed: syncState.isSyncing 
                  ? null 
                  : () => ref.read(syncProvider.notifier).syncOfflineData(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.textDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: syncState.isSyncing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Sync'),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

