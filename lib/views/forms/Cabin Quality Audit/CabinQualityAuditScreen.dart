import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../services/api_exception.dart';
import '../../../services/app_api_service.dart';

class _Colors {
  static const Color primary = Color(0xFF3D5AFE);
  static const Color background = Color(0xFFF5F6FA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color pass = Color(0xFF22C55E);
  static const Color fail = Color(0xFFEF4444);
  static const Color na = Color(0xFF9E9E9E);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color namePrimary = Color(0xFF1A1A2E);
  static const Color highlightBg = Color(0xFFEEF2FF);
}

enum AuditStatus { pass, fail, na }

extension AuditStatusExt on AuditStatus {
  String get label {
    switch (this) {
      case AuditStatus.pass:
        return 'Pass';
      case AuditStatus.fail:
        return 'Fail';
      case AuditStatus.na:
        return 'N/A';
    }
  }

  Color get color {
    switch (this) {
      case AuditStatus.pass:
        return _Colors.pass;
      case AuditStatus.fail:
        return _Colors.fail;
      case AuditStatus.na:
        return _Colors.na;
    }
  }

  IconData get icon {
    switch (this) {
      case AuditStatus.pass:
        return Icons.check_circle_rounded;
      case AuditStatus.fail:
        return Icons.cancel_rounded;
      case AuditStatus.na:
        return Icons.remove_circle_outline_rounded;
    }
  }
}

class CheckItemResult {
  final String itemName;
  final AuditStatus status;
  final List<String> pictures;
  final List<String> hashtags;

  CheckItemResult({
    required this.itemName,
    required this.status,
    this.pictures = const <String>[],
    this.hashtags = const <String>[],
  });
}

class AuditedAreaResult {
  final String areaId;
  final String sectionLabel;
  final String? areaGroup;
  final List<CheckItemResult> checkItems;
  final double? weightedScorePercent;
  final double? earnedPoints;
  final double? possiblePoints;
  final double? areaWeight;

  AuditedAreaResult({
    required this.areaId,
    required this.sectionLabel,
    required this.checkItems,
    this.areaGroup,
    this.weightedScorePercent,
    this.earnedPoints,
    this.possiblePoints,
    this.areaWeight,
  });

  AuditStatus get overallStatus {
    if (checkItems.any((c) => c.status == AuditStatus.fail)) {
      return AuditStatus.fail;
    }
    if (checkItems.any((c) => c.status == AuditStatus.pass)) {
      return AuditStatus.pass;
    }
    return AuditStatus.na;
  }

  int get passCount =>
      checkItems.where((c) => c.status == AuditStatus.pass).length;
  int get failCount =>
      checkItems.where((c) => c.status == AuditStatus.fail).length;
  int get naCount => checkItems.where((c) => c.status == AuditStatus.na).length;

  double get scorePercent {
    if (weightedScorePercent != null) {
      return weightedScorePercent!;
    }
    final applicable = checkItems
        .where((c) => c.status != AuditStatus.na)
        .toList();
    if (applicable.isEmpty) {
      return 0;
    }
    final passed = applicable.where((c) => c.status == AuditStatus.pass).length;
    return (passed / applicable.length) * 100;
  }

  List<String> get pictures => checkItems
      .expand((item) => item.pictures)
      .where((picture) => picture.trim().isNotEmpty)
      .toSet()
      .toList();
}

class CabinAuditDetailModel {
  final String auditorName;
  final String date;
  final String time;
  final String gate;
  final String shipNumber;
  final String flightNumber;
  final String type;
  final String aircraft;
  final String supervisor;
  final List<AuditedAreaResult> auditedAreas;
  final List<String> pictures;
  final String? notes;
  final double? weightedScorePercent;
  final double? earnedPoints;
  final double? possiblePoints;

  CabinAuditDetailModel({
    required this.auditorName,
    required this.date,
    required this.time,
    required this.gate,
    required this.shipNumber,
    required this.flightNumber,
    required this.type,
    required this.aircraft,
    required this.supervisor,
    required this.auditedAreas,
    required this.pictures,
    this.notes,
    this.weightedScorePercent,
    this.earnedPoints,
    this.possiblePoints,
  });

