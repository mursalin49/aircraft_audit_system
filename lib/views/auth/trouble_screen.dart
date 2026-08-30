import 'package:avislap/controllers/login_controller.dart';
import 'package:avislap/views/auth/email_id.dart';
import 'package:avislap/views/auth/forget.dart';
import 'package:avislap/views/auth/forget_id.dart';
import 'package:avislap/widgets/parallax_hero_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class _C {
  static const Color blue  = Color(0xFF3D5AFE);
  static const Color ink   = Color(0xFF0E0E10);
  static const Color white = Color(0xFFFFFFFF);
}

class TroubleScreen extends StatefulWidget {
  const TroubleScreen({super.key});

  @override
  State<TroubleScreen> createState() => _TroubleScreenState();
}

class _TroubleScreenState extends State<TroubleScreen> {
  final controller = Get.put(AuthController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // ── Blue hero — takes top portion ──────────
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: IgnorePointer(
                    ignoring: true,
                    child: ParallaxHeroWidget(
                      bottomPadding: 220,
                      child: Text(
                        'Having Trouble\nSigning in?',
                        style: GoogleFonts.dmSans(
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.8,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── White card overlaps hero from bottom ───
                Positioned(
                  top: 235.h,   // ← overlap point: sits over blue
                  left: 0, right: 0, bottom: 0,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          margin: EdgeInsets.symmetric(
                              horizontal: 16.w),
                          padding: EdgeInsets.fromLTRB(
                              24.w, 28.h, 24.w, 28.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius.circular(28.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Please Select your issue',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14.sp,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              SizedBox(height: 20.h),
                              _buildRadioOption(
                                "I don't know my used ID ?",
                                "id_issue",
                              ),
                              SizedBox(height: 8.h),
                              _buildRadioOption(
                                "I don't know my Password ?",
                                "pass_issue",
                              ),
                              SizedBox(height: 8.h),
                              _buildRadioOption(
                                "Doesn't have access to my Registered E-mail ID",
                                "email_issue",
                              ),
                              SizedBox(height: 28.h),
                              _buildContinueButton(),
                              SizedBox(height: 16.h),
                              GestureDetector(
                                onTap: () => Get.back(),
                                child: Text(
                                  'Back to Sign In',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14.sp,
                                    color: _C.blue,
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildHomeIndicator(),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String title, String value) {
    return Obx(() {
      final selected = controller.selectedIssue.value == value;
      return GestureDetector(
        onTap: () => controller.selectedIssue.value = value,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected
                  ? _C.blue.withOpacity(0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12.r),
            ),
            padding: EdgeInsets.all(8.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? _C.blue
                          : Colors.grey.shade400,
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  child: selected
                      ? Center(
                    child: Container(
                      width: 10.w,
                      height: 10.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.blue,
                      ),
                    ),
                  )
                      : null,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14.sp,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected
                          ? Colors.grey.shade900
                          : Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildContinueButton() {
    return GestureDetector(
      onTap: () {
        final issue = controller.selectedIssue.value;
        if (issue == 'id_issue') {
          Get.to(() => const ForgotIdScreen());
        } else if (issue == 'pass_issue') {
          Get.to(() => const ForgotPasswordScreen());
        } else if (issue == 'email_issue') {
          Get.to(() => const NoEmailAccessScreen());
        }
      },
      child: Container(
        height: 54.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _C.blue,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
              color: _C.blue.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'CONTINUE',
          style: GoogleFonts.dmSans(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Center(
        child: Container(
          width: 134.w,
          height: 5.h,
          decoration: BoxDecoration(
            color: _C.ink.withOpacity(0.15),
            borderRadius: BorderRadius.circular(3.r),
          ),
        ),
      ),
    );
  }
}