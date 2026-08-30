import 'package:avislap/views/forms/Cabin%20Quality%20Audit/CabinQualityAuditList.dart';
import 'package:avislap/views/forms/LAV%20Safety%20Observation/LavSafetyObservationScreen.dart';
import 'package:avislap/views/forms/cabin%20security%20search/CabinSecurityTrainingScreen.dart';
import 'package:avislap/views/forms/hidden_object_audit/hidden_object_audit_screen.dart';
import 'package:avislap/config/app_permission_codes.dart';
import 'package:avislap/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

// MODELS
// =====================
class DrawerSubItem {
  final String title;
  final IconData? icon;
  const DrawerSubItem({required this.title, this.icon});
}

class DrawerMenuItem {
  final String title;
  final IconData icon;
  final List<DrawerSubItem>? subItems;
  const DrawerMenuItem({
    required this.title,
    required this.icon,
    this.subItems,
  });
  bool get hasChildren => subItems != null && subItems!.isNotEmpty;
}

// =====================
// CONTROLLER
// =====================
class AppDrawerController extends GetxController {
  final RxString expandedItem = ''.obs;
  final RxString activeItem = 'Dashboard'.obs;
  final SessionService _session = Get.find<SessionService>();

  List<DrawerMenuItem> get menuItems {
    final formSubItems = <DrawerSubItem>[
      if (_session.hasPermission(AppPermissionCodes.cabinQualityAudit))
        const DrawerSubItem(title: 'Cabin Quality Audit'),
      if (_session.hasPermission(
        AppPermissionCodes.cabinSecuritySearchTraining,
      ))
        const DrawerSubItem(title: 'Cabin Security Search Training'),
      if (_session.hasPermission(AppPermissionCodes.hiddenObjectAudit))
        const DrawerSubItem(title: 'Hidden Object Audit'),
      if (_session.hasPermission(AppPermissionCodes.lavSafetyObservation))
        const DrawerSubItem(title: 'LAV Safety Observation'),
    ];

    return const [
          DrawerMenuItem(
            title: 'Dashboard',
            icon: Icons.pie_chart_outline_rounded,
          ),
          DrawerMenuItem(
            title: 'My Employees',
            icon: Icons.people_outline_rounded,
            subItems: [
              DrawerSubItem(
                title: 'Employee Detail',
                icon: Icons.person_outline_rounded,
              ),
              DrawerSubItem(title: 'Directory', icon: Icons.phone_outlined),
            ],
          ),
        ]
        .followedBy([
          if (formSubItems.isNotEmpty)
            DrawerMenuItem(
              title: 'Forms',
              icon: Icons.insert_drive_file_outlined,
              subItems: formSubItems,
            ),
          const DrawerMenuItem(
            title: 'Inventory',
            icon: Icons.grid_view_outlined,
          ),
          const DrawerMenuItem(
            title: 'Chat',
            icon: Icons.chat_bubble_outline_rounded,
          ),
          const DrawerMenuItem(
            title: 'Time and Edits',
            icon: Icons.access_time_rounded,
            subItems: [
              DrawerSubItem(
                title: 'Time Sheet',
                icon: Icons.calendar_today_outlined,
              ),
              DrawerSubItem(title: 'Edit Requests', icon: Icons.edit_outlined),
            ],
          ),
          const DrawerMenuItem(
            title: 'Feedback',
            icon: Icons.people_alt_outlined,
          ),
        ])
        .toList(growable: false);
  }

  void toggleExpand(String title) =>
      expandedItem.value = expandedItem.value == title ? '' : title;
  void setActive(String title) => activeItem.value = title;
  bool isExpanded(String title) => expandedItem.value == title;
  bool isActive(String title) => activeItem.value == title;
}

// =====================
// DRAWER WIDGET
// =====================
class AppDrawerWidget extends StatelessWidget {
  final String appName;
  final String? userName;
  final String? userRole;
  final String? userImage;
  final VoidCallback? onLogout;

  AppDrawerWidget({
    super.key,
    this.appName = 'Parallax',
    this.userName,
    this.userRole,
    this.userImage,
    this.onLogout,
  });

