import 'package:avislap/utils/app_colors.dart';
import 'package:avislap/config/app_permission_codes.dart';
import 'package:avislap/views/forms/cabin%20security%20search/cabin_secuirity.dart';
import 'package:avislap/views/forms/cabin%20security%20search/training_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../services/api_exception.dart';
import '../../../services/app_api_service.dart';
import '../../../services/session_service.dart';

class _Colors {
  static const Color primary = Color(0xFF3D5AFE);
  static const Color background = Color(0xFFF5F6FA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color dotColor = Color(0xFF9E9E9E);
  static const Color namePrimary = Color(0xFF1A1A2E);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color pass = Color(0xFF22C55E);
  static const Color fail = Color(0xFFEF4444);
  static const Color na = Color(0xFF9E9E9E);
  static const Color highlightBg = Color(0xFFEEF2FF);
  static const Color newAuditBtn = Color(0xFF3D5AFE);
}

enum SecurityAuditStatus { pass, fail, na }

extension SecurityAuditStatusExt on SecurityAuditStatus {
  String get label {
    switch (this) {
      case SecurityAuditStatus.pass:
        return 'Pass';
      case SecurityAuditStatus.fail:
        return 'Fail';
      case SecurityAuditStatus.na:
        return 'N/A';
    }
  }

  Color get color {
    switch (this) {
      case SecurityAuditStatus.pass:
        return _Colors.pass;
      case SecurityAuditStatus.fail:
        return _Colors.fail;
      case SecurityAuditStatus.na:
        return _Colors.na;
    }
  }

  IconData get icon {
    switch (this) {
      case SecurityAuditStatus.pass:
        return Icons.check_circle_rounded;
      case SecurityAuditStatus.fail:
        return Icons.cancel_rounded;
      case SecurityAuditStatus.na:
        return Icons.remove_circle_outline_rounded;
    }
  }
}

class SecurityCheckItemResult {
  const SecurityCheckItemResult({
    required this.itemName,
    required this.status,
    this.pictures = const <String>[],
    this.hashtags = const <String>[],
  });

  final String itemName;
  final SecurityAuditStatus status;
  final List<String> pictures;
  final List<String> hashtags;
}

class SecurityAreaDetailResult {
  const SecurityAreaDetailResult({
    required this.areaId,
    required this.sectionLabel,
    required this.checkItems,
    this.areaPictures = const <String>[],
  });

  final String areaId;
  final String sectionLabel;
  final List<SecurityCheckItemResult> checkItems;
  final List<String> areaPictures;

  SecurityAuditStatus get overallStatus {
    if (checkItems.any((item) => item.status == SecurityAuditStatus.fail)) {
      return SecurityAuditStatus.fail;
    }
    if (checkItems.any((item) => item.status == SecurityAuditStatus.pass)) {
      return SecurityAuditStatus.pass;
    }
    if (areaPictures.isNotEmpty) {
      return SecurityAuditStatus.pass;
    }
    return SecurityAuditStatus.na;
  }

  List<String> get allPictures {
    final merged = <String>[];
    final seen = <String>{};

    for (final picture in [
      ...areaPictures,
      ...checkItems.expand((item) => item.pictures),
    ]) {
      final normalized = picture.trim();
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      merged.add(normalized);
    }

    return merged;
  }

  int get passCount => checkItems
      .where((item) => item.status == SecurityAuditStatus.pass)
      .length;

  int get failCount => checkItems
      .where((item) => item.status == SecurityAuditStatus.fail)
      .length;

  int get naCount =>
      checkItems.where((item) => item.status == SecurityAuditStatus.na).length;

  double get scorePercent {
    final applicable = checkItems
        .where((item) => item.status != SecurityAuditStatus.na)
        .toList();
    if (applicable.isEmpty) {
      return 0;
    }
    final passed = applicable
        .where((item) => item.status == SecurityAuditStatus.pass)
        .length;
    return (passed / applicable.length) * 100;
  }
}

class _ParsedTrainingNotes {
  const _ParsedTrainingNotes({
    required this.aircraft,
    required this.supervisorRole,
    required this.notes,
  });

