import 'package:avislap/utils/app_colors.dart';
import 'package:avislap/views/forms/Cabin%20Quality%20Audit/CabinAudit.dart';
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
import 'CabinQualityAuditScreen.dart';

// =====================
// COLORS
// =====================
class _Colors {
  static const Color primary = Color(0xFF3D5AFE);
  static const Color background = Color(0xFFF5F6FA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color dotColor = Color(0xFF9E9E9E);
  static const Color namePrimary = Color(0xFF3D5AFE);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color newAuditBtn = Color(0xFF3D5AFE);
}

// =====================
// MODEL
// =====================
class CabinAuditItem {
  final String id;
  final String observerName;
  final String? observerImage;
  final String date;
  final String time;
  final String gate;
  final String shipNumber;
  final String flightNumber;

  /// Real clean types:
  /// Charter | Diversion | DCS Turn | MSGT Turn |
  /// RAD – Remain All Day | RON – Remain Over Night | Security Search
  final String type;

  final String? locationImage;
  final String? locationImage2;
  final String? bottomAvatarImage;

  CabinAuditItem({
    required this.id,
    required this.observerName,
    this.observerImage,
    required this.date,
    required this.time,
    required this.gate,
    required this.shipNumber,
    required this.flightNumber,
    required this.type,
    this.locationImage,
    this.locationImage2,
    this.bottomAvatarImage,
  });
}

// =====================
// CONTROLLER
// =====================
class CabinQualityAuditListController extends GetxController {
  final AppApiService _api = Get.find<AppApiService>();
  final SessionService _session = Get.find<SessionService>();
  final RxList<CabinAuditItem> audits = <CabinAuditItem>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadAudits();
  }

