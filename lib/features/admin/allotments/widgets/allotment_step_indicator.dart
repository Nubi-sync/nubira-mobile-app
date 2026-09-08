import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class AllotmentStepIndicator extends StatelessWidget {
  final int currentStep; // 1, 2, or 3

  const AllotmentStepIndicator({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: const Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildStep(
            stepNum: 1,
            title: 'Target & Lineman',
            isActive: currentStep >= 1,
            isCurrent: currentStep == 1,
          ),
          _buildDivider(isDone: currentStep > 1),
          _buildStep(
            stepNum: 2,
            title: 'Size & Colors',
            isActive: currentStep >= 2,
            isCurrent: currentStep == 2,
          ),
          _buildDivider(isDone: currentStep > 2),
          _buildStep(
            stepNum: 3,
            title: 'BOM Handover',
            isActive: currentStep >= 3,
            isCurrent: currentStep == 3,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required int stepNum,
    required String title,
    required bool isActive,
    required bool isCurrent,
  }) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? AppTheme.steel
                  : (isActive ? AppTheme.steelTint : AppTheme.steelMist),
              border: Border.all(
                color: isActive ? AppTheme.steel : AppTheme.border,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              stepNum.toString(),
              style: TextStyle(
                color: isCurrent
                    ? Colors.white
                    : (isActive ? AppTheme.steelDark : AppTheme.inkFaint),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent
                    ? AppTheme.ink
                    : (isActive ? AppTheme.inkSoft : AppTheme.inkFaint),
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider({required bool isDone}) {
    return Container(
      width: 16,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDone ? AppTheme.steel : AppTheme.border,
    );
  }
}