  final String aircraft;
  final String supervisorRole;
  final String notes;
}

class TrainingItem {
  const TrainingItem({
    required this.id,
    required this.observerName,
    required this.date,
    required this.time,
    required this.dateTime,
    required this.gate,
    required this.isPassed,
    this.shipNumber = '',
    this.role = '',
    this.pictures = const <String>[],
    this.areaResults = const <SecurityAreaDetailResult>[],
    this.otherFindings = '',
    this.additionalNotes = '',
    this.aircraft = '',
    this.supervisorName = '',
    this.supervisorRole = '',
  });

  final String id;
  final String observerName;
  final String date;
  final String time;
  final DateTime dateTime;
  final String gate;
  final String shipNumber;
  final String role;
  final List<String> pictures;
  final bool isPassed;
  final List<SecurityAreaDetailResult> areaResults;
  final String otherFindings;
  final String additionalNotes;
  final String aircraft;
  final String supervisorName;
  final String supervisorRole;

  int get passAreaCount => areaResults
      .where((area) => area.overallStatus == SecurityAuditStatus.pass)
      .length;

  int get failAreaCount => areaResults
      .where((area) => area.overallStatus == SecurityAuditStatus.fail)
      .length;

  bool get hasAnyFail => areaResults.any(
    (area) =>
        area.checkItems.any((item) => item.status == SecurityAuditStatus.fail),
  );

  bool get passedOverall => areaResults.isEmpty ? isPassed : !hasAnyFail;

  double get scorePercent {
    int total = 0;
    int passed = 0;

    for (final area in areaResults) {
      for (final item in area.checkItems) {
        if (item.status == SecurityAuditStatus.na) {
          continue;
        }
        total++;
        if (item.status == SecurityAuditStatus.pass) {
          passed++;
        }
      }
    }

    if (total == 0) {
      if (areaResults.isEmpty) {
        return 0;
      }
      return (passAreaCount / areaResults.length) * 100;
    }

    return (passed / total) * 100;
  }
}

class CabinSecurityController extends GetxController {
  final AppApiService _api = Get.find<AppApiService>();
  final RxList<TrainingItem> _allTrainings = <TrainingItem>[].obs;
  final RxList<TrainingItem> filteredTrainings = <TrainingItem>[].obs;
  final RxInt expandedAreaIndex = (-1).obs;
  final RxBool isLoading = true.obs;
  final RxString filterName = ''.obs;
  final RxString filterFromDate = ''.obs;
  final RxString filterToDate = ''.obs;
  final RxSet<String> filterResults = <String>{}.obs;

  bool get hasActiveFilter =>
      filterName.isNotEmpty ||
      filterFromDate.isNotEmpty ||
      filterToDate.isNotEmpty ||
      filterResults.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    loadTrainings();
  }

  void toggleArea(int index) {
    expandedAreaIndex.value = expandedAreaIndex.value == index ? -1 : index;
  }

