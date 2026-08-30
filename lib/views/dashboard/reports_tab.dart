import 'dart:math' as math;

import 'package:avislap/services/api_exception.dart';
import 'package:avislap/services/app_api_service.dart';
import 'package:avislap/services/report_export_service.dart';
import 'package:avislap/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final AppApiService _api = Get.find<AppApiService>();
  final ReportExportService _reportExportService = ReportExportService();

  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  int _selectedIndex = 0;
  Map<String, dynamic> _summary = const <String, dynamic>{};

  static const List<_ReportBundleMeta> _bundleMetas = <_ReportBundleMeta>[
    _ReportBundleMeta(
      key: 'cabinQuality',
      shortLabel: 'Cabin Quality',
      title: 'Cabin Quality',
      subtitle:
          'Audit, area, section, employee, auditor, aircraft, arrivals, and hashtags.',
      icon: Icons.airline_seat_recline_normal_rounded,
      accent: Color(0xFF2563EB),
      areaMeaning:
          'The exact audited spot like a seat, galley, lav, or jump seat.',
      sectionMeaning:
          'The larger cabin grouping like First Class, Comfort+, Main Cabin, or Galley.',
    ),
    _ReportBundleMeta(
      key: 'cabinSecurity',
      shortLabel: 'Cabin Security',
      title: 'Cabin Security',
      subtitle:
          'Audit, area, section, employee, auditor, aircraft, arrivals, and hashtags.',
      icon: Icons.security_rounded,
      accent: Color(0xFFD97706),
      areaMeaning:
          'The exact searched location like a seat, bin, galley, or lav zone.',
      sectionMeaning:
          'The broader search zone like First Class, Main Cabin, Front Galley, or Lav Zone.',
    ),
    _ReportBundleMeta(
      key: 'lavSafety',
      shortLabel: 'LAV Safety',
      title: 'LAV Safety',
      subtitle: 'Audit, checklist type, auditor, driver, and ship number.',
      icon: Icons.clean_hands_rounded,
      accent: Color(0xFF0891B2),
      areaMeaning:
          'For LAV Safety, the detailed unit is the checklist type rather than a cabin area.',
      sectionMeaning:
          'This bundle focuses on type, auditor, driver, and ship number instead of cabin sections.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final Map<String, dynamic> result = await _api.getReportsSummary();
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = result;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load report summaries right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> get _bundlesMap => _asMap(_summary['bundles']);

  _ReportBundleMeta get _selectedMeta {
    final int safeIndex = _selectedIndex.clamp(0, _bundleMetas.length - 1);
    return _bundleMetas[safeIndex];
  }

  _ReportBundleSummaryView _bundleFor(_ReportBundleMeta meta) {
    return _ReportBundleSummaryView.fromMap(
      meta,
      _asMap(_bundlesMap[meta.key]),
    );
  }

  _ReportBundleSummaryView get _selectedBundle => _bundleFor(_selectedMeta);

  _RatioSummary get _overallTotals =>
      _RatioSummary.fromMap(_asMap(_summary['totals']));

  bool get _canExportSelectedBundle {
    final _ReportBundleSummaryView bundle = _selectedBundle;
    return bundle.auditCount > 0 &&
        bundle.metrics.any((metric) => metric.available);
  }

  String get _generatedLabel {
    final String raw = _summary['generatedAt']?.toString() ?? '';
    final DateTime? parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) {
      return 'Live backend data';
    }
    return DateFormat('MMM d, h:mm a').format(parsed);
  }

  Future<void> _exportSelectedBundle() async {
    final _ReportBundleMeta meta = _selectedMeta;
    final _ReportBundleSummaryView bundle = _selectedBundle;

    if (_isExporting) {
      return;
    }

    if (bundle.auditCount <= 0 ||
        bundle.metrics.every((metric) => !metric.available)) {
      Get.snackbar(
        'Nothing to export',
        'No live ${meta.shortLabel} report data is available yet.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black.withValues(alpha: 0.82),
        colorText: Colors.white,
        margin: EdgeInsets.all(16.w),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final ApiDownloadedFile download = await _api.downloadReportBundlePdf(
        bundleKey: meta.key,
      );
      final ReportExportResult result = await _reportExportService.savePdf(
        bytes: download.bytes,
        fileName: download.fileName,
      );

      if (!mounted) {
        return;
      }

      Get.snackbar(
        'PDF ready',
        'Exported ${result.fileName}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black.withValues(alpha: 0.82),
        colorText: Colors.white,
        margin: EdgeInsets.all(16.w),
        duration: const Duration(seconds: 3),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      Get.snackbar(
        'Export failed',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFB91C1C),
        colorText: Colors.white,
        margin: EdgeInsets.all(16.w),
        duration: const Duration(seconds: 3),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      Get.snackbar(
        'Export failed',
        'Unable to generate the PDF right now.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFB91C1C),
        colorText: Colors.white,
        margin: EdgeInsets.all(16.w),
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _summary.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F8FB),
        body: SafeArea(
          top: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_errorMessage != null && _summary.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        body: SafeArea(
          top: false,
          child: _ErrorState(
            title: 'Reports unavailable',
            message: _errorMessage!,
            onRetry: _loadSummary,
          ),
        ),
      );
    }

    final _ReportBundleMeta meta = _selectedMeta;
    final _ReportBundleSummaryView bundle = _selectedBundle;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      floatingActionButton: _ExportFloatingButton(
        meta: meta,
        bundle: bundle,
        enabled: _canExportSelectedBundle && !_isExporting,
        isExporting: _isExporting,
        onPressed: _canExportSelectedBundle && !_isExporting
            ? _exportSelectedBundle
            : null,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadSummary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 116.h),
            children: <Widget>[
              _PageHeader(
                updatedLabel: _generatedLabel,
                onRefresh: _loadSummary,
                isRefreshing: _isLoading,
              ),
              if (_errorMessage != null) ...<Widget>[
                SizedBox(height: 12.h),
                _NoticeCard(
                  title: 'Showing last loaded data',
                  message: _errorMessage!,
                ),
              ],
              SizedBox(height: 16.h),
              _BundleSelector(
                metas: _bundleMetas,
                selectedIndex: _selectedIndex,
                bundleFor: _bundleFor,
                onSelected: (int index) =>
                    setState(() => _selectedIndex = index),
              ),
              SizedBox(height: 16.h),
              _OverviewCard(meta: meta, bundle: bundle, totals: _overallTotals),
              SizedBox(height: 16.h),
              _GlossaryCard(meta: meta),
              SizedBox(height: 18.h),
              Text(
                'Available Reports',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                meta.subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.from_heading,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 12.h),
              if (bundle.metrics.isEmpty)
                _EmptyStateCard(
                  title: 'No reports available yet',
                  message:
                      'This audit bundle does not have any report metrics returned by the backend right now.',
                )
              else
                ...bundle.metrics.map(
                  (_ReportMetricSummaryView metric) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _MetricListTile(
                      accent: meta.accent,
                      metric: metric,
                      onTap: metric.available
                          ? () => Get.to<void>(
                              () => _ReportMetricDetailScreen(
                                bundleMeta: meta,
                                bundle: bundle,
                                metric: metric,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic entry) => MapEntry(key.toString(), entry),
      );
    }
    return const <String, dynamic>{};
  }
}

class _ReportMetricDetailScreen extends StatefulWidget {
  const _ReportMetricDetailScreen({
    required this.bundleMeta,
    required this.bundle,
    required this.metric,
  });

  final _ReportBundleMeta bundleMeta;
  final _ReportBundleSummaryView bundle;
  final _ReportMetricSummaryView metric;

  @override
  State<_ReportMetricDetailScreen> createState() =>
      _ReportMetricDetailScreenState();
}

class _ReportMetricDetailScreenState extends State<_ReportMetricDetailScreen> {
  final AppApiService _api = Get.find<AppApiService>();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _detail = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final Map<String, dynamic> result = await _api.getReportMetricDetail(
        bundleKey: widget.bundleMeta.key,
        metricKey: widget.metric.key,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = result;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load report details right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  _ReportMetricDetailView get _metricDetail => _ReportMetricDetailView.fromMap(
    _asMap(_detail['metric']),
    fallback: widget.metric,
  );

  String get _generatedLabel {
    final String raw = _detail['generatedAt']?.toString() ?? '';
    final DateTime? parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) {
      return 'Live backend data';
    }
    return DateFormat('MMM d, h:mm a').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final _ReportMetricDetailView metric = _metricDetail;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FB),
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: widget.bundleMeta.accent),
        titleSpacing: 0,
        title: Text(
          widget.metric.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadDetail,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 28.h),
            children: <Widget>[
              _DetailHeaderCard(
                meta: widget.bundleMeta,
                metric: metric,
                bundle: widget.bundle,
                generatedLabel: _generatedLabel,
              ),
              if (_errorMessage != null) ...<Widget>[
                SizedBox(height: 12.h),
                _NoticeCard(
                  title: 'Showing last loaded detail',
                  message: _errorMessage!,
                ),
              ],
              if (_isLoading && _detail.isEmpty) ...<Widget>[
                SizedBox(height: 28.h),
                const Center(child: CircularProgressIndicator()),
              ] else ...<Widget>[
                SizedBox(height: 16.h),
                _DetailStatsRow(metric: metric),
                SizedBox(height: 16.h),
                if (!metric.available)
                  _EmptyStateCard(
                    title: 'No live detail available',
                    message: metric.note,
                  )
                else ...<Widget>[
                  _ChartCard(metric: metric),
                  SizedBox(height: 16.h),
                  _SimpleSectionCard(
                    title: metric.highlightTitle,
                    child: Text(
                      metric.highlightValue,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                        height: 1.45,
                      ),
                    ),
                  ),
                  if (metric.topItems.isNotEmpty) ...<Widget>[
                    SizedBox(height: 16.h),
                    _SimpleSectionCard(
                      title: 'Top items',
                      child: Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: metric.topItems
                            .map(
                              (_ReportDistributionItem item) => _TagChip(
                                label: '${item.label} ${item.failRate}%',
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  if (metric.items.isNotEmpty) ...<Widget>[
                    SizedBox(height: 16.h),
                    _BreakdownSection(items: metric.items),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic entry) => MapEntry(key.toString(), entry),
      );
    }
    return const <String, dynamic>{};
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.updatedLabel,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final String updatedLabel;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Updated $updatedLabel',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          IconButton(
            onPressed: isRefreshing ? null : onRefresh,
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.mainAppColor,
              size: 22.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _BundleSelector extends StatelessWidget {
  const _BundleSelector({
    required this.metas,
    required this.selectedIndex,
    required this.bundleFor,
    required this.onSelected,
  });

  final List<_ReportBundleMeta> metas;
  final int selectedIndex;
  final _ReportBundleSummaryView Function(_ReportBundleMeta meta) bundleFor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metas.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (BuildContext context, int index) {
          final _ReportBundleMeta meta = metas[index];
          final bool selected = index == selectedIndex;
          final _ReportBundleSummaryView bundle = bundleFor(meta);

          return InkWell(
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(999.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: selected ? meta.accent : Colors.white,
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(
                  color: selected ? meta.accent : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    meta.icon,
                    size: 16.sp,
                    color: selected ? Colors.white : meta.accent,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    meta.shortLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.dark,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    bundle.auditCount.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? Colors.white70
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.meta,
    required this.bundle,
    required this.totals,
  });

  final _ReportBundleMeta meta;
  final _ReportBundleSummaryView bundle;
  final _RatioSummary totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(meta.icon, size: 18.sp, color: meta.accent),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  bundle.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            meta.subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.from_heading,
              height: 1.45,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: <Widget>[
              Expanded(
                child: _SmallStat(
                  label: 'Audits',
                  value: bundle.auditCount.toString(),
                ),
              ),
              Expanded(
                child: _SmallStat(
                  label: 'Pass Rate',
                  value: '${bundle.passRate}%',
                ),
              ),
              Expanded(
                child: _SmallStat(
                  label: 'Overall',
                  value: totals.totalCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportFloatingButton extends StatelessWidget {
  const _ExportFloatingButton({
    required this.meta,
    required this.bundle,
    required this.enabled,
    required this.isExporting,
    required this.onPressed,
  });

  final _ReportBundleMeta meta;
  final _ReportBundleSummaryView bundle;
  final bool enabled;
  final bool isExporting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: enabled || isExporting ? 1 : 0.86,
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: enabled ? meta.accent : const Color(0xFF94A3B8),
        foregroundColor: Colors.white,
        elevation: enabled ? 8 : 2,
        extendedPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        icon: isExporting
            ? SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.1,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(Icons.file_download_rounded, size: 20.sp),
        label: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              isExporting ? 'Preparing PDF...' : 'Export Report',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.8.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              enabled
                  ? '${meta.shortLabel} • ${bundle.auditCount} audits'
                  : 'No exportable data yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.2.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.84),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.from_heading,
          ),
        ),
      ],
    );
  }
}

class _GlossaryCard extends StatelessWidget {
  const _GlossaryCard({required this.meta});

  final _ReportBundleMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Label guide',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 10.h),
          _GlossaryRow(label: 'Area', description: meta.areaMeaning),
          SizedBox(height: 8.h),
          _GlossaryRow(label: 'Section', description: meta.sectionMeaning),
        ],
      ),
    );
  }
}

class _GlossaryRow extends StatelessWidget {
  const _GlossaryRow({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 56.w,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
        ),
        Expanded(
          child: Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.8.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.from_heading,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricListTile extends StatelessWidget {
  const _MetricListTile({
    required this.accent,
    required this.metric,
    required this.onTap,
  });

  final Color accent;
  final _ReportMetricSummaryView metric;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(metric.icon, color: accent, size: 18.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    metric.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                Icon(
                  onTap == null
                      ? Icons.lock_clock_outlined
                      : Icons.chevron_right_rounded,
                  size: 20.sp,
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              metric.subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.8.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.from_heading,
                height: 1.4,
              ),
            ),
            SizedBox(height: 10.h),
            if (metric.available) ...<Widget>[
              Row(
                children: <Widget>[
                  _RatioPill(
                    label: 'Pass ${metric.summary.passRate}%',
                    color: const Color(0xFF15803D),
                    background: const Color(0xFFE9FBF2),
                  ),
                  SizedBox(width: 8.w),
                  _RatioPill(
                    label: 'Fail ${metric.summary.failRate}%',
                    color: const Color(0xFFDC2626),
                    background: const Color(0xFFFDEEEE),
                  ),
                  const Spacer(),
                  Text(
                    '${metric.summary.totalCount} results',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              _SplitBar(
                passValue: metric.summary.passCount,
                failValue: metric.summary.failCount,
                height: 8.h,
              ),
            ] else
              Text(
                metric.note,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.8.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                  height: 1.45,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeaderCard extends StatelessWidget {
  const _DetailHeaderCard({
    required this.meta,
    required this.metric,
    required this.bundle,
    required this.generatedLabel,
  });

  final _ReportBundleMeta meta;
  final _ReportMetricDetailView metric;
  final _ReportBundleSummaryView bundle;
  final String generatedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: meta.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(metric.icon, color: meta.accent, size: 18.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  metric.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            metric.subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.from_heading,
              height: 1.45,
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: <Widget>[
              _TagChip(label: bundle.label),
              _TagChip(label: 'Audits ${bundle.auditCount}'),
              _TagChip(label: generatedLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailStatsRow extends StatelessWidget {
  const _DetailStatsRow({required this.metric});

  final _ReportMetricDetailView metric;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SmallStatCard(label: 'Pass', value: metric.summary.passCount),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _SmallStatCard(label: 'Fail', value: metric.summary.failCount),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _SmallStatCard(
            label: 'Total',
            value: metric.summary.totalCount,
          ),
        ),
      ],
    );
  }
}

class _SmallStatCard extends StatelessWidget {
  const _SmallStatCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value.toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.from_heading,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.metric});

  final _ReportMetricDetailView metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricColumn(
                  label: 'Pass',
                  count: metric.summary.passCount,
                  percent: metric.summary.passRate,
                  color: const Color(0xFF16A34A),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _MetricColumn(
                  label: 'Fail',
                  count: metric.summary.failCount,
                  percent: metric.summary.failRate,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _SplitBar(
            passValue: metric.summary.passCount,
            failValue: metric.summary.failCount,
            height: 14.h,
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
  });

  final String label;
  final int count;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            count.toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '$percent%',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.from_heading,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleSectionCard extends StatelessWidget {
  const _SimpleSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.items});

  final List<_ReportDistributionItem> items;

  @override
  Widget build(BuildContext context) {
    return _SimpleSectionCard(
      title: 'Breakdown',
      child: Column(
        children: items
            .map(
              (_ReportDistributionItem item) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: _BreakdownRow(item: item),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.item});

  final _ReportDistributionItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '${item.passRate}% / ${item.failRate}%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _SplitBar(
            passValue: item.passCount,
            failValue: item.failCount,
            height: 7.h,
          ),
          SizedBox(height: 6.h),
          Text(
            '${item.passCount} pass / ${item.failCount} fail / ${item.totalCount} total',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.8.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.from_heading,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatioPill extends StatelessWidget {
  const _RatioPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.passValue,
    required this.failValue,
    required this.height,
  });

  final int passValue;
  final int failValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    final int total = passValue + failValue;
    if (total <= 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(999.r),
        ),
      );
    }

    if (passValue <= 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(999.r),
        ),
      );
    }

    if (failValue <= 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(999.r),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999.r),
      child: SizedBox(
        height: height,
        child: Row(
          children: <Widget>[
            Expanded(
              flex: math.max(passValue, 1),
              child: Container(color: const Color(0xFF16A34A)),
            ),
            Expanded(
              flex: math.max(failValue, 1),
              child: Container(color: const Color(0xFFEF4444)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF92400E),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.8.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF92400E),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.from_heading,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.signal_wifi_connected_no_internet_4_rounded,
              size: 44.sp,
              color: const Color(0xFFD64545),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.from_heading,
                height: 1.45,
              ),
            ),
            SizedBox(height: 18.h),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBundleMeta {
  const _ReportBundleMeta({
    required this.key,
    required this.shortLabel,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.areaMeaning,
    required this.sectionMeaning,
  });

  final String key;
  final String shortLabel;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String areaMeaning;
  final String sectionMeaning;
}

class _ReportBundleSummaryView {
  const _ReportBundleSummaryView({
    required this.key,
    required this.label,
    required this.auditCount,
    required this.passCount,
    required this.failCount,
    required this.passRate,
    required this.watchLabel,
    required this.metrics,
  });

  factory _ReportBundleSummaryView.fromMap(
    _ReportBundleMeta meta,
    Map<String, dynamic> map,
  ) {
    return _ReportBundleSummaryView(
      key: _stringOrFallback(map['key'], meta.key),
      label: _stringOrFallback(map['label'], meta.title),
      auditCount: _toInt(map['auditCount']),
      passCount: _toInt(map['passCount']),
      failCount: _toInt(map['failCount']),
      passRate: _toInt(map['passRate']),
      watchLabel: _stringOrFallback(map['watchLabel'], 'No issues flagged'),
      metrics: (map['metrics'] as List? ?? const <dynamic>[])
          .map(
            (dynamic entry) => _ReportMetricSummaryView.fromMap(_toMap(entry)),
          )
          .toList(),
    );
  }

  final String key;
  final String label;
  final int auditCount;
  final int passCount;
  final int failCount;
  final int passRate;
  final String watchLabel;
  final List<_ReportMetricSummaryView> metrics;
}

class _ReportMetricSummaryView {
  const _ReportMetricSummaryView({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.available,
    required this.note,
    required this.summary,
    required this.icon,
  });

  factory _ReportMetricSummaryView.fromMap(Map<String, dynamic> map) {
    final String key = _stringOrFallback(map['key'], 'metric');
    return _ReportMetricSummaryView(
      key: key,
      title: _stringOrFallback(map['title'], 'Report metric'),
      subtitle: _stringOrFallback(map['subtitle'], ''),
      available: map['available'] == true,
      note: _stringOrFallback(map['note'], 'No live data available yet.'),
      summary: _RatioSummary.fromMap(_toMap(map['summary'])),
      icon: _iconForMetric(key),
    );
  }

  final String key;
  final String title;
  final String subtitle;
  final bool available;
  final String note;
  final _RatioSummary summary;
  final IconData icon;
}

class _ReportMetricDetailView {
  const _ReportMetricDetailView({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.available,
    required this.note,
    required this.summary,
    required this.highlightTitle,
    required this.highlightValue,
    required this.items,
    required this.topItems,
    required this.icon,
  });

  factory _ReportMetricDetailView.fromMap(
    Map<String, dynamic> map, {
    required _ReportMetricSummaryView fallback,
  }) {
    final String key = _stringOrFallback(map['key'], fallback.key);
    final List<_ReportDistributionItem> items =
        (map['items'] as List? ?? const <dynamic>[])
            .map(
              (dynamic entry) => _ReportDistributionItem.fromMap(_toMap(entry)),
            )
            .where(
              (_ReportDistributionItem item) =>
                  item.label.trim().isNotEmpty && item.totalCount > 0,
            )
            .toList();
    final List<_ReportDistributionItem> topItems =
        (map['topItems'] as List? ?? const <dynamic>[])
            .map(
              (dynamic entry) => _ReportDistributionItem.fromMap(_toMap(entry)),
            )
            .where(
              (_ReportDistributionItem item) =>
                  item.label.trim().isNotEmpty && item.totalCount > 0,
            )
            .toList();

    return _ReportMetricDetailView(
      key: key,
      title: _stringOrFallback(map['title'], fallback.title),
      subtitle: _stringOrFallback(map['subtitle'], fallback.subtitle),
      available: map['available'] == true || fallback.available,
      note: _stringOrFallback(map['note'], fallback.note),
      summary: _RatioSummary.fromMap(
        map['summary'] == null
            ? _ratioSummaryToMap(fallback.summary)
            : _toMap(map['summary']),
      ),
      highlightTitle: _stringOrFallback(map['highlightTitle'], 'Current read'),
      highlightValue: _stringOrFallback(map['highlightValue'], fallback.note),
      items: items,
      topItems: topItems.isNotEmpty ? topItems : items.take(3).toList(),
      icon: _iconForMetric(key),
    );
  }

  final String key;
  final String title;
  final String subtitle;
  final bool available;
  final String note;
  final _RatioSummary summary;
  final String highlightTitle;
  final String highlightValue;
  final List<_ReportDistributionItem> items;
  final List<_ReportDistributionItem> topItems;
  final IconData icon;
}

class _RatioSummary {
  const _RatioSummary({
    required this.passCount,
    required this.failCount,
    required this.totalCount,
    required this.passRate,
    required this.failRate,
  });

  factory _RatioSummary.fromMap(Map<String, dynamic> map) {
    final int passCount = _toInt(map['passCount']);
    final int failCount = _toInt(map['failCount']);
    final int totalCount = _toInt(map['totalCount']) == 0
        ? passCount + failCount
        : _toInt(map['totalCount']);

    return _RatioSummary(
      passCount: passCount,
      failCount: failCount,
      totalCount: totalCount,
      passRate: _toInt(map['passRate']),
      failRate: _toInt(map['failRate']),
    );
  }

  final int passCount;
  final int failCount;
  final int totalCount;
  final int passRate;
  final int failRate;
}

class _ReportDistributionItem extends _RatioSummary {
  const _ReportDistributionItem({
    required this.label,
    required super.passCount,
    required super.failCount,
    required super.totalCount,
    required super.passRate,
    required super.failRate,
  });

  factory _ReportDistributionItem.fromMap(Map<String, dynamic> map) {
    final _RatioSummary summary = _RatioSummary.fromMap(map);
    return _ReportDistributionItem(
      label: _stringOrFallback(map['label'], 'Unknown'),
      passCount: summary.passCount,
      failCount: summary.failCount,
      totalCount: summary.totalCount,
      passRate: summary.passRate,
      failRate: summary.failRate,
    );
  }

  final String label;
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic entry) => MapEntry(key.toString(), entry),
    );
  }
  return const <String, dynamic>{};
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _stringOrFallback(dynamic value, String fallback) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

Map<String, dynamic> _ratioSummaryToMap(_RatioSummary summary) {
  return <String, dynamic>{
    'passCount': summary.passCount,
    'failCount': summary.failCount,
    'totalCount': summary.totalCount,
    'passRate': summary.passRate,
    'failRate': summary.failRate,
  };
}

IconData _iconForMetric(String key) {
  switch (key) {
    case 'byAudit':
      return Icons.assignment_turned_in_outlined;
    case 'byArea':
      return Icons.grid_view_rounded;
    case 'bySection':
      return Icons.view_sidebar_outlined;
    case 'byEmployees':
      return Icons.groups_outlined;
    case 'byAuditor':
      return Icons.person_search_outlined;
    case 'byAircraftType':
      return Icons.flight_outlined;
    case 'byArrivals':
      return Icons.connecting_airports_outlined;
    case 'byHashtagType':
      return Icons.tag_outlined;
    case 'byChecklistType':
      return Icons.rule_folder_outlined;
    case 'byDriver':
      return Icons.person_outline_rounded;
    case 'byShipNumber':
      return Icons.confirmation_number_outlined;
    default:
      return Icons.query_stats_rounded;
  }
}
