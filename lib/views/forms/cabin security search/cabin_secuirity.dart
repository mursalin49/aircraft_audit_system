import 'dart:async';
import 'dart:io';
// ignore_for_file: unintended_html_in_doc_comment
import 'package:avislap/models/pending_upload_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'CabinSecurityTrainingScreen.dart';
import '../../../data/seat_map_config.dart' as seat_map_config;
import '../../../services/api_exception.dart';
import '../../../services/app_api_service.dart';
import '../../../services/audit_draft_store.dart';
import '../../../services/session_service.dart';

// ─────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────
class _C {
  static const Color primary = Color(0xFF3D5AFE);
  static const Color bg = Color(0xFFF5F6FA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color dark = Color(0xFF1A1A2E);
  static const Color grey = Color(0xFF8891A4);
  static const Color border = Color(0xFFE4E7EF);
  static const Color inputBg = Color(0xFFF9FAFB);
  static const Color seatColor = Color(0xFF6B7B99);
  static const Color green = Color(0xFF22C55E);
  static const Color red = Color(0xFFEF4444);
  static const Color planeGrey = Color(0xFFEDEFF4);
  static const Color infoBg = Color(0xFFEEF2FF);
  static const Color infoBorder = Color(0xFFB0BEF8);
  static const Color warnBg = Color(0xFFFFF8E1);
  static const Color warnBorder = Color(0xFFFFCC02);
}

// Max image size: 100MB
const int kMaxImageBytes = 100 * 1024 * 1024;

// ─────────────────────────────────────────────
// SUBCATEGORY ITEMS PER AREA
// ─────────────────────────────────────────────
class CabinSecurityCheckItems {
  static const Map<String, List<String>> areaItems = {
    'Front Galley': [
      'Counter / Surface',
      'Storage Compartments',
      'Oven / Microwave',
      'Coffee Maker',
      'Trash',
      'Floor',
    ],
    'Rear Galley': [
      'Counter / Surface',
      'Storage Compartments',
      'Oven / Microwave',
      'Trash',
      'Floor',
    ],
    'First Class': [
      'Seat Cushion',
      'Seat Back Pocket',
      'Overhead Bin',
      'Tray Table',
      'Armrest',
      'Under Seat',
      'IFE Unit',
    ],
    'Delta Comfort': [
      'Seat Cushion',
      'Seat Back Pocket',
      'Overhead Bin',
      'Tray Table',
      'Under Seat',
      'Floor / Carpet',
    ],
    'Main Cabin': [
      'Seat Cushion',
      'Seat Back Pocket',
      'Overhead Bin',
      'Tray Table',
      'Under Seat',
      'Floor / Carpet',
      'Armrest',
    ],
    'FWD LAV': [
      'Trash Bin',
      'Under Sink',
      'Mirror / Cabinet',
      'Toilet Area',
      'Floor',
      'Counter',
    ],
    'MID LAV L': [
      'Trash Bin',
      'Under Sink',
      'Mirror / Cabinet',
      'Toilet Area',
      'Floor',
      'Counter',
    ],
    'MID LAV R': [
      'Trash Bin',
      'Under Sink',
      'Mirror / Cabinet',
      'Toilet Area',
      'Floor',
      'Counter',
    ],
    'AFT LAV L': [
      'Trash Bin',
      'Under Sink',
      'Mirror / Cabinet',
      'Toilet Area',
      'Floor',
      'Counter',
    ],
    'AFT LAV R': [
      'Trash Bin',
      'Under Sink',
      'Mirror / Cabinet',
      'Toilet Area',
      'Floor',
      'Counter',
    ],
    'Overhead Bins': [
      'Bin Row 1–6',
      'Bin Row 7–14',
      'Bin Row 15–22',
      'Bin Row 23–33',
      'Bin Row 34–49',
    ],
    'Seat Pockets': [
      'Row 1–10 Pockets',
      'Row 11–20 Pockets',
      'Row 21–30 Pockets',
      'Row 31–49 Pockets',
    ],
    'Crew Rest Area': [
      'Bunk / Rest Surface',
      'Storage Compartment',
      'Curtain / Entry',
      'Floor',
    ],
    'Emergency Equipment': [
      'Life Vests Under Seats',
      'O2 Masks Access Panel',
      'Emergency Exit Slides',
      'Fire Extinguisher',
      'First Aid Kit',
    ],
  };

  static List<String> forArea(String area) =>
      areaItems[area] ?? ['General Check'];
}

// ─────────────────────────────────────────────
// AREA CARD MODEL
// ─────────────────────────────────────────────
class SubItemStatus {
  final String itemName;
  String status; // 'pass' | 'fail' | ''
  SubItemStatus({required this.itemName}) : status = '';
}

class AreaCard {
  final String areaName;
  String status; // overall: 'pass' | 'fail' | ''
  List<PendingUploadFile> images; // reference photos uploaded immediately
  List<File> auditImages; // audit-phase images (uploaded when marking)
  List<SubItemStatus> subItems;

  AreaCard({required this.areaName})
    : status = '',
      images = [],
      auditImages = [],
      subItems = CabinSecurityCheckItems.forArea(
        areaName,
      ).map((n) => SubItemStatus(itemName: n)).toList();

  /// Uploading the reference photo completes the area.
  bool get imageUploaded => images.any((upload) => upload.isCompleted);
  bool get hasUploadingImages => images.any((upload) => upload.isUploading);
  bool get hasUploadErrors => images.any((upload) => upload.hasError);

  String get computedStatus => imageUploaded ? 'pass' : '';

  double get scorePercent {
    final done = subItems.where((s) => s.status.isNotEmpty).toList();
    if (done.isEmpty) return 0;
    return (done.where((s) => s.status == 'pass').length / done.length) * 100;
  }
}

// ─────────────────────────────────────────────
// SHARED RESULT MODELS
// ─────────────────────────────────────────────
class CabinSecuritySubItem {
  final String name;
  final String status; // 'pass' | 'fail' | ''

  CabinSecuritySubItem({required this.name, required this.status});
}

class CabinSecurityAreaResult {
  final String area;
  final String status;
  final List<CabinSecuritySubItem> subItems;
  final List<String> pictures;

  CabinSecurityAreaResult({
    required this.area,
    required this.status,
    this.subItems = const [],
    this.pictures = const [],
  });

  int get passCount => subItems.where((c) => c.status == 'pass').length;
  int get failCount => subItems.where((c) => c.status == 'fail').length;
  int get naCount => subItems.where((c) => c.status.isEmpty).length;

  double get scorePercent {
    final applicable = subItems.where((c) => c.status.isNotEmpty).toList();
    if (applicable.isEmpty) return status == 'pass' ? 100 : 0;
    final passed = applicable.where((c) => c.status == 'pass').length;
    return (passed / applicable.length) * 100;
  }
}

// ─────────────────────────────────────────────
// SEAT MAP MODELS
// ─────────────────────────────────────────────
class AircraftSeatMap {
  final String name;
  final List<SeatSection> sections;
  final bool hasFirstClassArc;

  AircraftSeatMap({
    required this.name,
    required this.sections,
    this.hasFirstClassArc = false,
  });
}

class SeatSection {
  final String name;
  final int startRow;
  final int endRow;
  final List<String> leftCols;
  final List<String> rightCols;
  final bool hasExitBefore;
  final bool hasExitAfter;
  final List<AmenityRow>? amenitiesBefore;
  final List<AmenityRow>? amenitiesAfter;
  final List<int>? skipRows;

  SeatSection({
    required this.name,
    required this.startRow,
    required this.endRow,
    required this.leftCols,
    required this.rightCols,
    this.hasExitBefore = false,
    this.hasExitAfter = false,
    this.amenitiesBefore,
    this.amenitiesAfter,
    this.skipRows,
  });
}

class AmenityRow {
  final String? leftSvg;
  final String? leftId;
  final String? rightSvg;
  final String? rightId;
  final bool centerOnly;
  final String? customLabel;

  AmenityRow({
    this.leftSvg,
    this.leftId,
    this.rightSvg,
    this.rightId,
    this.centerOnly = false,
    this.customLabel,
  });
}

// ─────────────────────────────────────────────
// CONTROLLER
// ─────────────────────────────────────────────
class CabinQualityController extends GetxController {
  final selectedAircraft = 'Boeing 757-300 (75Y)'.obs;
  final selectedGate = 'Please Select One'.obs;
  final auditedSeats = <String, String>{}.obs;

  final shipNumber = ''.obs;
  final shipOptions = <String>[].obs;
  final supervisorName = 'John Doe'.obs;
  final supervisorRole = 'Supervisor'.obs;

  final otherFindingsCtrl = TextEditingController();
  final additionalNotesCtrl = TextEditingController();

  final RxList<String> selectedAreas = <String>[].obs;
  final RxList<AreaCard> areaCards = <AreaCard>[].obs;

  final RxSet<String> selectedSeatIds = <String>{}.obs;
  final RxSet<String> mandatoryAreas = <String>{}.obs;

  // Reactive trackers so Obx re-renders when image uploaded or subitem changes
  final RxMap<String, bool> imageUploadedMap = <String, bool>{}.obs;
  final RxInt subItemVersion = 0.obs; // increment to force Obx refresh

  final sec1Expanded = true.obs;
  final sec2Expanded = true.obs;
  final sec3Expanded = true.obs;

  final List<String> aircraftOptions = List<String>.from(
    seat_map_config.defaultAircraftSeatMaps.keys,
  );

  final List<String> gateOptions = [
    'Please Select One',
    'Gate - A',
    'Gate - B',
    'Gate - C',
    'Gate - D',
    'Gate A-01',
    'Gate A-02',
    'Gate A-03',
    'Gate A-12',
    'Gate B-01',
    'Gate B-02',
    'Gate B-04',
    'Gate C-07',
  ];

  final List<String> roleOptions = [
    'Vice President',
    'General Manager',
    'Duty Manager',
    'Supervisor',
    'All',
  ];

  Map<String, AircraftSeatMap> aircraftMaps = <String, AircraftSeatMap>{};

  bool get isFormValid {
    if (selectedGate.value == 'Please Select One') return false;
    if (shipNumber.value.trim().isEmpty) return false;
    if (selectedAreas.isEmpty) return false;
    // Every area must have at least 1 reference photo
    if (areaCards.any((c) => !c.imageUploaded)) return false;
    return true;
  }

  String get validationMessage {
    if (selectedGate.value == 'Please Select One') {
      return 'Please select a Gate.';
    }
    if (shipNumber.value.trim().isEmpty) return 'Please select the Ship #.';
    if (selectedAreas.isEmpty) {
      return 'Please select at least one area to inspect.';
    }
    if (areaCards.any((c) => !c.imageUploaded)) {
      return 'Please capture a reference photo for all selected areas.';
    }
    return '';
  }

  @override
  void onInit() {
    super.onInit();
    _initAircraftMaps();
    ever(selectedAircraft, (_) {
      resetAuditSelections();
    });
  }

  void resetAuditSelections() {
    auditedSeats.clear();
    selectedSeatIds.clear();
    areaCards.clear();
    selectedAreas.clear();
    mandatoryAreas.clear();
    imageUploadedMap.clear();
  }

