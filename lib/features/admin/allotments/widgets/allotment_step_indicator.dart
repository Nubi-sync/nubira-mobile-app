import 'package:flutter/material.dart';

class AllotmentStepIndicator extends StatelessWidget {
  final int currentStep; // 1, 2, or 3
  final String? subtitle;

  const AllotmentStepIndicator({
    super.key,
    required this.currentStep,
    this.subtitle,
  });

  String _getDefaultSubtitle() {
    switch (currentStep) {
      case 1:
        return 'Step 1 of 3 - Article & lineman assignment';
      case 2:
        return 'Step 2 of 3 - Size & color ratio matrix';
      case 3:
      default:
        return 'Step 3 of 3 - BOM raw materials and trims';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int i = 1; i <= 3; i++) ...[
                if (i > 1) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= currentStep ? const Color(0xFF1C1C1A) : const Color(0xFFE5E5E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle ?? _getDefaultSubtitle(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B6A65),
            ),
          ),
        ],
      ),
    );
  }
}

