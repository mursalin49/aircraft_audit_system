import 'dart:async';

import 'package:avislap/services/api_exception.dart';
import 'package:avislap/services/app_api_service.dart';
import 'package:avislap/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AuditOperationsTab extends StatefulWidget {
  const AuditOperationsTab({super.key});

  @override
  State<AuditOperationsTab> createState() => _AuditOperationsTabState();
}

class _AuditOperationsTabState extends State<AuditOperationsTab> {
  final AppApiService _api = Get.find<AppApiService>();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSearching = false;
  String? _errorMessage;
  String _selectedType = '';
  Timer? _searchDebounce;
  Map<String, dynamic> _overview = const <String, dynamic>{};
  List<Map<String, dynamic>> _records = const <Map<String, dynamic>>[];

  static const Map<String, String> _typeLabels = {
    '': 'All',
    'CABIN_QUALITY': 'Cabin Quality',
    'CABIN_SECURITY': 'Security',
    'HIDDEN_OBJECT': 'Hidden Object',
    'LAV_SAFETY': 'LAV Safety',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (mounted) {
      setState(() {
        if (showLoader) {
          _isLoading = true;
        } else {
          _isSearching = true;
        }
        _errorMessage = null;
      });
    }

    try {
      final query = <String, dynamic>{
        'page': 1,
        'limit': 50,
        if (_selectedType.isNotEmpty) 'auditType': _selectedType,
        if (_searchCtrl.text.trim().isNotEmpty)
          'search': _searchCtrl.text.trim(),
      };

      final results = await Future.wait([
        _api.getAdminOverview(),
        _api.getAdminAuditRecords(queryParameters: query),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _overview = results[0];
        _records = List<Map<String, dynamic>>.from(
          results[1]['items'] as List? ?? const <dynamic>[],
        );
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _records = const <Map<String, dynamic>>[];
          _errorMessage = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _records = const <Map<String, dynamic>>[];
          _errorMessage = 'Unable to load audit operations right now.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSearching = false;
        });
      }
    }
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadData(showLoader: false);
    });
  }

  Future<void> _openRecord(Map<String, dynamic> record) async {
    final id = record['id']?.toString() ?? '';
    final type = record['auditType']?.toString() ?? '';
    if (id.isEmpty || type.isEmpty) {
      return;
    }

    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      final detail = await _api.getAdminAuditDetail(id: id, type: type);
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      _showDetailSheet(record, detail);
    } on ApiException catch (error) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      _showError('Audit Unavailable', error.message);
    } catch (_) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      _showError('Audit Unavailable', 'Unable to load this audit right now.');
    }
  }

  void _showError(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  void _showDetailSheet(
    Map<String, dynamic> record,
    Map<String, dynamic> detail,
  ) {
    final type = record['auditType']?.toString() ?? '';
    final accent = _typeColor(type);
    final rows = _detailRows(type, detail, record);
    final resultRows = _resultRows(type, detail);

    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(16.w, 10.h, 8.w, 12.h),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE8EDF5)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 42.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7DEE9),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          _TypeIcon(type: type, color: accent),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              _auditTitle(record),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.dark,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Get.back(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.from_heading,
                              size: 22.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 28.h),
                    child: Column(
                      children: [
                        _ScoreCard(
                          score: _num(record['score']).round(),
                          status: record['status']?.toString() ?? '',
                        ),
                        _InfoCard(rows: rows),
                        if (resultRows.isNotEmpty)
                          _ResultsCard(
                            title: 'Submitted Results',
                            rows: resultRows,
                          ),
                        _ReadOnlyNotice(color: accent),
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

  List<_InfoRow> _detailRows(
    String type,
    Map<String, dynamic> detail,
    Map<String, dynamic> record,
  ) {
    final occurredAt = _parseDate(record['occurredAt']);
    final rows = <_InfoRow>[
      _InfoRow('Auditor', record['auditorName']?.toString() ?? ''),
      _InfoRow('Gate', record['gateCode']?.toString() ?? ''),
      _InfoRow('Summary', record['summary']?.toString() ?? ''),
      _InfoRow('Occurred', DateFormat('MMM d, y - h:mm a').format(occurredAt)),
    ];

    if (type == 'CABIN_SECURITY') {
      rows.add(_InfoRow('Ship Number', detail['shipNumber']?.toString() ?? ''));
    } else if (type == 'LAV_SAFETY') {
      rows.add(_InfoRow('Driver', detail['driverName']?.toString() ?? ''));
    } else if (type == 'HIDDEN_OBJECT') {
      rows.addAll([
        _InfoRow('Ship Number', detail['shipNumber']?.toString() ?? ''),
        _InfoRow(
          'Aircraft',
          _asMap(detail['aircraftType'])['name']?.toString() ?? '',
        ),
        _InfoRow('Objects', detail['objectsToHideCount']?.toString() ?? ''),
      ]);
    } else if (type == 'CABIN_QUALITY') {
      rows.add(
        _InfoRow('Clean Type', detail['cleanTypeSnapshot']?.toString() ?? ''),
      );
    }

    return rows.where((row) => row.value.trim().isNotEmpty).toList();
  }

  List<_ResultRow> _resultRows(String type, Map<String, dynamic> detail) {
    if (type == 'CABIN_QUALITY' || type == 'LAV_SAFETY') {
      return _listOfMaps(detail['responses']).map((item) {
        final checklist = _asMap(item['checklistItem']);
        return _ResultRow(
          checklist['label']?.toString() ?? 'Checklist Item',
          _normalizeStatus(item['response']?.toString() ?? ''),
        );
      }).toList();
    }

    if (type == 'CABIN_SECURITY') {
      return _listOfMaps(detail['results']).map((item) {
        final area = _asMap(item['area']);
        return _ResultRow(
          item['areaLabelSnapshot']?.toString() ??
              area['label']?.toString() ??
              'Area',
          _normalizeStatus(item['result']?.toString() ?? ''),
        );
      }).toList();
    }

    if (type == 'HIDDEN_OBJECT') {
      return _listOfMaps(detail['locations']).map((item) {
        return _ResultRow(
          [
            item['sectionLabel']?.toString() ?? '',
            item['locationLabel']?.toString() ?? '',
          ].where((part) => part.trim().isNotEmpty).join(' - '),
          item['status']?.toString() ?? '',
        );
      }).toList();
    }

    return const <_ResultRow>[];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Container(
          color: const Color(0xFFF5F7FB),
          child: RefreshIndicator(
            color: AppColors.mainAppColor,
            onRefresh: () => _loadData(showLoader: false),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverToBoxAdapter(child: _buildSummaryCards()),
                SliverToBoxAdapter(child: _buildFilters()),
                if (_isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorMessage != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MessageState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Audit operations unavailable',
                      message: _errorMessage!,
                      actionLabel: 'Try Again',
                      onAction: _loadData,
                    ),
                  )
                else if (_records.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MessageState(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'No audit records',
                      message: 'System-wide submitted audits will appear here.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 28.h),
                    sliver: SliverList.separated(
                      itemCount: _records.length,
                      separatorBuilder: (_, _) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) => _AuditRecordCard(
                        record: _records[index],
                        onTap: _openRecord,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 22.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EDF5))),
      ),
      child: Row(
        children: [
          if (canPop) ...[
            IconButton(
              tooltip: 'Back',
              onPressed: () => Get.back(),
              icon: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.from_heading,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 4.w),
          ],
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: AppColors.mainAppColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.assignment_turned_in_outlined,
              color: AppColors.mainAppColor,
              size: 25.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Submitted Audits',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'System-wide submitted audits',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.from_heading,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : () => _loadData(showLoader: false),
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.mainAppColor,
              size: 24.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totals = _asMap(_overview['totals']);
    final compliance = _asMap(_overview['compliance']);
    final attention = _asMap(_overview['attentionRequired']);
    final masterData = _asMap(_overview['masterData']);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.55,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        children: [
          _MetricCard(
            label: 'Total Audits',
            value: _num(totals['totalAudits']).round().toString(),
            icon: Icons.assignment_outlined,
            color: AppColors.mainAppColor,
          ),
          _MetricCard(
            label: 'Compliance',
            value: '${_num(compliance['overallScore']).round()}%',
            icon: Icons.verified_outlined,
            color: const Color(0xFF16A34A),
          ),
          _MetricCard(
            label: 'Attention',
            value: _num(attention['total']).round().toString(),
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFF59E0B),
          ),
          _MetricCard(
            label: 'Managed Gates',
            value: _num(masterData['gates']).round().toString(),
            icon: Icons.location_on_outlined,
            color: const Color(0xFF0F172A),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: _handleSearchChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.from_heading,
              ),
              suffixIcon: _isSearching
                  ? Padding(
                      padding: EdgeInsets.all(14.w),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        _loadData(showLoader: false);
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              hintText: 'Search auditor, gate, summary, status',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13.sp,
                color: AppColors.from_heading,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 40.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _typeLabels.length,
              separatorBuilder: (_, _) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final entry = _typeLabels.entries.elementAt(index);
                final selected = entry.key == _selectedType;
                return ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  label: Text(entry.value),
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.dark,
                  ),
                  selectedColor: AppColors.mainAppColor,
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: BorderSide(
                    color: selected
                        ? AppColors.mainAppColor
                        : const Color(0xFFE1E8F2),
                  ),
                  onSelected: (_) {
                    setState(() => _selectedType = entry.key);
                    _loadData(showLoader: false);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditRecordCard extends StatelessWidget {
  const _AuditRecordCard({required this.record, required this.onTap});

  final Map<String, dynamic> record;
  final ValueChanged<Map<String, dynamic>> onTap;

  @override
  Widget build(BuildContext context) {
    final type = record['auditType']?.toString() ?? '';
    final color = _typeColor(type);
    final score = _num(record['score']).round();
    final status = record['status']?.toString() ?? '';
    final occurredAt = _parseDate(record['occurredAt']);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: () => onTap(record),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeIcon(type: type, color: color),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _auditTitle(record),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        _Pill(label: status, color: _statusColor(status)),
                      ],
                    ),
                    SizedBox(height: 7.h),
                    Text(
                      record['summary']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.from_heading,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _MetaPill(
                          icon: Icons.person_outline_rounded,
                          label: record['auditorName']?.toString() ?? 'Unknown',
                        ),
                        _MetaPill(
                          icon: Icons.location_on_outlined,
                          label: record['gateCode']?.toString() ?? 'N/A',
                        ),
                        _MetaPill(
                          icon: Icons.calendar_today_outlined,
                          label: DateFormat('MMM d').format(occurredAt),
                        ),
                        _MetaPill(icon: Icons.speed_rounded, label: '$score%'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.from_heading,
                size: 22.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.from_heading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score, required this.status});

  final int score;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 62.w,
            height: 62.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$score%',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              'Status: ${status.isEmpty ? 'N/A' : status}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'Audit Information',
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 98.w,
                      child: Text(
                        row.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.from_heading,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.title, required this.rows});

  final String title;
  final List<_ResultRow> rows;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: title,
      child: Column(
        children: rows
            .map(
              (row) => Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFFE8EDF5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label.isEmpty ? 'Result' : row.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                        ),
                      ),
                    ),
                    _Pill(label: row.status, color: _statusColor(row.status)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, color: color, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'This is a view-only audit operations record.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type, required this.color});

  final String type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Icon(_typeIcon(type), color: color, size: 23.sp),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label.isEmpty ? 'N/A' : label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: AppColors.from_heading),
          SizedBox(width: 4.w),
          Text(
            label,
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

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(28.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.mainAppColor, size: 44.sp),
          SizedBox(height: 14.h),
          Text(
            title,
            textAlign: TextAlign.center,
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
              fontWeight: FontWeight.w600,
              color: AppColors.from_heading,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 16.h),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.mainAppColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

class _ResultRow {
  const _ResultRow(this.label, this.status);

  final String label;
  final String status;
}

String _auditTitle(Map<String, dynamic> record) {
  final type = record['auditType']?.toString() ?? '';
  switch (type) {
    case 'CABIN_QUALITY':
      return 'Cabin Quality Audit';
    case 'CABIN_SECURITY':
      return 'Cabin Security Search Training';
    case 'HIDDEN_OBJECT':
      return 'Hidden Object Audit';
    case 'LAV_SAFETY':
      return 'LAV Safety Observation';
    default:
      return record['title']?.toString() ?? 'Audit Record';
  }
}

IconData _typeIcon(String type) {
  switch (type) {
    case 'CABIN_QUALITY':
      return Icons.fact_check_outlined;
    case 'CABIN_SECURITY':
      return Icons.security_outlined;
    case 'HIDDEN_OBJECT':
      return Icons.search_rounded;
    case 'LAV_SAFETY':
      return Icons.clean_hands_outlined;
    default:
      return Icons.assignment_outlined;
  }
}

Color _typeColor(String type) {
  switch (type) {
    case 'CABIN_QUALITY':
      return const Color(0xFF2563EB);
    case 'CABIN_SECURITY':
      return const Color(0xFF10B981);
    case 'HIDDEN_OBJECT':
      return const Color(0xFF0F172A);
    case 'LAV_SAFETY':
      return const Color(0xFFF59E0B);
    default:
      return AppColors.mainAppColor;
  }
}

Color _statusColor(String status) {
  switch (status.trim().toUpperCase()) {
    case 'PASS':
      return const Color(0xFF16A34A);
    case 'ACTIVE':
      return const Color(0xFF2563EB);
    case 'SETUP':
      return const Color(0xFFF59E0B);
    case 'FAIL':
    case 'RED':
      return const Color(0xFFDC2626);
    case 'GREEN':
      return const Color(0xFF16A34A);
    default:
      return const Color(0xFF64748B);
  }
}

String _normalizeStatus(String value) {
  switch (value.trim().toUpperCase()) {
    case 'YES':
    case 'PASS':
    case 'GREEN':
      return 'PASS';
    case 'NO':
    case 'FAIL':
    case 'RED':
      return 'FAIL';
    case 'NA':
    case 'N/A':
      return 'N/A';
    default:
      return value.trim().isEmpty ? 'N/A' : value.trim().toUpperCase();
  }
}

DateTime _parseDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

double _num(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
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

List<Map<String, dynamic>> _listOfMaps(dynamic raw) {
  if (raw is! List) {
    return const <Map<String, dynamic>>[];
  }
  return raw.map(_asMap).where((entry) => entry.isNotEmpty).toList();
}