  AreaCard ensureAreaCard(String area) {
    final existing = areaCards.firstWhereOrNull((c) => c.areaName == area);
    if (existing != null) {
      if (!selectedAreas.contains(area)) {
        selectedAreas.add(area);
      }
      return existing;
    }

    if (!selectedAreas.contains(area)) {
      selectedAreas.add(area);
    }

    final card = AreaCard(areaName: area);
    areaCards.add(card);
    return card;
  }

  void removeArea(String area) {
    if (mandatoryAreas.contains(area)) return;
    selectedAreas.remove(area);
    areaCards.removeWhere((c) => c.areaName == area);
    imageUploadedMap.remove(area);
    selectedSeatIds.removeWhere((id) => _tagForSeatId(id) == area);
  }

  /// Returns the unique tag label for a seat/amenity.
  /// For LAV / Galley → use the area name (one per amenity).
  /// For seats → "Seat <id>" so each seat gets its own card.
  String _tagForSeatId(String seatId) {
    if (seatId.startsWith('LAV') || seatId == 'Closet') {
      return _seatAreaLabel(seatId); // e.g. "FWD LAV"
    }
    if (seatId.startsWith('Galley')) {
      return _seatAreaLabel(seatId); // e.g. "Front Galley"
    }
    if (seatId.startsWith('Jump Seat')) {
      return _seatAreaLabel(seatId);
    }
    // Regular seat — unique tag per seat
    return 'Seat $seatId'; // e.g. "Seat 1A", "Seat 3B"
  }

  void toggleSeatArea(String seatId) {
    final tag = _tagForSeatId(seatId);
    if (selectedSeatIds.contains(seatId)) {
      // Deselect seat → remove its unique tag & card
      selectedSeatIds.remove(seatId);
      removeArea(tag);
    } else {
      // Select seat → add unique tag & card
      selectedSeatIds.add(seatId);
      ensureAreaCard(tag);
    }
  }

  AreaCard ensureCardForSeat(String seatId) {
    if (!selectedSeatIds.contains(seatId)) {
      selectedSeatIds.add(seatId);
    }
    return ensureAreaCard(_tagForSeatId(seatId));
  }

  void removeSeatSelection(String seatId) {
    removeArea(_tagForSeatId(seatId));
  }

  String _seatAreaLabel(String seatId) {
    if (seatId.startsWith('LAV') || seatId == 'Closet') {
      if (seatId.contains('FWD')) return 'FWD LAV';
      if (seatId.contains('MID L')) return 'MID LAV L';
      if (seatId.contains('MID R')) return 'MID LAV R';
      if (seatId.contains('AFT L')) return 'AFT LAV L';
      if (seatId.contains('AFT R')) return 'AFT LAV R';
      return seatId;
    }
    if (seatId.startsWith('Galley')) {
      return seatId.contains('FWD') ? 'Front Galley' : 'Rear Galley';
    }
    if (seatId.startsWith('Jump Seat')) {
      return seatId;
    }
    final rowStr = seatId.replaceAll(RegExp(r'[A-Za-z]'), '');
    final rowNum = int.tryParse(rowStr) ?? 0;
    final map = currentAircraftMap;
    for (final section in map.sections) {
      if (rowNum >= section.startRow && rowNum <= section.endRow) {
        final n = section.name.toLowerCase();
        if (n.contains('first') || n.contains('business')) return 'First Class';
        if (n.contains('comfort')) return 'Delta Comfort';
        return 'Main Cabin';
      }
    }
    return 'Main Cabin';
  }

  void setAreaStatus(String area, String status) {
    final card = areaCards.firstWhereOrNull((c) => c.areaName == area);
    if (card != null) {
      card.status = status;
      areaCards.refresh();
    }
    for (final seatId in selectedSeatIds) {
      if (_tagForSeatId(seatId) == area) {
        auditedSeats[seatId] = status;
      }
    }
  }

  /// Called by setSubItemStatus to keep seat map in sync
  void _syncSeatMapForArea(String area) {
    final card = areaCards.firstWhereOrNull((c) => c.areaName == area);
    if (card == null) return;
    final computed = card.computedStatus;
    if (computed.isEmpty) return;
    for (final seatId in selectedSeatIds) {
      if (_tagForSeatId(seatId) == area) {
        auditedSeats[seatId] = computed;
      }
    }
  }

  void addAreaImage(String area, PendingUploadFile file) {
    final card = areaCards.firstWhereOrNull((c) => c.areaName == area);
    if (card != null) {
      card.images.add(file);
      imageUploadedMap[area] = card.imageUploaded;
      areaCards.refresh();
    }
  }

  void removeAreaImage(String area, int index) {
    final card = areaCards.firstWhereOrNull((c) => c.areaName == area);
    if (card != null) {
      card.images.removeAt(index);
      imageUploadedMap[area] = card.imageUploaded;
      areaCards.refresh();
    }
  }

  void refreshAreaImageState(String area) {
    final card = areaCards.firstWhereOrNull((c) => c.areaName == area);
    if (card != null) {
      imageUploadedMap[area] = card.imageUploaded;
      areaCards.refresh();
    }
  }

  // ── Audit-phase image (uploaded when marking pass/fail) ──
  void addAreaAuditImage(String area, File file) {
    final card = areaCards.firstWhereOrNull((c) => c.areaName == area);
    if (card != null) {
      card.auditImages.add(file);
      subItemVersion.value++;
      areaCards.refresh();
    }
  }

  void removeAreaAuditImage(String area, int index) {
    final card = areaCards.firstWhereOrNull((c) => c.areaName == area);
    if (card != null) {
      card.auditImages.removeAt(index);
      subItemVersion.value++;
      areaCards.refresh();
    }
  }

  // ── Subitem status ───────────────────────────────────────
  void setSubItemStatus(String area, String itemName, String status) {
    final card = areaCards.firstWhereOrNull((c) => c.areaName == area);
    if (card != null) {
      final sub = card.subItems.firstWhereOrNull((s) => s.itemName == itemName);
      if (sub != null) {
        sub.status = status;
        card.status = card.computedStatus;
        subItemVersion.value++; // force Obx re-render
        areaCards.refresh();
        _syncSeatMapForArea(area);
      }
    }
  }

  void markSeat(String id, String status) => auditedSeats[id] = status;
  void clearSeat(String id) => auditedSeats.remove(id);

  AircraftSeatMap get currentAircraftMap =>
      aircraftMaps[selectedAircraft.value] ?? aircraftMaps.values.first;

  static String get currentDateTime {
    final n = DateTime.now();
    return '${n.month.toString().padLeft(2, '0')}/'
        '${n.day.toString().padLeft(2, '0')}/${n.year}  '
        '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}';
  }

  void _initAircraftMaps() {
    aircraftMaps = _convertSeatMaps(seat_map_config.defaultAircraftSeatMaps);
  }