  Future<void> loadAudits() async {
    isLoading.value = true;

    try {
      final response = await _api.listCabinQualityAudits(
        queryParameters: {'page': 1, 'limit': 100},
      );

      final items = List<Map<String, dynamic>>.from(
        (response['items'] as List?) ?? const <dynamic>[],
      );

      audits.assignAll(items.map(_mapAuditItem));
    } on ApiException catch (error) {
      audits.clear();
      Get.snackbar(
        'Audits Unavailable',
        error.message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      audits.clear();
      Get.snackbar(
        'Audits Unavailable',
        'Unable to load cabin quality audits right now.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  CabinAuditItem _mapAuditItem(Map<String, dynamic> item) {
    final auditAt = DateTime.tryParse(
      item['auditAt']?.toString() ?? '',
    )?.toLocal();
    final profileImageFileId =
        (_session.user?['profileImageFileId'] as String?)?.trim() ?? '';
    final thumbnails = List<dynamic>.from(
      item['thumbnails'] as List? ?? const [],
    );
    final thumbnailUrls = thumbnails
        .map((entry) => entry.toString())
        .where((entry) => entry.isNotEmpty)
        .map(_api.buildFileContentUrl)
        .toList();

    return CabinAuditItem(
      id: item['id']?.toString() ?? '',
      observerName: (item['auditorName'] as String?)?.trim() ?? 'Unknown',
      observerImage: profileImageFileId.isEmpty
          ? null
          : _api.buildFileContentUrl(profileImageFileId),
      date: auditAt == null ? '' : DateFormat('MMM d, y').format(auditAt),
      time: auditAt == null ? '' : DateFormat('h:mm a').format(auditAt),
      gate: _formatGateLabel(item['gateCode']?.toString() ?? ''),
      shipNumber: (item['shipNumber'] as String?)?.trim() ?? '',
      flightNumber: (item['flightNumber'] as String?)?.trim() ?? '',
      type: (item['cleanType'] as String?)?.trim() ?? '',
      locationImage: thumbnailUrls.isNotEmpty ? thumbnailUrls.first : null,
      locationImage2: thumbnailUrls.length > 1 ? thumbnailUrls[1] : null,
    );
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

// =====================
// SCREEN
// =====================
class CabinQualityAuditListScreen extends StatefulWidget {
  const CabinQualityAuditListScreen({super.key});

  @override
  State<CabinQualityAuditListScreen> createState() =>
      _CabinQualityAuditListScreenState();
}

class _CabinQualityAuditListScreenState
    extends State<CabinQualityAuditListScreen> {
  late final CabinQualityAuditListController controller;
  final SessionService _session = Get.find<SessionService>();

  bool get _canCreateAudit => _session.hasPermission(
    AppPermissionCodes.cabinQualityAudit,
    action: 'write',
  );

  @override
  void initState() {
    super.initState();
    controller = Get.put(CabinQualityAuditListController());
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
                    _buildAuditList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────
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
          // Three dot menu
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: AppColors.mainAppColor,
              size: 24.sp,
            ),
            onPressed: () => Get.bottomSheet(
              const NewSearchSheet(),
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Header ───────────────────────────────────────
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
              'Past Audits',
              style: GoogleFonts.poppins(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: _Colors.textDark,
              ),
            ),
          ],
        ),
        if (_canCreateAudit)
          GestureDetector(
            onTap: _handleNewAuditTap,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: _Colors.newAuditBtn,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                'New Audit',
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

  // ── Audit List ───────────────────────────────────────────
  void _handleNewAuditTap() {
    if (!CabinAuditScreen.hasSavedDraft()) {
      Get.to(() => const CabinAuditScreen());
      return;
    }

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Draft Audit Found',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: _Colors.textDark,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'You have an incomplete Cabin Quality Audit saved as a draft.',
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: _Colors.textGrey,
              ),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.to(() => const CabinAuditScreen(restoreDraft: true));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Colors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  'Continue Draft',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  CabinAuditScreen.clearSavedDraft();
                  Get.back();
                  Get.to(() => const CabinAuditScreen());
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Colors.primary,
                  side: BorderSide(color: _Colors.primary),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  'Create New Audit',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildAuditList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.audits.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: _Colors.divider),
        itemBuilder: (context, index) {
          return _buildAuditCard(controller.audits[index]);
        },
      );
    });
  }

  // ── Audit Card ───────────────────────────────────────────
  Widget _buildAuditCard(CabinAuditItem item) {
    return InkWell(
      onTap: () {
        Get.to(() => CabinQualityAuditScreen(auditId: item.id));
      },
      child: Container(
        color: _Colors.cardBg,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with blue border + green dot
            Stack(
              children: [
                Container(
                  padding: EdgeInsets.all(3.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _Colors.primary, width: 2.5.w),
                  ),
                  child: _buildObserverAvatar(item),
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
            ),
            SizedBox(width: 12.w),

            // Middle content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4.h),

                  // Name
                  Text(
                    item.observerName,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: _Colors.namePrimary,
                    ),
                  ),
                  SizedBox(height: 5.h),

                  // Date • Time
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
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
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
                  SizedBox(height: 6.h),

                  // Gate
                  Text(
                    item.gate,
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: _Colors.textDark,
                    ),
                  ),
                  SizedBox(height: 4.h),

                  if (item.shipNumber.isNotEmpty ||
                      item.flightNumber.isNotEmpty)
                    Text(
                      [
                        if (item.shipNumber.isNotEmpty)
                          'Ship ${item.shipNumber}',
                        if (item.flightNumber.isNotEmpty)
                          'Flight ${item.flightNumber}',
                      ].join(' • '),
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: _Colors.textGrey,
                      ),
                    ),
                  if (item.shipNumber.isNotEmpty ||
                      item.flightNumber.isNotEmpty)
                    SizedBox(height: 4.h),

                  // Type
                  Text(
                    item.type,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: _Colors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),

            // Right: two stacked images + optional bottom avatar
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildLocationImage(item.locationImage),
                SizedBox(height: 6.h),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _buildLocationImage(item.locationImage2),
                    if (item.bottomAvatarImage != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 12.r,
                          backgroundImage: AssetImage(item.bottomAvatarImage!),
                          backgroundColor: Colors.grey.shade200,
                          onBackgroundImageError: (exception, stackTrace) {},
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Location Image ───────────────────────────────────────
  Widget _buildLocationImage(String? imagePath) {
    final imageHeaders = Get.find<AppApiService>().buildImageHeaders();
    final resolvedPath = imagePath?.trim() ?? '';

    if (resolvedPath.isEmpty) {
      return _buildMissingImage();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: resolvedPath.startsWith('http')
          ? Image.network(
              resolvedPath,
              width: 64.w,
              height: 56.h,
              fit: BoxFit.cover,
              headers: imageHeaders,
              errorBuilder: (context, error, stackTrace) =>
                  _buildMissingImage(),
            )
          : _buildMissingImage(),
    );
  }

  Widget _buildObserverAvatar(CabinAuditItem item) {
    final imageUrl = item.observerImage?.trim() ?? '';
    final imageHeaders = Get.find<AppApiService>().buildImageHeaders();

    if (imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 52.r,
          height: 52.r,
          fit: BoxFit.cover,
          headers: imageHeaders,
          errorBuilder: (context, error, stackTrace) =>
              _buildObserverInitials(item),
        ),
      );
    }

    return _buildObserverInitials(item);
  }

  Widget _buildObserverInitials(CabinAuditItem item) {
    final initials = item.observerName
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim()[0].toUpperCase())
        .join();

    return CircleAvatar(
      radius: 26.r,
      backgroundColor: const Color(0xFFE8EEFF),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: GoogleFonts.poppins(
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: _Colors.primary,
        ),
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
}