  Future<void> loadTrainings() async {
    isLoading.value = true;

    try {
      final response = await _api.listCabinSecurityTrainings(
        queryParameters: {'page': 1, 'limit': 100},
      );

      final items = List<Map<String, dynamic>>.from(
        (response['items'] as List?) ?? const <dynamic>[],
      );

      _allTrainings.assignAll(items.map(_mapTrainingListItem));
      _applyFilter();
    } on ApiException catch (error) {
      _allTrainings.clear();
      filteredTrainings.clear();
      Get.snackbar(
        'Trainings Unavailable',
        error.message,
        backgroundColor: _Colors.fail,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (_) {
      _allTrainings.clear();
      filteredTrainings.clear();
      Get.snackbar(
        'Trainings Unavailable',
        'Unable to load cabin security records right now.',
        backgroundColor: _Colors.fail,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<TrainingItem> loadTrainingDetail(String id) async {
    final response = await _api.getCabinSecurityTraining(id);
    return _mapTrainingDetail(response);
  }

  TrainingItem _mapTrainingListItem(Map<String, dynamic> item) {
    final trainingAt = DateTime.tryParse(
      item['trainingAt']?.toString() ?? '',
    )?.toLocal();
    final thumbnails = List<dynamic>.from(
      item['thumbnails'] as List? ?? const <dynamic>[],
    );
    final pictureUrls = thumbnails
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .map(_api.buildFileContentUrl)
        .toList();

    return TrainingItem(
      id: item['id']?.toString() ?? '',
      observerName: (item['auditorName'] as String?)?.trim() ?? 'Unknown',
      date: trainingAt == null ? '' : DateFormat('MMM d, y').format(trainingAt),
      time: trainingAt == null ? '' : DateFormat('h:mm a').format(trainingAt),
      dateTime: trainingAt ?? DateTime.now(),
      gate: _formatGateLabel(item['gateCode']?.toString() ?? ''),
      pictures: pictureUrls,
      isPassed: item['overallResult'] == 'PASS',
    );
  }

  TrainingItem _mapTrainingDetail(Map<String, dynamic> item) {
    final trainingAt = DateTime.tryParse(
      item['trainingAt']?.toString() ?? '',
    )?.toLocal();
    final parsedNotes = _parseNotes(item['additionalNotes']?.toString());
    final detailedResults = _parseDetailedAreas(item['detailedResultsJson']);
    final fallbackResults = List<Map<String, dynamic>>.from(
      (item['results'] as List?) ?? const <dynamic>[],
    );
    final files = List<Map<String, dynamic>>.from(
      (item['files'] as List?) ?? const <dynamic>[],
    );
    final pictureUrls = files
        .map((entry) => entry['fileId']?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .map(_api.buildFileContentUrl)
        .toList();
    final observerName =
        (item['auditorNameSnapshot'] as String?)?.trim() ?? 'Unknown';
    final role = (item['auditorRoleSnapshot'] as String?)?.trim() ?? '';

    return TrainingItem(
      id: item['id']?.toString() ?? '',
      observerName: observerName,
      date: trainingAt == null ? '' : DateFormat('MMM d, y').format(trainingAt),
      time: trainingAt == null ? '' : DateFormat('h:mm a').format(trainingAt),
      dateTime: trainingAt ?? DateTime.now(),
      gate: _formatGateLabel(item['gateCodeSnapshot']?.toString() ?? ''),
      shipNumber: (item['shipNumber'] as String?)?.trim() ?? '',
      role: role,
      pictures: pictureUrls,
      isPassed: item['overallResult'] == 'PASS',
      areaResults: detailedResults.isNotEmpty
          ? detailedResults
          : fallbackResults.map(_mapFallbackAreaResult).toList(),
      otherFindings: (item['otherFindings'] as String?)?.trim() ?? '',
      additionalNotes: parsedNotes.notes,
      aircraft: parsedNotes.aircraft,
      supervisorName: observerName,
      supervisorRole: parsedNotes.supervisorRole.isNotEmpty
          ? parsedNotes.supervisorRole
          : role,
    );
  }

  List<SecurityAreaDetailResult> _parseDetailedAreas(dynamic raw) {
    if (raw is! List) {
      return const <SecurityAreaDetailResult>[];
    }

    return raw
        .map(_asMap)
        .where((entry) => entry.isNotEmpty)
        .map((entry) {
          final rawItems = List<dynamic>.from(
            entry['checkItems'] as List? ?? const <dynamic>[],
          );
          final rawAreaId = entry['areaId']?.toString().trim() ?? '';
          final rawSectionLabel =
              entry['sectionLabel']?.toString().trim() ?? '';

          return SecurityAreaDetailResult(
            areaId: rawAreaId.isEmpty
                ? _deriveAreaId(rawSectionLabel)
                : rawAreaId,
            sectionLabel: rawSectionLabel.isEmpty
                ? _deriveSectionLabel(rawAreaId)
                : rawSectionLabel,
            areaPictures:
                List<dynamic>.from(
                      entry['imageFileIds'] as List? ?? const <dynamic>[],
                    )
                    .map((fileId) => fileId.toString().trim())
                    .where((fileId) => fileId.isNotEmpty)
                    .map(_api.buildFileContentUrl)
                    .toList(),
            checkItems: rawItems
                .map(_asMap)
                .where((item) => item.isNotEmpty)
                .map(
                  (item) => SecurityCheckItemResult(
                    itemName: item['itemName']?.toString().trim() ?? 'Item',
                    status: _mapStatus(item['status']?.toString() ?? 'na'),
                    pictures:
                        List<dynamic>.from(
                              item['imageFileIds'] as List? ??
                                  const <dynamic>[],
                            )
                            .map((fileId) => fileId.toString().trim())
                            .where((fileId) => fileId.isNotEmpty)
                            .map(_api.buildFileContentUrl)
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
        .where(
          (area) => area.checkItems.isNotEmpty || area.areaPictures.isNotEmpty,
        )
        .toList();
  }

  SecurityAreaDetailResult _mapFallbackAreaResult(Map<String, dynamic> item) {
    final label = (item['areaLabelSnapshot'] as String?)?.trim() ?? 'Area';
    final files = List<Map<String, dynamic>>.from(
      (item['files'] as List?) ?? const <dynamic>[],
    );

    return SecurityAreaDetailResult(
      areaId: _deriveAreaId(label),
      sectionLabel: _deriveSectionLabel(label),
      areaPictures: files
          .map((entry) => entry['fileId']?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty)
          .map(_api.buildFileContentUrl)
          .toList(),
      checkItems: <SecurityCheckItemResult>[
        SecurityCheckItemResult(
          itemName: 'Search Result',
          status: item['result'] == 'PASS'
              ? SecurityAuditStatus.pass
              : SecurityAuditStatus.fail,
        ),
      ],
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

  _ParsedTrainingNotes _parseNotes(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const _ParsedTrainingNotes(
        aircraft: '',
        supervisorRole: '',
        notes: '',
      );
    }

    var aircraft = '';
    var supervisorRole = '';
    final noteLines = <String>[];

    for (final line in raw.split('\n')) {
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
      if (trimmed.startsWith('Supervisor Role:')) {
        supervisorRole = trimmed.substring('Supervisor Role:'.length).trim();
        continue;
      }
      if (trimmed.startsWith('Area Summary:')) {
        continue;
      }
      noteLines.add(trimmed);
    }

    while (noteLines.isNotEmpty && noteLines.last.isEmpty) {
      noteLines.removeLast();
    }

    return _ParsedTrainingNotes(
      aircraft: aircraft,
      supervisorRole: supervisorRole,
      notes: noteLines.join('\n'),
    );
  }

  SecurityAuditStatus _mapStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'pass':
      case 'yes':
        return SecurityAuditStatus.pass;
      case 'fail':
      case 'no':
        return SecurityAuditStatus.fail;
      default:
        return SecurityAuditStatus.na;
    }
  }

  String _deriveAreaId(String label) {
    final trimmed = label.trim();
    if (trimmed.toLowerCase().startsWith('seat ')) {
      return trimmed.substring(5).trim();
    }
    return trimmed;
  }

  String _deriveSectionLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized.startsWith('seat ')) {
      final seatId = label.trim().substring(5).trim();
      final row = int.tryParse(seatId.replaceAll(RegExp(r'[^0-9]'), ''));
      if (row != null) {
        if (row <= 6) {
          return 'First Class';
        }
        if (row <= 15) {
          return 'Delta Comfort';
        }
        return 'Main Cabin';
      }
      return 'Cabin Seat';
    }
    if (normalized.contains('first class') || normalized.contains('business')) {
      return 'First Class';
    }
    if (normalized.contains('comfort')) {
      return 'Delta Comfort';
    }
    if (normalized.contains('main cabin') || normalized.contains('economy')) {
      return 'Main Cabin';
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
    return label.trim().isEmpty ? 'Area' : label.trim();
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

  void applyFilter({
    required String name,
    required String fromDate,
    required String toDate,
    required Set<String> results,
  }) {
    filterName.value = name;
    filterFromDate.value = fromDate;
    filterToDate.value = toDate;
    filterResults.assignAll(results);
    _applyFilter();
  }

  void clearFilter() {
    filterName.value = '';
    filterFromDate.value = '';
    filterToDate.value = '';
    filterResults.clear();
    _applyFilter();
  }

  void _applyFilter() {
    var list = List<TrainingItem>.from(_allTrainings);

    if (filterName.isNotEmpty) {
      list = list
          .where(
            (training) => training.observerName.toLowerCase().contains(
              filterName.value.toLowerCase(),
            ),
          )
          .toList();
    }

    if (filterFromDate.isNotEmpty || filterToDate.isNotEmpty) {
      DateTime? from;
      DateTime? to;
      try {
        if (filterFromDate.isNotEmpty) {
          from = _parseFilterDate(filterFromDate.value);
        }
        if (filterToDate.isNotEmpty) {
          final parsed = _parseFilterDate(filterToDate.value);
          to = DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59);
        }
      } catch (_) {}

      if (from != null || to != null) {
        list = list.where((training) {
          if (from != null && training.dateTime.isBefore(from)) {
            return false;
          }
          if (to != null && training.dateTime.isAfter(to)) {
            return false;
          }
          return true;
        }).toList();
      }
    }

    if (filterResults.length == 1) {
      final onlyPass = filterResults.contains('pass');
      list = list
          .where(
            (training) => onlyPass ? training.isPassed : !training.isPassed,
          )
          .toList();
    }

    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    filteredTrainings.assignAll(list);
  }

  DateTime _parseFilterDate(String value) {
    final parts = value.split('/');
    if (parts.length == 3) {
      final month = int.parse(parts[0]);
      final day = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    }
    throw FormatException('Invalid date format: $value');
  }
}

class CabinSecurityScreen extends StatefulWidget {
  const CabinSecurityScreen({super.key});

  @override
  State<CabinSecurityScreen> createState() => _CabinSecurityScreenState();
}

class _CabinSecurityScreenState extends State<CabinSecurityScreen> {
  late final CabinSecurityController controller;
  final SessionService _session = Get.find<SessionService>();
  final PageController _pageController = PageController();
  final RxInt _currentPage = 0.obs;

  bool get _canCreateTraining => _session.hasPermission(
    AppPermissionCodes.cabinSecuritySearchTraining,
    action: 'write',
  );

  @override
  void initState() {
    super.initState();
    controller = Get.put(CabinSecurityController());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildSectionHeader(),
                    SizedBox(height: 12.h),
                    _buildTrainingList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => Get.back(),
            child: Icon(Icons.arrow_back, color: _Colors.primary, size: 22.sp),
          ),
          Expanded(
            child: Text(
              'Cabin Security Search Training',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: _Colors.primary,
                height: 1.3,
              ),
            ),
          ),
          Obx(() {
            final active = controller.hasActiveFilter;
            return Stack(
              children: <Widget>[
                IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: AppColors.mainAppColor,
                    size: 24.sp,
                  ),
                  onPressed: _showFilterSheet,
                ),
                if (active)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8.w,
                      height: 8.h,
                      decoration: const BoxDecoration(
                        color: _Colors.fail,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 4.w,
              height: 22.h,
              decoration: BoxDecoration(
                color: _Colors.primary,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              'Past Trainings',
              style: GoogleFonts.poppins(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: _Colors.textDark,
              ),
            ),
          ],
        ),
        if (_canCreateTraining)
          GestureDetector(
            onTap: () async {
              if (CabinQualityAuditScreenN.hasSavedDraft()) {
                final continueDraft =
                    await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Draft Found'),
                        content: const Text(
                          'You already have a saved Cabin Security Search draft. Do you want to continue it?',
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
                    () => const CabinQualityAuditScreenN(restoreDraft: true),
                  );
                } else {
                  CabinQualityAuditScreenN.clearSavedDraft();
                  await Get.to(() => const CabinQualityAuditScreenN());
                }
              } else {
                await Get.to(() => const CabinQualityAuditScreenN());
              }
              await controller.loadTrainings();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: _Colors.newAuditBtn,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                '+ Conduct New Search',
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrainingList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final trainings = controller.filteredTrainings;
      if (trainings.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40.h),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.search_off_rounded,
                  color: _Colors.textGrey,
                  size: 48.sp,
                ),
                SizedBox(height: 12.h),
                Text(
                  'No trainings found',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: _Colors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: trainings.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: _Colors.divider),
        itemBuilder: (_, index) => _buildTrainingCard(trainings[index]),
      );
    });
  }

  Widget _buildTrainingCard(TrainingItem item) {
    final status = item.passedOverall
        ? SecurityAuditStatus.pass
        : SecurityAuditStatus.fail;

    return InkWell(
      onTap: () => _showViewOnlyDetail(item),
      child: Container(
        color: _Colors.cardBg,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildAvatar(item.observerName, status),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(height: 4.h),
                  Text(
                    item.observerName,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: _Colors.primary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: <Widget>[
                      Text(
                        item.date,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: _Colors.textGrey,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Container(
                          width: 3.w,
                          height: 3.h,
                          decoration: const BoxDecoration(
                            color: _Colors.dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Text(
                        item.time,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: _Colors.textGrey,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5.h),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.location_on_outlined,
                        size: 12.sp,
                        color: _Colors.textGrey,
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          item.gate,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: _Colors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  _compactStatusBadge(status),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _buildLocationImage(
                  item.pictures.isNotEmpty ? item.pictures.first : '',
                ),
                SizedBox(height: 6.h),
                _buildLocationImage(
                  item.pictures.length > 1 ? item.pictures[1] : '',
                ),
                SizedBox(height: 4.h),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _Colors.textGrey,
                  size: 18.sp,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, SecurityAuditStatus status) {
    final initials = _initialsForName(name);
    return Stack(
      children: <Widget>[
        Container(
          padding: EdgeInsets.all(3.r),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: status.color, width: 2.5.w),
          ),
          child: CircleAvatar(
            radius: 26.r,
            backgroundColor: status.color.withOpacity(0.12),
            child: Text(
              initials,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: status.color,
              ),
            ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            width: 13.w,
            height: 13.h,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  String _initialsForName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Widget _buildLocationImage(String imagePath) {
    if (imagePath.trim().isEmpty) {
      return _buildMissingImage();
    }

    final imageHeaders = Get.find<AppApiService>().buildImageHeaders();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: imagePath.startsWith('http')
          ? Image.network(
              imagePath,
              width: 64.w,
              height: 56.h,
              fit: BoxFit.cover,
              headers: imageHeaders,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return _buildImageLoadingState(width: 64.w, height: 56.h);
              },
              errorBuilder: (context, error, stackTrace) =>
                  _buildMissingImage(),
            )
          : Image.asset(
              imagePath,
              width: 64.w,
              height: 56.h,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildMissingImage(),
            ),
    );
  }

  Widget _buildMissingImage() {
    return Container(
      width: 64.w,
      height: 56.h,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(
        Icons.image_outlined,
        color: Colors.grey.shade400,
        size: 22.sp,
      ),
    );
  }

  Future<void> _showViewOnlyDetail(TrainingItem training) async {
    TrainingItem item = training;
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      item = await controller.loadTrainingDetail(training.id);
    } on ApiException catch (error) {
      Get.snackbar(
        'Training Unavailable',
        error.message,
        backgroundColor: _Colors.fail,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    } catch (_) {
      Get.snackbar(
        'Training Unavailable',
        'Unable to load this training record right now.',
        backgroundColor: _Colors.fail,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    } finally {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    }

    controller.expandedAreaIndex.value = -1;
    _currentPage.value = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: _Colors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  color: Colors.white,
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
                        child: Center(
                          child: Container(
                            width: 40.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE4E7EF),
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                        child: Row(
                          children: <Widget>[
                            GestureDetector(
                              onTap: () => Get.back(),
                              child: Icon(
                                Icons.arrow_back,
                                color: _Colors.primary,
                                size: 22.sp,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Cabin Security Search',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _Colors.primary,
                                ),
                              ),
                            ),
                            SizedBox(width: 24.w),
                          ],
                        ),
                      ),
                      if (item.date.isNotEmpty || item.time.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: _Colors.divider),
                            ),
                          ),
                          child: Text(
                            [item.date, item.time]
                                .where((part) => part.trim().isNotEmpty)
                                .join('  •  '),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: _Colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      children: <Widget>[
                        _buildScoreCard(item),
                        _buildInfoCard(item),
                        _buildAreaList(item),
                        if (item.pictures.isNotEmpty) _buildPicturesCard(item),
                        if (item.otherFindings.isNotEmpty)
                          _buildNotesCard(
                            title: 'Other Findings',
                            text: item.otherFindings,
                          ),
                        if (item.additionalNotes.isNotEmpty)
                          _buildNotesCard(
                            title: 'Additional Notes',
                            text: item.additionalNotes,
                          ),
                        _buildReadOnlyNotice(),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 28.h),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50.h,
                            child: ElevatedButton(
                              onPressed: () => Get.back(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _Colors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25.r),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Close',
                                style: GoogleFonts.poppins(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
        },
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildScoreCard(TrainingItem item) {
    final isGood = item.passedOverall;
    final scoreColor = isGood ? _Colors.pass : _Colors.fail;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 64.w,
            height: 64.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor,
            ),
            child: Center(
              child: Text(
                '${item.scorePercent.toStringAsFixed(0)}%',
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
              children: <Widget>[
                Text(
                  isGood ? 'Search Passed' : 'Search Failed',
                  style: GoogleFonts.poppins(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: scoreColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${item.areaResults.length} areas inspected  •  ${item.failAreaCount} failed',
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: _Colors.textGrey,
                  ),
                ),
                if (!isGood) ...<Widget>[
                  SizedBox(height: 3.h),
                  Text(
                    'Any failed item = search FAIL',
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
  }

  Widget _buildInfoCard(TrainingItem item) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _Colors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
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
                  item.observerName,
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: _Colors.namePrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: _Colors.highlightBg,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'View Only',
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: _Colors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          _infoRow(
            [
              item.date,
              item.time,
            ].where((part) => part.isNotEmpty).join('  •  '),
            isGrey: true,
          ),
          SizedBox(height: 8.h),
          _infoRow(item.gate),
          SizedBox(height: 10.h),
          Divider(color: _Colors.divider, height: 1),
          SizedBox(height: 12.h),
          if (item.role.isNotEmpty) ...<Widget>[
            _labelValue('Role', item.role),
            SizedBox(height: 8.h),
          ],
          if (item.shipNumber.isNotEmpty) ...<Widget>[
            _labelValue('Ship Number', item.shipNumber),
            SizedBox(height: 8.h),
          ],
          if (item.aircraft.isNotEmpty) ...<Widget>[
            _labelValue('Aircraft', item.aircraft),
            SizedBox(height: 8.h),
          ],
          if (item.supervisorRole.isNotEmpty)
            _labelValue(
              'Supervisor',
              item.supervisorName.isEmpty
                  ? item.supervisorRole
                  : '${item.supervisorName} • ${item.supervisorRole}',
            ),
        ],
      ),
    );
  }

  Widget _buildAreaList(TrainingItem item) {
    return Obx(() {
      final filteredAreas = item.areaResults.toList();

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
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                children: <Widget>[
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
                      'Inspected Areas',
                      style: GoogleFonts.poppins(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: _Colors.namePrimary,
                      ),
                    ),
                  ),
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

  Widget _buildAreaTile(
    SecurityAreaDetailResult area,
    int index,
    bool isExpanded,
  ) {
    final subtitleParts = <String>[
      if (area.areaId.trim().isNotEmpty &&
          area.areaId.trim().toLowerCase() !=
              area.sectionLabel.trim().toLowerCase())
        'Area: ${area.areaId}',
      '${area.allPictures.length} photo${area.allPictures.length == 1 ? '' : 's'}',
    ];

    return Column(
      children: <Widget>[
        InkWell(
          onTap: () => controller.toggleArea(index),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: <Widget>[
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
                    children: <Widget>[
                      Text(
                        area.sectionLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: _Colors.namePrimary,
                        ),
                      ),
                      Text(
                        subtitleParts.join('  •  '),
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: _Colors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
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
        if (isExpanded) _buildExpandedAreaItems(area),
        Divider(height: 1, color: _Colors.divider),
      ],
    );
  }

  Widget _buildExpandedAreaItems(SecurityAreaDetailResult area) {
    final pictures = area.allPictures;

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _Colors.background,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (pictures.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(
                'No images were uploaded for this area.',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: _Colors.textGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else ...<Widget>[
            Text(
              'Uploaded images',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _Colors.namePrimary,
              ),
            ),
            SizedBox(height: 8.h),
            _buildAreaPictures(pictures),
          ],
        ],
      ),
    );
  }

  Widget _buildAreaPictures(List<String> pictures) {
    return SizedBox(
      height: 84.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pictures.length,
        itemBuilder: (context, index) {
          return Container(
            width: 84.w,
            margin: EdgeInsets.only(right: 8.w),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: _buildResponsiveImage(
                pictures[index],
                width: 84.w,
                height: 84.h,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPicturesCard(TrainingItem item) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _Colors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle('Photos'),
          SizedBox(height: 12.h),
          _buildImageSlider(item.pictures),
        ],
      ),
    );
  }

  Widget _buildImageSlider(List<String> images) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 180.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) => _currentPage.value = index,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: _buildResponsiveImage(
                  images[index],
                  width: double.infinity,
                  height: 180.h,
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

  Widget _buildResponsiveImage(
    String imagePath, {
    required double width,
    required double height,
  }) {
    final imageHeaders = Get.find<AppApiService>().buildImageHeaders();

    if (imagePath.trim().isEmpty) {
      return _buildImagePlaceholder(width: width, height: height);
    }

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        headers: imageHeaders,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return _buildImageLoadingState(width: width, height: height);
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildImagePlaceholder(width: width, height: height),
      );
    }

    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _buildImagePlaceholder(width: width, height: height),
    );
  }

  Widget _buildImagePlaceholder({
    required double width,
    required double height,
  }) {
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

  Widget _buildImageLoadingState({
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: SizedBox(
          width: 22.w,
          height: 22.h,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(_Colors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesCard({required String title, required String text}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _Colors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle(title),
          SizedBox(height: 10.h),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              color: _Colors.textGrey,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyNotice() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFFFCC02).withOpacity(0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: 16.sp,
            color: const Color(0xFFF59E0B),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'This record is view-only and cannot be modified after submission.',
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                color: const Color(0xFF92400E),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: <Widget>[
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
      children: <Widget>[
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

  Widget _compactStatusBadge(SecurityAuditStatus status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: status.color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: status.color,
        ),
      ),
    );
  }

  IconData _sectionIcon(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('first class') || normalized.contains('business')) {
      return Icons.airline_seat_recline_extra_rounded;
    }
    if (normalized.contains('comfort')) {
      return Icons.airline_seat_recline_normal_rounded;
    }
    if (normalized.contains('main cabin') ||
        normalized.contains('cabin seat')) {
      return Icons.weekend_rounded;
    }
    if (normalized.contains('lav')) {
      return Icons.wc_rounded;
    }
    if (normalized.contains('galley')) {
      return Icons.restaurant_rounded;
    }
    if (normalized.contains('overhead')) {
      return Icons.inventory_2_outlined;
    }
    if (normalized.contains('pocket')) {
      return Icons.book_outlined;
    }
    if (normalized.contains('crew')) {
      return Icons.people_outline_rounded;
    }
    if (normalized.contains('emergency')) {
      return Icons.health_and_safety_outlined;
    }
    return Icons.event_seat_rounded;
  }

  void _showFilterSheet() async {
    final result = await Get.bottomSheet<Map<String, dynamic>>(
      const NewSearchSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (result != null) {
      final rawFilter = result['filter'];
      final Set<String> resultsSet = rawFilter is Set<String>
          ? rawFilter
          : rawFilter is String && rawFilter.isNotEmpty
          ? <String>{rawFilter}
          : <String>{};
      controller.applyFilter(
        name: result['name'] ?? '',
        fromDate: result['fromDate'] ?? '',
        toDate: result['toDate'] ?? '',
        results: resultsSet,
      );
    }
  }
}
