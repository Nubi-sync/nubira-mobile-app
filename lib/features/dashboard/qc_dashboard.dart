import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../scanner/screens/camera_scanner_screen.dart';
import '../../core/theme/app_theme.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('QC Data Saved Offline/Online!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.successGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
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
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('QC Inspection Area'),
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
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppTheme.primaryBlue,
            secondary: AppTheme.primaryBlueDark,
          ),
        ),
        child: Stepper(
          currentStep: _currentStep,
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep == 0 ? 'Proceed' : 'Submit QC Data'),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: details.onStepCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            );
          },
          onStepContinue: () {
            if (_currentStep == 0) {
              if (_scannedBarcode == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please scan a bundle first!'),
                    backgroundColor: Colors.orange.shade800,
                    behavior: SnackBarBehavior.floating,
                  ),
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
              title: Text('Scan Bundle', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  if (_scannedBarcode != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Scanned: $_scannedBarcode',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Simulated scan for now
                      _onScanSuccess('B-UUID-1');
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Simulate Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryBlue,
                      elevation: 0,
                      side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3)),
                    ),
                  )
                ],
              ),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: Text('QC Inspection Form', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
              content: Column(
                children: [
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passedQtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Passed Quantity (e.g., 48)',
                      prefixIcon: Icon(Icons.check_circle_outline_rounded, color: AppTheme.successGreen),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _rejectedQtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rejected Quantity (e.g., 2)',
                      prefixIcon: Icon(Icons.cancel_outlined, color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _defectReason,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                    items: ['NONE', 'STITCHING_ERROR', 'FABRIC_STAIN', 'SIZING_ISSUE']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _defectReason = val!),
                    decoration: const InputDecoration(
                      labelText: 'Defect Reason',
                      prefixIcon: Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                    ),
                  )
                ],
              ),
              isActive: _currentStep >= 1,
            ),
          ],
        ),
      ),
    );
  }
}

