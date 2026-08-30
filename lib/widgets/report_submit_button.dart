import 'package:flutter/material.dart';
import 'package:hold_to_confirm_button/hold_to_confirm_button.dart';
import '../utils/app_colors.dart';

/// Global hold-to-confirm button for submitting reports.
/// Label and hint make it clear that the user must press and hold.
class ReportSubmitButton extends StatelessWidget {
  final VoidCallback onConfirm;
  final String label;
  final String hint;
  final double height;
  final double borderRadius;
  final bool enabled;

  const ReportSubmitButton({
    super.key,
    required this.onConfirm,
    this.label = 'Hold to send report',
    this.hint = 'Press and hold to confirm',
    this.height = 52,
    this.borderRadius = 12,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final holdButton = HoldToConfirmButton(
      onProgressCompleted: onConfirm,
      backgroundColor: AppColors.mainAppColor,
      borderRadius: BorderRadius.circular(borderRadius),
      hapticFeedback: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.touch_app_rounded, size: 20, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );

    final wrappedButton = IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: holdButton,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        wrappedButton,
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 14, color: AppColors.from_heading),
            const SizedBox(width: 6),
            Text(
              enabled ? hint : 'Complete all required fields to enable',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.from_heading,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