  factory CabinAuditDetailModel.empty() => CabinAuditDetailModel(
    auditorName: 'Cabin Quality Audit',
    date: '',
    time: '',
    gate: '',
    shipNumber: '',
    flightNumber: '',
    type: '',
    aircraft: '',
    supervisor: '',
    auditedAreas: const <AuditedAreaResult>[],
    pictures: const <String>[],
  );

  double get scorePercent {
    if (weightedScorePercent != null) {
      return weightedScorePercent!;
    }
    int total = 0;
    int passed = 0;
    for (final area in auditedAreas) {
      for (final item in area.checkItems) {
        if (item.status != AuditStatus.na) {
          total++;
          if (item.status == AuditStatus.pass) {
            passed++;
          }
        }
      }
    }
    if (total == 0) {
      return 0;
    }
    return (passed / total) * 100;
  }

  bool get hasAnyFail => auditedAreas.any(
    (area) => area.checkItems.any((c) => c.status == AuditStatus.fail),
  );
}

class _ParsedNotes {
  const _ParsedNotes({
    required this.aircraft,
    required this.supervisor,
    required this.shipNumber,
    required this.flightNumber,
    required this.notes,
  });

  final String aircraft;
  final String supervisor;
  final String shipNumber;
  final String flightNumber;
  final String notes;
}

class _ParsedScoreSummary {
  const _ParsedScoreSummary({
    required this.scorePercent,
    required this.earnedPoints,
    required this.possiblePoints,
  });

  final double scorePercent;
  final double earnedPoints;
  final double possiblePoints;
}

class CabinQualityAuditController extends GetxController {
  CabinQualityAuditController({required this.api});

  final AppApiService api;
  final Rx<CabinAuditDetailModel> detail = CabinAuditDetailModel.empty().obs;
  final RxBool isLoading = false.obs;
  final Rx<AuditStatus?> filter = Rx<AuditStatus?>(null);
  final RxString currentDate = ''.obs;
  final RxInt expandedAreaIndex = RxInt(-1);

