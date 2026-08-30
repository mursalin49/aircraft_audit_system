import 'dart:async';
import 'package:avislap/views/auth/otp_password_succesful.dart';
import 'package:avislap/widgets/parallax_hero_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_exception.dart';
import '../../services/app_api_service.dart';
import '../../services/session_service.dart';

class _C {
  static const Color blue = Color(0xFF3D5AFE);
  static const Color ink = Color(0xFF0E0E10);
  static const Color border = Color(0xFFEAECF2);
}

class OtpPasswordVerificationScreen extends StatefulWidget {
  const OtpPasswordVerificationScreen({super.key});

  @override
  State<OtpPasswordVerificationScreen> createState() => _OtpPasswordVerificationScreenState();
}

class _OtpPasswordVerificationScreenState extends State<OtpPasswordVerificationScreen> {
  final AppApiService _api = Get.find<AppApiService>();
  final SessionService _session = Get.find<SessionService>();

  // ── OTP fields ───────────────────────────────────────────
  final int _otpLength = 5;
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  // ── Resend timer ─────────────────────────────────────────
  Timer? _timer;
  int _secondsLeft = 0; // 0 = show "Resend OTP", >0 = show "wait for X.XX sec"
  bool _canResend = true;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());

    // Focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  // ── Resend timer logic ───────────────────────────────────
  void _startResendTimer() {
    setState(() {
      _secondsLeft = 60; // 60 seconds countdown
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft -= 1;
        if (_secondsLeft <= 0) {
          _secondsLeft = 0;
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _handleResend() async {
    final email = _session.passwordRecoveryEmail?.trim() ?? '';
    if (email.isEmpty) {
      _startResendTimer();
      return;
    }

    try {
      final response = await _api.requestForgotPassword(email);
      final recoveryToken = (response['recoveryToken'] as String?)?.trim() ?? '';
      if (recoveryToken.isNotEmpty) {
        _session.savePasswordRecovery(token: recoveryToken, email: email);
      }
      if (!mounted) {
        return;
      }
      _startResendTimer();
    } on ApiException catch (error) {
      Get.snackbar(
        'Resend Failed',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      Get.snackbar(
        'Resend Failed',
        'Unable to resend the password recovery email right now.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String get _timerText {
    final secs = (_secondsLeft / 10).floor();
    final tenths = _secondsLeft % 10;
    return 'wait for $secs.$tenths sec';
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── OTP input handler ────────────────────────────────────
  void _onOtpChanged(String value, int index) {
    if (value.length == 1) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // ── Blue Hero ──────────────────────────────────
          ParallaxHeroWidget(
            bottomPadding: 200,
            child: Text(
              'OTP Verification',
              style: GoogleFonts.dmSans(
                fontSize: 30.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.8,
                height: 1.15,
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Transform.translate(
                offset: const Offset(0, -140),
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
                        'Enter the OTP sent to your email address\nto continue resetting your password',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 13.sp,
                          color: Colors.grey.shade500,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // OTP boxes
                      _buildOtpRow(),
                      SizedBox(height: 28.h),

                      // Continue button
                      _buildContinueButton(),
                      SizedBox(height: 16.h),

                      // Resend / Timer
                      _canResend
                          ? GestureDetector(
                        onTap: _handleResend,
                        child: Text(
                          'Resend OTP',
                          style: GoogleFonts.dmSans(
                            fontSize: 14.sp,
                            color: _C.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                          : Text(
                        _timerText,
                        style: GoogleFonts.dmSans(
                          fontSize: 14.sp,
                          color: _C.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Back to Sign In
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Text(
                          'Back to Sign In',
                          style: GoogleFonts.dmSans(
                            fontSize: 14.sp,
                            color: _C.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

  // ── OTP Row ───────────────────────────────────────────────
  Widget _buildOtpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_otpLength, (i) => _buildOtpBox(i)),
    );
  }

  Widget _buildOtpBox(int index) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (e) => _onKeyEvent(e, index),
      child: SizedBox(
        width: 52.w,
        height: 58.h,
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.dmSans(
            fontSize: 22.sp,
            fontWeight: FontWeight.w600,
            color: _C.ink,
          ),
          onChanged: (v) => _onOtpChanged(v, index),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: _C.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: _C.blue, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  // ── Continue Button ───────────────────────────────────────
  Widget _buildContinueButton() {
    return GestureDetector(
      onTap: () {
        Get.to(() => const OtpPasswordSuccessScreen());
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
