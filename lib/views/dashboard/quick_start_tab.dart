import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_permission_codes.dart';
import '../../services/session_service.dart';
import '../../utils/app_colors.dart';
import '../forms/Cabin%20Quality%20Audit/CabinQualityAuditList.dart';
import '../forms/LAV%20Safety%20Observation/LavSafetyObservationScreen.dart';
import '../forms/cabin%20security%20search/CabinSecurityTrainingScreen.dart';
import '../forms/hidden_object_audit/hidden_object_audit_screen.dart';
import '../forms/survey_hub/survey_hub_screen.dart';

class QuickStartTab extends StatelessWidget {
  const QuickStartTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: _FormsCreationLaunchCard(
                  onTap: () => Get.to(() => const SurveyHubScreen()),
                ),
              ),
              SizedBox(height: 24.h),
              const QuickAccessSection(),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickAccessSection extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;

  const QuickAccessSection({
    super.key,
    this.title = "Quick Access",
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    final showLavSafety = session.hasPermission(
      AppPermissionCodes.lavSafetyObservation,
    );
    final showCabinQuality = session.hasPermission(
      AppPermissionCodes.cabinQualityAudit,
    );
    final showCabinSecurity = session.hasPermission(
      AppPermissionCodes.cabinSecuritySearchTraining,
    );
    final showHiddenObjectAudit = session.hasPermission(
      AppPermissionCodes.hiddenObjectAudit,
    );

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          _QuickAccessGrid(
            showLavSafety: showLavSafety,
            showCabinQuality: showCabinQuality,
            showCabinSecurity: showCabinSecurity,
            showHiddenObjectAudit: showHiddenObjectAudit,
          ),
        ],
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  final bool showLavSafety;
  final bool showCabinQuality;
  final bool showCabinSecurity;
  final bool showHiddenObjectAudit;

  const _QuickAccessGrid({
    required this.showLavSafety,
    required this.showCabinQuality,
    required this.showCabinSecurity,
    required this.showHiddenObjectAudit,
  });

  void _showComingSoon(String title) {
    Get.snackbar(
      title,
      'This feature will be available soon.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      colorText: Colors.white,
      margin: EdgeInsets.all(16.w),
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      if (showLavSafety)
        {
          'title': 'Lav Safety\nObservation',
          'icon': Icons.clean_hands,
          'color': const Color(0xFF0EA5E9),
          'onTap': () => Get.to(() => LavSafetyObservationScreen()),
        },
      if (showCabinQuality)
        {
          'title': 'Cabin Quality\nAudit',
          'icon': Icons.check_circle_outline,
          'color': const Color(0xFF10B981),
          'onTap': () => Get.to(() => CabinQualityAuditListScreen()),
        },
      if (showCabinSecurity)
        {
          'title': 'Cabin Security\nSearch Training',
          'icon': Icons.security,
          'color': const Color(0xFFF59E0B),
          'onTap': () => Get.to(() => CabinSecurityScreen()),
        },
      if (showHiddenObjectAudit)
        {
          'title': 'Hidden Object\nAudit',
          'icon': Icons.search,
          'color': const Color(0xFF8B5CF6),
          'onTap': () => Get.to(() => const HiddenObjectAuditListScreen()),
        },
      {
        'title': 'Employee\nDetail',
        'icon': Icons.person_outline_rounded,
        'color': const Color(0xFF6366F1),
        'onTap': () => _showComingSoon('Employee Detail'),
      },
      {
        'title': 'Time and Edits',
        'icon': Icons.access_time_rounded,
        'color': const Color(0xFFF43F5E),
        'onTap': () => _showComingSoon('Time Sheet'),
      },
      {
        'title': 'Inventory',
        'icon': Icons.grid_view_outlined,
        'color': const Color(0xFFEAB308),
        'onTap': () => _showComingSoon('Inventory'),
      },
      {
        'title': 'Feedback',
        'icon': Icons.people_alt_outlined,
        'color': const Color(0xFF8B5CF6),
        'onTap': () => _showComingSoon('Feedback'),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.w,
          mainAxisSpacing: 16.h,
          childAspectRatio: 1.15,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final Color iColor = item['color'] as Color;

          return InkWell(
            onTap: item['onTap'] as void Function()?,
            borderRadius: BorderRadius.circular(16.r),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: iColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(item['icon'] as IconData, color: iColor, size: 24.sp),
                  ),
                  const Spacer(),
                  Text(
                    item['title'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FormsCreationLaunchCard extends StatelessWidget {
  final VoidCallback onTap;

  const _FormsCreationLaunchCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.r),
      child: Ink(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF0F172A), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                'Forms & Surveys',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Open the new survey answer flow',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Use this shortcut to browse published forms and submit your answers from mobile.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.82),
                height: 1.45,
              ),
            ),
            SizedBox(height: 18.h),
            Row(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    'Go Now',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mainAppColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
