import 'package:avislap/utils/app_colors.dart';
import 'package:avislap/views/forms/cabin%20security%20search/training_filter.dart';
import 'package:avislap/config/app_permission_codes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../services/api_exception.dart';
import '../../../services/app_api_service.dart';
import '../../../services/session_service.dart';
import 'LAVSafety.dart';

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
  static const Color newObservationBtn = Color(0xFF3D5AFE);
  static const Color highlightBg = Color(0xFFEEF2FF);
}

enum LavObservationStatus { pass, fail }

extension LavObservationStatusExt on LavObservationStatus {
  String get label => this == LavObservationStatus.pass ? 'Pass' : 'Fail';

  Color get color =>
      this == LavObservationStatus.pass ? _Colors.pass : _Colors.fail;

  IconData get icon => this == LavObservationStatus.pass
      ? Icons.check_circle_rounded
      : Icons.cancel_rounded;
}

class ObservationItem {
  final String id;
  final String observerName;
  final String observerImage;
  final String date;
  final String time;
  final DateTime dateTime;
  final String gate;
  final String driverName;
  final String locationImage;
  final String locationImage2;

  ObservationItem({
    required this.id,
    required this.observerName,
    required this.observerImage,
    required this.date,
    required this.time,
    required this.dateTime,
    required this.gate,
    required this.driverName,
    required this.locationImage,
    required this.locationImage2,
  });
}

class LavChecklistResult {
  const LavChecklistResult({
    required this.label,
    required this.status,
    this.pictures = const <String>[],
  });

  final String label;
  final LavObservationStatus status;
  final List<String> pictures;
}

class _ParsedNotes {
  const _ParsedNotes({required this.supervisor, required this.notes});

  final String supervisor;
  final String notes;
}

class LavObservationDetail {
  const LavObservationDetail({
    required this.id,
    required this.observerName,
    required this.observerImage,
    required this.date,
    required this.time,
    required this.gate,
    required this.driverName,
    required this.shipNumber,
    required this.role,
    required this.checklistResults,
    required this.generalPictures,
    required this.signatureImage,
    required this.otherFindings,
    required this.additionalNotes,
    required this.supervisor,
  });

  final String id;
  final String observerName;
  final String observerImage;
  final String date;
  final String time;
  final String gate;
  final String driverName;
  final String shipNumber;
  final String role;
  final List<LavChecklistResult> checklistResults;
  final List<String> generalPictures;
  final String signatureImage;
  final String otherFindings;
  final String additionalNotes;
  final String supervisor;

  int get passCount => checklistResults
      .where((item) => item.status == LavObservationStatus.pass)
      .length;

  int get failCount => checklistResults
      .where((item) => item.status == LavObservationStatus.fail)
      .length;

  bool get passedOverall => failCount == 0;

  double get scorePercent {
    if (checklistResults.isEmpty) {
      return 0;
    }
    return (passCount / checklistResults.length) * 100;
  }
}

class LavSafetyController extends GetxController {
  final AppApiService _api = Get.find<AppApiService>();
  final SessionService _session = Get.find<SessionService>();