  final AppDrawerController _ctrl = Get.put(AppDrawerController());
  static const Color _blue = Color(0xFF3D5AFE);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 290.w,
      backgroundColor: _blue,
      elevation: 0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 8.h),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _ctrl.menuItems.length,
                itemBuilder: (_, i) => _buildItem(_ctrl.menuItems[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logo header ────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
      child: Row(
        children: [
          SizedBox(
            height: 17.h,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _logoBar(17.h, 1.0),
                SizedBox(width: 3.w),
                _logoBar(12.h, 0.5),
                SizedBox(width: 3.w),
                _logoBar(7.h, 0.22),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            appName,
            style: GoogleFonts.dmSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoBar(double h, double opacity) => Container(
    width: 3.5.w,
    height: h,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      borderRadius: BorderRadius.circular(2.r),
    ),
  );

  // ── Menu item ──────────────────────────────────────────
  Widget _buildItem(DrawerMenuItem item) {
    return Obx(() {
      final expanded = _ctrl.isExpanded(item.title);
      final active = _ctrl.isActive(item.title);
      final isActiveLeaf = active && !item.hasChildren;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main row
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (item.hasChildren) {
                _ctrl.toggleExpand(item.title);
              } else {
                _ctrl.setActive(item.title);
                Get.back();
              }
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
              decoration: BoxDecoration(
                // ✅ Active item (Dashboard etc) → white card
                color: isActiveLeaf ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 20.sp,
                    color: isActiveLeaf ? _blue : Colors.white,
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Text(
                      item.title,
                      style: GoogleFonts.dmSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: isActiveLeaf ? _blue : Colors.white,
                      ),
                    ),
                  ),
                  // ✅ Collapsed = chevron right, Expanded = chevron down
                  if (item.hasChildren)
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      size: 21.sp,
                      color: Colors.white.withOpacity(0.8),
                    ),
                ],
              ),
            ),
          ),

          // ✅ Sub-items with vertical line
          if (item.hasChildren)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _buildSubList(item.subItems!),
            ),
        ],
      );
    });
  }

  // ── Sub list with bracket connector (└) ────────────────
  Widget _buildSubList(List<DrawerSubItem> subs) {
    const double itemH = 44.0;
    const double bracketW = 16.0;

    return Padding(
      padding: EdgeInsets.only(left: 28.w, right: 12.w, bottom: 6.h),
      child: Stack(
        children: [
          // ✅ CustomPainter: vertical line + horizontal bracket per item
          Positioned.fill(
            child: CustomPaint(
              painter: _BracketLinePainter(
                itemCount: subs.length,
                itemHeight: itemH,
                bracketWidth: bracketW,
                color: Colors.white.withOpacity(0.45),
                strokeWidth: 1.5,
              ),
            ),
          ),

          // Sub items — indented past the bracket
          Padding(
            padding: const EdgeInsets.only(left: bracketW + 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: subs.map((s) => _buildSubItem(s, itemH)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItem(DrawerSubItem sub, double itemH) {
    return Obx(() {
      final active = _ctrl.isActive(sub.title);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _ctrl.setActive(sub.title);

          Get.back(); // Close drawer first

          if (sub.title == 'LAV Safety Observation') {
            Get.to(() => LavSafetyObservationScreen());
          } else if (sub.title == 'Cabin Quality Audit') {
            Get.to(() => CabinQualityAuditListScreen());
          } else if (sub.title == 'Cabin Security Search Training') {
            Get.to(() => CabinSecurityScreen());
          } else if (sub.title == 'Hidden Object Audit') {
            Get.to(() => const HiddenObjectAuditListScreen());
          }
        },
        child: SizedBox(
          height: itemH,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                if (sub.icon != null) ...[
                  Icon(
                    sub.icon,
                    size: 16.sp,
                    color: Colors.white.withOpacity(active ? 1.0 : 0.72),
                  ),
                  SizedBox(width: 9.w),
                ],
                Expanded(
                  child: Text(
                    sub.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14.sp,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w600,
                      color: Colors.white.withOpacity(active ? 1.0 : 0.82),
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
}

// =====================
// CUSTOM PAINTER — bracket connector (└)
// =====================
class _BracketLinePainter extends CustomPainter {
  final int itemCount;
  final double itemHeight;
  final double bracketWidth;
  final Color color;
  final double strokeWidth;

  const _BracketLinePainter({
    required this.itemCount,
    required this.itemHeight,
    required this.bracketWidth,
    required this.color,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Vertical line: from top to last item midpoint
    final double lastMidY = (itemCount - 1) * itemHeight + itemHeight / 2;

    // Draw main vertical line
    canvas.drawLine(const Offset(0, 0), Offset(0, lastMidY), paint);

    // Draw horizontal bracket for each item (└ shape)
    for (int i = 0; i < itemCount; i++) {
      final double midY = i * itemHeight + itemHeight / 2;
      canvas.drawLine(Offset(0, midY), Offset(bracketWidth, midY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BracketLinePainter old) =>
      old.itemCount != itemCount ||
      old.itemHeight != itemHeight ||
      old.color != color;
}
