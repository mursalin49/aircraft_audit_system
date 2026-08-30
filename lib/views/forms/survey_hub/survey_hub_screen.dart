import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../../../services/api_exception.dart';
import '../../../services/app_api_service.dart';
import '../../../utils/app_colors.dart';

class SurveyQuestion {
  final String id;
  final String title;
  final String description;
  final String type;
  final bool required;
  final List<String> options;

  const SurveyQuestion({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.required,
    required this.options,
  });

  factory SurveyQuestion.fromMap(Map<String, dynamic> map) {
    return SurveyQuestion(
      id: (map['id'] as String?)?.trim().isNotEmpty == true
          ? (map['id'] as String).trim()
          : 'question_${DateTime.now().microsecondsSinceEpoch}',
      title: ((map['title'] as String?) ?? 'Untitled question').trim(),
      description: ((map['description'] as String?) ?? '').trim(),
      type: ((map['type'] as String?) ?? 'short-answer').trim().toLowerCase(),
      required: map['required'] == true,
      options: (map['options'] is List)
          ? (map['options'] as List)
                .map((dynamic item) => item.toString().trim())
                .where((String item) => item.isNotEmpty)
                .toList()
          : const <String>[],
    );
  }

  bool get isShortText =>
      type == 'short-answer' ||
      type == 'text' ||
      type == 'email' ||
      type == 'number';

  bool get isLongText => type == 'paragraph' || type == 'long_text';

  bool get isSingleChoice =>
      type == 'multiple-choice' ||
      type == 'multiple_choice' ||
      type == 'single-choice' ||
      type == 'single_choice';

  bool get isMultiChoice =>
      type == 'checkboxes' ||
      type == 'checkbox' ||
      type == 'multi-choice' ||
      type == 'multi_choice';

  bool get isDropdown => type == 'dropdown';

  bool get isRating =>
      type == 'rating' || type == 'linear-scale' || type == 'linear_scale';

  bool get isDate => type == 'date';

  bool get isTime => type == 'time';

  bool get isFileUpload => type == 'file-upload' || type == 'file_upload';
}

class SurveyTemplate {
  final String id;
  final String title;
  final String description;
  final String category;
  final String formType;
  final String status;
  final int estimatedMinutes;
  final List<SurveyQuestion> questions;