  Map<String, AircraftSeatMap> _convertSeatMaps(
    Map<String, seat_map_config.AircraftSeatMap> source,
  ) {
    return source.map(
      (key, value) => MapEntry(
        key,
        AircraftSeatMap(
          name: value.name,
          hasFirstClassArc: value.hasFirstClassArc,
          sections: value.sections
              .map(
                (section) => SeatSection(
                  name: section.name,
                  startRow: section.startRow,
                  endRow: section.endRow,
                  leftCols: List<String>.from(section.leftCols),
                  rightCols: List<String>.from(section.rightCols),
                  hasExitBefore: section.hasExitBefore,
                  hasExitAfter: section.hasExitAfter,
                  amenitiesBefore: section.amenitiesBefore
                      ?.map(
                        (amenity) => AmenityRow(
                          leftSvg: amenity.leftSvg,
                          leftId: amenity.leftId,
                          rightSvg: amenity.rightSvg,
                          rightId: amenity.rightId,
                          centerOnly: amenity.centerOnly,
                          customLabel: amenity.customLabel,
                        ),
                      )
                      .toList(),
                  amenitiesAfter: section.amenitiesAfter
                      ?.map(
                        (amenity) => AmenityRow(
                          leftSvg: amenity.leftSvg,
                          leftId: amenity.leftId,
                          rightSvg: amenity.rightSvg,
                          rightId: amenity.rightId,
                          centerOnly: amenity.centerOnly,
                          customLabel: amenity.customLabel,
                        ),
                      )
                      .toList(),
                  skipRows: section.skipRows == null
                      ? null
                      : List<int>.from(section.skipRows!),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  void onClose() {
    otherFindingsCtrl.dispose();
    additionalNotesCtrl.dispose();
    super.onClose();
  }
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class CabinQualityAuditScreenN extends StatefulWidget {
  final bool restoreDraft;
  final String? initialShipNumber;
  final String? initialGateNumber;

  const CabinQualityAuditScreenN({
    super.key,
    this.restoreDraft = false,
    this.initialShipNumber,
    this.initialGateNumber,
  });

  static const String draftStorageKey = 'cabin_security_search_training_draft';
  static bool hasSavedDraft() => AuditDraftStore.hasDraft(draftStorageKey);
  static void clearSavedDraft() => AuditDraftStore.clearDraft(draftStorageKey);

  @override
  State<CabinQualityAuditScreenN> createState() =>
      _CabinQualityAuditScreenNState();
}

class _CabinQualityAuditScreenNState extends State<CabinQualityAuditScreenN> {
  final _ctrl = Get.put(CabinQualityController());
  final AppApiService _api = Get.find<AppApiService>();
  final SessionService _session = Get.find<SessionService>();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  // Steps: 0 = Instruction + Section 1
  //        1 = Section 2 (Checklist + Seat Map)
  //        2 = Section 3 (Finalize)
  int _step = 0;

  final RxList<PendingUploadFile> _generalImages = <PendingUploadFile>[].obs;
  final ImagePicker _picker = ImagePicker();
  final Map<String, String> _gateIdsByLabel = <String, String>{};
  final Map<String, String> _areaIdsByLabel = <String, String>{};
  final Map<String, String> _fleetAircraftNamesByShip = <String, String>{};
  final Map<String, String> _hiddenObjectAreaByLocationId = <String, String>{};
  String? _linkedHiddenObjectAuditId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _didSubmitSuccessfully = false;
  bool _isGateLocked = false;

  String _normalizeGateValue(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^gate\s*'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceAll(RegExp(r'0+([1-9])'), r'$1');
  }

  String _formatGateLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return trimmed.toLowerCase().startsWith('gate ')
        ? trimmed
        : 'Gate $trimmed';
  }

  String? _resolveGateId(String selectedGate) {
    final direct = _gateIdsByLabel[selectedGate];
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final normalizedSelected = _normalizeGateValue(selectedGate);
    for (final entry in _gateIdsByLabel.entries) {
      if (_normalizeGateValue(entry.key) == normalizedSelected &&
          entry.value.isNotEmpty) {
        return entry.value;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  // ── 100MB image validation ────────────────────────────
  Future<List<PendingUploadFile>> _pickValidatedImages() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    final List<PendingUploadFile> valid = [];
    final List<String> oversized = [];

    if (picked != null) {
      final file = File(picked.path);
      final size = await file.length();
      if (size > kMaxImageBytes) {
        oversized.add(picked.name);
      } else {
        final upload = PendingUploadFile(localFile: file);
        valid.add(upload);
      }
    }

    if (oversized.isNotEmpty) {
      Get.snackbar(
        'Image Too Large',
        '${oversized.join(', ')} exceeds the 100MB limit and was not added.',
        backgroundColor: _C.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
    }
    return valid;
  }

  Future<void> _loadFormData() async {
    setState(() => _isLoading = true);

    try {
      final stationId = _session.activeStationId;
      if (stationId.isEmpty) {
        throw Exception('No active station selected');
      }

      final results = await Future.wait([
        _api.getGates(stationId),
        _api.getSecuritySearchAreas(),
        _api.getAircraftTypes(),
        _api.getFleetAircraft(),
      ]);

      final gates = List<Map<String, dynamic>>.from(results[0]);
      final areas = List<Map<String, dynamic>>.from(results[1]);
      final aircraftTypes = List<Map<String, dynamic>>.from(results[2]);
      final fleetAircraft = List<Map<String, dynamic>>.from(results[3]);

      final gateLabels = <String>['Please Select One'];
      _gateIdsByLabel.clear();
      for (final gate in gates) {
        final gateId = gate['id']?.toString() ?? '';
        final gateCode = gate['gateCode']?.toString().trim() ?? '';
        if (gateId.isEmpty || gateCode.isEmpty) {
          continue;
        }
        final label = gateCode.toLowerCase().startsWith('gate ')
            ? gateCode
            : 'Gate $gateCode';
        gateLabels.add(label);
        _gateIdsByLabel[label] = gateId;
        _gateIdsByLabel[gateCode] = gateId;
      }

      _areaIdsByLabel.clear();
      for (final area in areas) {
        final areaId = area['id']?.toString() ?? '';
        final label = area['label']?.toString().trim() ?? '';
        if (areaId.isEmpty || label.isEmpty) {
          continue;
        }
        _areaIdsByLabel[label] = areaId;
      }

      _ctrl.gateOptions
        ..clear()
        ..addAll(gateLabels);
      if (!_ctrl.gateOptions.contains(_ctrl.selectedGate.value)) {
        _ctrl.selectedGate.value = 'Please Select One';
      }

      final shipNumbers = <String>[];
      _fleetAircraftNamesByShip.clear();
      for (final aircraft in fleetAircraft) {
        if (aircraft['isActive'] == false) {
          continue;
        }

        final shipNumber = aircraft['shipNumber']?.toString().trim() ?? '';
        final aircraftType = _asMap(aircraft['aircraftType']);
        final aircraftName = aircraftType['name']?.toString().trim() ?? '';
        if (shipNumber.isEmpty) {
          continue;
        }

        shipNumbers.add(shipNumber);
        if (aircraftName.isNotEmpty) {
          _fleetAircraftNamesByShip[shipNumber] = aircraftName;
        }
      }

      shipNumbers.sort();
      _ctrl.shipOptions
        ..clear()
        ..addAll(shipNumbers);
      if (_ctrl.shipNumber.value.isNotEmpty &&
          !_ctrl.shipOptions.contains(_ctrl.shipNumber.value)) {
        _ctrl.shipNumber.value = '';
      }

      final syncedAircraftMaps = _ctrl._convertSeatMaps(
        seat_map_config.buildAircraftSeatMapsFromApi(aircraftTypes),
      );
      if (syncedAircraftMaps.isNotEmpty) {
        _ctrl.aircraftMaps = syncedAircraftMaps;
        _ctrl.aircraftOptions
          ..clear()
          ..addAll(syncedAircraftMaps.keys);
      }
      if (_ctrl.aircraftOptions.isNotEmpty &&
          !_ctrl.aircraftOptions.contains(_ctrl.selectedAircraft.value)) {
        _ctrl.selectedAircraft.value = _ctrl.aircraftOptions.first;
      }

      // Populate from API if available
      if (widget.initialShipNumber != null &&
          widget.initialShipNumber!.isNotEmpty) {
        final ship = widget.initialShipNumber!.trim().toUpperCase();
        if (_ctrl.shipOptions.contains(ship)) {
          _ctrl.shipNumber.value = ship;
          final aircraftName = _fleetAircraftNamesByShip[ship];
          if (aircraftName != null &&
              _ctrl.aircraftOptions.contains(aircraftName)) {
            _ctrl.selectedAircraft.value = aircraftName;
          }
        }
      }

      if (widget.initialGateNumber != null &&
          widget.initialGateNumber!.isNotEmpty) {
        final gText = widget.initialGateNumber!.trim().toLowerCase();

        // Skip if the provided gate is just a placeholder
        if (gText != "—" && gText != "n/a" && gText != "unknown") {
          // Normalization: remove non-alphanumeric, then remove leading zeros from numbers
          final normalizedInput = _normalizeGateValue(gText);

          final match = _ctrl.gateOptions.firstWhereOrNull((opt) {
            if (opt.toLowerCase().contains('select')) return false;
            final normalizedOpt = _normalizeGateValue(opt);
            return normalizedOpt == normalizedInput ||
                normalizedOpt.contains(normalizedInput) ||
                normalizedInput.contains(normalizedOpt);
          });

          if (match != null) {
            _ctrl.selectedGate.value = match;
            _isGateLocked = true;
          } else {
            final fallbackLabel = _formatGateLabel(widget.initialGateNumber!);
            if (!_ctrl.gateOptions.contains(fallbackLabel)) {
              _ctrl.gateOptions.insert(1, fallbackLabel);
            }
            _ctrl.selectedGate.value = fallbackLabel;
          }
        }
      }

      if (_session.fullName.isNotEmpty) {
        _ctrl.supervisorName.value = _session.fullName;
      } else if (_session.firstName.isNotEmpty) {
        _ctrl.supervisorName.value = _session.firstName;
      }

      final roleName =
          (_session.activeStation?['roleName'] as String?)?.trim() ?? '';
      if (roleName.isNotEmpty) {
        _ctrl.supervisorRole.value = roleName;
      }

      if (widget.restoreDraft) {
        _restoreDraft();
      }
    } on ApiException catch (error) {
      Get.snackbar(
        'Form Unavailable',
        error.message,
        backgroundColor: _C.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (_) {
      Get.snackbar(
        'Form Unavailable',
        'Unable to load gate and area data right now.',
        backgroundColor: _C.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  String _normalizeShipNumber(String value) => value.trim().toUpperCase();

  void _clearLinkedHiddenObjectAuditState({bool clearSelections = false}) {
    _linkedHiddenObjectAuditId = null;
    _hiddenObjectAreaByLocationId.clear();
    if (clearSelections) {
      _ctrl.resetAuditSelections();
    }
  }

  String _resolveHiddenObjectAreaName(Map<String, dynamic> location) {
    final locationId = location['id']?.toString() ?? '';
    final locationCode = location['locationCode']?.toString().trim() ?? '';
    final locationLabel = location['locationLabel']?.toString().trim() ?? '';
    final sectionLabel = location['sectionLabel']?.toString().trim() ?? '';

    final isSeatMapAddressable =
        RegExp(r'^\d+[A-Z]+$', caseSensitive: false).hasMatch(locationCode) ||
        locationCode.startsWith('LAV') ||
        locationCode.startsWith('Galley') ||
        locationCode.startsWith('Jump Seat') ||
        locationCode == 'Closet';

    if (locationId.isEmpty) {
      return '';
    }

    if (isSeatMapAddressable) {
      if (RegExp(r'^\d+[A-Z]+$', caseSensitive: false).hasMatch(locationCode)) {
        return _ctrl._tagForSeatId(locationCode);
      }
      return _ctrl._seatAreaLabel(locationCode);
    }

    final fallbackArea = locationLabel.isNotEmpty
        ? locationLabel
        : sectionLabel.isNotEmpty
        ? sectionLabel
        : 'Hidden Object Target';

    return fallbackArea;
  }

  Future<bool> _syncHiddenObjectAuditForSearch() async {
    final shipNumber = _normalizeShipNumber(_ctrl.shipNumber.value);
    if (shipNumber.isEmpty) {
      return false;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _api.listHiddenObjectAudits(
        queryParameters: {
          'shipNumber': shipNumber,
          'status': 'ACTIVE',
          'page': 1,
          'limit': 20,
        },
      );
      final items = _asListOfMaps(response['items']);
      final matchedAudits = items
          .where(
            (item) =>
                _normalizeShipNumber(item['shipNumber']?.toString() ?? '') ==
                shipNumber,
          )
          .toList();

      if (matchedAudits.length > 1) {
        Get.snackbar(
          'Hidden Object Audit Conflict',
          'More than one active hidden object audit was found for ship $shipNumber. Please close the duplicate session first.',
          backgroundColor: _C.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        return false;
      }

      final matchedAudit = matchedAudits.firstOrNull;

      if (matchedAudit == null) {
        _clearLinkedHiddenObjectAuditState();
        return true;
      }

      final detail = await _api.getHiddenObjectAudit(
        matchedAudit['id']?.toString() ?? '',
      );
      final aircraftType = _asMap(detail['aircraftType']);
      final aircraftName = aircraftType['name']?.toString().trim() ?? '';
      final activeLocations = _asListOfMaps(
        detail['locations'],
      ).where((location) => location['status']?.toString() == 'BLUE').toList();

      if (aircraftName.isEmpty || activeLocations.isEmpty) {
        Get.snackbar(
          'Hidden Object Audit Required',
          'The active hidden object audit is missing searchable locations.',
          backgroundColor: _C.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        return false;
      }

      if (_ctrl.aircraftOptions.isNotEmpty &&
          !_ctrl.aircraftOptions.contains(aircraftName)) {
        Get.snackbar(
          'Aircraft Mismatch',
          'The linked hidden object audit uses an aircraft type that is not available in this search form.',
          backgroundColor: _C.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        return false;
      }

      _clearLinkedHiddenObjectAuditState(clearSelections: true);
      _ctrl.shipNumber.value = shipNumber;
      _ctrl.selectedAircraft.value = aircraftName;

      for (final location in activeLocations) {
        final locationId = location['id']?.toString() ?? '';
        final areaName = _resolveHiddenObjectAreaName(location);
        if (locationId.isEmpty || areaName.isEmpty) {
          continue;
        }
        _hiddenObjectAreaByLocationId[locationId] = areaName;
      }

      _linkedHiddenObjectAuditId = detail['id']?.toString();
      return _linkedHiddenObjectAuditId != null &&
          _hiddenObjectAreaByLocationId.isNotEmpty;
    } on ApiException catch (error) {
      if (_isPermissionDeniedError(error)) {
        _clearLinkedHiddenObjectAuditState();
        return true;
      }

      Get.snackbar(
        'Hidden Object Audit',
        error.message,
        backgroundColor: _C.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isPermissionDeniedError(ApiException error) {
    final message = error.message.trim().toLowerCase();
    return message.contains('permission denied') ||
        message.contains('forbidden');
  }

  List<Map<String, dynamic>> _buildHiddenObjectLocationResults() {
    final results = <Map<String, dynamic>>[];
    for (final entry in _hiddenObjectAreaByLocationId.entries) {
      final card = _ctrl.areaCards.firstWhereOrNull(
        (item) => item.areaName == entry.value,
      );
      final found = card?.imageUploaded == true;
      results.add({'locationId': entry.key, 'found': found});
    }

    return results;
  }

  Future<void> _showAreaCardSheetForSeat(String id) async {
    final card = _ctrl.ensureCardForSeat(id);
    final areaName = card.areaName;
    final isSeatArea = areaName.startsWith('Seat ');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.93,
          child: Container(
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(height: 12.h),
                Container(
                  width: 46.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: _C.border,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 12.h),
                  child: Row(
                    children: [
                      Container(
                        width: 46.w,
                        height: 46.h,
                        decoration: BoxDecoration(
                          color: _C.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Icon(
                          _areaCardIcon(areaName),
                          color: _C.primary,
                          size: 22.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              areaName,
                              style: GoogleFonts.dmSans(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                                color: _C.dark,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              isSeatArea
                                  ? 'Inspect this seat without losing your place on the map.'
                                  : 'Inspect this area without losing your place on the map.',
                              style: GoogleFonts.dmSans(
                                fontSize: 12.sp,
                                color: _C.grey,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(sheetContext).pop(),
                        child: Container(
                          width: 38.w,
                          height: 38.h,
                          decoration: BoxDecoration(
                            color: _C.inputBg,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: _C.border),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: _C.dark,
                            size: 18.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 14.h),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 11.h,
                    ),
                    decoration: BoxDecoration(
                      color: _C.infoBg,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: _C.infoBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: _C.primary,
                          size: 16.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Complete the checks here, or remove this selection if you tapped the wrong place.',
                            style: GoogleFonts.dmSans(
                              fontSize: 12.sp,
                              color: _C.dark,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                    child: Column(
                      children: [
                        _AreaCardWidget(
                          key: ValueKey('sheet-$areaName'),
                          card: card,
                          ctrl: _ctrl,
                          pickImages: _pickValidatedImages,
                          retryAreaUpload: (upload, area) =>
                              _uploadPendingImage(upload, areaName: area),
                          trailingIcon: Icons.close_rounded,
                          onTrailingTap: () => Navigator.of(sheetContext).pop(),
                        ),
                        SizedBox(height: 10.h),
                        if (!_ctrl.mandatoryAreas.contains(areaName))
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _ctrl.removeSeatSelection(id);
                                Navigator.of(sheetContext).pop();
                              },
                              icon: Icon(
                                Icons.remove_circle_outline_rounded,
                                color: _C.red,
                                size: 18.sp,
                              ),
                              label: Text(
                                isSeatArea
                                    ? 'Remove this seat from selection'
                                    : 'Remove this area from selection',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _C.red,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                side: BorderSide(
                                  color: _C.red.withOpacity(0.35),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                backgroundColor: _C.red.withOpacity(0.03),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _persistDraftIfNeeded();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: _step == 0
          ? _buildStep0()
          : _step == 1
          ? _buildStep1()
          : _buildStep2(),
    );
  }

  // ── App Bar ───────────────────────────────────────────
  AppBar _buildAppBar() => AppBar(
    backgroundColor: _C.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: Icon(Icons.arrow_back_rounded, color: _C.primary, size: 22.sp),
      onPressed: () => _step > 0 ? setState(() => _step--) : Get.back(),
    ),
    title: Text(
      'Cabin Security Search',
      style: GoogleFonts.dmSans(
        fontSize: 17.sp,
        fontWeight: FontWeight.w600,
        color: _C.primary,
      ),
    ),
    centerTitle: true,
    actions: [
      IconButton(
        icon: Icon(Icons.save_outlined, color: _C.primary, size: 22.sp),
        onPressed: _saveDraftManually,
      ),
      IconButton(
        icon: Icon(Icons.info_outline_rounded, color: _C.primary, size: 22.sp),
        onPressed: _showInstructions,
      ),
    ],
  );

  // ─────────────────────────────────────────────
  // STEP 0
  // ─────────────────────────────────────────────
  Widget _buildStep0() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInstructionBanner(),
                SizedBox(height: 16.h),
                _buildReferenceImage(),
                SizedBox(height: 16.h),
                _buildSection1(),
              ],
            ),
          ),
        ),
        _nextButton(() async {
          if (_ctrl.selectedGate.value == 'Please Select One') {
            Get.snackbar(
              'Incomplete',
              'Please select a Gate before continuing.',
              backgroundColor: _C.red,
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 3),
            );
            return;
          }
          if (_ctrl.shipNumber.value.trim().isEmpty) {
            Get.snackbar(
              'Incomplete',
              'Please select the Ship # before continuing.',
              backgroundColor: _C.red,
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 3),
            );
            return;
          }

          final synced = await _syncHiddenObjectAuditForSearch();
          if (!synced) {
            return;
          }

          setState(() => _step = 1);
        }),
      ],
    );
  }

  Widget _buildReferenceImage() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _C.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: Image.asset(
          'assets/images/indor.png',
          height: 180.h,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 180.h,
            decoration: BoxDecoration(
              color: _C.infoBg,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flight_rounded, color: _C.primary, size: 40.sp),
                SizedBox(height: 8.h),
                Text(
                  'Cabin Interior Reference',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    color: _C.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section 1 ────────────────────────────────────────
  Widget _buildSection1() {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _ctrl.sec1Expanded.value = !_ctrl.sec1Expanded.value,
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: _C.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 18.h,
                    decoration: BoxDecoration(
                      color: _C.primary,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Section 1: Training Info',
                      style: GoogleFonts.dmSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: _C.dark,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _ctrl.sec1Expanded.value ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _C.grey,
                      size: 22.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_ctrl.sec1Expanded.value) ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: _C.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Date and Time'),
                  _readOnlyField(
                    CabinQualityController.currentDateTime,
                    icon: Icons.calendar_month_outlined,
                  ),
                  SizedBox(height: 14.h),
                  _label('Supervisor / Lead'),
                  _readOnlyField(
                    _ctrl.supervisorName.value,
                    icon: Icons.person_outline_rounded,
                  ),

                  SizedBox(height: 14.h),
                  _label('Gate *'),
                  if (_isGateLocked)
                    Obx(
                      () => _readOnlyField(
                        _ctrl.selectedGate.value,
                        icon: Icons.lock_outline_rounded,
                      ),
                    )
                  else
                    Obx(
                      () => _pillDropdown(
                        value: _ctrl.selectedGate.value,
                        items: _ctrl.gateOptions,
                        onChanged: (v) => _ctrl.selectedGate.value = v!,
                      ),
                    ),
                  SizedBox(height: 14.h),
                  _label('Ship # *'),
                  Obx(
                    () => _pillDropdown(
                      value: _ctrl.shipNumber.value.isEmpty
                          ? (_ctrl.shipOptions.isEmpty
                                ? 'No ships available'
                                : 'Select ship number')
                          : _ctrl.shipNumber.value,
                      items: _ctrl.shipOptions,
                      onChanged: (v) {
                        final shipNumber = v?.trim() ?? '';
                        _ctrl.shipNumber.value = shipNumber;
                        _clearLinkedHiddenObjectAuditState(
                          clearSelections: true,
                        );

                        final aircraftName =
                            _fleetAircraftNamesByShip[shipNumber];
                        if (aircraftName != null &&
                            _ctrl.aircraftOptions.contains(aircraftName)) {
                          _ctrl.selectedAircraft.value = aircraftName;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STEP 1
  // ─────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                _buildSection2(),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),
        _nextButton(() {
          if (_ctrl.selectedAreas.isEmpty) {
            Get.snackbar(
              'Incomplete',
              'Please select at least one area to inspect.',
              backgroundColor: _C.red,
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 3),
            );
            return;
          }
          if (_ctrl.areaCards.any((c) => !c.imageUploaded)) {
            Get.snackbar(
              'Missing Photo',
              'Please capture a reference photo for every selected area before continuing.',
              backgroundColor: _C.red,
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 3),
            );
            return;
          }
          setState(() => _step = 2);
        }),
      ],
    );
  }

  // ── Section 2 (reordered: area search first, aircraft below) ──
  Widget _buildSection2() {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          InkWell(
            onTap: () => _ctrl.sec2Expanded.value = !_ctrl.sec2Expanded.value,
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: _C.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 18.h,
                    decoration: BoxDecoration(
                      color: _C.primary,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Section 2: Inspection Checklist',
                      style: GoogleFonts.dmSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: _C.dark,
                      ),
                    ),
                  ),
                  Obx(() {
                    final count = _ctrl.selectedAreas.length;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      margin: EdgeInsets.only(right: 8.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: _C.primary,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }),
                  AnimatedRotation(
                    turns: _ctrl.sec2Expanded.value ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _C.grey,
                      size: 22.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_ctrl.sec2Expanded.value) ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: _C.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Area tag chips
                  Obx(() {
                    if (_ctrl.selectedAreas.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: Text(
                          'Tap seats or cabin locations on the map to add areas.',
                          style: GoogleFonts.dmSans(
                            fontSize: 12.sp,
                            color: _C.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 12.h),
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_searching_rounded,
                                    color: Colors.orange.shade800,
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'Selected Search Areas',
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.sp,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Review the areas you selected for inspection. Tap seats or cabin locations on the map to add more areas.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12.sp,
                                  color: Colors.orange.shade800,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: _ctrl.selectedAreas.map((area) {
                            final isMandatory = _ctrl.mandatoryAreas.contains(
                              area,
                            );
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: _C.primary,
                                borderRadius: BorderRadius.circular(20.r),
                                border: isMandatory
                                    ? Border.all(color: Colors.orange, width: 2)
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    area,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12.sp,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (!isMandatory) SizedBox(width: 6.w),
                                  if (!isMandatory)
                                    GestureDetector(
                                      onTap: () => _ctrl.removeArea(area),
                                      child: Icon(
                                        Icons.close,
                                        size: 14.sp,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  }),
                  SizedBox(height: 16.h),

                  // Dynamic area cards
                  Obx(() {
                    if (_ctrl.areaCards.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: _ctrl.areaCards
                          .map((card) => _buildAreaCard(card))
                          .toList(),
                    );
                  }),

                  // ── Divider ───────────────────────────────────
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(child: Divider(color: _C.border)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        child: Text(
                          'select area on the seat map',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.sp,
                            color: _C.grey,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: _C.border)),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // ── 2. Type of Aircraft (BELOW area search) ───
                  _label('Type of Aircraft *'),
                  Obx(
                    () => _pillDropdown(
                      value: _ctrl.selectedAircraft.value,
                      items: _ctrl.aircraftOptions,
                      onChanged: (v) {
                        if (_linkedHiddenObjectAuditId != null) {
                          Get.snackbar(
                            'Aircraft Locked',
                            'The aircraft type is locked to the active hidden object audit.',
                            backgroundColor: _C.red,
                            colorText: Colors.white,
                            snackPosition: SnackPosition.TOP,
                          );
                          return;
                        }
                        _ctrl.selectedAircraft.value = v!;
                      },
                      suffixIcon: Icons.search_rounded,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Legend
                  _buildLegend(),
                  SizedBox(height: 12.h),

                  // Seat Map
                  _buildSeatMap(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STEP 2
  // ─────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                _buildSection3(),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),
        _buildSubmitButton(),
      ],
    );
  }

  // ── Section 3 ────────────────────────────────────────
  Widget _buildSection3() {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _ctrl.sec3Expanded.value = !_ctrl.sec3Expanded.value,
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: _C.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 18.h,
                    decoration: BoxDecoration(
                      color: _C.primary,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Section 3: Finalize',
                      style: GoogleFonts.dmSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: _C.dark,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _ctrl.sec3Expanded.value ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _C.grey,
                      size: 22.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_ctrl.sec3Expanded.value) ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: _C.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Other Findings'),
                  _multilineField(
                    'Enter any additional findings...',
                    controller: _ctrl.otherFindingsCtrl,
                  ),
                  SizedBox(height: 14.h),
                  _label('Additional Notes'),
                  _multilineField(
                    'Enter additional notes...',
                    controller: _ctrl.additionalNotesCtrl,
                  ),
                  SizedBox(height: 14.h),
                  _label('Pictures'),
                  _uploadBox(),
                  SizedBox(height: 10.h),
                  Obx(
                    () => _generalImages.isEmpty
                        ? const SizedBox.shrink()
                        : Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: _generalImages.asMap().entries.map((e) {
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.r),
                                    child: Image.file(
                                      e.value.localFile,
                                      width: 80.w,
                                      height: 80.w,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (e.value.isUploading || e.value.hasError)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.45),
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                        ),
                                        child: Center(
                                          child: e.value.isUploading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                )
                                              : IconButton(
                                                  onPressed: () => unawaited(
                                                    _uploadPendingImage(
                                                      e.value,
                                                    ),
                                                  ),
                                                  icon: const Icon(
                                                    Icons.refresh_rounded,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () =>
                                          _generalImages.removeAt(e.key),
                                      child: Container(
                                        padding: EdgeInsets.all(2.r),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 13.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _label('Signature *'),
                      GestureDetector(
                        onTap: () => _signatureController.clear(),
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: Text(
                            'Clear',
                            style: GoogleFonts.dmSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: _C.red,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _C.border),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Signature(
                        controller: _signatureController,
                        height: 120.h,
                        backgroundColor: _C.inputBg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SUBMIT BUTTON — success popup then navigate
  // ─────────────────────────────────────────────
  Future<void> _uploadPendingImage(
    PendingUploadFile upload, {
    String? areaName,
  }) async {
    setState(() {
      upload.status = PendingUploadStatus.uploading;
      upload.progress = 0;
      upload.errorMessage = null;
    });

    try {
      final uploaded = await _api.uploadFile(
        upload.localFile,
        category: 'IMAGE',
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
        throw const ApiException('Image upload did not return a file id.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        upload.fileId = fileId;
        upload.cloudinaryUrl = uploaded['cloudinaryUrl']?.toString().trim();
        upload.progress = 1;
        upload.status = PendingUploadStatus.completed;
        upload.errorMessage = null;
      });
      if (areaName != null) {
        _ctrl.refreshAreaImageState(areaName);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        upload.status = PendingUploadStatus.failed;
        upload.errorMessage = error.message;
      });
      if (areaName != null) {
        _ctrl.refreshAreaImageState(areaName);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        upload.status = PendingUploadStatus.failed;
        upload.errorMessage = 'Unable to upload this image right now.';
      });
      if (areaName != null) {
        _ctrl.refreshAreaImageState(areaName);
      }
    }
  }

  List<String> _uploadedFileIds(Iterable<PendingUploadFile> uploads) {
    final uploadedIds = <String>[];
    for (final upload in uploads) {
      final fileId = upload.fileId?.trim() ?? '';
      if (upload.isCompleted && fileId.isNotEmpty) {
        uploadedIds.add(fileId);
      }
    }
    return uploadedIds;
  }

  String? _imageUploadBlockerMessage() {
    final uploads = <PendingUploadFile>[
      ..._generalImages,
      ..._ctrl.areaCards.expand((card) => card.images),
    ];

    if (uploads.any((upload) => upload.isUploading)) {
      return 'Please wait for all selected images to finish uploading.';
    }
    if (uploads.any((upload) => upload.hasError)) {
      return 'Retry or remove failed image uploads before submitting.';
    }
    return null;
  }

  String? _buildSubmissionNotes() {
    final userNotes = _ctrl.additionalNotesCtrl.text.trim();
    final summary = _ctrl.areaCards
        .map((card) {
          final status = card.computedStatus == 'pass' ? 'PASS' : 'FAIL';
          return '${card.areaName}=$status';
        })
        .join(', ');

    final metadata = <String>[
      if (_ctrl.selectedAircraft.value.trim().isNotEmpty)
        'Aircraft: ${_ctrl.selectedAircraft.value.trim()}',
      if (_ctrl.supervisorRole.value.trim().isNotEmpty)
        'Supervisor Role: ${_ctrl.supervisorRole.value.trim()}',
      if (summary.isNotEmpty) 'Area Summary: $summary',
    ].join('\n');

    final combined = [
      if (userNotes.isNotEmpty) userNotes,
      if (metadata.isNotEmpty) metadata,
    ].join('\n\n');

    if (combined.trim().isEmpty) {
      return null;
    }

    const maxLength = 3000;
    return combined.length <= maxLength
        ? combined
        : combined.substring(0, maxLength);
  }

  String _buildDetailedAreaId(String areaName) {
    final trimmed = areaName.trim();
    if (trimmed.toLowerCase().startsWith('seat ')) {
      return trimmed.substring(5).trim();
    }
    return trimmed;
  }

  String _buildDetailedSectionLabel(String areaName) {
    final trimmed = areaName.trim();
    final normalized = trimmed.toLowerCase();

    if (normalized.startsWith('seat ')) {
      final seatId = trimmed.substring(5).trim();
      final row = int.tryParse(seatId.replaceAll(RegExp(r'[^0-9]'), ''));
      if (row != null) {
        for (final section in _ctrl.currentAircraftMap.sections) {
          if (row >= section.startRow && row <= section.endRow) {
            final sectionName = section.name.trim();
            final lowerName = sectionName.toLowerCase();
            if (lowerName.contains('first') || lowerName.contains('business')) {
              return 'First Class';
            }
            if (lowerName.contains('comfort')) {
              return 'Delta Comfort';
            }
            if (lowerName.contains('main')) {
              return 'Main Cabin';
            }
            return sectionName;
          }
        }
      }
      return 'Cabin Seat';
    }

    if (normalized.contains('galley')) {
      return 'Galley';
    }
    if (normalized.contains('lav')) {
      return 'Lav';
    }
    if (normalized.contains('overhead')) {
      return 'Overhead Bins';
    }
    if (normalized.contains('pocket')) {
      return 'Seat Pockets';
    }
    if (normalized.contains('crew')) {
      return 'Crew Rest Area';
    }
    if (normalized.contains('emergency')) {
      return 'Emergency Equipment';
    }

    return trimmed;
  }

  Widget _buildSubmitButton() {
    return Obx(() {
      final valid = _ctrl.isFormValid;
      return Container(
        color: _C.white,
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        child: GestureDetector(
          onTap: _isSubmitting
              ? null
              : () {
                  if (!valid) {
                    Get.snackbar(
                      'Incomplete Form',
                      _ctrl.validationMessage,
                      backgroundColor: _C.red,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.TOP,
                      duration: const Duration(seconds: 3),
                    );
                    return;
                  }
                  _handleSubmit();
                },
          child: Container(
            height: 52.h,
            decoration: BoxDecoration(
              color: valid && !_isSubmitting ? _C.primary : _C.border,
              borderRadius: BorderRadius.circular(30.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSubmitting) ...[
                  SizedBox(
                    width: 18.w,
                    height: 18.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 10.w),
                ] else ...[
                  Icon(Icons.send_rounded, color: Colors.white, size: 18.sp),
                  SizedBox(width: 10.w),
                ],
                Text(
                  _isSubmitting ? 'SUBMITTING...' : 'SEND AUDIT REPORT',
                  style: GoogleFonts.dmSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────
  // HANDLE SUBMIT — show success dialog then go
  // ─────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }

    final gateId = _resolveGateId(_ctrl.selectedGate.value);
    if (gateId == null || gateId.isEmpty) {
      Get.snackbar(
        'Gate Required',
        'Please select a valid gate before submitting.',
        backgroundColor: _C.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    final uploadBlocker = _imageUploadBlockerMessage();
    if (uploadBlocker != null) {
      Get.snackbar(
        'Uploads Pending',
        uploadBlocker,
        backgroundColor: _C.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final generalPictureFileIds = _uploadedFileIds(_generalImages);
      final hiddenObjectLocationResults = _buildHiddenObjectLocationResults();
      final hiddenObjectTotalCount = hiddenObjectLocationResults.length;
      final hiddenObjectFoundCount = hiddenObjectLocationResults
          .where((entry) => entry['found'] == true)
          .length;
      final hiddenObjectNotFoundCount =
          hiddenObjectTotalCount - hiddenObjectFoundCount;
      final hasLinkedHiddenObjectSummary =
          _linkedHiddenObjectAuditId != null && hiddenObjectTotalCount > 0;
      final isPassed = hasLinkedHiddenObjectSummary
          ? hiddenObjectNotFoundCount == 0
          : _ctrl.areaCards.every((c) => c.computedStatus == 'pass');
      final resultLabel = hasLinkedHiddenObjectSummary
          ? (isPassed
                ? 'All Hidden Items Found'
                : '$hiddenObjectFoundCount of $hiddenObjectTotalCount Hidden Items Found')
          : (isPassed ? 'All Passed' : 'Some Failed');

      if (_linkedHiddenObjectAuditId != null &&
          hiddenObjectLocationResults.isEmpty) {
        throw const ApiException(
          'The linked hidden object audit could not be synchronized with this search report.',
        );
      }

      final areaResults = <Map<String, dynamic>>[];
      final detailedAreaResults = <Map<String, dynamic>>[];
      for (final card in _ctrl.areaCards) {
        final imageFileIds = _uploadedFileIds(card.images);

        final areaPayload = <String, dynamic>{
          'result': card.imageUploaded ? 'PASS' : 'FAIL',
          if (imageFileIds.isNotEmpty) 'imageFileIds': imageFileIds,
        };

        final knownAreaId = _areaIdsByLabel[card.areaName];
        if (knownAreaId != null && knownAreaId.isNotEmpty) {
          areaPayload['areaId'] = knownAreaId;
        } else {
          areaPayload['areaLabel'] = card.areaName;
        }

        areaResults.add(areaPayload);
        detailedAreaResults.add({
          'areaId': _buildDetailedAreaId(card.areaName),
          'sectionLabel': _buildDetailedSectionLabel(card.areaName),
          if (imageFileIds.isNotEmpty) 'imageFileIds': imageFileIds,
          'checkItems': card.subItems
              .map(
                (sub) => {
                  'itemName': sub.itemName,
                  'status': sub.status.isEmpty ? 'na' : sub.status,
                },
              )
              .toList(),
        });
      }

      await _api.createCabinSecurityTraining({
        'shipNumber': _ctrl.shipNumber.value.trim(),
        'gateId': gateId,
        'areaResults': areaResults,
        'detailedAreaResults': detailedAreaResults,
        if (_linkedHiddenObjectAuditId != null)
          'hiddenObjectAuditId': _linkedHiddenObjectAuditId,
        if (hiddenObjectLocationResults.isNotEmpty)
          'hiddenObjectLocationResults': hiddenObjectLocationResults,
        if (_ctrl.otherFindingsCtrl.text.trim().isNotEmpty)
          'otherFindings': _ctrl.otherFindingsCtrl.text.trim(),
        if (_buildSubmissionNotes() != null)
          'additionalNotes': _buildSubmissionNotes(),
        if (generalPictureFileIds.isNotEmpty)
          'generalPictureFileIds': generalPictureFileIds,
      });

      if (Get.isRegistered<CabinSecurityController>()) {
        await Get.find<CabinSecurityController>().loadTrainings();
      }

      if (!mounted) {
        return;
      }

      _didSubmitSuccessfully = true;
      CabinQualityAuditScreenN.clearSavedDraft();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: _C.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: _C.green,
                    size: 48.sp,
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Report Submitted!',
                  style: GoogleFonts.dmSans(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: _C.dark,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Your cabin security audit report has been submitted successfully.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    color: _C.grey,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: _C.bg,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      _summaryRow(
                        Icons.local_airport_rounded,
                        'Gate',
                        _ctrl.selectedGate.value,
                      ),
                      SizedBox(height: 6.h),
                      _summaryRow(
                        Icons.tag_rounded,
                        'Ship #',
                        _ctrl.shipNumber.value.trim(),
                      ),
                      SizedBox(height: 6.h),
                      _summaryRow(
                        Icons.location_on_rounded,
                        'Areas',
                        '${_ctrl.areaCards.length} inspected',
                      ),
                      if (hasLinkedHiddenObjectSummary) ...[
                        SizedBox(height: 6.h),
                        _summaryRow(
                          Icons.visibility_rounded,
                          'Found',
                          '$hiddenObjectFoundCount of $hiddenObjectTotalCount',
                          valueColor: hiddenObjectFoundCount > 0
                              ? _C.green
                              : _C.dark,
                        ),
                        SizedBox(height: 6.h),
                        _summaryRow(
                          Icons.visibility_off_rounded,
                          'Not Found',
                          '$hiddenObjectNotFoundCount',
                          valueColor: hiddenObjectNotFoundCount == 0
                              ? _C.green
                              : _C.red,
                        ),
                      ],
                      SizedBox(height: 6.h),
                      _summaryRow(
                        Icons.bar_chart_rounded,
                        'Result',
                        resultLabel,
                        valueColor: isPassed ? _C.green : _C.red,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    Get.back();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: _C.primary,
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Done',
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
        ),
      );
      return;
    } on ApiException catch (error) {
      Get.snackbar(
        'Submission Failed',
        error.message,
        backgroundColor: _C.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    } catch (_) {
      Get.snackbar(
        'Submission Failed',
        'Unable to submit this cabin security report right now.',
        backgroundColor: _C.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _summaryRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14.sp, color: _C.primary),
        SizedBox(width: 6.w),
        Text(
          '$label: ',
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            color: _C.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: valueColor ?? _C.dark,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // INSTRUCTION BANNER
  // ─────────────────────────────────────────────
  Widget _buildInstructionBanner() {
    const instructions = [
      'Hide Test objects and take pictures of where you hide them and then have the team search. Go back and mark the one they did not find.',
      'The goal is to find common areas of failure so we can focus on those areas for a TSA Audit.',
      'Do not tell agents how many objects were hidden.',
      'Only tell them where the objects are after the team says they have completed the search fully.',
      'Conduct Audits Proactive and Submit them as you do them; Do not wait until the End of the Shift to complete them.',
    ];
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _C.infoBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _C.infoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_rounded, color: _C.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Instructions',
                style: GoogleFonts.dmSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: _C.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ...instructions.asMap().entries.map(
            (e) => Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.key + 1}. ',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: _C.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.sp,
                        color: _C.dark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // LEGEND
  // ─────────────────────────────────────────────
  Widget _buildLegend() {
    return Wrap(
      spacing: 14.w,
      runSpacing: 6.h,
      children: [_legendDot(_C.green, 'Pass'), _legendDot(_C.red, 'Fail')],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.w,
          height: 10.h,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 10.sp, color: _C.grey),
        ),
      ],
    );
  }

  bool _hasDraftContent() {
    return _step > 0 ||
        _ctrl.selectedGate.value != 'Please Select One' ||
        _ctrl.shipNumber.value.trim().isNotEmpty ||
        _ctrl.selectedAreas.isNotEmpty ||
        _ctrl.areaCards.isNotEmpty ||
        _ctrl.selectedSeatIds.isNotEmpty ||
        _ctrl.mandatoryAreas.isNotEmpty ||
        _ctrl.auditedSeats.isNotEmpty ||
        _ctrl.otherFindingsCtrl.text.trim().isNotEmpty ||
        _ctrl.additionalNotesCtrl.text.trim().isNotEmpty ||
        _generalImages.isNotEmpty ||
        (_linkedHiddenObjectAuditId?.trim().isNotEmpty ?? false);
  }

  void _persistDraftIfNeeded() {
    if (_isSubmitting || _didSubmitSuccessfully) {
      return;
    }

    if (!_hasDraftContent()) {
      CabinQualityAuditScreenN.clearSavedDraft();
      return;
    }

    AuditDraftStore.saveDraft(
      id: CabinQualityAuditScreenN.draftStorageKey,
      type: AuditDraftType.cabinSecuritySearchTraining,
      title: 'Cabin Security Search Training',
      subtitle: 'Resume the selected areas, findings, and hidden object links.',
      shipNumber: _ctrl.shipNumber.value.trim(),
      gate: _ctrl.selectedGate.value,
      payload: {
        'savedAt': DateTime.now().toIso8601String(),
        'step': _step,
        'selectedAircraft': _ctrl.selectedAircraft.value,
        'selectedGate': _ctrl.selectedGate.value,
        'shipNumber': _ctrl.shipNumber.value.trim(),
        'supervisorName': _ctrl.supervisorName.value,
        'supervisorRole': _ctrl.supervisorRole.value,
        'otherFindings': _ctrl.otherFindingsCtrl.text.trim(),
        'additionalNotes': _ctrl.additionalNotesCtrl.text.trim(),
        'selectedAreas': _ctrl.selectedAreas.toList(),
        'selectedSeatIds': _ctrl.selectedSeatIds.toList(),
        'mandatoryAreas': _ctrl.mandatoryAreas.toList(),
        'auditedSeats': Map<String, String>.from(_ctrl.auditedSeats),
        'generalImages': _generalImages
            .map(_serializePendingUpload)
            .toList(growable: false),
        'linkedHiddenObjectAuditId': _linkedHiddenObjectAuditId,
        'hiddenObjectAreaByLocationId': Map<String, String>.from(
          _hiddenObjectAreaByLocationId,
        ),
        'areaCards': _ctrl.areaCards
            .map(_serializeAreaCard)
            .toList(growable: false),
      },
    );
  }

  void _restoreDraft() {
    final draft = AuditDraftStore.getPayload(
      CabinQualityAuditScreenN.draftStorageKey,
    );
    if (draft == null || draft.isEmpty) {
      return;
    }

    final draftAircraft = draft['selectedAircraft']?.toString().trim() ?? '';
    if (draftAircraft.isNotEmpty &&
        _ctrl.aircraftOptions.contains(draftAircraft)) {
      _ctrl.selectedAircraft.value = draftAircraft;
    }

    final draftGate = draft['selectedGate']?.toString().trim() ?? '';
    if (!_isGateLocked &&
        draftGate.isNotEmpty &&
        _ctrl.gateOptions.contains(draftGate)) {
      _ctrl.selectedGate.value = draftGate;
    }

    _ctrl.shipNumber.value = draft['shipNumber']?.toString() ?? '';
    _ctrl.supervisorName.value =
        draft['supervisorName']?.toString() ?? _ctrl.supervisorName.value;
    _ctrl.supervisorRole.value =
        draft['supervisorRole']?.toString() ?? _ctrl.supervisorRole.value;
    _ctrl.otherFindingsCtrl.text = draft['otherFindings']?.toString() ?? '';
    _ctrl.additionalNotesCtrl.text = draft['additionalNotes']?.toString() ?? '';
    _step = ((draft['step'] as num?)?.toInt() ?? 0).clamp(0, 2).toInt();

    _ctrl.selectedAreas.assignAll(_readStringList(draft['selectedAreas']));
    _ctrl.selectedSeatIds.assignAll(_readStringList(draft['selectedSeatIds']));
    _ctrl.mandatoryAreas.assignAll(_readStringList(draft['mandatoryAreas']));
    _ctrl.auditedSeats.assignAll(_readStringMap(draft['auditedSeats']));

    _generalImages.assignAll(_deserializeUploads(draft['generalImages']));

    _linkedHiddenObjectAuditId =
        draft['linkedHiddenObjectAuditId']?.toString().trim().isEmpty == true
        ? null
        : draft['linkedHiddenObjectAuditId']?.toString().trim();
    _hiddenObjectAreaByLocationId
      ..clear()
      ..addAll(_readStringMap(draft['hiddenObjectAreaByLocationId']));

    _ctrl.areaCards.assignAll(_deserializeAreaCards(draft['areaCards']));
    for (final card in _ctrl.areaCards) {
      _ctrl.imageUploadedMap[card.areaName] = card.imageUploaded;
    }
    _ctrl.subItemVersion.value++;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      Get.snackbar(
        'Draft Restored',
        'Your Cabin Security Search draft is ready to continue.',
        backgroundColor: _C.primary,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    });
  }

  Map<String, dynamic> _serializePendingUpload(PendingUploadFile upload) {
    return {
      'path': upload.localFile.path,
      'fileId': upload.fileId,
      'cloudinaryUrl': upload.cloudinaryUrl,
      'progress': upload.progress,
      'status': upload.status.name,
      'errorMessage': upload.errorMessage,
    };
  }

  PendingUploadFile? _deserializePendingUpload(dynamic raw) {
    final map = AuditDraftStore.normalizeMap(raw);
    final path = map['path']?.toString().trim() ?? '';
    if (path.isEmpty) {
      return null;
    }

    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }

    final rawStatus = map['status']?.toString().trim().toLowerCase() ?? '';
    var status = switch (rawStatus) {
      'completed' => PendingUploadStatus.completed,
      'failed' => PendingUploadStatus.failed,
      _ => PendingUploadStatus.failed,
    };
    final fileId = map['fileId']?.toString().trim();
    if (status == PendingUploadStatus.completed &&
        (fileId == null || fileId.isEmpty)) {
      status = PendingUploadStatus.failed;
    }

    return PendingUploadFile(
      localFile: file,
      fileId: fileId?.isNotEmpty == true ? fileId : null,
      cloudinaryUrl: map['cloudinaryUrl']?.toString().trim(),
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      status: status,
      errorMessage: status == PendingUploadStatus.failed
          ? (map['errorMessage']?.toString().trim().isNotEmpty == true
                ? map['errorMessage']?.toString().trim()
                : 'Upload was interrupted. Tap retry.')
          : map['errorMessage']?.toString().trim(),
    );
  }

  List<PendingUploadFile> _deserializeUploads(dynamic raw) {
    if (raw is! List) {
      return const <PendingUploadFile>[];
    }

    return raw
        .map(_deserializePendingUpload)
        .whereType<PendingUploadFile>()
        .toList(growable: false);
  }

  Map<String, dynamic> _serializeAreaCard(AreaCard card) {
    return {
      'areaName': card.areaName,
      'status': card.status,
      'images': card.images
          .map(_serializePendingUpload)
          .toList(growable: false),
      'subItems': card.subItems
          .map((sub) => {'itemName': sub.itemName, 'status': sub.status})
          .toList(growable: false),
    };
  }

  List<AreaCard> _deserializeAreaCards(dynamic raw) {
    if (raw is! List) {
      return const <AreaCard>[];
    }

    final cards = <AreaCard>[];
    for (final entry in raw) {
      final map = AuditDraftStore.normalizeMap(entry);
      final areaName = map['areaName']?.toString().trim() ?? '';
      if (areaName.isEmpty) {
        continue;
      }

      final card = AreaCard(areaName: areaName);
      card.status = map['status']?.toString() ?? '';
      card.images = _deserializeUploads(map['images']);

      final rawSubItems = map['subItems'];
      if (rawSubItems is List) {
        for (final subEntry in rawSubItems) {
          final subMap = AuditDraftStore.normalizeMap(subEntry);
          final itemName = subMap['itemName']?.toString().trim() ?? '';
          if (itemName.isEmpty) {
            continue;
          }
          final subItem = card.subItems.firstWhereOrNull(
            (item) => item.itemName == itemName,
          );
          if (subItem != null) {
            subItem.status = subMap['status']?.toString() ?? '';
          }
        }
      }

      cards.add(card);
    }
    return cards;
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

  Map<String, String> _readStringMap(dynamic raw) {
    if (raw is! Map) {
      return <String, String>{};
    }

    final mapped = <String, String>{};
    raw.forEach((key, value) {
      final normalizedKey = key.toString().trim();
      final normalizedValue = value?.toString().trim() ?? '';
      if (normalizedKey.isNotEmpty && normalizedValue.isNotEmpty) {
        mapped[normalizedKey] = normalizedValue;
      }
    });
    return mapped;
  }

  void _saveDraftManually() {
    _persistDraftIfNeeded();
    if (!CabinQualityAuditScreenN.hasSavedDraft()) {
      Get.snackbar(
        'Nothing To Save',
        'Select a few areas or notes first, then save the draft.',
        backgroundColor: _C.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    Get.snackbar(
      'Draft Saved',
      'Cabin Security Search draft saved successfully.',
      backgroundColor: _C.primary,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
    );
  }

  // ─────────────────────────────────────────────
  // SEAT MAP
  // ─────────────────────────────────────────────
  Widget _buildSeatMap() {
    double planeWidth = 330.w;
    return Obx(() {
      final aircraftMap = _ctrl.currentAircraftMap;
      return SizedBox(
        width: planeWidth,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // BACKGROUND PLANE SHAPE
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
                        color: _C.planeGrey,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(width: planeWidth, color: _C.planeGrey),
                  ),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: 0.90,
                      child: Image.asset(
                        'assets/images/tail.png',
                        width: planeWidth * 1.06,
                        fit: BoxFit.fitWidth,
                        color: _C.planeGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // FOREGROUND SEAT MAP
            Container(
              constraints: BoxConstraints(minHeight: planeWidth * 2.0),
              child: Column(
                children: [
                  SizedBox(height: 110.h),
                  _buildCockpitWindows(),
                  SizedBox(height: 100.h),

                  ...aircraftMap.sections.map((s) => _buildSection(s)),
                  SizedBox(height: 320.h),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCockpitWindows() {
    int windowCount = 6;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(windowCount, (i) {
        double indexOffset = i - (windowCount - 1) / 2;
        double angle = indexOffset * 0.25;
        double yOffset = (indexOffset.abs() * indexOffset.abs()) * 4;
        return Transform.translate(
          offset: Offset(0, yOffset),
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

  Widget _buildSection(SeatSection section) {
    return Column(
      children: [
        if (section.amenitiesBefore != null)
          ...section.amenitiesBefore!.map((a) {
            if (a.customLabel != null) return _buildClosetRow();
            return _buildAmenityRow(
              leftSvg: a.leftSvg,
              leftId: a.leftId,
              rightSvg: a.rightSvg,
              rightId: a.rightId,
              centerOnly: a.centerOnly,
            );
          }),
        if (section.hasExitBefore) _buildExitRow(),
        SizedBox(height: 4.h),
        if (section.name.isNotEmpty) _buildSectionLabel(section.name),
        SizedBox(height: 4.h),
        _buildColHeaders([...section.leftCols, '', ...section.rightCols]),
        SizedBox(height: 4.h),
        ...List.generate(section.endRow - section.startRow + 1, (i) {
          final rowNum = section.startRow + i;
          if (section.skipRows != null && section.skipRows!.contains(rowNum)) {
            return _buildSeatRow(
              rowNum: rowNum,
              leftCols: ['', ''],
              rightCols: section.rightCols,
            );
          }
          return _buildSeatRow(
            rowNum: rowNum,
            leftCols: section.leftCols,
            rightCols: section.rightCols,
          );
        }),
        SizedBox(height: 16.h),
        if (section.hasExitAfter) _buildExitRow(),
        if (section.amenitiesAfter != null)
          ...section.amenitiesAfter!.map(
            (a) => _buildAmenityRow(
              leftSvg: a.leftSvg,
              leftId: a.leftId,
              rightSvg: a.rightSvg,
              rightId: a.rightId,
              centerOnly: a.centerOnly,
            ),
          ),
      ],
    );
  }

  Widget _buildColHeaders(List<String> cols) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: cols
            .map(
              (c) => c.isEmpty
                  ? SizedBox(width: 28.w)
                  : SizedBox(
                      width: 34.w,
                      child: Center(
                        child: Text(
                          c,
                          style: GoogleFonts.dmSans(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: _C.grey,
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
            (col) => col.isEmpty ? SizedBox(width: 34.w) : _seat('$rowNum$col'),
          ),
          SizedBox(
            width: 28.w,
            child: Center(
              child: Text(
                '$rowNum',
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: _C.grey,
                ),
              ),
            ),
          ),
          ...rightCols.map(
            (col) => col.isEmpty ? SizedBox(width: 34.w) : _seat('$rowNum$col'),
          ),
        ],
      ),
    );
  }

  Widget _seat(String id) {
    return Obx(() {
      final status = _ctrl.auditedSeats[id];
      final isSelected = _ctrl.selectedSeatIds.contains(id);
      final color = status == 'pass'
          ? _C.green
          : status == 'fail'
          ? _C.red
          : isSelected
          ? _C.primary
          : _C.seatColor;
      return GestureDetector(
        onTap: () => _showAreaCardSheetForSeat(id),
        child: Container(
          width: 30.w,
          height: 32.h,
          margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
          child: CustomPaint(painter: _SeatPainter(color: color)),
        ),
      );
    });
  }

  Widget _buildAmenityRow({
    String? leftSvg,
    String? leftId,
    String? rightSvg,
    String? rightId,
    bool centerOnly = false,
  }) {
    if (centerOnly) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: _amenityBox(rightSvg!, rightId!),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 40.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (leftSvg != null && leftId != null)
            _amenityBox(leftSvg, leftId)
          else
            SizedBox(width: 44.w),
          if (rightSvg != null && rightId != null)
            _amenityBox(rightSvg, rightId)
          else
            SizedBox(width: 44.w),
        ],
      ),
    );
  }

  Widget _amenityBox(String svgPath, String id) {
    return Obx(() {
      final status = _ctrl.auditedSeats[id];
      final isSelected = _ctrl.selectedSeatIds.contains(id);
      final color = status == 'pass'
          ? _C.green
          : status == 'fail'
          ? _C.red
          : isSelected
          ? _C.primary
          : _C.seatColor;
      return GestureDetector(
        onTap: () => _showAreaCardSheetForSeat(id),
        child: Container(
          width: 44.w,
          height: 44.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10.r),
            border: isSelected
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
          child: Center(
            child: SvgPicture.asset(
              svgPath,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              width: 22.sp,
              height: 22.sp,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildExitRow() => Padding(
    padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 20.w),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '◁ Exit',
          style: GoogleFonts.dmSans(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: _C.grey,
          ),
        ),
        Text(
          'Exit ▷',
          style: GoogleFonts.dmSans(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: _C.grey,
          ),
        ),
      ],
    ),
  );

  Widget _buildClosetRow() => Padding(
    padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 40.w),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Closet',
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            color: _C.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        _amenityBox('assets/icons/toilet.svg', 'Closet'),
      ],
    ),
  );

  Widget _buildSectionLabel(String t) => Padding(
    padding: EdgeInsets.symmetric(vertical: 10.h),
    child: Center(
      child: Text(
        t,
        style: GoogleFonts.dmSans(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: _C.dark,
        ),
      ),
    ),
  );

  // ─────────────────────────────────────────────
  // AREA SEARCH FIELD
  // ─────────────────────────────────────────────
  // ─────────────────────────────────────────────
  // DYNAMIC AREA CARD — delegates to StatefulWidget
  // ─────────────────────────────────────────────
  Widget _buildAreaCard(AreaCard card) {
    return _AreaCardWidget(
      key: ValueKey(card.areaName),
      card: card,
      ctrl: _ctrl,
      pickImages: _pickValidatedImages,
      retryAreaUpload: (upload, areaName) =>
          _uploadPendingImage(upload, areaName: areaName),
    );
  }

  // Area icon helper
  IconData _areaCardIcon(String area) {
    final a = area.toLowerCase();
    if (a.contains('galley')) return Icons.restaurant_rounded;
    if (a.contains('lav')) return Icons.wc_rounded;
    if (a.contains('jump seat')) return Icons.event_seat_rounded;
    if (a.contains('first class') || a.contains('business')) {
      return Icons.airline_seat_recline_extra_rounded;
    }
    if (a.contains('comfort')) return Icons.airline_seat_recline_normal_rounded;
    if (a.contains('cabin') || a.contains('main')) return Icons.weekend_rounded;
    if (a.contains('overhead')) return Icons.inventory_2_outlined;
    if (a.contains('pocket')) return Icons.book_outlined;
    if (a.contains('crew')) return Icons.people_outline_rounded;
    if (a.contains('emergency')) return Icons.health_and_safety_outlined;
    return Icons.location_searching_rounded;
  }

  // ─────────────────────────────────────────────
  // SHARED HELPERS
  // ─────────────────────────────────────────────
  Widget _label(String t) => Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Text(
      t,
      style: GoogleFonts.dmSans(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: _C.primary,
      ),
    ),
  );

  TextStyle _fieldStyle() =>
      GoogleFonts.dmSans(fontSize: 15.sp, color: _C.dark);

  Widget _readOnlyField(String value, {IconData? icon}) => Container(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
    decoration: BoxDecoration(
      color: _C.inputBg,
      borderRadius: BorderRadius.circular(30.r),
      border: Border.all(color: _C.border),
    ),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18.sp, color: _C.grey),
          SizedBox(width: 10.w),
        ],
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.dmSans(fontSize: 14.sp, color: _C.grey),
          ),
        ),
        Icon(Icons.lock_outline_rounded, size: 14.sp, color: _C.border),
      ],
    ),
  );

  Widget _pillDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? suffixIcon,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      return PopupMenuButton<String>(
        onSelected: onChanged,
        offset: Offset(0, 58.h),
        constraints: BoxConstraints(
          minWidth: constraints.maxWidth,
          maxWidth: constraints.maxWidth,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        itemBuilder: (context) => items
            .map(
              (i) => PopupMenuItem(
                value: i,
                height: 40.h,
                child: Text(i, style: _fieldStyle()),
              ),
            )
            .toList(),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            children: [
              Expanded(child: Text(value, style: _fieldStyle())),
              Icon(
                suffixIcon ?? Icons.keyboard_arrow_down_rounded,
                color: _C.grey,
                size: 20.sp,
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _multilineField(String hint, {TextEditingController? controller}) =>
      TextField(
        controller: controller,
        maxLines: 4,
        style: _fieldStyle(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(fontSize: 14.sp, color: _C.grey),
          filled: true,
          fillColor: _C.white,
          contentPadding: EdgeInsets.all(16.w),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(color: _C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(color: _C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(color: _C.primary, width: 1.5),
          ),
        ),
      );

  Widget _uploadBox() => GestureDetector(
    onTap: () async {
      final files = await _pickValidatedImages();
      _generalImages.addAll(files);
      for (final upload in files) {
        unawaited(_uploadPendingImage(upload));
      }
    },
    child: Container(
      height: 52.h,
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, size: 20.sp, color: _C.grey),
          SizedBox(width: 8.w),
          Text(
            'Capture image',
            style: GoogleFonts.dmSans(fontSize: 14.sp, color: _C.grey),
          ),
          SizedBox(width: 6.w),
          Text(
            '(max 100MB each)',
            style: GoogleFonts.dmSans(fontSize: 10.sp, color: _C.grey),
          ),
        ],
      ),
    ),
  );

  Widget _nextButton(VoidCallback onTap) => Container(
    color: _C.white,
    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52.h,
        decoration: BoxDecoration(
          color: _C.primary,
          borderRadius: BorderRadius.circular(30.r),
        ),
        alignment: Alignment.center,
        child: Text(
          'NEXT',
          style: GoogleFonts.dmSans(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
    ),
  );

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _C.primary, size: 24.sp),
            SizedBox(width: 8.w),
            Text(
              'How to use',
              style: GoogleFonts.dmSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          '1. Read the instructions and reference image carefully.\n'
          '2. Fill in Gate and Ship # in Section 1.\n'
          '3. Tap seats on the map to select areas.\n'
          '4. Select aircraft type and review the seat map.\n'
          '5. Capture a reference photo for each selected area.\n'
          '6. Add findings, notes, and sign in Section 3 before submitting.',
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            color: _C.grey,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Got it',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                color: _C.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AREA CARD — StatefulWidget (owns image/subitem state)
// ─────────────────────────────────────────────
class _AreaCardWidget extends StatefulWidget {
  final AreaCard card;
  final CabinQualityController ctrl;
  final Future<List<PendingUploadFile>> Function() pickImages;
  final Future<void> Function(PendingUploadFile upload, String areaName)
  retryAreaUpload;
  final VoidCallback? onTrailingTap;
  final IconData trailingIcon;

  const _AreaCardWidget({
    required Key key,
    required this.card,
    required this.ctrl,
    required this.pickImages,
    required this.retryAreaUpload,
    this.onTrailingTap,
    this.trailingIcon = Icons.close_rounded,
  }) : super(key: key);

  @override
  State<_AreaCardWidget> createState() => _AreaCardWidgetState();
}

class _AreaCardWidgetState extends State<_AreaCardWidget> {
  AreaCard get card => widget.card;
  CabinQualityController get ctrl => widget.ctrl;

  // ── Phase 1: upload hiding photo ──────────────
  Future<void> _pickHideImages() async {
    final uploads = await widget.pickImages();
    if (uploads.isEmpty) return;
    for (final upload in uploads) {
      ctrl.addAreaImage(card.areaName, upload);
      unawaited(
        widget.retryAreaUpload(upload, card.areaName).whenComplete(() {
          if (mounted) {
            setState(() {});
          }
        }),
      );
    }
    setState(() {});
  }

  IconData _areaIcon(String area) {
    final a = area.toLowerCase();
    if (a.contains('galley')) return Icons.restaurant_rounded;
    if (a.contains('lav')) return Icons.wc_rounded;
    if (a.contains('jump seat')) return Icons.event_seat_rounded;
    if (a.contains('first class') || a.contains('business')) {
      return Icons.airline_seat_recline_extra_rounded;
    }
    if (a.contains('comfort')) return Icons.airline_seat_recline_normal_rounded;
    if (a.contains('cabin') || a.contains('main')) return Icons.weekend_rounded;
    if (a.contains('overhead')) return Icons.inventory_2_outlined;
    if (a.contains('pocket')) return Icons.book_outlined;
    if (a.contains('crew')) return Icons.people_outline_rounded;
    if (a.contains('emergency')) return Icons.health_and_safety_outlined;
    return Icons.location_searching_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final imageUploaded = card.imageUploaded;
    final hasUploadingImages = card.hasUploadingImages;
    final hasUploadErrors = card.hasUploadErrors;
    final overallStatus = card.computedStatus;

    final borderColor = overallStatus == 'pass'
        ? _C.green.withOpacity(0.45)
        : overallStatus == 'fail'
        ? _C.red.withOpacity(0.45)
        : _C.border;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: borderColor,
          width: overallStatus.isNotEmpty ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
            child: Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.h,
                  decoration: BoxDecoration(
                    color: _C.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    _areaIcon(card.areaName),
                    color: _C.primary,
                    size: 18.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.areaName,
                        style: GoogleFonts.dmSans(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: _C.dark,
                        ),
                      ),
                      Text(
                        imageUploaded
                            ? 'Reference photo uploaded'
                            : hasUploadingImages
                            ? 'Uploading reference photo...'
                            : hasUploadErrors
                            ? 'Reference photo upload failed'
                            : 'Reference photo required',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          color: imageUploaded
                              ? _C.green
                              : hasUploadErrors
                              ? _C.red
                              : _C.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap:
                      widget.onTrailingTap ??
                      () => ctrl.removeArea(card.areaName),
                  child: Icon(widget.trailingIcon, color: _C.grey, size: 18.sp),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: _C.border),

          // ── Phase 1: Upload hiding photo ─────────
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        color: imageUploaded ? _C.green : _C.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        imageUploaded
                            ? Icons.check_rounded
                            : Icons.looks_one_rounded,
                        color: Colors.white,
                        size: 12.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Capture reference photo *',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: imageUploaded ? _C.green : _C.dark,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                GestureDetector(
                  onTap: _pickHideImages,
                  child: Container(
                    height: 46.h,
                    decoration: BoxDecoration(
                      color: _C.white,
                      borderRadius: BorderRadius.circular(25.r),
                      border: Border.all(
                        color: imageUploaded
                            ? _C.green.withOpacity(0.5)
                            : _C.border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 18.sp,
                          color: imageUploaded ? _C.green : _C.grey,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          imageUploaded
                              ? 'Capture more photos'
                              : 'Capture reference photo (max 100MB)',
                          style: GoogleFonts.dmSans(
                            fontSize: 13.sp,
                            color: imageUploaded ? _C.green : _C.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (card.images.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  SizedBox(
                    height: 72.h,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: card.images.length,
                      itemBuilder: (_, i) => Stack(
                        children: [
                          Container(
                            width: 64.w,
                            height: 64.h,
                            margin: EdgeInsets.only(right: 8.w),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: _C.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: Image.file(
                                card.images[i].localFile,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          if (card.images[i].isUploading ||
                              card.images[i].hasError)
                            Positioned.fill(
                              child: Container(
                                width: 64.w,
                                height: 64.h,
                                margin: EdgeInsets.only(right: 8.w),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Center(
                                  child: card.images[i].isUploading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : IconButton(
                                          onPressed: () => unawaited(
                                            widget
                                                .retryAreaUpload(
                                                  card.images[i],
                                                  card.areaName,
                                                )
                                                .whenComplete(() {
                                                  if (mounted) {
                                                    setState(() {});
                                                  }
                                                }),
                                          ),
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 2,
                            right: 10,
                            child: GestureDetector(
                              onTap: () {
                                ctrl.removeAreaImage(card.areaName, i);
                                setState(() {});
                              },
                              child: Container(
                                padding: EdgeInsets.all(2.r),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 12.sp,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: imageUploaded ? _C.green.withOpacity(0.08) : _C.warnBg,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: imageUploaded
                      ? _C.green.withOpacity(0.28)
                      : _C.warnBorder.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    imageUploaded
                        ? Icons.check_circle_rounded
                        : Icons.photo_camera_back_outlined,
                    color: imageUploaded ? _C.green : const Color(0xFFAA7A00),
                    size: 14.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      imageUploaded
                          ? 'Reference photo uploaded. This area is complete.'
                          : hasUploadingImages
                          ? 'Reference photo is uploading. Submission will unlock as soon as it finishes.'
                          : hasUploadErrors
                          ? 'Reference photo upload failed. Retry or remove the failed image above.'
                          : 'Capture a reference photo above to complete this area.',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        color: imageUploaded
                            ? _C.green
                            : hasUploadErrors
                            ? _C.red
                            : const Color(0xFF7A5800),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────
class _SeatPainter extends CustomPainter {
  final Color color;
  const _SeatPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h * 0.58),
        const Radius.circular(5),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-1, h * 0.55, w + 2, h * 0.38),
        const Radius.circular(4),
      ),
      paint,
    );
    final armPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-3, h * 0.25, 4, h * 0.45),
        const Radius.circular(2),
      ),
      armPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - 1, h * 0.25, 4, h * 0.45),
        const Radius.circular(2),
      ),
      armPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SeatPainter old) => old.color != color;
}

// ignore: unused_element
class _PlaneSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
