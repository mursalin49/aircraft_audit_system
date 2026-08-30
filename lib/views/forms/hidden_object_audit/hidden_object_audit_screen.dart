import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:avislap/config/app_permission_codes.dart';
import 'package:avislap/data/seat_map_config.dart' as seat_map_config;
import 'package:avislap/models/pending_upload_file.dart';
import 'package:avislap/services/api_exception.dart';
import 'package:avislap/services/app_api_service.dart';
import 'package:avislap/services/audit_draft_store.dart';
import 'package:avislap/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class _HOColors {
  static const Color primary = Color(0xFF3D5AFE);
  static const Color background = Color(0xFFF5F6FA);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF7B8794);
  static const Color border = Color(0xFFE4E7EF);
  static const Color seat = Color(0xFF9AA5B1);
  static const Color planeGrey = Color(0xFFEDEFF4);
  static const Color orange = Color(0xFFFF9800);
  static const Color blue = Color(0xFF2196F3);
  static const Color green = Color(0xFF22C55E);
  static const Color red = Color(0xFFEF4444);
  static const Color purple = Color(0xFF8B5CF6);
}

class HiddenObjectAuditListItem {
  HiddenObjectAuditListItem({
    required this.id,
    required this.sessionAt,
    required this.auditorName,
    required this.shipNumber,
    required this.aircraftTypeName,
    required this.status,
    required this.total,
    required this.orange,
    required this.blue,
    required this.green,
    required this.red,
    required this.purple,
  });

  final String id;
  final DateTime sessionAt;
  final String auditorName;
  final String shipNumber;
  final String aircraftTypeName;
  final String status;
  final int total;
  final int orange;
  final int blue;
  final int green;
  final int red;
  final int purple;

