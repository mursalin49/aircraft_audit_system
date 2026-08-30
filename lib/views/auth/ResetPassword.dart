import 'package:avislap/views/auth/reset_successful.dart';
import 'package:avislap/widgets/parallax_hero_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class _C {
  static const Color blue = Color(0xFF3D5AFE);
  static const Color ink = Color(0xFF0E0E10);
  static const Color border = Color(0xFFEAECF2);
  static const Color placeholder = Color(0xFFC8CDD9);
  static const Color muted = Color(0xFF8891A4);
}

class ResetId extends StatefulWidget {
  const ResetId ({super.key});

  @override
  State<ResetId > createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetId > {
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // ── Blue Hero ──────────────────────────────────
          ParallaxHeroWidget(
            bottomPadding: 220,
            child: Text(
              'Reset ID',
              style: GoogleFonts.dmSans(
                fontSize: 32.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.8,
              ),
            ),
          ),

          // ── White Card ────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Transform.translate(
                offset: const Offset(0, -160),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 28.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Subtitle
                      Text(
                        'Enter new password & confirm the\npassword to set a new password',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 13.sp,
                          color: Colors.grey.shade500,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // New Password
                      _buildField(
                        label: 'New Password',
                        child: _buildInput(
                          controller: _newPasswordCtrl,
                          hint: 'Enter new password',
                          obscure: _obscureNew,
                          onToggle: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Confirm Password
                      _buildField(
                        label: 'Confirm Password',
                        child: _buildInput(
                          controller: _confirmPasswordCtrl,
                          hint: 'Confirm password',
                          obscure: _obscureConfirm,
                          onToggle: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      SizedBox(height: 28.h),

                      // Submit button
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          _buildHomeIndicator(),
        ],
      ),
    );
  }

  // ── Field + Label ─────────────────────────────────────────
  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: _C.blue,
          ),
        ),
        SizedBox(height: 6.h),
        child,
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      height: 52.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: _C.border, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.dmSans(fontSize: 15.sp, color: _C.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(fontSize: 15.sp, color: _C.placeholder),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
          suffixIcon: Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: onToggle,
              child: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _C.muted,
                size: 20.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Submit Button ─────────────────────────────────────────
  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: () {
        // submit logic
        // Get.back();
        Get.to(()=> ResetSuccessScreen());
      },
      child: Container(
        height: 54.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _C.blue,
          borderRadius: BorderRadius.circular(30.r),
        ),
        alignment: Alignment.center,
        child: Text(
          'SUBMIT',
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