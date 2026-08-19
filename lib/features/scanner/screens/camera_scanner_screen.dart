import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sync_provider.dart';

class CameraScannerScreen extends ConsumerStatefulWidget {
  final String scanContext;
  
  const CameraScannerScreen({Key? key, required this.scanContext}) : super(key: key);

  @override
  ConsumerState<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends ConsumerState<CameraScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;
  
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final code = barcodes.first.rawValue!;
      setState(() => _isProcessing = true);
      
      await ref.read(syncProvider.notifier).processScan(code, widget.scanContext);
      
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Bundle'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: MobileScanner(
        controller: controller,
        onDetect: _onDetect,
      ),
    );
  }
}
