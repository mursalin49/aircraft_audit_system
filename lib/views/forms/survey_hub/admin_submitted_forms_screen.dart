import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../services/api_exception.dart';
import '../../../services/app_api_service.dart';
import '../../../utils/app_colors.dart';
import 'my_submitted_forms_screen.dart';

class AdminSubmittedFormsScreen extends StatefulWidget {
  const AdminSubmittedFormsScreen({super.key});

  @override
  State<AdminSubmittedFormsScreen> createState() =>
      _AdminSubmittedFormsScreenState();
}

class _AdminSubmittedFormsScreenState extends State<AdminSubmittedFormsScreen> {
  final AppApiService _api = Get.find<AppApiService>();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<SubmittedSurveyEntry> _items = const <SubmittedSurveyEntry>[];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_handleSearchChanged);
    _loadSubmissions();
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final next = _searchCtrl.text.trim();
    if (next == _searchQuery) {
      return;
    }
    setState(() => _searchQuery = next);
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.listAllDynamicFormSubmissions(
        queryParameters: {'page': 1, 'limit': 100},
      );
      final rawItems = response['items'] is List
          ? response['items'] as List<dynamic>
          : const <dynamic>[];
      setState(() {
        _items = rawItems
            .map(
              (item) => SubmittedSurveyEntry.fromMap(
                item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      });
    } catch (error) {
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : 'Unable to load system-wide submitted forms right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<SubmittedSurveyEntry> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return _items;
    }

    final query = _searchQuery.toLowerCase();
    return _items.where((entry) {
      return entry.template.title.toLowerCase().contains(query) ||
          entry.template.category.toLowerCase().contains(query) ||
          entry.template.formType.toLowerCase().contains(query) ||
          entry.submittedByName.toLowerCase().contains(query) ||
          entry.submittedByRole.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final totalAnswers = _items.fold<int>(
      0,
      (sum, item) => sum + item.answers.length,
    );
    final uniqueSubmitters = _items
        .map((item) => item.submittedByName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'All Submitted Forms',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSubmissions,
            icon: _isLoading
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSubmissions,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 28.h),
          children: [
            _buildHero(totalAnswers, uniqueSubmitters),
            SizedBox(height: 18.h),
            _buildSearchBox(),
            SizedBox(height: 18.h),
            if (_isLoading)
              const _AdminSubmissionsLoadingPanel()
            else if (_errorMessage != null)
              _AdminSubmissionsErrorPanel(
                message: _errorMessage!,
                onRetry: _loadSubmissions,
              )
            else if (filteredItems.isEmpty)
              _AdminSubmissionsEmptyPanel(hasSearch: _searchQuery.isNotEmpty)
            else
              ...filteredItems.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 14.h),
                  child: _AdminSubmittedFormCard(
                    entry: entry,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AdminSubmittedFormAnswersScreen(entry: entry),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(int totalAnswers, int uniqueSubmitters) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0F172A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              'Admin Submission Monitor',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Review every submitted form across the app context.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Admins can inspect who submitted each form, when it happened, and open the full captured answers.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.45,
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: _AdminMetricTile(
                  title: 'Submissions',
                  value: '${_items.length}',
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _AdminMetricTile(
                  title: 'Submitters',
                  value: '$uniqueSubmitters',
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _AdminMetricTile(
                  title: 'Answers',
                  value: '$totalAnswers',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
          SizedBox(width: 10.w),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by form, category, submitter, or role',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMetricTile extends StatelessWidget {
  final String title;
  final String value;

  const _AdminMetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSubmissionsLoadingPanel extends StatelessWidget {
  const _AdminSubmissionsLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 28.w,
            height: 28.w,
            child: const CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 14.h),
          Text(
            'Loading all submitted forms...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.from_heading,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSubmissionsErrorPanel extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _AdminSubmissionsErrorPanel({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load system submissions',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFB91C1C),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF991B1B),
              height: 1.45,
            ),
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainAppColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              onPressed: () => onRetry(),
              child: Text(
                'Retry',
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
  }
}

class _AdminSubmissionsEmptyPanel extends StatelessWidget {
  final bool hasSearch;

  const _AdminSubmissionsEmptyPanel({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            color: const Color(0xFF94A3B8),
            size: 36.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            hasSearch ? 'No matching submissions' : 'No system submissions yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            hasSearch
                ? 'Try a different search keyword.'
                : 'Once users submit forms from the mobile survey flow, they will appear here for admin review.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.sp,
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

class _AdminSubmittedFormCard extends StatelessWidget {
  final SubmittedSurveyEntry entry;
  final VoidCallback onTap;

  const _AdminSubmittedFormCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final answerEntries = entry.answers.entries.toList();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22.r),
      child: Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _AdminPillChip(
                  label: entry.template.category,
                  background: const Color(0xFFDBEAFE),
                  foreground: const Color(0xFF1D4ED8),
                ),
                _AdminPillChip(
                  label: DateFormat(
                    'MMM d, y • h:mm a',
                  ).format(entry.submittedAt),
                  background: const Color(0xFFFFEDD5),
                  foreground: const Color(0xFF9A3412),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.template.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '${entry.submittedByName.isEmpty ? "Unknown user" : entry.submittedByName} • ${entry.submittedByRole.isEmpty ? "Operational user" : entry.submittedByRole}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        entry.template.description.isNotEmpty
                            ? entry.template.description
                            : 'Tap to open the full submitted answers.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.from_heading,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.mainAppColor,
                    size: 24.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _AdminSummaryLine(
                      label: 'Form type',
                      value: entry.template.formType,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _AdminSummaryLine(
                      label: 'Answers',
                      value: '${answerEntries.length}',
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _AdminSummaryLine(
                      label: 'Questions',
                      value: '${entry.template.questionCount}',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminSubmittedFormAnswersScreen extends StatelessWidget {
  final SubmittedSurveyEntry entry;

  const AdminSubmittedFormAnswersScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final questionLookup = {
      for (final question in entry.template.questions) question.id: question,
    };
    final answerEntries = entry.answers.entries.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          entry.template.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
        children: [
          Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _AdminPillChip(
                      label: entry.template.category,
                      background: const Color(0xFFDBEAFE),
                      foreground: const Color(0xFF1D4ED8),
                    ),
                    _AdminPillChip(
                      label: DateFormat(
                        'MMM d, y • h:mm a',
                      ).format(entry.submittedAt),
                      background: const Color(0xFFFFEDD5),
                      foreground: const Color(0xFF9A3412),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                Text(
                  '${entry.submittedByName.isEmpty ? "Unknown user" : entry.submittedByName} • ${entry.submittedByRole.isEmpty ? "Operational user" : entry.submittedByRole}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  entry.template.description.isNotEmpty
                      ? entry.template.description
                      : 'Admin review of the submitted survey answers.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.from_heading,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(
                      child: _AdminSummaryLine(
                        label: 'Form type',
                        value: entry.template.formType,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _AdminSummaryLine(
                        label: 'Answers',
                        value: '${answerEntries.length}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Submitted answers',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 10.h),
          if (answerEntries.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'This submission does not contain any captured answers.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.from_heading,
                ),
              ),
            )
          else
            ...answerEntries.asMap().entries.map((entryItem) {
              final answer = entryItem.value;
              final question = questionLookup[answer.key];
              return Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question?.title ?? 'Question ${entryItem.key + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                        ),
                      ),
                      if ((question?.description ?? '').trim().isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          question!.description,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.from_heading,
                          ),
                        ),
                      ],
                      SizedBox(height: 8.h),
                      Text(
                        _formatAnswerValue(answer.value),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatAnswerValue(dynamic value) {
    if (value == null) {
      return 'No response';
    }
    if (value is List) {
      return value.isEmpty ? 'No response' : value.join(', ');
    }
    if (value is Map) {
      final normalized = value.map(
        (key, entry) => MapEntry(key.toString(), entry),
      );
      final originalFileName =
          normalized['originalFileName']?.toString().trim() ?? '';
      final cloudinaryUrl =
          normalized['cloudinaryUrl']?.toString().trim() ?? '';
      final fileId = normalized['fileId']?.toString().trim() ?? '';

      if (originalFileName.isNotEmpty) {
        return originalFileName;
      }
      if (cloudinaryUrl.isNotEmpty) {
        return cloudinaryUrl;
      }
      if (fileId.isNotEmpty) {
        return fileId;
      }
      return normalized.toString();
    }
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    return value.toString().trim().isEmpty ? 'No response' : value.toString();
  }
}

class _AdminSummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _AdminSummaryLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _AdminPillChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _AdminPillChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}