  Future<void> loadAudit(String id) async {
    isLoading.value = true;
    expandedAreaIndex.value = -1;

    try {
      final response = await api.getCabinQualityAudit(id);
      final auditAt = DateTime.tryParse(
        response['auditAt']?.toString() ?? '',
      )?.toLocal();
      final parsedNotes = _parseNotes(
        otherFindings: response['otherFindings']?.toString(),
        additionalNotes: response['additionalNotes']?.toString(),
      );
      final parsedScoreSummary = _parseScoreSummary(response['scoreSummary']);
      final detailedResults = _parseDetailedAreas(
        response['detailedResultsJson'],
      );
      final fallbackResponses = List<Map<String, dynamic>>.from(
        (response['responses'] as List?) ?? const <dynamic>[],
      );
      final files = List<Map<String, dynamic>>.from(
        (response['files'] as List?) ?? const <dynamic>[],
      );

      detail.value = CabinAuditDetailModel(
        auditorName:
            (response['auditorNameSnapshot'] as String?)?.trim() ?? 'Unknown',
        date: auditAt == null ? '' : DateFormat('MMM d, y').format(auditAt),
        time: auditAt == null ? '' : DateFormat('h:mm a').format(auditAt),
        gate: _formatGateLabel(response['gateCodeSnapshot']?.toString() ?? ''),
        shipNumber:
            (response['shipNumber'] as String?)?.trim().isNotEmpty == true
            ? (response['shipNumber'] as String).trim()
            : parsedNotes.shipNumber,
        flightNumber:
            (response['flightNumber'] as String?)?.trim().isNotEmpty == true
            ? (response['flightNumber'] as String).trim()
            : parsedNotes.flightNumber,
        type: (response['cleanTypeSnapshot'] as String?)?.trim() ?? '',
        aircraft: parsedNotes.aircraft,
        supervisor: parsedNotes.supervisor,
        auditedAreas: detailedResults.isNotEmpty
            ? detailedResults
            : fallbackResponses.map(_mapFallbackResponseToArea).toList(),
        pictures: files
            .map((entry) => entry['fileId']?.toString() ?? '')
            .where((entry) => entry.isNotEmpty)
            .map(api.buildFileContentUrl)
            .toList(),
        notes: parsedNotes.notes,
        weightedScorePercent: parsedScoreSummary?.scorePercent,
        earnedPoints: parsedScoreSummary?.earnedPoints,
        possiblePoints: parsedScoreSummary?.possiblePoints,
      );

      currentDate.value = auditAt == null
          ? ''
          : DateFormat('MMM d, y • h:mm a').format(auditAt);
    } on ApiException catch (error) {
      Get.snackbar(
        'Audit Unavailable',
        error.message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      Get.snackbar(
        'Audit Unavailable',
        'Unable to load this cabin quality audit right now.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  List<AuditedAreaResult> _parseDetailedAreas(dynamic raw) {
    if (raw is! List) {
      return const <AuditedAreaResult>[];
    }

    return raw
        .map((entry) => _asMap(entry))
        .where((entry) => entry.isNotEmpty)
        .map((entry) {
          final rawItems = List<dynamic>.from(
            entry['checkItems'] as List? ?? const <dynamic>[],
          );

          return AuditedAreaResult(
            areaId: entry['areaId']?.toString().trim() ?? '',
            sectionLabel: entry['sectionLabel']?.toString().trim() ?? 'Area',
            areaGroup: entry['areaGroup']?.toString().trim(),
            weightedScorePercent: _asDouble(entry['scorePercent']),
            earnedPoints: _asDouble(entry['earnedPoints']),
            possiblePoints: _asDouble(entry['possiblePoints']),
            areaWeight: _asDouble(entry['areaWeight']),
            checkItems: rawItems
                .map((item) => _asMap(item))
                .where((item) => item.isNotEmpty)
                .map(
                  (item) => CheckItemResult(
                    itemName: item['itemName']?.toString().trim() ?? 'Item',
                    status: _mapAuditStatus(item['status']?.toString() ?? 'na'),
                    pictures:
                        List<dynamic>.from(
                              item['imageFileIds'] as List? ??
                                  const <dynamic>[],
                            )
                            .map((fileId) => fileId.toString().trim())
                            .where((fileId) => fileId.isNotEmpty)
                            .map(api.buildFileContentUrl)
                            .toList(),
                    hashtags:
                        List<dynamic>.from(
                              item['hashtags'] as List? ?? const <dynamic>[],
                            )
                            .map((tag) => tag.toString().trim())
                            .where((tag) => tag.isNotEmpty)
                            .toList(),
                  ),
                )
                .toList(),
          );
        })
        .where((area) => area.checkItems.isNotEmpty)
        .toList();
  }

  _ParsedScoreSummary? _parseScoreSummary(dynamic raw) {
    final data = _asMap(raw);
    if (data.isEmpty) {
      return null;
    }

    final scorePercent = _asDouble(data['scorePercent']);
    final earnedPoints = _asDouble(data['earnedPoints']);
    final possiblePoints = _asDouble(data['possiblePoints']);
    if (scorePercent == null ||
        earnedPoints == null ||
        possiblePoints == null) {
      return null;
    }

    return _ParsedScoreSummary(
      scorePercent: scorePercent,
      earnedPoints: earnedPoints,
      possiblePoints: possiblePoints,
    );
  }

  AuditedAreaResult _mapFallbackResponseToArea(Map<String, dynamic> item) {
    final checklistItem = item['checklistItem'] is Map<String, dynamic>
        ? item['checklistItem'] as Map<String, dynamic>
        : <String, dynamic>{};
    final label = (checklistItem['label'] as String?)?.trim() ?? 'Checklist';
    final files = List<Map<String, dynamic>>.from(
      (item['files'] as List?) ?? const <dynamic>[],
    );

    return AuditedAreaResult(
      areaId: label,
      sectionLabel: label,
      checkItems: [
        CheckItemResult(
          itemName: label,
          status: _mapAuditStatus(item['response']?.toString() ?? 'NA'),
          pictures: files
              .map((entry) => entry['fileId']?.toString() ?? '')
              .where((entry) => entry.isNotEmpty)
              .map(api.buildFileContentUrl)
              .toList(),
        ),
      ],
    );
  }

  AuditStatus _mapAuditStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'yes':
      case 'pass':
        return AuditStatus.pass;
      case 'no':
      case 'fail':
        return AuditStatus.fail;
      default:
        return AuditStatus.na;
    }
  }

  String _formatGateLabel(String gateCode) {
    final trimmed = gateCode.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    return trimmed.toLowerCase().startsWith('gate ')
        ? trimmed
        : 'Gate $trimmed';
  }

  _ParsedNotes _parseNotes({String? otherFindings, String? additionalNotes}) {
    String aircraft = '';
    String supervisor = '';
    String shipNumber = '';
    String flightNumber = '';
    final noteBlocks = <String>[];

    final findings = otherFindings?.trim() ?? '';
    if (findings.isNotEmpty) {
      noteBlocks.add('Other Findings\n$findings');
    }

    final rawAdditional = additionalNotes?.trim() ?? '';
    if (rawAdditional.isNotEmpty) {
      final noteLines = <String>[];
      for (final line in rawAdditional.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          if (noteLines.isNotEmpty && noteLines.last.isNotEmpty) {
            noteLines.add('');
          }
          continue;
        }
        if (trimmed.startsWith('Aircraft:')) {
          aircraft = trimmed.substring('Aircraft:'.length).trim();
          continue;
        }
        if (trimmed.startsWith('Supervisor/Lead:')) {
          supervisor = trimmed.substring('Supervisor/Lead:'.length).trim();
          continue;
        }
        if (trimmed.startsWith('Ship Number:')) {
          shipNumber = trimmed.substring('Ship Number:'.length).trim();
          continue;
        }
        if (trimmed.startsWith('Flight Number:')) {
          flightNumber = trimmed.substring('Flight Number:'.length).trim();
          continue;
        }
        noteLines.add(trimmed);
      }

      final cleanedNotes = noteLines.join('\n').trim();
      if (cleanedNotes.isNotEmpty) {
        noteBlocks.add('Additional Notes\n$cleanedNotes');
      }
    }

    return _ParsedNotes(
      aircraft: aircraft,
      supervisor: supervisor,
      shipNumber: shipNumber,
      flightNumber: flightNumber,
      notes: noteBlocks.join('\n\n').trim(),
    );
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

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  void previousDate() {}

  void nextDate() {}

  void toggleArea(int index) {
    expandedAreaIndex.value = expandedAreaIndex.value == index ? -1 : index;
  }
}

class CabinQualityAuditScreen extends StatefulWidget {
  const CabinQualityAuditScreen({super.key, this.auditId});

