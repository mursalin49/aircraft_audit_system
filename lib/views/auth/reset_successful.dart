import 'package:avislap/widgets/parallax_hero_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class _C {
  static const Color blue = Color(0xFF3D5AFE);
  static const Color ink = Color(0xFF0E0E10);
}

class ResetSuccessScreen extends StatefulWidget {
  const ResetSuccessScreen({super.key});

  @override
  State<ResetSuccessScreen> createState() => _ResetSuccessScreenState();
}

class _ResetSuccessScreenState extends State<ResetSuccessScreen>
    with SingleTickerProviderStateMixin {

  // ✅ Check icon animation
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;

  @override
  void initState() {
    super.initState();

    // ✅ Check icon bounce-in animation
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _checkCtrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeIn)));

    // Start check after short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _checkCtrl.forward();
    });
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
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
            child: Transform.translate(
              offset: const Offset(0, -180),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w),
                padding: EdgeInsets.fromLTRB(24.w, 40.h, 24.w, 36.h),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✅ Animated check icon
                    AnimatedBuilder(
                      animation: _checkCtrl,
                      builder: (_, __) => Opacity(
                        opacity: _checkOpacity.value,
                        child: Transform.scale(
                          scale: _checkScale.value,
                          child: Container(
                            width: 72.w,
                            height: 72.h,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                              Border.all(color: _C.blue, width: 2.5),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: _C.blue,
                              size: 36.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Title
                    Text(
                      'ID Reset\nSuccessful',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w700,
                        color: _C.blue,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Subtitle
                    Text(
                      'You can now login with your\nNew ID',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        color: Colors.grey.shade500,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // GO TO SIGN IN button
                    GestureDetector(
                      onTap: () {
                        // Navigate back to login, clearing stack
                        Get.offAllNamed('/login');
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
                          'GO TO SIGN IN',
                          style: GoogleFonts.dmSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          _buildHomeIndicator(),
        ],
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