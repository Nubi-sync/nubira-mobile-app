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
      await DioClient.dio.post('/scanner/sync', data: {
        'payloads': [
          {
            'barcode': bundleNo,
            'context': action,
            'timestamp': DateTime.now().toIso8601String(),
          }
        ]
      });
      state = state.copyWith(message: 'Scan uploaded successfully: $bundleNo');
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode! >= 400 && e.response!.statusCode! < 500) {
        // Bad request or unauthorized, don't queue it forever
        state = state.copyWith(message: 'Scan rejected: ${e.response?.data["message"] ?? e.message}');
      } else {
        await LocalDatabase.insertScan(bundleNo, action);
        await refreshPendingCount();
        state = state.copyWith(message: 'Offline: Scan queued locally: $bundleNo');
      }
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
    
    if (scans.isEmpty) {
      state = state.copyWith(isSyncing: false, message: 'Nothing to sync');
      return;
    }

    final payloads = scans.map((scan) => {
      'barcode': scan['bundle_no'],
      'context': scan['status'],
      'timestamp': scan['timestamp'],
    }).toList();

    try {
      await DioClient.dio.post('/scanner/sync', data: {
        'payloads': payloads,
      });
      await LocalDatabase.clearScans();
      state = state.copyWith(isSyncing: false, pendingCount: 0, message: 'Sync complete! (${scans.length} items)');
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode! >= 400 && e.response!.statusCode! < 500) {
        // Clear scans if they are permanently invalid to unblock queue, 
        // but typically we'd show an error. Let's just clear for now.
        await LocalDatabase.clearScans();
        state = state.copyWith(isSyncing: false, pendingCount: 0, message: 'Offline scans were rejected by server.');
      } else {
        await refreshPendingCount();
        state = state.copyWith(isSyncing: false, message: 'Sync failed: Check connection.');
      }
    } catch (e) {
      await refreshPendingCount();
      state = state.copyWith(isSyncing: false, message: 'Sync failed: Unknown error.');
    }
  }
}