  final String? auditId;

  @override
  State<CabinQualityAuditScreen> createState() =>
      _CabinQualityAuditScreenState();
}

class _CabinQualityAuditScreenState extends State<CabinQualityAuditScreen> {
  late final CabinQualityAuditController controller;
  late final String _controllerTag;
  final PageController _pageController = PageController();
  final RxInt _currentPage = 0.obs;

  @override
  void initState() {
    super.initState();
    _controllerTag = widget.auditId?.trim().isNotEmpty ?? false
        ? widget.auditId!.trim()
        : 'cabin-quality-detail-${identityHashCode(this)}';
    controller = Get.put(
      CabinQualityAuditController(api: Get.find<AppApiService>()),
      tag: _controllerTag,
    );
    if ((widget.auditId?.trim().isNotEmpty ?? false)) {
      controller.loadAudit(widget.auditId!.trim());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
    if (Get.isRegistered<CabinQualityAuditController>(tag: _controllerTag)) {
      Get.delete<CabinQualityAuditController>(tag: _controllerTag);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.background,
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Column(
              children: [
                _buildAppBar(),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildDateNavigation(),
                      _buildScoreCard(),
                      _buildInfoCard(),
                      _buildAuditedAreasList(),
                      _buildPicturesCard(),
                      _buildNotesCard(),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Icon(Icons.arrow_back, color: _Colors.primary, size: 22.sp),
          ),
          Expanded(
            child: Text(
              'Cabin Quality Audit',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: _Colors.primary,
              ),
            ),
          ),
          GestureDetector(
            onTap: _showFilterSheet,
            child: Icon(Icons.tune, color: _Colors.primary, size: 24.sp),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: _Colors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Status',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: _Colors.primary,
              ),
            ),
            SizedBox(height: 16.h),
            _filterOption('All', null),
            _filterOption('Pass', AuditStatus.pass),
            _filterOption('Fail', AuditStatus.fail),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }

  Widget _filterOption(String label, AuditStatus? status) {
    return Obx(() {
      final isSelected = controller.filter.value == status;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          status == null ? Icons.all_inclusive_rounded : status.icon,
          color: status == null ? _Colors.primary : status.color,
        ),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? _Colors.primary : _Colors.namePrimary,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_rounded, color: _Colors.primary)
            : null,
        onTap: () {
          controller.filter.value = status;
          controller.expandedAreaIndex.value = -1;
          Get.back();
        },
      );
    });
  }

