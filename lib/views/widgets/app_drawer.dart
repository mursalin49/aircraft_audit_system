import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../healper/route.dart';
import '../../services/api_exception.dart';
import '../../services/app_api_service.dart';
import '../../services/session_service.dart';
import '../../utils/app_colors.dart';
import '../audits/draft_audits_screen.dart';
import '../audits/my_audits_screen.dart';
import '../dashboard/audit_operations_tab.dart';
import '../../config/app_permission_codes.dart';
import '../forms/survey_hub/admin_submitted_forms_screen.dart';
import '../forms/survey_hub/my_submitted_forms_screen.dart';
import '../forms/Cabin%20Quality%20Audit/CabinQualityAuditList.dart';
import '../forms/LAV%20Safety%20Observation/LavSafetyObservationScreen.dart';
import '../forms/cabin%20security%20search/CabinSecurityTrainingScreen.dart';
import '../forms/hidden_object_audit/hidden_object_audit_screen.dart';

class _StationOption {
  const _StationOption({
    required this.id,
    required this.label,
    required this.availableContracts,
    this.activeContract,
  });

  final String id;
  final String label;
  final List<String> availableContracts;
  final String? activeContract;
}

class AppDrawer extends StatefulWidget {
  final VoidCallback? onDashboardTap;
  final VoidCallback? onProfileTap;

  const AppDrawer({super.key, this.onDashboardTap, this.onProfileTap});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final AppApiService _api = Get.find<AppApiService>();
  bool _isLoggingOut = false;
  bool _isLoadingStations = false;
  final List<_StationOption> _stations = <_StationOption>[];

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    if (_isLoadingStations || _stations.isNotEmpty) {
      return;
    }

    setState(() => _isLoadingStations = true);

    try {
      final stations = await _api.getMyStations();
      final mappedStations = stations
          .map((station) {
            final code = (station['stationCode'] as String?)?.trim() ?? '';
            final name = (station['stationName'] as String?)?.trim() ?? '';
            final label = [
              code,
              name,
            ].where((part) => part.isNotEmpty).join(' - ');

            return _StationOption(
              id: (station['stationId'] as String?)?.trim() ?? '',
              label: label.isEmpty ? 'Station' : label,
              availableContracts:
                  ((station['availableContracts'] as List?) ?? [])
                      .map((entry) => entry?.toString().trim() ?? '')
                      .where((entry) => entry.isNotEmpty)
                      .toList(growable: false),
              activeContract: (station['activeContract'] as String?)?.trim(),
            );
          })
          .where((station) => station.id.isNotEmpty)
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _stations
          ..clear()
          ..addAll(mappedStations);
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      Get.snackbar(
        'Stations Unavailable',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      Get.snackbar(
        'Stations Unavailable',
        'Unable to load the stations right now.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingStations = false);
      }
    }
  }

