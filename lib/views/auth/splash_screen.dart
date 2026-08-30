import 'package:avislap/views/dashboard/dashboard_screen.dart';
import 'package:avislap/views/select_station/select_station.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_api_service.dart';
import '../../services/session_service.dart';
import 'login_screen.dart';

class _C {
  static const Color blue = Color(0xFF3D5AFE);
  static const Color ink = Color(0xFF0E0E10);
  static const Color white = Color(0xFFFFFFFF);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;

  late AnimationController _bar1Ctrl;
  late AnimationController _bar2Ctrl;
  late AnimationController _bar3Ctrl;
  late Animation<double> _bar1Scale;
  late Animation<double> _bar2Scale;
  late Animation<double> _bar3Scale;

  late AnimationController _wordCtrl;
  late Animation<Offset> _wordSlide;

  late AnimationController _exitCtrl;
  late Animation<double> _exitOpacity;
  late Animation<double> _exitScale;

  final SessionService _sessionService = Get.find<SessionService>();
  final AppApiService _api = Get.find<AppApiService>();

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(_logoCtrl);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutExpo));

    _bar1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bar2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bar3Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bar1Scale = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _bar1Ctrl, curve: Curves.easeOutExpo));
    _bar2Scale = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _bar2Ctrl, curve: Curves.easeOutExpo));
    _bar3Scale = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _bar3Ctrl, curve: Curves.easeOutExpo));

    _wordCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _wordSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _wordCtrl, curve: Curves.easeOutExpo));

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(_exitCtrl);
    _exitScale = Tween<double>(begin: 1, end: 1.03).animate(_exitCtrl);

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    _bar1Ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _bar2Ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _bar3Ctrl.forward();
    _wordCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1400));
    _exitCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 520));

    if (!mounted) {
      return;
    }

    if (_sessionService.isLoggedIn) {
      if (_sessionService.activeStationId.isNotEmpty) {
        var hasStationSession = true;
        try {
          final activeStation = await _api.getActiveStation();
          if (activeStation != null) {
            _sessionService.saveActiveStation(activeStation);
            hasStationSession = _sessionService.hasCompleteOperationalContext;
          } else {
            _sessionService.saveActiveStation(null);
            hasStationSession = false;
          }
        } catch (_) {
          // Keep the locally persisted station if refresh is temporarily unavailable.
          hasStationSession = _sessionService.hasCompleteOperationalContext;
        }

        if (hasStationSession) {
          Get.offAll(() => const DashboardScreen());
        } else {
          Get.offAll(
            () => StationSelectionScreen(userName: _sessionService.firstName),
          );
        }
        return;
      }

      Get.offAll(
        () => StationSelectionScreen(userName: _sessionService.firstName),
      );
      return;
    }

    Get.offAll(() => const LoginScreen());
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _bar1Ctrl.dispose();
    _bar2Ctrl.dispose();
    _bar3Ctrl.dispose();
    _wordCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.white,
      body: AnimatedBuilder(
        animation: _exitCtrl,
        builder: (context, child) => Opacity(
          opacity: _exitOpacity.value,
          child: Transform.scale(scale: _exitScale.value, child: child),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _logoCtrl,
            builder: (context, _) => FadeTransition(
              opacity: _logoOpacity,
              child: SlideTransition(
                position: _logoSlide,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogoMark(),
                    SizedBox(height: 14.h),
                    ClipRect(
                      child: SizedBox(
                        height: 40.h,
                        child: SlideTransition(
                          position: _wordSlide,
                          child: Text(
                            'Parallax',
                            style: GoogleFonts.dmSans(
                              fontSize: 30.sp,
                              fontWeight: FontWeight.w400,
                              color: _C.ink,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoMark() {
    return SizedBox(
      height: 38.h,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBar(_bar1Scale, 38.h, 1.0),
          SizedBox(width: 6.w),
          _buildBar(_bar2Scale, 30.h, 0.38),
          SizedBox(width: 6.w),
          _buildBar(_bar3Scale, 22.h, 0.14),
        ],
      ),
    );
  }

  Widget _buildBar(Animation<double> scale, double height, double opacity) {
    return AnimatedBuilder(
      animation: scale,
      builder: (_, child) => Align(
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scaleY: scale.value,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 8.w,
            height: height,
            decoration: BoxDecoration(
              color: _C.blue.withOpacity(opacity),
              borderRadius: BorderRadius.circular(2.5.r),
            ),
          ),
        ),
      ),
    );
  }
}