  Widget _buildDateNavigation() {
    return Container(
      color: Colors.white,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: controller.previousDate,
              child: Icon(
                Icons.chevron_left,
                color: _Colors.primary,
                size: 24.sp,
              ),
            ),
            Expanded(
              child: Text(
                controller.currentDate.value.isEmpty
                    ? 'Audit Details'
                    : controller.currentDate.value,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: _Colors.primary,
                ),
              ),
            ),
            GestureDetector(
              onTap: controller.nextDate,
              child: Icon(
                Icons.chevron_right,
                color: _Colors.primary,
                size: 24.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Obx(() {
      final d = controller.detail.value;
      final score = d.scorePercent;
      final isGood = !d.hasAnyFail;
      final scoreColor = isGood ? _Colors.pass : _Colors.fail;
      final failAreaCount = d.auditedAreas
          .where((a) => a.overallStatus == AuditStatus.fail)
          .length;

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: scoreColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: scoreColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 64.w,
              height: 64.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scoreColor,
              ),
              child: Center(
                child: Text(
                  '${score.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGood ? 'Audit Passed' : 'Audit Failed',
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: scoreColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${d.auditedAreas.length} areas audited  •  $failAreaCount failed',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: _Colors.textGrey,
                    ),
                  ),
                  if (d.earnedPoints != null && d.possiblePoints != null) ...[
                    SizedBox(height: 3.h),
                    Text(
                      '${d.earnedPoints!.toStringAsFixed(2)} / ${d.possiblePoints!.toStringAsFixed(2)} weighted pts',
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: _Colors.textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (!isGood) ...[
                    SizedBox(height: 3.h),
                    Text(
                      'Any failed item = audit FAIL',
                      style: GoogleFonts.poppins(
                        fontSize: 10.sp,
                        color: _Colors.fail,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildInfoCard() {
    return Obx(() {
      final d = controller.detail.value;
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: _Colors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4.w,
                  height: 22.h,
                  decoration: BoxDecoration(
                    color: _Colors.primary,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    d.auditorName,
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: _Colors.namePrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _infoRow('${d.date}  •  ${d.time}', isGrey: true),
            SizedBox(height: 8.h),
            _infoRow(d.gate),
            SizedBox(height: 10.h),
            Divider(color: _Colors.divider, height: 1),
            SizedBox(height: 12.h),
            _labelValue(
              'Ship',
              d.shipNumber.isEmpty ? 'Not provided' : d.shipNumber,
            ),
            SizedBox(height: 8.h),
            _labelValue(
              'Flight Number',
              d.flightNumber.isEmpty ? 'Not provided' : d.flightNumber,
            ),
            SizedBox(height: 8.h),
            _labelValue('Type', d.type.isEmpty ? 'Not provided' : d.type),
            SizedBox(height: 8.h),
            _labelValue(
              'Aircraft',
              d.aircraft.isEmpty ? 'Not provided' : d.aircraft,
            ),
            if (d.supervisor.isNotEmpty) ...[
              SizedBox(height: 8.h),
              _labelValue('Supervisor', d.supervisor),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildAuditedAreasList() {
    return Obx(() {
      final d = controller.detail.value;
      final currentFilter = controller.filter.value;

      final filteredAreas = d.auditedAreas.where((area) {
        if (currentFilter == null) {
          return true;
        }
        if (area.overallStatus == currentFilter) {
          return true;
        }
        return area.checkItems.any((c) => c.status == currentFilter);
      }).toList();

      if (filteredAreas.isEmpty) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: _Colors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Center(
            child: Text(
              'No sections match the selected filter.',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: _Colors.textGrey,
              ),
            ),
          ),
        );
      }

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: _Colors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 20.h,
                    decoration: BoxDecoration(
                      color: _Colors.primary,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Audited Areas',
                      style: GoogleFonts.poppins(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: _Colors.namePrimary,
                      ),
                    ),
                  ),
                  if (currentFilter != null) _statusBadge(currentFilter),
                ],
              ),
            ),
            Divider(height: 1, color: _Colors.divider),
            ...List.generate(filteredAreas.length, (index) {
              final area = filteredAreas[index];
              final isExpanded = controller.expandedAreaIndex.value == index;
              return _buildAreaTile(area, index, isExpanded);
            }),
            SizedBox(height: 4.h),
          ],
        ),
      );
    });
  }

  Widget _buildAreaTile(AuditedAreaResult area, int index, bool isExpanded) {
    final overall = area.overallStatus;
    return Column(
      children: [
        InkWell(
          onTap: () => controller.toggleArea(index),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                Container(
                  width: 38.w,
                  height: 38.h,
                  decoration: BoxDecoration(
                    color: _Colors.highlightBg,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    _sectionIcon(area.sectionLabel),
                    color: _Colors.primary,
                    size: 18.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        area.sectionLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: _Colors.namePrimary,
                        ),
                      ),
                      Text(
                        'Area: ${area.areaId}  •  ${area.passCount}P  ${area.failCount}F  ${area.naCount}N/A',
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: _Colors.textGrey,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final pct = area.scorePercent / 100;
                          final barColor = overall == AuditStatus.fail
                              ? _Colors.fail
                              : _Colors.pass;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4.r),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 5.h,
                                      width: constraints.maxWidth,
                                      color: barColor.withOpacity(0.15),
                                    ),
                                    Container(
                                      height: 5.h,
                                      width: constraints.maxWidth * pct,
                                      color: barColor,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                '${area.scorePercent.toStringAsFixed(0)}% score',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: barColor,
                                ),
                              ),
                              // if (area.earnedPoints != null &&
                              //     area.possiblePoints != null) ...[
                              //   SizedBox(height: 2.h),
                              //   Text(
                              //     '${area.earnedPoints!.toStringAsFixed(2)} / ${area.possiblePoints!.toStringAsFixed(2)} pts',
                              //     style: GoogleFonts.poppins(
                              //       fontSize: 10.sp,
                              //       color: _Colors.textGrey,
                              //     ),
                              //   ),
                              // ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _statusBadge(overall),
                SizedBox(width: 8.w),
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _Colors.textGrey,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) _buildExpandedItems(area),
        Divider(height: 1, color: _Colors.divider),
      ],
    );
  }

  Widget _buildExpandedItems(AuditedAreaResult area) {
    final currentFilter = controller.filter.value;
    final itemsToShow = area.checkItems.where((item) {
      if (item.status == AuditStatus.na) {
        return false;
      }
      if (currentFilter != null && item.status != currentFilter) {
        return false;
      }
      return true;
    }).toList();

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _Colors.background,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (itemsToShow.isEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(
                'No audited items in this section.',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: _Colors.textGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ] else ...[
            ...itemsToShow.map((item) => _buildCheckItemDetail(item)),
          ],
          if (area.pictures.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Divider(color: _Colors.divider),
            SizedBox(height: 8.h),
            Text(
              'Attachments for ${area.sectionLabel}',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _Colors.namePrimary,
              ),
            ),
            SizedBox(height: 8.h),
            _buildAreaPictures(area.pictures),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckItemDetail(CheckItemResult item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.status.icon, color: item.status.color, size: 16.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  item.itemName,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: _Colors.namePrimary,
                  ),
                ),
              ),
              _statusChip(item.status),
            ],
          ),
          if (item.hashtags.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.only(left: 26.w),
              child: Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: item.hashtags
                    .map(
                      (tag) => Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: _Colors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.poppins(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: _Colors.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (item.pictures.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.only(left: 26.w),
              child: _buildAreaPictures(item.pictures),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAreaPictures(List<String> pictures) {
    return SizedBox(
      height: 80.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pictures.length,
        itemBuilder: (context, i) {
          return Container(
            width: 80.w,
            margin: EdgeInsets.only(right: 8.w),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: _buildImageContent(
                pictures[i],
                width: 80.w,
                height: 80.h,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPicturesCard() {
    return Obx(() {
      final d = controller.detail.value;
      if (d.pictures.isEmpty) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: _Colors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Other Findings & Pictures'),
            SizedBox(height: 12.h),
            _buildImageSlider(d.pictures),
          ],
        ),
      );
    });
  }

  Widget _buildNotesCard() {
    return Obx(() {
      final d = controller.detail.value;
      if (d.notes == null || d.notes!.isEmpty) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: _Colors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Notes & Findings'),
            SizedBox(height: 10.h),
            Text(
              d.notes!,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: _Colors.textGrey,
                height: 1.6,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildImageSlider(List<String> images) {
    return Column(
      children: [
        SizedBox(
          height: 180.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => _currentPage.value = i,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: _buildImageContent(
                  images[index],
                  width: double.infinity,
                  height: 180.h,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
        SizedBox(height: 10.h),
        Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (index) {
              final isActive = _currentPage.value == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: isActive ? 18.w : 6.w,
                height: 6.h,
                decoration: BoxDecoration(
                  color: isActive ? _Colors.primary : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3.r),
                ),
              );
            }),
          ),
        ),
        SizedBox(height: 8.h),
      ],
    );
  }

  Widget _buildImageContent(
    String imagePath, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    final imageHeaders = Get.find<AppApiService>().buildImageHeaders();

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        headers: imageHeaders,
        errorBuilder: (context, error, stackTrace) =>
            _buildMissingImage(width, height),
      );
    }

    return _buildMissingImage(width, height);
  }

  Widget _buildMissingImage(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Icon(
        Icons.image_outlined,
        color: Colors.grey.shade400,
        size: 40.sp,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 20.h,
          decoration: BoxDecoration(
            color: _Colors.primary,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: _Colors.namePrimary,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String text, {bool isGrey = false}) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13.sp,
        color: isGrey ? _Colors.textGrey : _Colors.namePrimary,
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label : ',
          style: GoogleFonts.poppins(fontSize: 13.sp, color: _Colors.textGrey),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: _Colors.namePrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(AuditStatus status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: status.color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.poppins(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }

  Widget _statusChip(AuditStatus status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.poppins(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }

  IconData _sectionIcon(String label) {
    switch (label.toLowerCase()) {
      case 'first class':
      case 'business class':
        return Icons.airline_seat_recline_extra_rounded;
      case 'comfort':
      case 'comfort+':
        return Icons.airline_seat_recline_normal_rounded;
      case 'main cabin':
      case 'economy':
        return Icons.weekend_rounded;
      case 'lav':
      case 'lav / restroom':
        return Icons.wc_rounded;
      case 'galley':
        return Icons.restaurant_rounded;
      default:
        return Icons.event_seat_rounded;
    }
  }
}
