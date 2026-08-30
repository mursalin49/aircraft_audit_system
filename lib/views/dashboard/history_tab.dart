import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            "Completed tasks",
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.dark,
          ),
          const SizedBox(height: 8),
          AppText(
            "History and stats",
            fontSize: 14,
            color: AppColors.from_heading,
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(Icons.history, size: 64, color: AppColors.from_heading),
                const SizedBox(height: 24),
                AppText(
                  "No completed tasks yet",
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey,
                ),
                const SizedBox(height: 8),
                AppText(
                  "Completed audits will appear here.",
                  fontSize: 14,
                  color: AppColors.from_heading,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