  factory HiddenObjectAuditListItem.fromMap(Map<String, dynamic> map) {
    final counts = _asMap(map['counts']);
    return HiddenObjectAuditListItem(
      id: map['id']?.toString() ?? '',
      sessionAt:
          DateTime.tryParse(map['sessionAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      auditorName: map['auditorName']?.toString() ?? 'Unknown',
      shipNumber: map['shipNumber']?.toString() ?? '',
      aircraftTypeName: map['aircraftTypeName']?.toString() ?? '',
      status: map['status']?.toString() ?? 'SETUP',
      total: _toInt(counts['total']),
      orange: _toInt(counts['orange']),
      blue: _toInt(counts['blue']),
      green: _toInt(counts['green']),
      red: _toInt(counts['red']),
      purple: _toInt(counts['purple']),
    );
  }
}

class HiddenObjectFleetOption {
  HiddenObjectFleetOption({
    required this.id,
    required this.shipNumber,
    required this.displayName,
    required this.aircraftTypeId,
    required this.aircraftTypeName,
  });

  final String id;
  final String shipNumber;
  final String displayName;
  final String aircraftTypeId;
  final String aircraftTypeName;

  factory HiddenObjectFleetOption.fromMap(Map<String, dynamic> map) {
    final aircraftType = _asMap(map['aircraftType']);
    return HiddenObjectFleetOption(
      id: map['id']?.toString() ?? '',
      shipNumber: map['shipNumber']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      aircraftTypeId: aircraftType['id']?.toString() ?? '',
      aircraftTypeName: aircraftType['name']?.toString() ?? '',
    );
  }
}

class HiddenObjectAircraftOption {
  HiddenObjectAircraftOption({
    required this.id,
    required this.name,
    required this.seatMap,
  });

  final String id;
  final String name;
  final seat_map_config.AircraftSeatMap? seatMap;

  factory HiddenObjectAircraftOption.fromMap(Map<String, dynamic> map) {
    final name = map['name']?.toString() ?? '';
    seat_map_config.AircraftSeatMap? parsedSeatMap;
    final rawSeatMap = map['seatMap'];
    if (rawSeatMap is Map) {
      try {
        parsedSeatMap = seat_map_config.AircraftSeatMap.fromJson(
          Map<String, dynamic>.from(rawSeatMap),
          fallbackName: name,
        );
      } catch (_) {
        parsedSeatMap = seat_map_config.defaultAircraftSeatMaps[name];
      }
    } else {
      parsedSeatMap = seat_map_config.defaultAircraftSeatMaps[name];
    }

    return HiddenObjectAircraftOption(
      id: map['id']?.toString() ?? '',
      name: name,
      seatMap: parsedSeatMap,
    );
  }
}

class HiddenObjectLocation {
  HiddenObjectLocation({
    required this.id,
    required this.locationCode,
    required this.locationLabel,
    required this.sectionLabel,
    required this.locationType,
    required this.status,
    required this.subLocation,
    required this.photoFileIds,
    required this.subLocationOptions,
    required this.foundByName,
  });

  final String id;
  final String locationCode;
  final String locationLabel;
  final String sectionLabel;
  final String locationType;
  final String status;
  final String subLocation;
  final List<String> photoFileIds;
  final List<String> subLocationOptions;
  final String foundByName;

  factory HiddenObjectLocation.fromMap(Map<String, dynamic> map) {
    return HiddenObjectLocation(
      id: map['id']?.toString() ?? '',
      locationCode: map['locationCode']?.toString() ?? '',
      locationLabel: map['locationLabel']?.toString() ?? '',
      sectionLabel: map['sectionLabel']?.toString() ?? '',
      locationType: map['locationType']?.toString() ?? '',
      status: map['status']?.toString() ?? 'ORANGE',
      subLocation: map['subLocation']?.toString() ?? '',
      photoFileIds: _asStringList(map['photoFileIds']),
      subLocationOptions: _asStringList(map['subLocationOptions']),
      foundByName: map['foundByName']?.toString() ?? '',
    );
  }
}

class HiddenObjectAuditDetail {
  HiddenObjectAuditDetail({
    required this.id,
    required this.sessionAt,
    required this.status,
    required this.shipNumber,
    required this.aircraftTypeId,
    required this.aircraftTypeName,
    required this.seatMap,
    required this.auditorName,
    required this.auditorRole,
    required this.objectsToHideCount,
    required this.total,
    required this.orange,
    required this.blue,
    required this.green,
    required this.red,
    required this.purple,
    required this.canActivate,
    required this.canClose,
    required this.locations,
  });

  final String id;
  final DateTime sessionAt;
  final String status;
  final String shipNumber;
  final String aircraftTypeId;
  final String aircraftTypeName;
  final seat_map_config.AircraftSeatMap? seatMap;
  final String auditorName;
  final String auditorRole;
  final int objectsToHideCount;
  final int total;
  final int orange;
  final int blue;
  final int green;
  final int red;
  final int purple;
  final bool canActivate;
  final bool canClose;
  final List<HiddenObjectLocation> locations;

  Map<String, HiddenObjectLocation> get locationMap => {
    for (final location in locations) location.locationCode: location,
  };

  factory HiddenObjectAuditDetail.fromMap(Map<String, dynamic> map) {
    final aircraftType = _asMap(map['aircraftType']);
    final counts = _asMap(map['counts']);
    final aircraftName = aircraftType['name']?.toString() ?? '';
    seat_map_config.AircraftSeatMap? parsedSeatMap;
    final rawSeatMap = aircraftType['seatMap'];
    if (rawSeatMap is Map) {
      try {
        parsedSeatMap = seat_map_config.AircraftSeatMap.fromJson(
          Map<String, dynamic>.from(rawSeatMap),
          fallbackName: aircraftName,
        );
      } catch (_) {
        parsedSeatMap = seat_map_config.defaultAircraftSeatMaps[aircraftName];
      }
    } else {
      parsedSeatMap = seat_map_config.defaultAircraftSeatMaps[aircraftName];
    }

    return HiddenObjectAuditDetail(
      id: map['id']?.toString() ?? '',
      sessionAt:
          DateTime.tryParse(map['sessionAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      status: map['status']?.toString() ?? 'SETUP',
      shipNumber: map['shipNumber']?.toString() ?? '',
      aircraftTypeId: aircraftType['id']?.toString() ?? '',
      aircraftTypeName: aircraftName,
      seatMap: parsedSeatMap,
      auditorName: _asMap(map['auditor'])['name']?.toString() ?? '',
      auditorRole: _asMap(map['auditor'])['role']?.toString() ?? '',
      objectsToHideCount: _toInt(map['objectsToHideCount']),
      total: _toInt(counts['total']),
      orange: _toInt(counts['orange']),
      blue: _toInt(counts['blue']),
      green: _toInt(counts['green']),
      red: _toInt(counts['red']),
      purple: _toInt(counts['purple']),
      canActivate: map['canActivate'] == true,
      canClose: map['canClose'] == true,
      locations: _asListOfMaps(
        map['locations'],
      ).map(HiddenObjectLocation.fromMap).toList(),
    );
  }
}

class HiddenObjectAuditListScreen extends StatefulWidget {
  const HiddenObjectAuditListScreen({super.key});

  @override
  State<HiddenObjectAuditListScreen> createState() =>
      _HiddenObjectAuditListScreenState();
}

class _HiddenObjectAuditListScreenState
    extends State<HiddenObjectAuditListScreen> {
  final AppApiService _api = Get.find<AppApiService>();
  final SessionService _session = Get.find<SessionService>();
  final List<HiddenObjectAuditListItem> _items = <HiddenObjectAuditListItem>[];
  bool _loading = true;

  bool get _canCreateAudit => _session.hasPermission(
    AppPermissionCodes.hiddenObjectAudit,
    action: 'write',
  );

  @override
  void initState() {
    super.initState();
    if (!_session.hasPermission(AppPermissionCodes.hiddenObjectAudit)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Get.offAllNamed('/dashboard');
        Get.snackbar(
          'Access Restricted',
          'Hidden Object Audit is not enabled for your current role.',
          backgroundColor: _HOColors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      });
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.listHiddenObjectAudits(
        queryParameters: {'page': 1, 'limit': 100},
      );
      final items = _asListOfMaps(
        response['items'],
      ).map(HiddenObjectAuditListItem.fromMap).toList();
      setState(() {
        _items
          ..clear()
          ..addAll(items);
      });
    } on ApiException catch (error) {
      Get.snackbar(
        'Hidden Object Audits',
        error.message,
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      Get.snackbar(
        'Hidden Object Audits',
        'Unable to load hidden object audits right now.',
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openWorkflow({String? auditId}) async {
    if (auditId == null && HiddenObjectAuditWorkflowScreen.hasSavedDraft()) {
      final continueDraft =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Draft Found'),
              content: const Text(
                'You already have a saved Hidden Object Audit draft. Do you want to continue it?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Start New'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Continue Draft'),
                ),
              ],
            ),
          ) ??
          false;

      if (continueDraft) {
        await Get.to(
          () => const HiddenObjectAuditWorkflowScreen(restoreDraft: true),
          transition: Transition.rightToLeft,
        );
        await _load();
        return;
      }

      HiddenObjectAuditWorkflowScreen.clearSavedDraft();
    }

    await Get.to(
      () => HiddenObjectAuditWorkflowScreen(auditId: auditId),
      transition: Transition.rightToLeft,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HOColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Hidden Object Audit',
          style: GoogleFonts.dmSans(
            color: _HOColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: _HOColors.textDark),
      ),
      floatingActionButton: _canCreateAudit
          ? FloatingActionButton.extended(
              backgroundColor: _HOColors.primary,
              onPressed: () => _openWorkflow(),
              icon: const Icon(Icons.add),
              label: const Text('New Audit'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: 120.h),
                  Icon(
                    Icons.search_off_rounded,
                    size: 72.sp,
                    color: _HOColors.textMuted,
                  ),
                  SizedBox(height: 16.h),
                  Center(
                    child: Text(
                      'No hidden object audits yet.',
                      style: GoogleFonts.dmSans(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: _HOColors.textDark,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: _items.length,
                separatorBuilder: (_, _) => SizedBox(height: 12.h),
                itemBuilder: (_, index) {
                  final item = _items[index];
                  return GestureDetector(
                    onTap: () => _openWorkflow(auditId: item.id),
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: _HOColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.shipNumber,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _HOColors.textDark,
                                  ),
                                ),
                              ),
                              _statusChip(item.status),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            item.aircraftTypeName,
                            style: GoogleFonts.dmSans(
                              fontSize: 13.sp,
                              color: _HOColors.textMuted,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            '${item.auditorName} - ${DateFormat('MMM d, y - h:mm a').format(item.sessionAt)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12.sp,
                              color: _HOColors.textMuted,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              _metricChip(
                                _statusLabel('ORANGE'),
                                item.orange,
                                _HOColors.orange,
                              ),
                              _metricChip(
                                _statusLabel('BLUE'),
                                item.blue,
                                _HOColors.blue,
                              ),
                              _metricChip(
                                _statusLabel('GREEN'),
                                item.green,
                                _HOColors.green,
                              ),
                              _metricChip(
                                _statusLabel('RED'),
                                item.red,
                                _HOColors.red,
                              ),
                              _metricChip(
                                _statusLabel('PURPLE'),
                                item.purple,
                                _HOColors.purple,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class HiddenObjectAuditWorkflowScreen extends StatefulWidget {
  const HiddenObjectAuditWorkflowScreen({
    super.key,
    this.auditId,
    this.restoreDraft = false,
  });

  final String? auditId;
  final bool restoreDraft;

  static const String draftStorageKey = 'hidden_object_audit_draft';
  static bool hasSavedDraft() => AuditDraftStore.hasDraft(draftStorageKey);
  static void clearSavedDraft() => AuditDraftStore.clearDraft(draftStorageKey);

  @override
  State<HiddenObjectAuditWorkflowScreen> createState() =>
      _HiddenObjectAuditWorkflowScreenState();
}

class _HiddenObjectAuditWorkflowScreenState
    extends State<HiddenObjectAuditWorkflowScreen> {
  final AppApiService _api = Get.find<AppApiService>();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _objectCountCtrl = TextEditingController(
    text: '3',
  );

  final List<HiddenObjectFleetOption> _fleetOptions =
      <HiddenObjectFleetOption>[];
  final List<HiddenObjectAircraftOption> _aircraftOptions =
      <HiddenObjectAircraftOption>[];
  final Set<String> _selectedCreateLocationCodes = <String>{};

  bool _loading = true;
  bool _saving = false;
  bool _manualSelectionEnabled = false;
  String? _selectedShipNumber;
  String? _selectedAircraftTypeId;
  HiddenObjectAuditDetail? _detail;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _persistDraftIfNeeded();
    _objectCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      if (widget.auditId == null) {
        await _loadCreateOptions();
      } else {
        final detail = await _api.getHiddenObjectAudit(widget.auditId!);
        setState(() {
          _detail = HiddenObjectAuditDetail.fromMap(detail);
        });
      }
    } on ApiException catch (error) {
      Get.snackbar(
        'Hidden Object Audit',
        error.message,
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      Get.snackbar(
        'Hidden Object Audit',
        'Unable to load this workflow right now.',
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadCreateOptions() async {
    final fleet = await _api.getFleetAircraft();
    final aircraftTypes = await _api.getAircraftTypes();
    final fleetOptions =
        fleet
            .where((item) => item['isActive'] != false)
            .map(HiddenObjectFleetOption.fromMap)
            .toList()
          ..sort((a, b) => a.shipNumber.compareTo(b.shipNumber));
    final aircraftOptions = aircraftTypes
        .map(HiddenObjectAircraftOption.fromMap)
        .toList();

    setState(() {
      _fleetOptions
        ..clear()
        ..addAll(fleetOptions);
      _aircraftOptions
        ..clear()
        ..addAll(aircraftOptions);
      _selectedShipNumber = _fleetOptions.any(
        (item) => item.shipNumber == _selectedShipNumber,
      )
          ? _selectedShipNumber
          : null;
      _selectedAircraftTypeId = _selectedShipNumber != null
          ? _fleetOptions
                .firstWhereOrNull(
                  (item) => item.shipNumber == _selectedShipNumber,
                )
                ?.aircraftTypeId
          : (_aircraftOptions.any((item) => item.id == _selectedAircraftTypeId)
                ? _selectedAircraftTypeId
                : aircraftOptions.isNotEmpty
                ? aircraftOptions.first.id
                : null);
    });

    if (widget.restoreDraft) {
      _restoreDraft();
    }
  }

  HiddenObjectFleetOption? get _selectedFleet => _fleetOptions.firstWhereOrNull(
    (item) => item.shipNumber == _selectedShipNumber,
  );

  String get _selectedShipDisplayLabel {
    final selectedFleet = _selectedFleet;
    if (selectedFleet == null) {
      return '';
    }

    return selectedFleet.displayName.isEmpty
        ? '${selectedFleet.shipNumber} - ${selectedFleet.aircraftTypeName}'
        : '${selectedFleet.shipNumber} - ${selectedFleet.displayName}';
  }

  List<HiddenObjectAircraftOption> get _availableAircraftOptions {
    final selectedFleet = _selectedFleet;
    if (selectedFleet == null) {
      return _aircraftOptions;
    }

    final matchedOption = _aircraftOptions.firstWhereOrNull(
      (item) => item.id == selectedFleet.aircraftTypeId,
    );
    return matchedOption == null
        ? const <HiddenObjectAircraftOption>[]
        : <HiddenObjectAircraftOption>[matchedOption];
  }

  bool get _hasManualCreateSelection => _selectedCreateLocationCodes.isNotEmpty;
  bool get _isUsingManualCreateSelection =>
      _manualSelectionEnabled && _hasManualCreateSelection;

  seat_map_config.AircraftSeatMap? get _currentSeatMap {
    if (_detail != null) {
      return _detail!.seatMap;
    }

    return _availableAircraftOptions
        .firstWhereOrNull((item) => item.id == _selectedAircraftTypeId)
        ?.seatMap;
  }

  void _clearCreateSelections({bool clearCount = false}) {
    _selectedCreateLocationCodes.clear();
  }

  void _syncObjectCountToSelection() {
    if (_selectedCreateLocationCodes.isEmpty) {
      return;
    }
    _objectCountCtrl.text = _selectedCreateLocationCodes.length.toString();
  }

  void _toggleCreateLocationSelection(String code) {
    setState(() {
      if (_selectedCreateLocationCodes.contains(code)) {
        _selectedCreateLocationCodes.remove(code);
      } else {
        _selectedCreateLocationCodes.add(code);
      }
      _syncObjectCountToSelection();
    });
  }

  void _setManualSelectionEnabled(bool enabled) {
    setState(() {
      _manualSelectionEnabled = enabled;
      if (!enabled) {
        _clearCreateSelections();
      } else {
        _syncObjectCountToSelection();
      }
    });
  }

  void _applySelectedShip(String? shipNumber) {
    final selected = _fleetOptions.firstWhereOrNull(
      (item) => item.shipNumber == shipNumber,
    );

    setState(() {
      _selectedShipNumber = shipNumber;
      if (selected != null) {
        _selectedAircraftTypeId = selected.aircraftTypeId;
      }
      _manualSelectionEnabled = false;
      _clearCreateSelections(clearCount: true);
    });
  }

  Future<void> _openShipNumberPicker() async {
    if (_fleetOptions.isEmpty) {
      return;
    }

    final selectedShip = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShipNumberPickerSheet(
        options: _fleetOptions,
        selectedShipNumber: _selectedShipNumber,
      ),
    );

    if (selectedShip == null || selectedShip == _selectedShipNumber) {
      return;
    }

    _applySelectedShip(selectedShip);
  }

  Future<void> _createAudit() async {
    final shipNumber = _selectedShipNumber?.trim() ?? '';
    final aircraftTypeId = _selectedAircraftTypeId?.trim() ?? '';
    final objectCount = _isUsingManualCreateSelection
        ? _selectedCreateLocationCodes.length
        : int.tryParse(_objectCountCtrl.text.trim()) ?? 0;

    if (_manualSelectionEnabled && !_hasManualCreateSelection) {
      Get.snackbar(
        'Create Audit',
        'Tap at least one seat or zone, or turn off manual selection to keep random generation.',
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (shipNumber.isEmpty || aircraftTypeId.isEmpty || objectCount <= 0) {
      Get.snackbar(
        'Create Audit',
        'Select ship number, aircraft type, and a valid object count.',
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
      return;
    }

    final selectedFleet = _selectedFleet;
    if (selectedFleet != null &&
        selectedFleet.aircraftTypeId != aircraftTypeId) {
      setState(() => _selectedAircraftTypeId = selectedFleet.aircraftTypeId);
      Get.snackbar(
        'Aircraft Type Updated',
        'Aircraft type was reset to ${selectedFleet.aircraftTypeName} to match ship ${selectedFleet.shipNumber}.',
        backgroundColor: _HOColors.primary,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final response = await _api.createHiddenObjectAudit({
        'shipNumber': shipNumber,
        'aircraftTypeId': aircraftTypeId,
        'numberOfObjectsToHide': objectCount,
        if (_isUsingManualCreateSelection)
          'selectedLocationCodes': _selectedCreateLocationCodes.toList(),
      });
      setState(() {
        _detail = HiddenObjectAuditDetail.fromMap(response);
      });
      HiddenObjectAuditWorkflowScreen.clearSavedDraft();
      Get.snackbar(
        'Audit Created',
        _isUsingManualCreateSelection
            ? 'Your selected hide locations are ready. Tap each pre-selected location to confirm the hiding point.'
            : 'Targets generated. Tap each pre-selected location to confirm the hiding point.',
        backgroundColor: _HOColors.green,
        colorText: Colors.white,
      );
    } on ApiException catch (error) {
      final selectedFleet = _selectedFleet;
      final errorMessage =
          error.message ==
              'Selected aircraft type does not match the fleet registry for this ship number'
          ? selectedFleet == null
                ? 'The selected ship has a different aircraft type in the fleet registry. Please reselect the ship and try again.'
                : 'Ship ${selectedFleet.shipNumber} is registered as ${selectedFleet.aircraftTypeName}. The form has been aligned to that aircraft type.'
          : error.message;

      if (error.message ==
          'Selected aircraft type does not match the fleet registry for this ship number') {
        setState(() {
          _selectedAircraftTypeId = selectedFleet?.aircraftTypeId;
        });
      }

      Get.snackbar(
        'Create Audit',
        errorMessage,
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _refreshDetail() async {
    if (_detail == null) {
      return;
    }
    final response = await _api.getHiddenObjectAudit(_detail!.id);
    setState(() {
      _detail = HiddenObjectAuditDetail.fromMap(response);
    });
  }

  Future<void> _activateAudit() async {
    if (_detail == null) return;
    setState(() => _saving = true);
    try {
      final response = await _api.activateHiddenObjectAudit(_detail!.id);
      setState(() {
        _detail = HiddenObjectAuditDetail.fromMap(response);
      });
      Get.snackbar(
        'Audit Active',
        'Agents can now begin searching. Hidden locations will move to Pass or Fail.',
        backgroundColor: _HOColors.green,
        colorText: Colors.white,
      );
    } on ApiException catch (error) {
      Get.snackbar(
        'Activate Audit',
        error.message,
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _showLocationSheet(HiddenObjectLocation location) async {
    if (_detail == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationActionSheet(
        auditId: _detail!.id,
        auditStatus: _detail!.status,
        location: location,
        api: _api,
        picker: _picker,
        onUpdated: (detailMap) {
          setState(() {
            _detail = HiddenObjectAuditDetail.fromMap(detailMap);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      backgroundColor: _HOColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          detail == null ? 'Create Hidden Object Audit' : detail.shipNumber,
          style: GoogleFonts.dmSans(
            color: _HOColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: _HOColors.textDark),
        actions: detail == null
            ? [
                IconButton(
                  onPressed: _saveDraftManually,
                  icon: const Icon(Icons.save_outlined),
                ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
          ? _buildCreateView()
          : RefreshIndicator(
              onRefresh: _refreshDetail,
              child: ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  _buildSummaryCard(detail),
                  SizedBox(height: 12.h),
                  _buildActionCard(detail),
                  SizedBox(height: 12.h),
                  // _buildLegendCard(),
                  SizedBox(height: 12.h),
                  if (detail.seatMap != null)
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(color: _HOColors.border),
                      ),
                      child: _HiddenObjectSeatMap(
                        seatMap: detail.seatMap!,
                        locationsByCode: detail.locationMap,
                        onLocationTap: _showLocationSheet,
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(color: _HOColors.border),
                      ),
                      child: Text(
                        'Seat map configuration is unavailable for this aircraft type.',
                        style: GoogleFonts.dmSans(
                          color: _HOColors.textMuted,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  SizedBox(height: 12.h),
                  ...detail.locations.map(
                    (location) => Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: GestureDetector(
                        onTap: () => _showLocationSheet(location),
                        child: Container(
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: _HOColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 12.w,
                                height: 12.w,
                                decoration: BoxDecoration(
                                  color: _statusColor(location.status),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      location.locationLabel,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: _HOColors.textDark,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      [
                                        location.sectionLabel,
                                        if (location.subLocation.isNotEmpty)
                                          location.subLocation,
                                      ].join(' - '),
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12.sp,
                                        color: _HOColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _statusChip(location.status),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCreateView() {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: _HOColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Audit Session',
                style: GoogleFonts.dmSans(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: _HOColors.textDark,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Choose a ship, confirm the aircraft type, and generate hiding targets. You can leave it random or tap the seat map to pick locations yourself.',
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  color: _HOColors.textMuted,
                ),
              ),
              SizedBox(height: 18.h),
              _fieldLabel('Ship # *'),
              SizedBox(height: 8.h),
              InkWell(
                onTap: _openShipNumberPicker,
                borderRadius: BorderRadius.circular(14.r),
                child: InputDecorator(
                  decoration: _inputDecoration(
                    hintText: 'Search and select ship number',
                    suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  child: Text(
                    _selectedShipDisplayLabel.isNotEmpty
                        ? _selectedShipDisplayLabel
                        : 'Search and select ship number',
                    style: GoogleFonts.dmSans(
                      fontSize: 14.sp,
                      color: _selectedShipDisplayLabel.isNotEmpty
                          ? _HOColors.textDark
                          : _HOColors.textMuted,
                      fontWeight: _selectedShipDisplayLabel.isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              _fieldLabel('Aircraft Type'),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value:
                    _availableAircraftOptions.any(
                      (item) => item.id == _selectedAircraftTypeId,
                    )
                    ? _selectedAircraftTypeId
                    : null,
                decoration: _inputDecoration(),
                items: _availableAircraftOptions
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: _selectedFleet == null
                    ? (value) => setState(() {
                        _selectedAircraftTypeId = value;
                        _manualSelectionEnabled = false;
                        _clearCreateSelections(clearCount: true);
                      })
                    : null,
              ),
              if (_selectedFleet != null) ...[
                SizedBox(height: 8.h),
                Text(
                  'Aircraft type is locked to the fleet registry for this ship.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: _HOColors.textMuted,
                  ),
                ),
              ],
              SizedBox(height: 16.h),
              _fieldLabel('Number of Objects to Hide'),
              SizedBox(height: 8.h),
              TextField(
                controller: _objectCountCtrl,
                readOnly: _manualSelectionEnabled,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  hintText: _manualSelectionEnabled
                      ? 'Count follows your selected seats'
                      : 'Enter a whole number',
                ),
              ),
              if (_selectedFleet != null) ...[
                SizedBox(height: 14.h),
                Text(
                  'Registry match: ${_selectedFleet!.shipNumber} uses ${_selectedFleet!.aircraftTypeName}.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _HOColors.primary,
                  ),
                ),
              ],
              if (_currentSeatMap != null) ...[
                SizedBox(height: 18.h),
                Text(
                  'Seat map preview',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: _HOColors.textDark,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: _HOColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose exact locations manually',
                              style: GoogleFonts.dmSans(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: _HOColors.textDark,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Keep this off to follow the original random-target flow.',
                              style: GoogleFonts.dmSans(
                                fontSize: 12.sp,
                                color: _HOColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _manualSelectionEnabled,
                        activeThumbColor: _HOColors.primary,
                        onChanged: _setManualSelectionEnabled,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _manualSelectionEnabled
                      ? _hasManualCreateSelection
                            ? 'Tap a highlighted location again to remove it. The object count is synced to your manual selection.'
                            : 'Tap seats or cabin zones to choose the exact hiding locations for this audit.'
                      : 'Preview only. Turn on manual selection if you want to choose the seats yourself.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    color: _HOColors.textMuted,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: _HOColors.border),
                  ),
                  child: _HiddenObjectSeatMap(
                    seatMap: _currentSeatMap!,
                    locationsByCode: const <String, HiddenObjectLocation>{},
                    onLocationTap: (_) {},
                    selectedLocationCodes: _selectedCreateLocationCodes,
                    onSelectableLocationTap: _manualSelectionEnabled
                        ? _toggleCreateLocationSelection
                        : null,
                  ),
                ),
                if (_manualSelectionEnabled && _hasManualCreateSelection) ...[
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedCreateLocationCodes.length} manual location${_selectedCreateLocationCodes.length == 1 ? '' : 's'} selected',
                          style: GoogleFonts.dmSans(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: _HOColors.primary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(
                          () => _clearCreateSelections(clearCount: true),
                        ),
                        child: Text(
                          'Clear',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            color: _HOColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: (_selectedCreateLocationCodes.toList()..sort())
                        .map(
                          (code) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: _HOColors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              code,
                              style: GoogleFonts.dmSans(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: _HOColors.orange,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
              SizedBox(height: 20.h),
              SizedBox(
                height: 52.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _HOColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  onPressed: _saving ? null : _createAudit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Generate Targets',
                          style: GoogleFonts.dmSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasDraftContent() {
    if (widget.auditId != null || _detail != null) {
      return false;
    }

    return (_selectedShipNumber?.trim().isNotEmpty ?? false) ||
        (_selectedAircraftTypeId?.trim().isNotEmpty ?? false) ||
        _objectCountCtrl.text.trim() != '3' ||
        _manualSelectionEnabled ||
        _selectedCreateLocationCodes.isNotEmpty;
  }

  void _persistDraftIfNeeded() {
    if (_saving || widget.auditId != null || _detail != null) {
      return;
    }

    if (!_hasDraftContent()) {
      HiddenObjectAuditWorkflowScreen.clearSavedDraft();
      return;
    }

    AuditDraftStore.saveDraft(
      id: HiddenObjectAuditWorkflowScreen.draftStorageKey,
      type: AuditDraftType.hiddenObjectAudit,
      title: 'Hidden Object Audit',
      subtitle: 'Resume the hidden object setup and selected target locations.',
      shipNumber: _selectedShipNumber?.trim(),
      payload: {
        'savedAt': DateTime.now().toIso8601String(),
        'selectedShipNumber': _selectedShipNumber,
        'selectedAircraftTypeId': _selectedAircraftTypeId,
        'objectCount': _objectCountCtrl.text.trim(),
        'manualSelectionEnabled': _manualSelectionEnabled,
        'selectedCreateLocationCodes': _selectedCreateLocationCodes.toList(),
      },
    );
  }

  void _restoreDraft() {
    final draft = AuditDraftStore.getPayload(
      HiddenObjectAuditWorkflowScreen.draftStorageKey,
    );
    if (draft == null || draft.isEmpty) {
      return;
    }

    final draftShipNumber = draft['selectedShipNumber']?.toString().trim();
    if (draftShipNumber != null &&
        _fleetOptions.any((item) => item.shipNumber == draftShipNumber)) {
      _selectedShipNumber = draftShipNumber;
    }

    final draftAircraftTypeId = draft['selectedAircraftTypeId']
        ?.toString()
        .trim();
    if (draftAircraftTypeId != null &&
        _aircraftOptions.any((item) => item.id == draftAircraftTypeId)) {
      _selectedAircraftTypeId = draftAircraftTypeId;
    }

    final objectCount = draft['objectCount']?.toString().trim() ?? '';
    if (objectCount.isNotEmpty) {
      _objectCountCtrl.text = objectCount;
    }

    _manualSelectionEnabled = draft['manualSelectionEnabled'] == true;
    _selectedCreateLocationCodes
      ..clear()
      ..addAll(_readStringList(draft['selectedCreateLocationCodes']));

    if (_manualSelectionEnabled && _selectedCreateLocationCodes.isNotEmpty) {
      _syncObjectCountToSelection();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      Get.snackbar(
        'Draft Restored',
        'Your Hidden Object Audit draft is ready to continue.',
        backgroundColor: _HOColors.primary,
        colorText: Colors.white,
      );
    });
  }

  List<String> _readStringList(dynamic raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  void _saveDraftManually() {
    _persistDraftIfNeeded();
    if (!HiddenObjectAuditWorkflowScreen.hasSavedDraft()) {
      Get.snackbar(
        'Nothing To Save',
        'Choose a ship or target setup first, then save the draft.',
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
      return;
    }

    Get.snackbar(
      'Draft Saved',
      'Hidden Object Audit draft saved successfully.',
      backgroundColor: _HOColors.primary,
      colorText: Colors.white,
    );
  }

  Widget _buildSummaryCard(HiddenObjectAuditDetail detail) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _HOColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${detail.shipNumber} - ${detail.aircraftTypeName}',
                  style: GoogleFonts.dmSans(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: _HOColors.textDark,
                  ),
                ),
              ),
              _statusChip(detail.status),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '${detail.auditorName} - ${detail.auditorRole}',
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              color: _HOColors.textMuted,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            DateFormat('MMM d, y - h:mm a').format(detail.sessionAt),
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: _HOColors.textMuted,
            ),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _metricChip(
                _statusLabel('ORANGE'),
                detail.orange,
                _HOColors.orange,
              ),
              _metricChip(_statusLabel('BLUE'), detail.blue, _HOColors.blue),
              _metricChip(_statusLabel('GREEN'), detail.green, _HOColors.green),
              _metricChip(_statusLabel('RED'), detail.red, _HOColors.red),
              _metricChip(
                _statusLabel('PURPLE'),
                detail.purple,
                _HOColors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(HiddenObjectAuditDetail detail) {
    final message = detail.status == 'SETUP'
        ? 'Tap each pre-selected location, choose a sub-location, and upload a hiding photo.'
        : detail.status == 'ACTIVE'
        ? 'Hidden locations are now searched from Cabin Security Search Training. This screen stays in setup and status mode only.'
        : 'This audit is closed. Pass means found, Fail means not found, and Ad-hoc means an object was found in another location.';

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _HOColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              color: _HOColors.textMuted,
            ),
          ),
          if (detail.canActivate) ...[
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _HOColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    onPressed: _saving ? null : _activateAudit,
                    child: Text(
                      'Start Live Audit',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Widget _buildLegendCard() {
  //   return Container(
  //     padding: EdgeInsets.all(16.w),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(18.r),
  //       border: Border.all(color: _HOColors.border),
  //     ),
  //     child: Wrap(
  //       spacing: 12.w,
  //       runSpacing: 12.h,
  //       children: [
  //         _legendItem(_statusLabel('ORANGE'), _HOColors.orange),
  //         _legendItem(_statusLabel('BLUE'), _HOColors.blue),
  //         _legendItem(_statusLabel('GREEN'), _HOColors.green),
  //         _legendItem(_statusLabel('RED'), _HOColors.red),
  //         _legendItem(_statusLabel('PURPLE'), _HOColors.purple),
  //       ],
  //     ),
  //   );
  // }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6.w),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            color: _HOColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: _HOColors.textDark,
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: _HOColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: _HOColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: _HOColors.primary),
      ),
    );
  }
}

class _ShipNumberPickerSheet extends StatefulWidget {
  const _ShipNumberPickerSheet({
    required this.options,
    required this.selectedShipNumber,
  });

  final List<HiddenObjectFleetOption> options;
  final String? selectedShipNumber;

  @override
  State<_ShipNumberPickerSheet> createState() => _ShipNumberPickerSheetState();
}

class _ShipNumberPickerSheetState extends State<_ShipNumberPickerSheet> {
  late final TextEditingController _searchCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HiddenObjectFleetOption> get _filteredOptions {
    if (_query.isEmpty) {
      return widget.options;
    }

    return widget.options.where((item) {
      final haystack =
          '${item.shipNumber} ${item.displayName} ${item.aircraftTypeName}'
              .toLowerCase();
      return haystack.contains(_query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: _HOColors.border,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Select Ship #',
                style: GoogleFonts.dmSans(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: _HOColors.textDark,
                ),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (value) => setState(() {
                  _query = value.trim().toLowerCase();
                }),
                decoration: InputDecoration(
                  hintText: 'Search ship number or aircraft',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: const BorderSide(color: _HOColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: const BorderSide(color: _HOColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: const BorderSide(color: _HOColors.primary),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: _filteredOptions.isEmpty
                    ? Center(
                        child: Text(
                          'No ship found for this search.',
                          style: GoogleFonts.dmSans(
                            fontSize: 14.sp,
                            color: _HOColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredOptions.length,
                        separatorBuilder: (_, _) => SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final item = _filteredOptions[index];
                          final isSelected =
                              item.shipNumber == widget.selectedShipNumber;
                          final subtitle = item.displayName.isEmpty
                              ? item.aircraftTypeName
                              : '${item.displayName} - ${item.aircraftTypeName}';

                          return InkWell(
                            borderRadius: BorderRadius.circular(16.r),
                            onTap: () =>
                                Navigator.of(context).pop(item.shipNumber),
                            child: Container(
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _HOColors.primary.withOpacity(0.08)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: isSelected
                                      ? _HOColors.primary
                                      : _HOColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.shipNumber,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w700,
                                            color: _HOColors.textDark,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          subtitle,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 12.sp,
                                            color: _HOColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: _HOColors.primary,
                                      size: 20.sp,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationActionSheet extends StatefulWidget {
  const _LocationActionSheet({
    required this.auditId,
    required this.auditStatus,
    required this.location,
    required this.api,
    required this.picker,
    required this.onUpdated,
  });

  final String auditId;
  final String auditStatus;
  final HiddenObjectLocation location;
  final AppApiService api;
  final ImagePicker picker;
  final ValueChanged<Map<String, dynamic>> onUpdated;

  @override
  State<_LocationActionSheet> createState() => _LocationActionSheetState();
}

class _LocationActionSheetState extends State<_LocationActionSheet> {
  late String _selectedSubLocation;
  late List<String> _photoFileIds;
  PendingUploadFile? _pendingPhotoUpload;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _selectedSubLocation = widget.location.subLocation.isNotEmpty
        ? widget.location.subLocation
        : widget.location.subLocationOptions.isNotEmpty
        ? widget.location.subLocationOptions.first
        : '';
    _photoFileIds = List<String>.from(widget.location.photoFileIds);
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picked = await widget.picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null) {
        return;
      }

      final pendingUpload = PendingUploadFile(localFile: File(picked.path));
      setState(() {
        _pendingPhotoUpload = pendingUpload;
        _photoFileIds = <String>[];
      });
      unawaited(_uploadSelectedPhoto(pendingUpload));
    } on ApiException catch (error) {
      Get.snackbar(
        'Upload Photo',
        error.message,
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _uploadSelectedPhoto(PendingUploadFile upload) async {
    setState(() {
      upload.status = PendingUploadStatus.uploading;
      upload.progress = 0;
      upload.errorMessage = null;
    });

    try {
      final uploaded = await widget.api.uploadFile(
        upload.localFile,
        category: 'IMAGE',
        skipCompression: true,
        onSendProgress: (sent, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            upload.progress = total <= 0 ? 0 : sent / total;
          });
        },
      );
      final fileId = uploaded['id']?.toString().trim() ?? '';
      if (fileId.isEmpty) {
        throw const ApiException('Photo upload did not return a file id.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        upload.fileId = fileId;
        upload.cloudinaryUrl = uploaded['cloudinaryUrl']?.toString().trim();
        upload.progress = 1;
        upload.status = PendingUploadStatus.completed;
        _photoFileIds = <String>[fileId];
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        upload.status = PendingUploadStatus.failed;
        upload.errorMessage = error.message;
      });
      Get.snackbar(
        'Upload Photo',
        error.message,
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _confirmLocation() async {
    if (_selectedSubLocation.trim().isEmpty) {
      Get.snackbar(
        'Confirm Location',
        'Choose a sub-location first.',
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_pendingPhotoUpload?.isUploading == true) {
      Get.snackbar(
        'Photo Uploading',
        'Please wait for the photo upload to finish first.',
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_pendingPhotoUpload?.hasError == true || _photoFileIds.isEmpty) {
      Get.snackbar(
        'Confirm Location',
        'Capture a photo and let it finish uploading first.',
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isConfirming = true);
    try {
      final response = await widget.api.confirmHiddenObjectLocation(
        auditId: widget.auditId,
        locationId: widget.location.id,
        payload: {
          'subLocation': _selectedSubLocation,
          'photoFileIds': _photoFileIds,
        },
      );
      widget.onUpdated(response);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      Get.snackbar(
        'Confirm Location',
        error.message,
        backgroundColor: _HOColors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageHeaders = widget.api.buildImageHeaders();
    final photoUrls = _pendingPhotoUpload != null
        ? <String>[]
        : _photoFileIds
              .map(widget.api.buildFileContentUrl)
              .toList(growable: false);
    final isUploadingPhoto = _pendingPhotoUpload?.isUploading == true;
    final hasUploadError = _pendingPhotoUpload?.hasError == true;
    final uploadProgress = _pendingPhotoUpload?.progress ?? 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16.w,
        16.h,
        16.w,
        MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
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
                color: _HOColors.border,
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.location.locationLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: _HOColors.textDark,
                  ),
                ),
              ),
              _statusChip(widget.location.status),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            widget.location.sectionLabel,
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              color: _HOColors.textMuted,
            ),
          ),
          SizedBox(height: 16.h),
          if (widget.auditStatus == 'SETUP') ...[
            Text(
              'Sub-location',
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: _HOColors.textDark,
              ),
            ),
            SizedBox(height: 8.h),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _selectedSubLocation.isEmpty ? null : _selectedSubLocation,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: _HOColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: _HOColors.border),
                ),
              ),
              items: widget.location.subLocationOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedSubLocation = value ?? ''),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isConfirming ? null : _pickAndUploadPhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(
                      _photoFileIds.isEmpty ? 'Capture Photo' : 'Replace Photo',
                    ),
                  ),
                ),
              ],
            ),
            if (_pendingPhotoUpload != null) ...[
              SizedBox(height: 12.h),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Image.file(
                      _pendingPhotoUpload!.localFile,
                      width: 90.w,
                      height: 90.h,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (isUploadingPhoto || hasUploadError)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Center(
                          child: isUploadingPhoto
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value:
                                            uploadProgress > 0 &&
                                                uploadProgress < 1
                                            ? uploadProgress
                                            : null,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Text(
                                      uploadProgress > 0
                                          ? '${(uploadProgress * 100).round()}%'
                                          : 'Uploading',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : IconButton(
                                  onPressed: () => _uploadSelectedPhoto(
                                    _pendingPhotoUpload!,
                                  ),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
              if (isUploadingPhoto) ...[
                SizedBox(height: 10.h),
                Text(
                  'Uploading hiding photo in the background...',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    color: _HOColors.textMuted,
                  ),
                ),
              ] else if (hasUploadError) ...[
                SizedBox(height: 10.h),
                Text(
                  _pendingPhotoUpload?.errorMessage?.trim().isNotEmpty == true
                      ? _pendingPhotoUpload!.errorMessage!.trim()
                      : 'Photo upload failed. Tap retry on the image.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    color: _HOColors.red,
                  ),
                ),
              ],
            ] else if (photoUrls.isNotEmpty) ...[
              SizedBox(height: 12.h),
              SizedBox(
                height: 90.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photoUrls.length,
                  separatorBuilder: (_, _) => SizedBox(width: 8.w),
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Image.network(
                      photoUrls[index],
                      width: 90.w,
                      height: 90.h,
                      fit: BoxFit.cover,
                      headers: imageHeaders,
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _HOColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: _isConfirming || isUploadingPhoto
                    ? null
                    : _confirmLocation,
                child: _isConfirming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Confirm Hiding Location',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ] else if (widget.auditStatus == 'ACTIVE' &&
              widget.location.status == 'BLUE') ...[
            if (widget.location.subLocation.isEmpty)
              Text(
                'Agents are searching this location from Cabin Security Search Training.',
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  color: _HOColors.textMuted,
                ),
              )
            else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Agents are searching ',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        color: _HOColors.textMuted,
                      ),
                    ),
                    TextSpan(
                      text: widget.location.subLocation.replaceAll(
                        ' ',
                        '\u00A0',
                      ),
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: _HOColors.primary,
                      ),
                    ),
                    TextSpan(
                      text: ' from Cabin Security Search Training.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        color: _HOColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            Text(
              widget.location.status == 'PURPLE'
                  ? 'An object was found here even though this location was not assigned.'
                  : widget.location.subLocation.isEmpty
                  ? 'No extra details were recorded for this location.'
                  : 'Sub-location: ${widget.location.subLocation}',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                color: _HOColors.textMuted,
              ),
            ),
            if (widget.location.foundByName.isNotEmpty) ...[
              SizedBox(height: 10.h),
              Text(
                'Found by ${widget.location.foundByName}',
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  color: _HOColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _HiddenObjectSeatMap extends StatelessWidget {
  const _HiddenObjectSeatMap({
    required this.seatMap,
    required this.locationsByCode,
    required this.onLocationTap,
    this.selectedLocationCodes = const <String>{},
    this.onSelectableLocationTap,
  });

  final seat_map_config.AircraftSeatMap seatMap;
  final Map<String, HiddenObjectLocation> locationsByCode;
  final ValueChanged<HiddenObjectLocation> onLocationTap;
  final Set<String> selectedLocationCodes;
  final ValueChanged<String>? onSelectableLocationTap;

  @override
  Widget build(BuildContext context) {
    final planeWidth = 330.w;
    return SizedBox(
      width: planeWidth,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: Column(
              children: [
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 0.95,
                    child: Image.asset(
                      'assets/images/nose.png',
                      width: planeWidth * 1.08,
                      fit: BoxFit.fitWidth,
                      color: _HOColors.planeGrey,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: planeWidth,
                    color: _HOColors.planeGrey,
                  ),
                ),
                ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: 0.90,
                    child: Image.asset(
                      'assets/images/tail.png',
                      width: planeWidth * 1.06,
                      fit: BoxFit.fitWidth,
                      color: _HOColors.planeGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: BoxConstraints(minHeight: planeWidth * 2.0),
            child: Column(
              children: [
                SizedBox(height: 110.h),
                _buildCockpitWindows(),
                SizedBox(height: 100.h),
                ...seatMap.sections.map(_buildSection),
                SizedBox(height: 320.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCockpitWindows() {
    const windowCount = 6;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(windowCount, (index) {
        final indexOffset = index - (windowCount - 1) / 2;
        final angle = indexOffset * 0.25;
        final yOffset = math.pow(indexOffset.abs(), 2) * 4;
        return Transform.translate(
          offset: Offset(0, yOffset.toDouble()),
          child: Transform.rotate(
            angle: angle,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              width: 24.w,
              height: 18.h,
              decoration: BoxDecoration(
                color: const Color(0xFF5D6E7E),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSection(seat_map_config.SeatSection section) {
    return Column(
      children: [
        if (section.amenitiesBefore != null)
          ...section.amenitiesBefore!.map(
            (amenity) =>
                amenity.customLabel != null && amenity.customLabel!.isNotEmpty
                ? _buildCustomAmenityRow(amenity)
                : _buildAmenityRow(amenity),
          ),
        if (section.hasExitBefore) _buildExitRow(),
        SizedBox(height: 4.h),
        if (section.name.isNotEmpty) _buildSectionLabel(section.name),
        SizedBox(height: 4.h),
        _buildColHeaders([...section.leftCols, '', ...section.rightCols]),
        SizedBox(height: 4.h),
        ...List.generate(section.endRow - section.startRow + 1, (index) {
          final row = section.startRow + index;
          final skipRow = section.skipRows?.contains(row) == true;
          return _buildSeatRow(
            rowNum: row,
            leftCols: skipRow
                ? List.filled(section.leftCols.length, '')
                : section.leftCols,
            rightCols: section.rightCols,
          );
        }),
        if (section.amenitiesAfter != null)
          ...section.amenitiesAfter!.map(
            (amenity) =>
                amenity.customLabel != null && amenity.customLabel!.isNotEmpty
                ? _buildCustomAmenityRow(amenity)
                : _buildAmenityRow(amenity),
          ),
        SizedBox(height: 16.h),
        if (section.hasExitAfter) _buildExitRow(),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
        color: _HOColors.textDark,
      ),
    );
  }

  Widget _buildColHeaders(List<String> cols) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: cols
            .map(
              (value) => value.isEmpty
                  ? SizedBox(width: 28.w)
                  : SizedBox(
                      width: 34.w,
                      child: Center(
                        child: Text(
                          value,
                          style: GoogleFonts.dmSans(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: _HOColors.textMuted,
                          ),
                        ),
                      ),
                    ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSeatRow({
    required int rowNum,
    required List<String> leftCols,
    required List<String> rightCols,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...leftCols.map(
            (col) =>
                col.isEmpty ? SizedBox(width: 34.w) : _buildSeat('$rowNum$col'),
          ),
          SizedBox(
            width: 28.w,
            child: Center(
              child: Text(
                '$rowNum',
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: _HOColors.textMuted,
                ),
              ),
            ),
          ),
          ...rightCols.map(
            (col) =>
                col.isEmpty ? SizedBox(width: 34.w) : _buildSeat('$rowNum$col'),
          ),
        ],
      ),
    );
  }

  Widget _buildSeat(String code) {
    final location = locationsByCode[code];
    final isSelected = selectedLocationCodes.contains(code);
    final color = location != null
        ? _statusColor(location.status)
        : isSelected
        ? _HOColors.orange
        : _HOColors.seat;
    return GestureDetector(
      onTap: location != null
          ? () => onLocationTap(location)
          : onSelectableLocationTap == null
          ? null
          : () => onSelectableLocationTap!(code),
      child: Container(
        width: 30.w,
        height: 32.h,
        margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
        child: CustomPaint(painter: _SeatPainter(color: color)),
      ),
    );
  }

  Widget _buildAmenityRow(seat_map_config.AmenityRow amenity) {
    if (amenity.centerOnly) {
      final location = locationsByCode[amenity.effectiveAmenityId];
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: _buildAmenityBox(
          id: amenity.effectiveAmenityId,
          asset: amenity.effectiveSvgAsset,
          location: location,
        ),
      );
    }

    final leftLocation = amenity.leftId == null
        ? null
        : locationsByCode[amenity.leftId];
    final rightLocation = amenity.rightId == null
        ? null
        : locationsByCode[amenity.rightId];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 40.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (amenity.leftId != null && amenity.leftSvg != null)
            _buildAmenityBox(
              id: amenity.leftId!,
              asset: amenity.leftSvg!,
              location: leftLocation,
            )
          else
            SizedBox(width: 46.w),
          if (amenity.rightId != null && amenity.rightSvg != null)
            _buildAmenityBox(
              id: amenity.rightId!,
              asset: amenity.rightSvg!,
              location: rightLocation,
            )
          else
            SizedBox(width: 46.w),
        ],
      ),
    );
  }

  Widget _buildExitRow() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 40.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '< Exit',
            style: GoogleFonts.dmSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: _HOColors.textMuted,
            ),
          ),
          Text(
            'Exit >',
            style: GoogleFonts.dmSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: _HOColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAmenityRow(seat_map_config.AmenityRow amenity) {
    final location = locationsByCode[amenity.effectiveAmenityId];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 40.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            amenity.customLabel ?? amenity.effectiveAmenityId,
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: _HOColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          _buildAmenityBox(
            id: amenity.effectiveAmenityId,
            asset: amenity.effectiveSvgAsset,
            location: location,
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityBox({
    required String id,
    required String asset,
    required HiddenObjectLocation? location,
  }) {
    final isSelected = selectedLocationCodes.contains(id);
    final color = location != null
        ? _statusColor(location.status)
        : isSelected
        ? _HOColors.orange
        : _HOColors.seat;
    return GestureDetector(
      onTap: location != null
          ? () => onLocationTap(location)
          : onSelectableLocationTap == null
          ? null
          : () => onSelectableLocationTap!(id),
      child: Container(
        width: 44.w,
        height: 44.h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Center(
          child: SvgPicture.asset(
            asset,
            width: 22.sp,
            height: 22.sp,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

class _SeatPainter extends CustomPainter {
  const _SeatPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final width = size.width;
    final height = size.height;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height * 0.58),
        const Radius.circular(5),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-1, height * 0.55, width + 2, height * 0.38),
        const Radius.circular(4),
      ),
      paint,
    );

    final armPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-3, height * 0.25, 4, height * 0.45),
        const Radius.circular(2),
      ),
      armPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width - 1, height * 0.25, 4, height * 0.45),
        const Radius.circular(2),
      ),
      armPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SeatPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

Widget _statusChip(String status) {
  final color = _statusColor(status);
  final label = _statusLabel(status);
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
    decoration: BoxDecoration(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20.r),
    ),
    child: Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

Widget _metricChip(String label, int value, Color color) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20.r),
    ),
    child: Text(
      '$label: $value',
      style: GoogleFonts.dmSans(
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

String _statusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'ORANGE':
      return 'Pre-selected';
    case 'BLUE':
      return 'Hidden';
    case 'GREEN':
    case 'PASS':
      return 'Pass';
    case 'RED':
    case 'FAIL':
      return 'Fail';
    case 'PURPLE':
    case 'AD_HOC':
    case 'AD-HOC':
      return 'Ad-hoc';
    case 'SETUP':
      return 'Setup';
    case 'ACTIVE':
      return 'Active';
    case 'CLOSED':
      return 'Closed';
    default:
      return status;
  }
}

Color _statusColor(String status) {
  switch (status.toUpperCase()) {
    case 'ORANGE':
    case 'SETUP':
      return _HOColors.orange;
    case 'BLUE':
    case 'ACTIVE':
      return _HOColors.blue;
    case 'GREEN':
    case 'PASS':
      return _HOColors.green;
    case 'RED':
    case 'CLOSED':
    case 'FAIL':
      return _HOColors.red;
    case 'PURPLE':
      return _HOColors.purple;
    default:
      return _HOColors.seat;
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value.map(_asMap).toList();
}

List<String> _asStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((entry) => entry.toString().trim())
      .where((entry) => entry.isNotEmpty)
      .toList();
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
