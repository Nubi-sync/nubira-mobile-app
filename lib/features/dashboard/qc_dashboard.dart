import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../scanner/screens/camera_scanner_screen.dart';

class QcDashboard extends ConsumerStatefulWidget {
  const QcDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<QcDashboard> createState() => _QcDashboardState();
}

class _QcDashboardState extends ConsumerState<QcDashboard> {
  int _currentStep = 0;
  String? _scannedBarcode;
  
  final _passedQtyController = TextEditingController();
  final _rejectedQtyController = TextEditingController();
  String _defectReason = 'NONE';

  void _onScanSuccess(String barcode) {
    setState(() {
      _scannedBarcode = barcode;
      _currentStep = 1; // Move to form step
    });
  }

  void _submitQc() {
    // In a real app, dispatch to a provider to save/upload
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QC Data Saved Offline/Online!')),
    );
    setState(() {
      _scannedBarcode = null;
      _passedQtyController.clear();
      _rejectedQtyController.clear();
      _currentStep = 0; // Back to scan step
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production / QC'),
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
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            // Need to scan first
            if (_scannedBarcode == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please scan a bundle first!')),
              );
              return;
            }
            setState(() => _currentStep += 1);
          } else if (_currentStep == 1) {
            _submitQc();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: [
          Step(
            title: const Text('Scan Bundle'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_scannedBarcode != null) ...[
                  Text('Scanned: $_scannedBarcode', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 16),
                ],
                ElevatedButton.icon(
                  onPressed: () async {
                    // Temporarily we could push CameraScannerScreen
                    // But CameraScannerScreen currently auto-inserts to DB
                    // For QC, we'd need a specific mode. For now, simulate:
                    _onScanSuccess('B-UUID-1');
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Simulate Scan (or open Camera)'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
                )
              ],
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('QC Inspection Form'),
            content: Column(
              children: [
                TextField(
                  controller: _passedQtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Passed Quantity (e.g., 48)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rejectedQtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Rejected Quantity (e.g., 2)'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _defectReason,
                  items: ['NONE', 'STITCHING_ERROR', 'FABRIC_STAIN', 'SIZING_ISSUE']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _defectReason = val!),
                  decoration: const InputDecoration(labelText: 'Defect Reason'),
                )
              ],
            ),
            isActive: _currentStep >= 1,
          ),
        ],
      ),
    );
  }
}
