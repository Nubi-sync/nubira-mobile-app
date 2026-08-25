import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ConnectivityIndicator extends StatefulWidget {
  final bool showLabel;
  const ConnectivityIndicator({super.key, this.showLabel = false});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  bool _isOnline = true;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
      if (mounted && isOnline != _isOnline) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final isOnline = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showLabel) {
      // Small persistent dot indicator in AppBar
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isOnline ? AppTheme.greenMist : AppTheme.amberMist,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isOnline ? AppTheme.green.withValues(alpha: 0.3) : AppTheme.amber.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isOnline ? AppTheme.green : AppTheme.amber,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              _isOnline ? 'Online' : 'Offline',
              style: GoogleFonts.publicSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _isOnline ? AppTheme.green : AppTheme.amber,
              ),
            ),
          ],
        ),
      );
    }

    // Full Banner version
    if (_isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.amberMist,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppTheme.amber.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: AppTheme.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — will sync when reconnected',
              style: GoogleFonts.publicSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