  final RxList<ObservationItem> observations = <ObservationItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxString filterName = ''.obs;
  final RxString filterFromDate = ''.obs;
  final RxString filterToDate = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadObservations();
  }

  Future<void> loadObservations() async {
    isLoading.value = true;
    try {
      final result = await _api.listLavSafetyObservations(
        queryParameters: {
          'auditorName': filterName.value,
          'fromDate': _toApiDate(filterFromDate.value),
          'toDate': _toApiDate(filterToDate.value, endOfDay: true),
        },
      );

      final items = (result['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                entry is Map<String, dynamic> ? entry : <String, dynamic>{},
          )
          .toList();
      final profileImageFileId =
          (_session.user?['profileImageFileId'] as String?)?.trim() ?? '';
      final observerImage = profileImageFileId.isEmpty
          ? ''
          : _api.buildFileContentUrl(profileImageFileId);

      observations.assignAll(
        List<ObservationItem>.generate(items.length, (index) {
          final item = items[index];
          final observedAtRaw = item['observedAt'] as String? ?? '';
          final observedAt = DateTime.tryParse(observedAtRaw)?.toLocal();
          final thumbnails = List<dynamic>.from(
            item['thumbnails'] as List? ?? const <dynamic>[],
          );
          final thumbnailUrls = thumbnails
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .map(_api.buildFileContentUrl)
              .toList();
          final date = observedAt != null
              ? DateFormat('MMM d, y').format(observedAt)
              : '--';
          final time = observedAt != null
              ? DateFormat('h:mm a').format(observedAt)
              : '--';

          return ObservationItem(
            id: item['id'] as String? ?? '',
            observerName: item['auditorName'] as String? ?? 'Unknown Auditor',
            observerImage: observerImage,
            date: date,
            time: time,
            dateTime: observedAt ?? DateTime.now(),
            gate: item['gateCode'] as String? ?? 'Unknown Gate',
            driverName: item['driverName'] as String? ?? 'Unknown Driver',
            locationImage: thumbnailUrls.isNotEmpty ? thumbnailUrls.first : '',
            locationImage2: thumbnailUrls.length > 1 ? thumbnailUrls[1] : '',
          );
        }),
      );
    } on ApiException catch (error) {
      observations.clear();
      Get.snackbar(
        'Load Failed',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      observations.clear();
      Get.snackbar(
        'Load Failed',
        'Unable to load LAV safety observations right now.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> applyFilter({
    required String name,
    required String fromDate,
    required String toDate,
  }) async {
    filterName.value = name;
    filterFromDate.value = fromDate;
    filterToDate.value = toDate;
    await loadObservations();
  }

  Future<LavObservationDetail> loadObservationDetail(String id) async {
    final result = await _api.getLavSafetyObservation(id);
    return _mapObservationDetail(result);
  }

  LavObservationDetail _mapObservationDetail(Map<String, dynamic> item) {
    final observedAt = DateTime.tryParse(
      item['observedAt']?.toString() ?? '',
    )?.toLocal();
    final files = List<Map<String, dynamic>>.from(
      item['files'] as List? ?? const <dynamic>[],
    );
    final responses = List<Map<String, dynamic>>.from(
      item['responses'] as List? ?? const <dynamic>[],
    );
    final parsedNotes = _parseNotes(item['additionalNotes']?.toString());
    final signatureFileId = (item['signatureFileId'] as String?)?.trim() ?? '';

    return LavObservationDetail(
      id: item['id']?.toString() ?? '',
      observerName:
          (item['auditorNameSnapshot'] as String?)?.trim() ?? 'Unknown Auditor',
      observerImage: _currentUserImageUrl(),
      date: observedAt == null
          ? '--'
          : DateFormat('MMM d, y').format(observedAt),
      time: observedAt == null ? '--' : DateFormat('h:mm a').format(observedAt),
      gate: _formatGateLabel(item['gateCodeSnapshot']?.toString() ?? ''),
      driverName: (item['driverName'] as String?)?.trim() ?? 'Unknown Driver',
      shipNumber: (item['shipNumber'] as String?)?.trim() ?? '',
      role: (item['auditorRoleSnapshot'] as String?)?.trim() ?? '',
      checklistResults: responses.map(_mapChecklistResult).toList(),
      generalPictures: files
          .map((entry) => entry['fileId']?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty)
          .map(_api.buildFileContentUrl)
          .toList(),
      signatureImage: signatureFileId.isEmpty
          ? ''
          : _api.buildFileContentUrl(signatureFileId),
      otherFindings: (item['otherFindings'] as String?)?.trim() ?? '',
      additionalNotes: parsedNotes.notes,
      supervisor: parsedNotes.supervisor,
    );
  }

  LavChecklistResult _mapChecklistResult(Map<String, dynamic> item) {
    final checklistItem = item['checklistItem'] is Map<String, dynamic>
        ? item['checklistItem'] as Map<String, dynamic>
        : <String, dynamic>{};
    final files = List<Map<String, dynamic>>.from(
      item['files'] as List? ?? const <dynamic>[],
    );

    return LavChecklistResult(
      label: (checklistItem['label'] as String?)?.trim() ?? 'Checklist Item',
      status: item['response'] == 'PASS'
          ? LavObservationStatus.pass
          : LavObservationStatus.fail,
      pictures: files
          .map((entry) => entry['fileId']?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty)
          .map(_api.buildFileContentUrl)
          .toList(),
    );
  }

  _ParsedNotes _parseNotes(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const _ParsedNotes(supervisor: '', notes: '');
    }

    var supervisor = '';
    final noteLines = <String>[];

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (noteLines.isNotEmpty && noteLines.last.isNotEmpty) {
          noteLines.add('');
        }
        continue;
      }
      if (trimmed.startsWith('Supervisor/Lead:')) {
        supervisor = trimmed.substring('Supervisor/Lead:'.length).trim();
        continue;
      }
      noteLines.add(trimmed);
    }

    while (noteLines.isNotEmpty && noteLines.last.isEmpty) {
      noteLines.removeLast();
    }

    return _ParsedNotes(supervisor: supervisor, notes: noteLines.join('\n'));
  }

  String _currentUserImageUrl() {
    final profileImageFileId =
        (_session.user?['profileImageFileId'] as String?)?.trim() ?? '';
    if (profileImageFileId.isEmpty) {
      return '';
    }
    return _api.buildFileContentUrl(profileImageFileId);
  }

  String? _toApiDate(String value, {bool endOfDay = false}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parts = trimmed.split('/');
    if (parts.length != 3) {
      return null;
    }

    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) {
      return null;
    }

    final date = DateTime(
      year,
      month,
      day,
      endOfDay ? 23 : 0,
      endOfDay ? 59 : 0,
      endOfDay ? 59 : 0,
    );

    return date.toIso8601String();
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
}

