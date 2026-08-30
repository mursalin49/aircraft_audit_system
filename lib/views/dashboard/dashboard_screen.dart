import 'package:avislap/views/inbox/inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motion_tab_bar/MotionTabBar.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';
import '../../utils/app_colors.dart';
import 'home_tab.dart';
import 'audit_tab.dart';
import 'quick_start_tab.dart';
import 'profile_tab.dart';
import 'reports_tab.dart';
import '../widgets/app_drawer.dart';

class _DashboardTabMeta {
  const _DashboardTabMeta({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  static const List<_DashboardTabMeta> _tabMeta = <_DashboardTabMeta>[
    _DashboardTabMeta(
      title: 'Home Dashboard',
      subtitle: 'Overview, live arrivals, and active station context',
    ),
    _DashboardTabMeta(
      title: 'Flight Audits',
      subtitle: 'Continue landed-flight audits and saved drafts',
    ),
    _DashboardTabMeta(
      title: 'Quick Start',
      subtitle: 'Open the forms and tools you use most',
    ),
    _DashboardTabMeta(
      title: 'Team Chat',
      subtitle: 'Search people and continue active conversations',
    ),
    _DashboardTabMeta(
      title: 'Reports',
      subtitle: 'Live audit metrics and backend summaries',
    ),
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  MotionTabBarController? _motionTabBarController;

  void _selectTab(int index) {
    setState(() {
      _motionTabBarController!.index = index;
    });
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  _DashboardTabMeta get _activeTabMeta {
    final int index = (_motionTabBarController?.index ?? 0).clamp(
      0,
      _tabMeta.length - 1,
    );
    return _tabMeta[index];
  }

  PreferredSizeWidget _buildDashboardAppBar() {
    final activeTab = _activeTabMeta;

    return PreferredSize(
      preferredSize: Size.fromHeight(82.h),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 82.h,
        titleSpacing: 0,
        leadingWidth: 56.w,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: IconButton(
            onPressed: _openDrawer,
            tooltip: 'Open menu',
            splashRadius: 22.r,
            icon: Icon(
              Icons.menu_rounded,
              size: 24.sp,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
        title: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activeTab.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                activeTab.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.h),
          child: Container(
            height: 1.h,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _motionTabBarController = MotionTabBarController(
      initialIndex: 0,
      length: 5,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _motionTabBarController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: _buildDashboardAppBar(),
      drawer: AppDrawer(
        onDashboardTap: () => _selectTab(0),
        onProfileTap: () => Get.to(() => const ProfileTab()),
      ),
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _motionTabBarController,
        children: const [
          HomeTab(),
          AuditTab(),
          QuickStartTab(),
          InboxScreen(),
          ReportsTab(),
        ],
      ),
      bottomNavigationBar: MotionTabBar(
        controller: _motionTabBarController,
        initialSelectedTab: "Home",
        useSafeArea: true,
        labels: const ["Home", "Audit", "Quick Start", "Chat", "Reports"],
        icons: const [
          Icons.home_outlined,
          Icons.assignment_outlined,
          Icons.flash_on_outlined,
          Icons.chat_bubble_outline,
          Icons.summarize_outlined,
        ],
        badges: const [null, null, null, null, null],
        tabSize: 50,
        tabBarHeight: 55,
        textStyle: const TextStyle(
          fontSize: 12,
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
        tabIconColor: AppColors.from_heading,
        tabIconSize: 28.0,
        tabIconSelectedSize: 26.0,
        tabSelectedColor: AppColors.mainAppColor,
        tabIconSelectedColor: Colors.white,
        tabBarColor: Colors.white,
        onTabItemSelected: (int value) {
          _selectTab(value);
        },
      ),
    );
  }
}
