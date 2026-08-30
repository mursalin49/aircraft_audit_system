import 'package:avislap/views/dashboard/dashboard_screen.dart';
import 'package:avislap/widgets/parallax_hero_widget.dart';
import 'package:flutter/material.dart';
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
  static const Color muted = Color(0xFF8891A4);
}

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

class StationSelectionScreen extends StatefulWidget {
  final String userName;
  final bool forceReselect;

  const StationSelectionScreen({
    super.key,
    this.userName = '',
    this.forceReselect = false,
  });

  @override
  State<StationSelectionScreen> createState() => _StationSelectionScreenState();
}

class _StationSelectionScreenState extends State<StationSelectionScreen> {
  final AppApiService _api = Get.find<AppApiService>();
  final SessionService _session = Get.find<SessionService>();

  String? _selectedStationId;
  String? _selectedContract;
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<_StationOption> _stations = const <_StationOption>[];
  final TextEditingController _searchCtrl = TextEditingController();
  String _stationQuery = '';

  String get _displayName {
    if (widget.userName.trim().isNotEmpty) {
      return widget.userName.trim();
    }
    if (_session.firstName.isNotEmpty) {
      return _session.firstName;
    }
    return 'User';
  }

  _StationOption? get _selectedStation {
    for (final station in _stations) {
      if (station.id == _selectedStationId) {
        return station;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadStations();
    _searchCtrl.addListener(() {
      setState(() => _stationQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoading = true);

    try {
      final stations = await _api.getMyStations();
      Map<String, dynamic>? activeStation;
      if (!widget.forceReselect) {
        activeStation = await _api.getActiveStation();
        _session.saveActiveStation(activeStation);
      } else {
        _session.saveActiveStation(null);
      }

      final mappedStations = stations
          .map((station) {
            final code = (station['stationCode'] as String?)?.trim() ?? '';
            final name = (station['stationName'] as String?)?.trim() ?? '';
            final label = [
              code,
              name,
            ].where((part) => part.isNotEmpty).join(' - ');

            return _StationOption(
              id: (station['stationId'] as String?) ?? '',
              label: label.isEmpty ? 'Station' : label,
              availableContracts: ((station['availableContracts'] as List?) ?? [])
                  .map((entry) => entry?.toString().trim() ?? '')
                  .where((entry) => entry.isNotEmpty)
                  .toList(growable: false),
              activeContract: (station['activeContract'] as String?)?.trim(),
            );
          })
          .where((station) => station.id.isNotEmpty)
          .toList();

      String preselectedId = widget.forceReselect
          ? ''
          : _session.activeStationId;
      if (!widget.forceReselect &&
          preselectedId.isEmpty &&
          activeStation != null) {
        preselectedId = (activeStation['stationId'] as String?) ?? '';
      }

      _StationOption? preselected;
      if (preselectedId.isNotEmpty) {
        for (final station in mappedStations) {
          if (station.id == preselectedId) {
            preselected = station;
            break;
          }
        }
      }

      final persistedActiveContract =
          (activeStation?['activeContract'] as String?)?.trim() ?? '';

      if (mounted) {
        setState(() {
          _stations = mappedStations;
          _selectedStationId = preselected?.id;
          _selectedContract = persistedActiveContract.isNotEmpty
              ? persistedActiveContract
              : preselected?.availableContracts.length == 1
              ? preselected?.availableContracts.first
              : null;
          _isLoading = false;
        });
      }

      if (!widget.forceReselect &&
          mappedStations.length == 1 &&
          mappedStations.first.availableContracts.length <= 1 &&
          mounted) {
        await _continueWithStation(mappedStations.first);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
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
      setState(() => _isLoading = false);
      Get.snackbar(
        'Stations Unavailable',
        'Unable to load the stations right now.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _handleLogout() async {
    await _api.logout();
    if (!mounted) {
      return;
    }
    Get.offAllNamed('/login');
  }

  Future<void> _continueWithStation([_StationOption? station]) async {
    _StationOption? selected = station;
    if (selected == null && _selectedStationId != null) {
      for (final option in _stations) {
        if (option.id == _selectedStationId) {
          selected = option;
          break;
        }
      }
    }

    if (selected == null) {
      Get.snackbar(
        'Station Required',
        'Please select a station first.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_isSubmitting) {
      return;
    }

    final availableContracts = selected.availableContracts;
    final selectedContract = _selectedContract?.trim() ?? '';
    if (availableContracts.isNotEmpty && selectedContract.isEmpty) {
      Get.snackbar(
        'Airline Required',
        'Please select the airline contract you want to sign into.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final activeStation = await _api.selectStation(
        selected.id,
        contract: selectedContract.isEmpty ? null : selectedContract,
      );
      _session.saveActiveStation(activeStation);

      if (!mounted) {
        return;
      }

      Get.offAll(() => const DashboardScreen());
    } on ApiException catch (error) {
      Get.snackbar(
        'Station Selection Failed',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      Get.snackbar(
        'Station Selection Failed',
        'Unable to continue with the selected station.',
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              ParallaxHeroWidget(
                bottomPadding: 220,
                trailingAction: GestureDetector(
                  onTap: _handleLogout,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.30),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Logout',
                          style: GoogleFonts.dmSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                child: Text(
                  'Welcome, $_displayName!',
                  style: GoogleFonts.dmSans(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.8,
                    height: 1.15,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -200),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 30.h),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isLoading
                            ? 'Loading your station access'
                            : _stations.isEmpty
                            ? 'No station assigned yet'
                            : 'Select your airport and airline contract to begin',
                        style: GoogleFonts.dmSans(
                          fontSize: 13.sp,
                          color: Colors.grey.shade500,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      _buildStationList(),
                      if (_selectedStation != null &&
                          _selectedStation!.availableContracts.isNotEmpty) ...[
                        SizedBox(height: 18.h),
                        _buildContractPicker(_selectedStation!),
                      ],
                      SizedBox(height: 16.h),
                      GestureDetector(
                        onTap:
                            (_isLoading ||
                                    _stations.isEmpty ||
                                    _isSubmitting ||
                                    (_selectedStation?.availableContracts
                                                .isNotEmpty ==
                                            true &&
                                        (_selectedContract?.isEmpty ?? true)))
                                ? null
                                : () => _continueWithStation(),
                        child: Container(
                          height: 54.h,
                          width: double.infinity,
                          decoration: BoxDecoration(
                             color: (_isLoading ||
                                     _stations.isEmpty ||
                                     (_selectedStation?.availableContracts
                                                 .isNotEmpty ==
                                             true &&
                                         (_selectedContract?.isEmpty ?? true)))
                                 ? _C.blue.withOpacity(0.45)
                                 : _C.blue,
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                          alignment: Alignment.center,
                          child: _isSubmitting
                              ? SizedBox(
                                  width: 22.w,
                                  height: 22.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'CONTINUE',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                      if (!_isLoading && _stations.isEmpty) ...[
                        SizedBox(height: 14.h),
                        Text(
                          'No station assigned yet. Please contact your administrator.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.sp,
                            color: _C.muted,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Transform.translate(
              //   offset: const Offset(0, -195),
              //   child: _buildHomeIndicator(),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationList() {
    final filtered = _stationQuery.isEmpty
        ? _stations
        : _stations
              .where((s) => s.label.toLowerCase().contains(_stationQuery))
              .toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
      constraints: BoxConstraints(minHeight: 86.h, maxHeight: 320.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: _C.border, width: 1.3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: _C.blue, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Stations',
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: _C.ink,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // ── Search bar ──
          if (_isLoading || _stations.isNotEmpty) ...[
            TextField(
              controller: _searchCtrl,
              style: GoogleFonts.dmSans(fontSize: 13.sp, color: _C.ink),
              decoration: InputDecoration(
                hintText: 'Search station...',
                hintStyle: GoogleFonts.dmSans(fontSize: 13.sp, color: _C.muted),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18.sp,
                  color: _C.muted,
                ),
                suffixIcon: _stationQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16.sp,
                          color: _C.muted,
                        ),
                      )
                    : null,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(color: _C.border, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(color: _C.border, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(color: _C.blue, width: 1.5),
                ),
              ),
            ),
            SizedBox(height: 10.h),
          ],
          if (_isLoading)
            SizedBox(
              height: 52.h,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else if (_stations.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                'No station assigned yet. Please contact your administrator.',
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  color: _C.muted,
                  height: 1.5,
                ),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                'No assigned stations match "${_searchCtrl.text}".',
                style: GoogleFonts.dmSans(fontSize: 13.sp, color: _C.muted),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: filtered
                      .map(
                        (station) => GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedStationId = station.id;
                              _selectedContract =
                                  station.availableContracts.length == 1
                                  ? station.availableContracts.first
                                  : station.activeContract;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              vertical: 14.h,
                              horizontal: 16.w,
                            ),
                            margin: EdgeInsets.only(bottom: 10.h),
                            decoration: BoxDecoration(
                              color: _selectedStationId == station.id
                                  ? _C.blue.withOpacity(0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(
                                color: _selectedStationId == station.id
                                    ? _C.blue.withOpacity(0.45)
                                    : _C.border,
                                width: _selectedStationId == station.id
                                    ? 1.6
                                    : 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40.w,
                                  height: 40.w,
                                  decoration: BoxDecoration(
                                    color: _selectedStationId == station.id
                                        ? _C.blue
                                        : const Color(0xFFEFF3FF),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Icon(
                                    Icons.flight_takeoff_rounded,
                                    color: _selectedStationId == station.id
                                        ? Colors.white
                                        : _C.blue,
                                    size: 18.sp,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Text(
                                    station.label,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14.sp,
                                      color: _selectedStationId == station.id
                                          ? _C.blue
                                          : _C.ink,
                                      fontWeight:
                                          _selectedStationId == station.id
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (_selectedStationId == station.id)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: _C.blue,
                                    size: 20.sp,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
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

  Widget _buildContractPicker(_StationOption station) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: _C.border, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business_center_outlined, color: _C.blue, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Airline Contracts',
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: _C.ink,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'Choose the airline you want to sign into for ${station.label}.',
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: _C.muted,
              height: 1.45,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: station.availableContracts.map((contract) {
              final isSelected = _selectedContract == contract;
              return GestureDetector(
                onTap: () => setState(() => _selectedContract = contract),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isSelected ? _C.blue : Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isSelected ? _C.blue : _C.border,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    contract,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : _C.ink,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