  const SurveyTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.formType,
    required this.status,
    required this.estimatedMinutes,
    required this.questions,
  });

  factory SurveyTemplate.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawQuestions = map['questions'] is List
        ? map['questions'] as List<dynamic>
        : const <dynamic>[];

    return SurveyTemplate(
      id: (map['id'] as String?) ?? '',
      title: ((map['title'] as String?) ?? 'Untitled form').trim(),
      description: ((map['description'] as String?) ?? '').trim(),
      category: ((map['category'] as String?) ?? 'Operations').trim(),
      formType: ((map['formType'] as String?) ?? 'SURVEY').trim(),
      status: ((map['status'] as String?) ?? 'PUBLISHED').trim(),
      estimatedMinutes: (map['estimatedMinutes'] as num?)?.toInt() ?? 1,
      questions: rawQuestions
          .map(
            (dynamic item) => SurveyQuestion.fromMap(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class SurveyHubScreen extends StatefulWidget {
  const SurveyHubScreen({super.key});

  @override
  State<SurveyHubScreen> createState() => _SurveyHubScreenState();
}

class _SurveyHubScreenState extends State<SurveyHubScreen> {
  final AppApiService _api = Get.find<AppApiService>();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<SurveyTemplate> _surveys = const <SurveyTemplate>[];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_handleSearchChanged);
    _loadSurveys();
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final String next = _searchCtrl.text.trim();
    if (next == _searchQuery) {
      return;
    }
    setState(() => _searchQuery = next);
  }

  Future<void> _loadSurveys() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Map<String, dynamic>> response = await _api
          .listPublishedDynamicForms();
      setState(() {
        _surveys = response.map(SurveyTemplate.fromMap).toList();
      });
    } catch (error) {
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : 'Unable to load published forms right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<SurveyTemplate> get _filteredSurveys {
    if (_searchQuery.isEmpty) {
      return _surveys;
    }

    final String query = _searchQuery.toLowerCase();
    return _surveys.where((SurveyTemplate template) {
      return template.title.toLowerCase().contains(query) ||
          template.description.toLowerCase().contains(query) ||
          template.category.toLowerCase().contains(query) ||
          template.formType.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<SurveyTemplate> filteredSurveys = _filteredSurveys;
    final int totalQuestions = _surveys.fold<int>(
      0,
      (int sum, SurveyTemplate item) => sum + item.questions.length,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Forms & Surveys',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
            letterSpacing: -0.5,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _isLoading ? null : _loadSurveys,
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
        onRefresh: _loadSurveys,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 28.h),
          children: <Widget>[
            Container(
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
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999.r),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      'Live Mobile Response Hub',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Answer the same forms your admins publish in the dashboard.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Published templates are loaded from the backend, rendered by question type, and submitted back into the admin log automatically.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricTile(
                          title: 'Published Forms',
                          value: '${_surveys.length}',
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _MetricTile(
                          title: 'Questions',
                          value: '$totalQuestions',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 22.h),
            _SearchSummaryCard(
              controller: _searchCtrl,
              searchQuery: _searchQuery,
              totalCount: _surveys.length,
              resultCount: filteredSurveys.length,
            ),
            SizedBox(height: 18.h),
            Text(
              'Available surveys',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            SizedBox(height: 14.h),
            if (_isLoading)
              const _LoadingPanel()
            else if (_errorMessage != null)
              _ErrorPanel(message: _errorMessage!, onRetry: _loadSurveys)
            else if (_surveys.isEmpty)
              const _EmptyPanel()
            else if (filteredSurveys.isEmpty)
              _SearchEmptyPanel(searchQuery: _searchQuery)
            else
              ...filteredSurveys.map(
                (SurveyTemplate template) => Padding(
                  padding: EdgeInsets.only(bottom: 14.h),
                  child: _SurveyCard(template: template),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchSummaryCard extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final int totalCount;
  final int resultCount;

  const _SearchSummaryCard({
    required this.controller,
    required this.searchQuery,
    required this.totalCount,
    required this.resultCount,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasSearch = searchQuery.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(16.w),
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
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
            child: Row(
              children: <Widget>[
                const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText:
                          'Search by form title, category, type, or keyword',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                if (hasSearch)
                  IconButton(
                    onPressed: controller.clear,
                    splashRadius: 18.r,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          // Text(
          //   hasSearch
          //       ? '$resultCount of $totalCount forms match "${searchQuery.trim()}".'
          //       : 'Browse all $totalCount published forms or search to jump to one faster.',
          //   style: GoogleFonts.plusJakartaSans(
          //     fontSize: 12.sp,
          //     fontWeight: FontWeight.w600,
          //     color: const Color(0xFF64748B),
          //     height: 1.45,
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

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
        children: <Widget>[
          SizedBox(
            width: 28.w,
            height: 28.w,
            child: const CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 14.h),
          Text(
            'Loading published forms...',
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

class _ErrorPanel extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorPanel({required this.message, required this.onRetry});

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
        children: <Widget>[
          Text(
            'Unable to load forms',
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
                'Retry Sync',
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

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

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
        children: <Widget>[
          Icon(
            Icons.assignment_outlined,
            color: const Color(0xFF94A3B8),
            size: 34.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            'No published forms yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Ask an admin to publish a form from Forms Creation, then pull to refresh here.',
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

class _SearchEmptyPanel extends StatelessWidget {
  final String searchQuery;

  const _SearchEmptyPanel({required this.searchQuery});

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
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            color: const Color(0xFF94A3B8),
            size: 34.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            'No matching forms found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'No published forms matched "$searchQuery". Try a different title, category, or keyword.',
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

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;

  const _MetricTile({required this.title, required this.value});

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
        children: <Widget>[
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

class _SurveyCard extends StatelessWidget {
  final SurveyTemplate template;

  const _SurveyCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: <Widget>[
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: <Widget>[
              _PillChip(
                label: template.category,
                background: const Color(0xFFDBEAFE),
                foreground: const Color(0xFF1D4ED8),
              ),
              _PillChip(
                label: '${template.questions.length} questions',
                background: const Color(0xFFF1F5F9),
                foreground: const Color(0xFF475569),
              ),
              _PillChip(
                label: '${template.estimatedMinutes} min',
                background: const Color(0xFFECFCCB),
                foreground: const Color(0xFF3F6212),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            template.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            template.description.isNotEmpty
                ? template.description
                : 'This published form is ready for mobile submission.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.from_heading,
              height: 1.45,
            ),
          ),
          SizedBox(height: 16.h),
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
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SurveyResponseScreen(template: template),
                  ),
                );
              },
              child: Text(
                'Start Survey',
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

class _PillChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _PillChip({
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
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class SurveyResponseScreen extends StatefulWidget {
  final SurveyTemplate template;

  const SurveyResponseScreen({super.key, required this.template});

  @override
  State<SurveyResponseScreen> createState() => _SurveyResponseScreenState();
}

class _SurveyResponseScreenState extends State<SurveyResponseScreen> {
  final AppApiService _api = Get.find<AppApiService>();
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, dynamic> _responses = <String, dynamic>{};

  bool _isSubmitting = false;
  String? _uploadingQuestionId;

  bool _isMissing(SurveyQuestion question) {
    if (!question.required) {
      return false;
    }

    final dynamic value = _responses[question.id];
    if (value == null) {
      return true;
    }
    if (value is String && value.trim().isEmpty) {
      return true;
    }
    if (value is List && value.isEmpty) {
      return true;
    }
    return false;
  }

  Future<void> _submit() async {
    final List<String> missing = widget.template.questions
        .where(_isMissing)
        .map((SurveyQuestion question) => question.title)
        .toList();

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complete required questions: ${missing.join(', ')}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _api.submitPublishedDynamicForm(
        widget.template.id,
        answers: _responses,
        metadata: <String, dynamic>{
          'source': 'flutter-mobile',
          'formType': widget.template.formType,
        },
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
            ),
            title: Text(
              'Survey Submitted',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            ),
            content: Text(
              'Your response has been synced with the admin dashboard successfully.',
              style: GoogleFonts.plusJakartaSans(height: 1.4),
            ),
            actions: <Widget>[
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = error is ApiException
          ? error.message
          : 'Unable to submit the form right now.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _selectDate(SurveyQuestion question) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _responses[question.id] = picked.toIso8601String().split('T').first;
    });
  }

  Future<void> _selectTime(SurveyQuestion question) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _responses[question.id] =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickAndUploadFile(
    SurveyQuestion question,
    ImageSource source,
  ) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(source: source);
      if (picked == null) {
        return;
      }

      setState(() {
        _uploadingQuestionId = question.id;
      });

      final File file = File(picked.path);
      final Map<String, dynamic> uploaded = await _api.uploadFile(
        file,
        category: 'DYNAMIC_FORM_ATTACHMENT',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _responses[question.id] = <String, dynamic>{
          'fileId': uploaded['id'],
          'cloudinaryUrl': uploaded['cloudinaryUrl'],
          'originalFileName':
              (uploaded['originalFileName'] as String?) ??
              path.basename(file.path),
        };
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = error is ApiException
          ? error.message
          : 'Unable to upload the attachment.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingQuestionId = null;
        });
      }
    }
  }

  Future<void> _openUploadChooser(SurveyQuestion question) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(18.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _UploadActionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from gallery',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadFile(question, ImageSource.gallery);
                  },
                ),
                SizedBox(height: 10.h),
                _UploadActionTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take a photo',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadFile(question, ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          widget.template.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: <Widget>[
                    _PillChip(
                      label: widget.template.category,
                      background: const Color(0xFFDBEAFE),
                      foreground: const Color(0xFF1D4ED8),
                    ),
                    _PillChip(
                      label: '${widget.template.questions.length} questions',
                      background: const Color(0xFFF1F5F9),
                      foreground: const Color(0xFF475569),
                    ),
                    _PillChip(
                      label: widget.template.formType,
                      background: const Color(0xFFF5F3FF),
                      foreground: const Color(0xFF6D28D9),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                Text(
                  widget.template.description.isNotEmpty
                      ? widget.template.description
                      : 'Complete the published questions below and submit your response.',
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
          SizedBox(height: 18.h),
          ...widget.template.questions.asMap().entries.map((
            MapEntry<int, SurveyQuestion> entry,
          ) {
            final int index = entry.key;
            final SurveyQuestion question = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: 14.h),
              child: _SurveyQuestionCard(
                index: index + 1,
                question: question,
                value: _responses[question.id],
                isUploading: _uploadingQuestionId == question.id,
                onChanged: (dynamic value) {
                  setState(() {
                    _responses[question.id] = value;
                  });
                },
                onSelectDate: () => _selectDate(question),
                onSelectTime: () => _selectTime(question),
                onUploadTap: () => _openUploadChooser(question),
              ),
            );
          }),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainAppColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Submit Response',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.sp,
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

class _UploadActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _UploadActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Ink(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: AppColors.mainAppColor),
            SizedBox(width: 12.w),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurveyQuestionCard extends StatelessWidget {
  final int index;
  final SurveyQuestion question;
  final dynamic value;
  final bool isUploading;
  final ValueChanged<dynamic> onChanged;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;
  final VoidCallback onUploadTap;

  const _SurveyQuestionCard({
    required this.index,
    required this.question,
    required this.value,
    required this.isUploading,
    required this.onChanged,
    required this.onSelectDate,
    required this.onSelectTime,
    required this.onUploadTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: AppColors.mainAppColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            question.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        if (question.required)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                            child: Text(
                              'Required',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (question.description.isNotEmpty) ...<Widget>[
                      SizedBox(height: 6.h),
                      Text(
                        question.description,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.from_heading,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildInput(context),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    if (question.isShortText) {
      return TextFormField(
        initialValue: value as String? ?? '',
        onChanged: onChanged,
        decoration: _inputDecoration('Enter answer'),
      );
    }

    if (question.isLongText) {
      return TextFormField(
        initialValue: value as String? ?? '',
        onChanged: onChanged,
        minLines: 4,
        maxLines: 6,
        decoration: _inputDecoration('Write your response'),
      );
    }

    if (question.isSingleChoice) {
      return RadioGroup<String>(
        groupValue: value as String?,
        onChanged: (String? next) => onChanged(next),
        child: Column(
          children: question.options.map((String option) {
            return RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: option,
              title: Text(
                option,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    if (question.isMultiChoice) {
      final List<String> current = value is List
          ? List<String>.from(value as List)
          : <String>[];
      return Column(
        children: question.options.map((String option) {
          final bool checked = current.contains(option);
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: checked,
            title: Text(
              option,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
            onChanged: (bool? next) {
              final List<String> updated = <String>[...current];
              if (next == true && !updated.contains(option)) {
                updated.add(option);
              } else {
                updated.remove(option);
              }
              onChanged(updated);
            },
          );
        }).toList(),
      );
    }

    if (question.isDropdown) {
      return DropdownButtonFormField<String>(
        initialValue: value as String?,
        items: question.options
            .map(
              (String option) =>
                  DropdownMenuItem<String>(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: (String? next) => onChanged(next),
        decoration: _inputDecoration('Select an option'),
      );
    }

    if (question.isRating) {
      final int rating = value as int? ?? 0;
      return Row(
        children: List<Widget>.generate(5, (int index) {
          final int star = index + 1;
          return IconButton(
            onPressed: () => onChanged(star),
            icon: Icon(
              Icons.star_rounded,
              color: rating >= star
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFCBD5E1),
              size: 30.sp,
            ),
          );
        }),
      );
    }

    if (question.isDate) {
      return _PickerTile(
        label: value as String? ?? 'Select date',
        icon: Icons.calendar_today_outlined,
        onTap: onSelectDate,
      );
    }

    if (question.isTime) {
      return _PickerTile(
        label: value as String? ?? 'Select time',
        icon: Icons.access_time_outlined,
        onTap: onSelectTime,
      );
    }

    if (question.isFileUpload) {
      final Map<String, dynamic>? upload = value is Map<String, dynamic>
          ? value
          : (value is Map ? Map<String, dynamic>.from(value as Map) : null);
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Upload evidence',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              upload?['originalFileName']?.toString() ??
                  'Choose a photo from camera or gallery and upload it to the backend.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.from_heading,
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
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: isUploading ? null : onUploadTap,
                child: isUploading
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        upload == null
                            ? 'Upload Attachment'
                            : 'Replace Attachment',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    return TextFormField(
      initialValue: value as String? ?? '',
      onChanged: onChanged,
      minLines: 3,
      maxLines: 5,
      decoration: _inputDecoration('Capture your response'),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: AppColors.mainAppColor, width: 1.4),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Ink(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: AppColors.mainAppColor, size: 18.sp),
            SizedBox(width: 12.w),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
