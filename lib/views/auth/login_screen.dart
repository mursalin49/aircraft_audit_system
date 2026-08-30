import 'package:avislap/views/auth/trouble_screen.dart';
import 'package:avislap/views/select_station/select_station.dart';
import 'package:avislap/widgets/parallax_hero_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_exception.dart';
import '../../services/app_api_service.dart';
import '../../services/session_service.dart';
import '../../utils/app_colors.dart';

class _C {
  static const Color blue = Color(0xFF3D5AFE);
  static const Color ink = Color(0xFF0E0E10);
  static const Color muted = Color(0xFF8891A4);
  static const Color border = Color(0xFFEAECF2);
  static const Color placeholder = Color(0xFFC8CDD9);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _userIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final AppApiService _api = Get.find<AppApiService>();
  final SessionService _session = Get.find<SessionService>();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isSubmitting = false;

  late AnimationController _heroCtrl;
  late Animation<double> _heroOpacity;
  late Animation<Offset> _heroSlide;

  late AnimationController _formCtrl;
  late List<Animation<double>> _itemOpacity;
  late List<Animation<Offset>> _itemSlide;

  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();

    _rememberMe = _session.rememberMe;
    _userIdCtrl.text = (_session.user?['uid'] as String?) ?? '';

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heroOpacity = Tween<double>(begin: 0, end: 1).animate(_heroCtrl);
    _heroSlide = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutExpo));

    _formCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _itemOpacity = List.generate(
      5,
      (i) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _formCtrl,
          curve: Interval(i * 0.1, i * 0.1 + 0.55, curve: Curves.easeOutExpo),
        ),
      ),
    );
    _itemSlide = List.generate(
      5,
      (i) => Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
          .animate(
        CurvedAnimation(
          parent: _formCtrl,
          curve: Interval(i * 0.1, i * 0.1 + 0.55, curve: Curves.easeOutExpo),
        ),
      ),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(_shimmerCtrl);

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        _heroCtrl.forward();
        _formCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _passwordCtrl.dispose();
    _heroCtrl.dispose();
    _formCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final userId = _userIdCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (userId.isEmpty || password.isEmpty) {
      Get.snackbar(
        'Incomplete',
        'Please enter your User ID and password.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = await _api.login(
        userId: userId,
        password: password,
        rememberMe: _rememberMe,
      );

      _session.saveAuth(
        accessToken: (auth['accessToken'] as String?) ?? '',
        refreshToken: (auth['refreshToken'] as String?) ?? '',
        rememberMe: _rememberMe,
      );

      final profile = await _api.me();
      _session.saveUser(
        profile['user'] is Map<String, dynamic>
            ? profile['user'] as Map<String, dynamic>
            : null,
      );
      _session.saveActiveStation(null);

      if (!mounted) {
        return;
      }

      Get.off(
        () => StationSelectionScreen(
          userName: _session.firstName,
          forceReselect: true,
        ),
      );
    } on ApiException catch (error) {
      _session.clear();
      Get.snackbar(
        'Sign In Failed',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      _session.clear();
      Get.snackbar(
        'Sign In Failed',
        'Something went wrong while signing in.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _heroOpacity,
            child: SlideTransition(
              position: _heroSlide,
              child: ParallaxHeroWidget(
                bottomPadding: 220,
                child: Text(
                  'Sign in to\nyour Account',
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
          Positioned.fill(
            top: 230.h,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, bottomInset + 28.h),
              child: _buildFormCard(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildHomeIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormItem({required int index, required Widget child}) {
    return FadeTransition(
      opacity: _itemOpacity[index],
      child: SlideTransition(position: _itemSlide[index], child: child),
    );
  }

  Widget _buildUserIdField() => _buildField(
    label: 'User ID',
    child: _buildInput(controller: _userIdCtrl, hint: 'Enter your User ID'),
  );

  Widget _buildPasswordField() => _buildField(
    label: 'New Password',
    child: _buildInput(
      controller: _passwordCtrl,
      hint: 'Enter new password',
      obscure: _obscurePassword,
      suffixIcon: GestureDetector(
        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
        child: Icon(
          _obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: _C.muted,
          size: 20.sp,
        ),
      ),
    ),
  );

  Widget _buildRememberRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              width: 20.w,
              height: 20.h,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                activeColor: _C.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.r),
                ),
                side: BorderSide(color: AppColors.mainAppColor),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'Remember me',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                color: AppColors.mainAppColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Get.to(() => const TroubleScreen()),
          child: Text(
            'Trouble Signing in?',
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              color: _C.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({required String label, required Widget child}) =>
      Column(
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

  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 28.h),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormItem(index: 0, child: _buildUserIdField()),
          SizedBox(height: 16.h),
          _buildFormItem(index: 1, child: _buildPasswordField()),
          SizedBox(height: 14.h),
          _buildFormItem(index: 2, child: _buildRememberRow()),
          SizedBox(height: 24.h),
          _buildFormItem(index: 3, child: _buildSignInButton()),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffixIcon,
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
        enabled: !_isSubmitting,
        style: GoogleFonts.dmSans(fontSize: 15.sp, color: _C.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(fontSize: 15.sp, color: _C.placeholder),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: suffixIcon,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _handleSignIn,
      child: AnimatedBuilder(
        animation: _shimmerAnim,
        builder: (context, _) => Container(
          height: 54.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _isSubmitting ? _C.blue.withOpacity(0.75) : _C.blue,
            borderRadius: BorderRadius.circular(30.r),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(
                    _shimmerAnim.value * MediaQuery.of(context).size.width,
                    0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 0.4,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _isSubmitting
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'SIGN IN',
                      style: GoogleFonts.dmSans(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeIndicator() => Padding(
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