  Future<void> _showWorkspaceSwitcher(SessionService session) async {
    await _loadStations();
    if (!mounted) {
      return;
    }

    String? selectedStationId = session.activeStationId.isNotEmpty
        ? session.activeStationId
        : (_stations.isNotEmpty ? _stations.first.id : null);
    String? selectedContract = session.activeContract.isNotEmpty
        ? session.activeContract
        : null;
    bool isSubmitting = false;

    _StationOption? findSelectedStation() {
      for (final station in _stations) {
        if (station.id == selectedStationId) {
          return station;
        }
      }
      return null;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedStation = findSelectedStation();
            final availableContracts =
                selectedStation?.availableContracts ?? const <String>[];

            Widget contextChip({
              required IconData icon,
              required String label,
              required String value,
              required Color tint,
            }) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15.sp, color: tint),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        '$label: $value',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: tint,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            Future<void> submit() async {
              if (selectedStation == null) {
                Get.snackbar(
                  'Station Required',
                  'Please select a station first.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              final normalizedContract = selectedContract?.trim() ?? '';
              if (availableContracts.isNotEmpty && normalizedContract.isEmpty) {
                Get.snackbar(
                  'Airline Required',
                  'Please choose the airline contract for this station.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              setModalState(() => isSubmitting = true);
              try {
                final activeStation = await _api.selectStation(
                  selectedStation.id,
                  contract: normalizedContract.isEmpty
                      ? null
                      : normalizedContract,
                );
                session.saveActiveStation(activeStation);

                if (!mounted || !sheetContext.mounted) {
                  return;
                }

                Navigator.of(sheetContext).pop();
                Get.offAllNamed(RouteHelper.dashboard);
              } on ApiException catch (error) {
                Get.snackbar(
                  'Update Failed',
                  error.message,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              } catch (_) {
                Get.snackbar(
                  'Update Failed',
                  'Unable to switch workspace right now.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              } finally {
                if (sheetContext.mounted) {
                  setModalState(() => isSubmitting = false);
                }
              }
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                20.w,
                16.h,
                20.w,
                MediaQuery.of(sheetContext).padding.bottom + 22.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'Switch Workspace',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Change your station session and airline contract without leaving the dashboard.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      contextChip(
                        icon: Icons.flight_land_rounded,
                        label: 'Station',
                        value: session.activeStationCode.isEmpty
                            ? 'Not selected'
                            : session.activeStationCode,
                        tint: const Color(0xFF2563EB),
                      ),
                      contextChip(
                        icon: Icons.business_center_outlined,
                        label: 'Airline',
                        value: session.activeContract.isEmpty
                            ? 'Not selected'
                            : session.activeContract,
                        tint: const Color(0xFF0F766E),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'Station',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStationId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: const BorderSide(color: Color(0xFF2563EB)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 16.h,
                      ),
                    ),
                    hint: const Text('Select station'),
                    items: _stations
                        .map(
                          (station) => DropdownMenuItem<String>(
                            value: station.id,
                            child: Text(
                              station.label,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: isSubmitting
                        ? null
                        : (value) {
                            setModalState(() {
                              selectedStationId = value;
                              final station = findSelectedStation();
                              if (station == null) {
                                selectedContract = null;
                              } else if (station.availableContracts.length ==
                                  1) {
                                selectedContract =
                                    station.availableContracts.first;
                              } else {
                                final currentContract =
                                    selectedContract?.trim() ?? '';
                                selectedContract =
                                    station.availableContracts.contains(
                                      currentContract,
                                    )
                                    ? currentContract
                                    : station.activeContract;
                              }
                            });
                          },
                  ),
                  if (availableContracts.isNotEmpty) ...[
                    SizedBox(height: 18.h),
                    Text(
                      'Airline Contract',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: availableContracts
                          .map((contract) {
                            final isSelected = selectedContract == contract;
                            return ChoiceChip(
                              label: Text(contract),
                              selected: isSelected,
                              onSelected: isSubmitting
                                  ? null
                                  : (_) => setModalState(
                                      () => selectedContract = contract,
                                    ),
                              labelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                              selectedColor: const Color(0xFF0F766E),
                              backgroundColor: const Color(0xFFF8FAFC),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFFE2E8F0),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                  if (_stations.isEmpty && !_isLoadingStations) ...[
                    SizedBox(height: 16.h),
                    Text(
                      'No station assignments are available for this user yet.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_stations.isEmpty || isSubmitting)
                          ? null
                          : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(
                          0xFF2563EB,
                        ).withValues(alpha: 0.40),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: isSubmitting
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Apply Workspace',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Log out'),
            content: const Text('Do you want to end your current session?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isLoggingOut = true);

    await _api.logout();

    if (!mounted) {
      return;
    }

    Get.offAllNamed(RouteHelper.login);
  }

  String _workspaceValue({
    required String currentValue,
    required List<String> fallbackOptions,
    required String emptyLabel,
  }) {
    if (currentValue.trim().isNotEmpty) {
      return currentValue.trim();
    }
    if (fallbackOptions.isNotEmpty) {
      return emptyLabel;
    }
    return 'Not set';
  }

  String _workspaceSummary({
    required String stationLabel,
    required String airlineLabel,
  }) {
    final details = <String>[];
    if (stationLabel != 'Not set' && stationLabel != 'Choose station') {
      details.add(stationLabel);
    } else if (stationLabel == 'Choose station') {
      details.add('Choose station');
    }

    if (airlineLabel != 'Not set' && airlineLabel != 'Choose airline') {
      details.add(airlineLabel);
    } else if (airlineLabel == 'Choose airline') {
      details.add('Choose airline');
    }

    if (details.isEmpty) {
      return 'No station or airline selected yet';
    }

    return details.join('  •  ');
  }

  Widget _buildWorkspaceSwitcher({
    required String summary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: onTap,
      child: Ink(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(Icons.swap_horiz_rounded, size: 18.sp, color: Colors.white),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Change workspace • $summary',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_right_rounded,
              size: 18.sp,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    final canViewAdminSubmissions = session.hasPermission(
      AppPermissionCodes.adminDashboardSubmissions,
    );
    final showLavSafety = session.hasPermission(
      AppPermissionCodes.lavSafetyObservation,
    );
    final showCabinQuality = session.hasPermission(
      AppPermissionCodes.cabinQualityAudit,
    );
    final showCabinSecurity = session.hasPermission(
      AppPermissionCodes.cabinSecuritySearchTraining,
    );
    final showHiddenObjectAudit = session.hasPermission(
      AppPermissionCodes.hiddenObjectAudit,
    );
    final hasAuditWorkflowAccess =
        showLavSafety ||
        showCabinQuality ||
        showCabinSecurity ||
        showHiddenObjectAudit;
    final stationLabel = _workspaceValue(
      currentValue: session.activeStationCode,
      fallbackOptions: _stations
          .map((station) => station.id)
          .toList(growable: false),
      emptyLabel: 'Choose station',
    );
    final airlineLabel = _workspaceValue(
      currentValue: session.activeContract,
      fallbackOptions: session.availableContracts,
      emptyLabel: 'Choose airline',
    );
    final workspaceSummary = _workspaceSummary(
      stationLabel: stationLabel,
      airlineLabel: airlineLabel,
    );
    final String profileImageUrl = session.profileImageFileId.isEmpty
        ? ''
        : _api.buildFileContentUrl(session.profileImageFileId);
    final Map<String, String> imageHeaders = _api.buildImageHeaders();
    final String initials = session.fullName.trim().isEmpty
        ? 'U'
        : session.fullName
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();
    final ImageProvider<Object>? profileImage = profileImageUrl.isEmpty
        ? null
        : NetworkImage(profileImageUrl, headers: imageHeaders);

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            margin: EdgeInsets.zero,
            currentAccountPictureSize: Size.square(56.w),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF0F172A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: <Color>[Color(0x66FFFFFF), Color(0x1FFFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white30, width: 1.5),
              ),
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                backgroundImage: profileImage,
                child: profileImage == null
                    ? Text(
                        initials,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 18.sp,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
            accountName: Text(
              session.fullName.isEmpty ? "User" : session.fullName,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            accountEmail: _buildWorkspaceSwitcher(
              summary: workspaceSummary,
              onTap: () => _showWorkspaceSwitcher(session),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerSectionHeader(title: 'Workspace'),
                DrawerTile(
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  onTap: () {
                    Get.back();
                    widget.onDashboardTap?.call();
                  },
                ),
                DrawerTile(
                  icon: Icons.person_outline_rounded,
                  title: 'My Profile',
                  onTap: () {
                    Get.back();
                    widget.onProfileTap?.call();
                  },
                ),
                if (hasAuditWorkflowAccess) ...[
                  const SizedBox(height: 8),
                  _DrawerSectionHeader(
                    title: 'Audit Workflows',
                    subtitle: 'Start the right audit flow for your shift.',
                  ),
                  if (showLavSafety)
                    DrawerTile(
                      icon: Icons.clean_hands,
                      title: 'Lav Safety Observation',
                      iconColor: const Color(0xFF0EA5E9),
                      onTap: () {
                        Get.back();
                        Get.to(() => LavSafetyObservationScreen());
                      },
                    ),
                  if (showCabinQuality)
                    DrawerTile(
                      icon: Icons.check_circle_outline,
                      title: 'Cabin Quality Audit',
                      iconColor: const Color(0xFF10B981),
                      onTap: () {
                        Get.back();
                        Get.to(() => CabinQualityAuditListScreen());
                      },
                    ),
                  if (showCabinSecurity)
                    DrawerTile(
                      icon: Icons.security,
                      title: 'Cabin Security Search Training',
                      iconColor: const Color(0xFFF59E0B),
                      onTap: () {
                        Get.back();
                        Get.to(() => CabinSecurityScreen());
                      },
                    ),
                  if (showHiddenObjectAudit)
                    DrawerTile(
                      icon: Icons.search,
                      title: 'Hidden Object Audit',
                      iconColor: const Color(0xFF8B5CF6),
                      onTap: () {
                        Get.back();
                        Get.to(() => const HiddenObjectAuditListScreen());
                      },
                    ),
                ],
                const SizedBox(height: 8),
                _DrawerSectionHeader(title: 'My Activity'),
                DrawerTile(
                  icon: Icons.history_outlined,
                  title: 'My Audits',
                  onTap: () {
                    Get.back();
                    Get.to(() => const MyAuditsScreen());
                  },
                ),
                DrawerTile(
                  icon: Icons.drafts_outlined,
                  title: 'Draft Audits',
                  onTap: () {
                    Get.back();
                    Get.to(() => const DraftAuditsScreen());
                  },
                ),
                DrawerTile(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'My Submitted Forms',
                  onTap: () {
                    Get.back();
                    Get.to(() => const MySubmittedFormsScreen());
                  },
                ),
                DrawerTile(
                  icon: Icons.manage_search_outlined,
                  title: 'All Submitted Audits',
                  onTap: () {
                    Get.back();
                    Get.to(() => const AuditOperationsTab());
                  },
                ),
                if (canViewAdminSubmissions)
                  DrawerTile(
                    icon: Icons.topic_outlined,
                    title: 'All Submitted Forms',
                    onTap: () {
                      Get.back();
                      Get.to(() => const AdminSubmittedFormsScreen());
                    },
                  ),
                DrawerTile(
                  icon: Icons.assignment_outlined,
                  title: 'Pending Tasks',
                  onTap: () {
                    Get.back();
                    Get.snackbar(
                      'Coming Soon',
                      'Pending tasks will be available soon.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.black87,
                      colorText: Colors.white,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _DrawerSectionHeader(title: 'App'),
                DrawerTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {
                    Get.back();
                    Get.snackbar(
                      'Coming Soon',
                      'Settings will be available soon.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.black87,
                      colorText: Colors.white,
                    );
                  },
                ),
                DrawerTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  onTap: () {
                    Get.back();
                    Get.snackbar(
                      'Coming Soon',
                      'Help & support will be available soon.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.black87,
                      colorText: Colors.white,
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          DrawerTile(
            icon: Icons.logout_rounded,
            title: _isLoggingOut ? 'Logging out...' : 'Logout',
            textColor: Colors.redAccent,
            iconColor: Colors.redAccent,
            trailing: _isLoggingOut
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _logout,
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

class _DrawerSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _DrawerSectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;
  final Widget? trailing;

  const DrawerTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? const Color(0xFF475569)),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppColors.dark,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
