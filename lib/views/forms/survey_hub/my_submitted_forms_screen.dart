import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../services/api_exception.dart';
import '../../../services/app_api_service.dart';
import '../../../utils/app_colors.dart';

class SubmittedSurveyQuestion {
  final String id;
  final String title;
  final String description;
  final String type;

  const SubmittedSurveyQuestion({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
  });

  factory SubmittedSurveyQuestion.fromMap(Map<String, dynamic> map) {
    return SubmittedSurveyQuestion(
      id: (map['id'] as String?) ?? '',
      title: ((map['title'] as String?) ?? 'Question').trim(),
      description: ((map['description'] as String?) ?? '').trim(),
      type: ((map['type'] as String?) ?? '').trim(),
    );
  }
}

class SubmittedSurveyTemplate {
  final String id;
  final String title;
  final String description;
  final String category;
  final String formType;
  final int questionCount;
  final int estimatedMinutes;
  final List<SubmittedSurveyQuestion> questions;

  const SubmittedSurveyTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.formType,
    required this.questionCount,
    required this.estimatedMinutes,
    required this.questions,
  });

  factory SubmittedSurveyTemplate.fromMap(Map<String, dynamic> map) {
    final rawQuestions = map['questions'] is List
        ? map['questions'] as List<dynamic>
        : const <dynamic>[];

    return SubmittedSurveyTemplate(
      id: (map['id'] as String?) ?? '',
      title: ((map['title'] as String?) ?? 'Untitled form').trim(),
      description: ((map['description'] as String?) ?? '').trim(),
      category: ((map['category'] as String?) ?? 'Operations').trim(),
      formType: ((map['formType'] as String?) ?? 'SURVEY').trim(),
      questionCount: (map['questionCount'] as num?)?.toInt() ?? 0,
      estimatedMinutes: (map['estimatedMinutes'] as num?)?.toInt() ?? 0,
      questions: rawQuestions
          .map(
            (item) => SubmittedSurveyQuestion.fromMap(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class SubmittedSurveyEntry {
  final String id;
  final String submittedByName;
  final String submittedByRole;
  final DateTime submittedAt;
  final Map<String, dynamic> answers;
  final Map<String, dynamic> metadata;
  final SubmittedSurveyTemplate template;

  const SubmittedSurveyEntry({
    required this.id,
    required this.submittedByName,
    required this.submittedByRole,
    required this.submittedAt,
    required this.answers,
    required this.metadata,
    required this.template,
  });

  factory SubmittedSurveyEntry.fromMap(Map<String, dynamic> map) {
    return SubmittedSurveyEntry(
      id: (map['id'] as String?) ?? '',
      submittedByName: ((map['submittedByName'] as String?) ?? '').trim(),
      submittedByRole: ((map['submittedByRole'] as String?) ?? '').trim(),
      submittedAt:
          DateTime.tryParse((map['submittedAt'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
      answers: _asMap(map['answers']),
      metadata: _asMap(map['metadata']),
      template: SubmittedSurveyTemplate.fromMap(_asMap(map['template'])),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }
}

class MySubmittedFormsScreen extends StatefulWidget {
  const MySubmittedFormsScreen({super.key});

  @override
  State<MySubmittedFormsScreen> createState() => _MySubmittedFormsScreenState();
}

class _MySubmittedFormsScreenState extends State<MySubmittedFormsScreen> {
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
      final response = await _api.listMyDynamicFormSubmissions(
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
            : 'Unable to load your submitted forms right now.';
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
          entry.template.formType.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final totalAnswers = _items.fold<int>(
      0,
      (sum, item) => sum + item.answers.length,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'My Submitted Forms',
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
            _buildHero(totalAnswers),
            SizedBox(height: 18.h),
            _buildSearchBox(),
            SizedBox(height: 18.h),
            if (_isLoading)
              const _SubmittedFormsLoadingPanel()
            else if (_errorMessage != null)
              _SubmittedFormsErrorPanel(
                message: _errorMessage!,
                onRetry: _loadSubmissions,
              )
            else if (filteredItems.isEmpty)
              _SubmittedFormsEmptyPanel(hasSearch: _searchQuery.isNotEmpty)
            else
              ...filteredItems.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 14.h),
                  child: _SubmittedFormCard(
                    entry: entry,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SubmittedFormAnswersScreen(entry: entry),
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

  Widget _buildHero(int totalAnswers) {
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
              'Personal Submission History',
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
            'Tap a form name to open your submitted answers.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Keep the main list clean, then drill into a dedicated answer view when you want the full submission details.',
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
                child: _SubmittedMetricTile(
                  title: 'Submitted Forms',
                  value: '${_items.length}',
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _SubmittedMetricTile(
                  title: 'Captured Answers',
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
                hintText: 'Search by form title, category, or type',
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

class _SubmittedMetricTile extends StatelessWidget {
  final String title;
  final String value;

  const _SubmittedMetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
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
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmittedFormsLoadingPanel extends StatelessWidget {
  const _SubmittedFormsLoadingPanel();

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
            'Loading your submitted forms...',
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

class _SubmittedFormsErrorPanel extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _SubmittedFormsErrorPanel({
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
            'Unable to load submissions',
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

class _SubmittedFormsEmptyPanel extends StatelessWidget {
  final bool hasSearch;

  const _SubmittedFormsEmptyPanel({required this.hasSearch});

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
            hasSearch
                ? Icons.search_off_rounded
                : Icons.assignment_turned_in_outlined,
            color: const Color(0xFF94A3B8),
            size: 36.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            hasSearch ? 'No matching submissions' : 'No submitted forms yet',
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
                : 'Once you submit a survey from the Forms & Surveys hub, it will appear here.',
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

class _SubmittedFormCard extends StatelessWidget {
  final SubmittedSurveyEntry entry;
  final VoidCallback onTap;

  const _SubmittedFormCard({required this.entry, required this.onTap});

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
                _SubmittedPillChip(
                  label: entry.template.category,
                  background: const Color(0xFFDBEAFE),
                  foreground: const Color(0xFF1D4ED8),
                ),
                _SubmittedPillChip(
                  label: '${entry.template.questionCount} questions',
                  background: const Color(0xFFF1F5F9),
                  foreground: const Color(0xFF475569),
                ),
                _SubmittedPillChip(
                  label: DateFormat(
                    'MMM d, y • h:mm a',
                  ).format(entry.submittedAt),
                  background: const Color(0xFFECFCCB),
                  foreground: const Color(0xFF3F6212),
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
                        entry.template.description.isNotEmpty
                            ? entry.template.description
                            : 'Tap to view the submitted answers for this form.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.sp,
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
                    child: _SummaryLine(
                      label: 'Form type',
                      value: entry.template.formType,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _SummaryLine(
                      label: 'Captured answers',
                      value: '${answerEntries.length}',
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

  static String formatAnswerValue(dynamic value) {
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

class SubmittedFormAnswersScreen extends StatelessWidget {
  final SubmittedSurveyEntry entry;

  const SubmittedFormAnswersScreen({super.key, required this.entry});

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
                    _SubmittedPillChip(
                      label: entry.template.category,
                      background: const Color(0xFFDBEAFE),
                      foreground: const Color(0xFF1D4ED8),
                    ),
                    _SubmittedPillChip(
                      label: '${entry.template.questionCount} questions',
                      background: const Color(0xFFF1F5F9),
                      foreground: const Color(0xFF475569),
                    ),
                    _SubmittedPillChip(
                      label: DateFormat(
                        'MMM d, y • h:mm a',
                      ).format(entry.submittedAt),
                      background: const Color(0xFFECFCCB),
                      foreground: const Color(0xFF3F6212),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                Text(
                  entry.template.description.isNotEmpty
                      ? entry.template.description
                      : 'Submitted from the synced mobile survey flow.',
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
                      child: _SummaryLine(
                        label: 'Form type',
                        value: entry.template.formType,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _SummaryLine(
                        label: 'Captured answers',
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
                        _SubmittedFormCard.formatAnswerValue(answer.value),
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
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({required this.label, required this.value});

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

class _SubmittedPillChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _SubmittedPillChip({
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