class LavSafetyObservationScreen extends StatefulWidget {
  const LavSafetyObservationScreen({super.key});

  @override
  State<LavSafetyObservationScreen> createState() =>
      _LavSafetyObservationScreenState();
}

class _LavSafetyObservationScreenState
    extends State<LavSafetyObservationScreen> {
  late final LavSafetyController controller;
  final SessionService _session = Get.find<SessionService>();
  final PageController _pageController = PageController();
  final RxInt _currentPage = 0.obs;

  bool get _canCreateObservation => _session.hasPermission(
    AppPermissionCodes.lavSafetyObservation,
    action: 'write',
  );

  @override
  void initState() {
    super.initState();
    controller = Get.put(LavSafetyController());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showFilterSheet() async {
    final result = await Get.bottomSheet<Map<String, dynamic>>(
      const NewSearchSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (result == null) {
      return;
    }

    await controller.applyFilter(
      name: result['name'] as String? ?? '',
      fromDate: result['fromDate'] as String? ?? '',
      toDate: result['toDate'] as String? ?? '',
    );
  }

  Future<void> _showObservationDetail(ObservationItem item) async {
    LavObservationDetail detail;
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      detail = await controller.loadObservationDetail(item.id);
    } on ApiException catch (error) {
      Get.snackbar(
        'Observation Unavailable',
        error.message,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    } catch (_) {
      Get.snackbar(
        'Observation Unavailable',
        'Unable to load this LAV safety observation right now.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    } finally {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    }

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
              children: [
                _buildDetailHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      children: [
                        _buildScoreCard(detail),
                        _buildInfoCard(detail),
                        _buildChecklistCard(detail),
                        if (detail.generalPictures.isNotEmpty)
                          _buildPicturesCard(detail.generalPictures),
                        if (detail.signatureImage.isNotEmpty)
                          _buildSignatureCard(detail.signatureImage),
                        if (detail.otherFindings.isNotEmpty)
                          _buildNotesCard(
                            title: 'Other Findings',
                            text: detail.otherFindings,
                          ),
                        if (detail.additionalNotes.isNotEmpty)
                          _buildNotesCard(
                            title: 'Additional Notes',
                            text: detail.additionalNotes,
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

  Widget _buildDetailHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 10.w, 10.h),
      child: Column(
        children: [
          Container(
            width: 42.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999.r),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  'LAV Observation Details',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: _Colors.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Get.back(),
                icon: Icon(
                  Icons.close_rounded,
                  color: _Colors.primary,
                  size: 22.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(LavObservationDetail detail) {
    final scoreColor = detail.passedOverall ? _Colors.pass : _Colors.fail;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
            alignment: Alignment.center,
            child: Text(
              '${detail.scorePercent.toStringAsFixed(0)}%',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.passedOverall
                      ? 'Observation Passed'
                      : 'Observation Failed',
                  style: GoogleFonts.poppins(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: scoreColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${detail.checklistResults.length} checklist items reviewed',
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: _Colors.textGrey,
                  ),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _summaryChip(
                      label: '${detail.passCount} pass',
                      color: _Colors.pass,
                    ),
                    _summaryChip(
                      label: '${detail.failCount} fail',
                      color: _Colors.fail,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(LavObservationDetail detail) {
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
              _buildAvatar(detail.observerName, detail.observerImage),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.observerName,
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: _Colors.namePrimary,
                      ),
                    ),
                    if (detail.role.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        detail.role,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: _Colors.textGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _infoRow('${detail.date}  •  ${detail.time}', isGrey: true),
          SizedBox(height: 8.h),
          _infoRow(detail.gate.isEmpty ? 'Gate not available' : detail.gate),
          SizedBox(height: 12.h),
          Divider(height: 1, color: _Colors.divider),
          SizedBox(height: 12.h),
          _labelValue('Driver', detail.driverName),
          if (detail.shipNumber.isNotEmpty) ...[
            SizedBox(height: 8.h),
            _labelValue('Ship Number', detail.shipNumber),
          ],
          if (detail.supervisor.isNotEmpty) ...[
            SizedBox(height: 8.h),
            _labelValue('Supervisor/Lead', detail.supervisor),
          ],
          SizedBox(height: 8.h),
          _labelValue('Observation ID', detail.id),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(LavObservationDetail detail) {
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
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Checklist Details'),
                SizedBox(height: 8.h),
                Text(
                  'Each line below is a submitted checklist result from the observation form.',
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: _Colors.textGrey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _Colors.divider),
          if (detail.checklistResults.isEmpty)
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                'No checklist details were saved for this observation.',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: _Colors.textGrey,
                ),
              ),
            )
          else
            ...detail.checklistResults.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == detail.checklistResults.length - 1;
              return Container(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(color: _Colors.divider, width: 1),
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38.w,
                          height: 38.h,
                          decoration: BoxDecoration(
                            color: _Colors.highlightBg,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            item.status.icon,
                            color: item.status.color,
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _Colors.namePrimary,
                                ),
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                'Sub-category response',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.sp,
                                  color: _Colors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _statusChip(item.status),
                      ],
                    ),
                    if (item.pictures.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      _buildPictureStrip(item.pictures),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPicturesCard(List<String> pictures) {
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
          _sectionTitle('Observation Pictures'),
          SizedBox(height: 12.h),
          _buildImageSlider(pictures),
        ],
      ),
    );
  }

  Widget _buildSignatureCard(String signatureImage) {
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
          _sectionTitle('Signature'),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: _buildImageWidget(
              signatureImage,
              width: double.infinity,
              height: 180.h,
            ),
          ),
        ],
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
        children: [
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
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _Colors.highlightBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _Colors.primary.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, color: _Colors.primary, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'This is a view-only copy of the submitted observation.',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: _Colors.primary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPictureStrip(List<String> pictures) {
    return SizedBox(
      height: 80.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pictures.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: _buildImageWidget(
              pictures[index],
              width: 86.w,
              height: 80.h,
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageSlider(List<String> images) {
    return Column(
      children: [
        SizedBox(
          height: 190.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) => _currentPage.value = index,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: _buildImageWidget(
                  images[index],
                  width: double.infinity,
                  height: 190.h,
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
      ],
    );
  }

  Widget _buildImageWidget(
    String imagePath, {
    required double width,
    required double height,
  }) {
    if (imagePath.trim().isEmpty) {
      return _buildMissingImage(width: width, height: height);
    }

    final imageHeaders = Get.find<AppApiService>().buildImageHeaders();

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        headers: imageHeaders,
        errorBuilder: (context, error, stackTrace) =>
            _buildMissingImage(width: width, height: height),
      );
    }

    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _buildMissingImage(width: width, height: height),
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
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: _Colors.namePrimary,
            ),
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

  Widget _summaryChip({required String label, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _statusChip(LavObservationStatus status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(),
                    SizedBox(height: 12.h),
                    _buildObservationList(),
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
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Icon(Icons.arrow_back, color: _Colors.primary, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'LAV Safety Observation',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: _Colors.primary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: AppColors.mainAppColor,
              size: 24.sp,
            ),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            Text(
              'Past Observations',
              style: GoogleFonts.poppins(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: _Colors.textDark,
              ),
            ),
          ],
        ),
        if (_canCreateObservation)
          GestureDetector(
            onTap: () async {
              if (LAVSafetyScreen.hasSavedDraft()) {
                final continueDraft =
                    await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Draft Found'),
                        content: const Text(
                          'You already have a saved LAV Safety Observation draft. Do you want to continue it?',
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
                  await Get.to(() => const LAVSafetyScreen(restoreDraft: true));
                } else {
                  LAVSafetyScreen.clearSavedDraft();
                  await Get.to(() => const LAVSafetyScreen());
                }
                return;
              }

              await Get.to(() => const LAVSafetyScreen());
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: _Colors.newObservationBtn,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                'New Observation',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildObservationList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (controller.observations.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40.h),
            child: Text(
              'No observations found',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: AppColors.textGrey,
              ),
            ),
          ),
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.observations.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: _Colors.divider, indent: 0),
        itemBuilder: (context, index) {
          return _buildObservationCard(controller.observations[index]);
        },
      );
    });
  }

  Widget _buildObservationCard(ObservationItem item) {
    return InkWell(
      onTap: () => _showObservationDetail(item),
      child: Container(
        color: _Colors.cardBg,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(item.observerName, item.observerImage),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 5.h),
                  Text(
                    item.observerName,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: _Colors.primary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Text(
                        item.date,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: _Colors.textGrey,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5.w),
                        child: Container(
                          width: 4.w,
                          height: 4.h,
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
                  SizedBox(height: 10.h),
                  Text(
                    item.gate,
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: _Colors.textDark,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'Driver: ${item.driverName}',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: _Colors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              children: [
                _buildObservationImage(item.locationImage),
                SizedBox(height: 6.h),
                _buildObservationImage(item.locationImage2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String imageUrl) {
    final normalizedImageUrl = imageUrl.trim();
    final imageHeaders = Get.find<AppApiService>().buildImageHeaders();

    return Stack(
      children: [
        Container(
          padding: EdgeInsets.all(3.r),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF3D5AFE), width: 2.5.w),
          ),
          child: CircleAvatar(
            radius: 26.r,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: normalizedImageUrl.isEmpty
                ? null
                : (normalizedImageUrl.startsWith('http')
                      ? NetworkImage(normalizedImageUrl, headers: imageHeaders)
                      : AssetImage(normalizedImageUrl) as ImageProvider),
            child: normalizedImageUrl.isEmpty
                ? Text(
                    _initialsForName(name),
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: _Colors.primary,
                    ),
                  )
                : null,
          ),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            width: 13.w,
            height: 13.h,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildObservationImage(String imagePath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: _buildImageWidget(imagePath, width: 64.w, height: 60.h),
    );
  }

  Widget _buildMissingImage({double? width, double? height}) {
    return Container(
      width: width ?? 64.w,
      height: height ?? 60.h,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(
        Icons.image_outlined,
        color: Colors.grey.shade400,
        size: 24.sp,
      ),
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
}
