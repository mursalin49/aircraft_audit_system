import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ParallaxHeroWidget
// Reusable blue hero section used across auth/select-station screens.
// Includes: animated ring circles + Parallax logo + slot for custom content.
// ─────────────────────────────────────────────────────────────────────────────
class ParallaxHeroWidget extends StatefulWidget {
  /// Content placed below the logo inside the SafeArea column.
  final Widget child;

  /// Optional trailing widget on the same row as the logo (e.g. logout button).
  final Widget? trailingAction;

  /// Bottom padding of the blue hero container (default 180.h).
  final double bottomPadding;

  const ParallaxHeroWidget({
    super.key,
    required this.child,
    this.trailingAction,
    this.bottomPadding = 180,
  });

  @override
  State<ParallaxHeroWidget> createState() => _ParallaxHeroWidgetState();
}

class _ParallaxHeroWidgetState extends State<ParallaxHeroWidget>
    with SingleTickerProviderStateMixin {
  static const Color _blue = Color(0xFF3D5AFE);

  late AnimationController _waveCtrl;
  late Animation<double> _c2Opacity;
  late Animation<double> _c3Opacity;

  @override
  void initState() {
    super.initState();

    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();

    // Circle 2 — opens first, fades out together with C3
    _c2Opacity = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0), weight: 10), // fade in early
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40), // ON
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0), weight: 10), // fade out TOGETHER
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 40), // OFF
    ]).animate(_waveCtrl);

    // Circle 3 — opens later, fades out at same time as C2
    _c3Opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 25), // wait
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0), weight: 10), // fade in late
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 15), // ON
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0), weight: 10), // fade out TOGETHER
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 40), // OFF
    ]).animate(_waveCtrl);
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, widget.bottomPadding.h),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36.r),
          bottomRight: Radius.circular(36.r),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Circle 1 — small, always fixed ────────────────
          Positioned(
            top: -size.width * 0.12,
            right: -size.width * 0.12,
            child: Container(
              width: size.width * 0.38,
              height: size.width * 0.38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.30),
                  width: 1.5,
                ),
              ),
            ),
          ),

          // ── Circle 2 — medium, animated (opens first) ─────
          Positioned(
            top: -size.width * 0.18,
            right: -size.width * 0.18,
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) => Opacity(
                opacity: _c2Opacity.value.clamp(0.0, 1.0),
                child: Container(
                  width: size.width * 0.62,
                  height: size.width * 0.62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.20),
                        width: 1.5),
                  ),
                ),
              ),
            ),
          ),

          // ── Circle 3 — biggest, animated (opens late) ─────
          Positioned(
            top: -size.width * 0.28,
            right: -size.width * 0.28,
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) => Opacity(
                opacity: _c3Opacity.value.clamp(0.0, 1.0),
                child: Container(
                  width: size.width * 0.90,
                  height: size.width * 0.90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.13),
                        width: 1.5),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 25.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo mark + "Parallax" text
                    Row(
                      children: [
                        _buildMark(),
                        SizedBox(width: 8.w),
                        Text(
                          'Parallax',
                          style: GoogleFonts.dmSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    if (widget.trailingAction != null) widget.trailingAction!,
                  ],
                ),
                SizedBox(height: 24.h),
                widget.child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Parallax bar mark ─────────────────────────────────────
  Widget _buildMark() {
    return SizedBox(
      height: 18.h,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(18.h, 1.0),
          SizedBox(width: 3.w),
          _bar(13.h, 0.4),
          SizedBox(width: 3.w),
          _bar(9.h, 0.15),
        ],
      ),
    );
  }

  Widget _bar(double h, double opacity) => Container(
        width: 4.w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          borderRadius: BorderRadius.circular(2.r),
        ),
      );
}
