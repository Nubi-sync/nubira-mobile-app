import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/db/local_db.dart';
import '../../../core/network/dio_client.dart';

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier();
});

class SyncState {
  final int pendingCount;
  final bool isSyncing;
  final String? message;

  SyncState({this.pendingCount = 0, this.isSyncing = false, this.message});

  SyncState copyWith({int? pendingCount, bool? isSyncing, String? message}) {
    return SyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      isSyncing: isSyncing ?? this.isSyncing,
      message: message,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier() : super(SyncState()) {
    refreshPendingCount();
  }

  Future<void> refreshPendingCount() async {
    final scans = await LocalDatabase.getPendingScans();
    state = state.copyWith(pendingCount: scans.length);
  }

  Future<void> processScan(String bundleNo, String action) async {
    try {
      await DioClient.dio.post('/bundle/scan', data: {
        'bundle_no': bundleNo,
        'action': action,
      });
      state = state.copyWith(message: 'Scan uploaded successfully: $bundleNo');
    } catch (e) {
      await LocalDatabase.insertScan(bundleNo, action);
      await refreshPendingCount();
      state = state.copyWith(message: 'Offline: Scan queued locally: $bundleNo');
    }
  }

  Future<void> syncOfflineData() async {
    if (state.pendingCount == 0 || state.isSyncing) return;
    
    state = state.copyWith(isSyncing: true, message: 'Syncing...');
    final scans = await LocalDatabase.getPendingScans();
    int successCount = 0;

    for (var scan in scans) {
      try {
        await DioClient.dio.post('/bundle/scan', data: {
          'bundle_no': scan['bundle_no'],
          'action': scan['status'],
        });
        successCount++;
      } catch (e) {
        break; // break on network failure
      }
    }

    if (successCount == scans.length) {
      await LocalDatabase.clearScans();
      state = state.copyWith(isSyncing: false, pendingCount: 0, message: 'Sync complete! ($successCount items)');
    } else {
      await refreshPendingCount();
      state = state.copyWith(isSyncing: false, message: 'Partial sync: Check connection.');
    }
  }
}
