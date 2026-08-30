import 'package:avislap/views/auth/splash_screen.dart';
import 'package:avislap/views/auth/login_screen.dart';
import 'package:avislap/config/app_permission_codes.dart';
import 'package:avislap/services/session_service.dart';
import 'package:avislap/views/forms/LAV%20Safety%20Observation/LavSafetyObservationScreen.dart';
import 'package:avislap/views/forms/hidden_object_audit/hidden_object_audit_screen.dart';
import 'package:get/get.dart';

import '../views/dashboard/dashboard_screen.dart';
import '../views/forms/Cabin Quality Audit/CabinAudit.dart';
import '../views/forms/cabin security search/cabin_secuirity.dart';

class RouteHelper {
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String cabinAudit = '/cabin-audit';
  // static const String lavSafety = '/lav-safety';
  static const String lavSafety = '/LAVSafety';
  static const String cabinSecurityTraining = '/cabin_secuirity';
  static const String hiddenObjectAudit = '/hidden_object_audit';

  static List<GetPage> routes = [
    GetPage(
      name: splash,
      // page: () => FlightAnimation(),
      page: () => SplashScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: dashboard,
      page: () => const DashboardScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: cabinAudit,
      page: () {
        final session = Get.find<SessionService>();
        if (!session.hasPermission(AppPermissionCodes.cabinQualityAudit)) {
          return const DashboardScreen();
        }
        return CabinAuditScreen();
      },
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: lavSafety,
      page: () {
        final session = Get.find<SessionService>();
        if (!session.hasPermission(AppPermissionCodes.lavSafetyObservation)) {
          return const DashboardScreen();
        }
        return LavSafetyObservationScreen();
      },
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: cabinSecurityTraining,
      page: () {
        final session = Get.find<SessionService>();
        if (!session.hasPermission(
          AppPermissionCodes.cabinSecuritySearchTraining,
        )) {
          return const DashboardScreen();
        }
        return const CabinQualityAuditScreenN();
      },
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: hiddenObjectAudit,
      page: () {
        final session = Get.find<SessionService>();
        if (!session.hasPermission(AppPermissionCodes.hiddenObjectAudit)) {
          return const DashboardScreen();
        }
        return const HiddenObjectAuditListScreen();
      },
      transition: Transition.rightToLeft,
    ),
  ];
}
