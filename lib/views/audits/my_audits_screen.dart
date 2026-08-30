import 'package:avislap/services/api_exception.dart';
import 'package:avislap/services/app_api_service.dart';
import 'package:avislap/services/session_service.dart';
import 'package:avislap/utils/app_colors.dart';
import 'package:avislap/views/forms/Cabin%20Quality%20Audit/CabinQualityAuditScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

enum AuditCategory { all, cabinQuality, lavSafety, cabinSecurity }

class MyAuditItem {
  const MyAuditItem({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.dateTime,
    required this.status,
    required this.accentColor,
    required this.icon,
    this.gate = '',
    this.shipNumber = '',
    this.thumbnailUrl = '',
  });

  final String id;
  final AuditCategory category;
  final String title;
  final String subtitle;
  final DateTime dateTime;
  final String status;
  final Color accentColor;
  final IconData icon;
  final String gate;
  final String shipNumber;
  final String thumbnailUrl;

  String get dateLabel => DateFormat('MMM d, y').format(dateTime);
  String get timeLabel => DateFormat('h:mm a').format(dateTime);
}

class _LavDetail {
  const _LavDetail({
    required this.id,
    required this.auditorName,
    required this.dateTime,
    required this.gate,
    required this.driverName,
    required this.shipNumber,
    required this.role,
    required this.results,
    required this.photos,
    required this.signatureUrl,
    required this.otherFindings,
    required this.additionalNotes,
    required this.supervisor,
  });

  final String id;
  final String auditorName;
  final DateTime dateTime;
  final String gate;
  final String driverName;
  final String shipNumber;
  final String role;
  final List<_AuditResult> results;
  final List<String> photos;
  final String signatureUrl;
  final String otherFindings;
  final String additionalNotes;
  final String supervisor;

  int get passCount => results.where((item) => item.status == 'PASS').length;
  int get failCount => results.where((item) => item.status == 'FAIL').length;
  bool get passedOverall => failCount == 0;
  double get scorePercent =>
      results.isEmpty ? 0 : (passCount / results.length) * 100;
}

class _SecurityDetail {
  const _SecurityDetail({
    required this.id,
    required this.auditorName,
    required this.dateTime,
    required this.gate,
    required this.shipNumber,
    required this.role,
    required this.areas,
    required this.photos,
    required this.otherFindings,
    required this.additionalNotes,
    required this.aircraft,
    required this.supervisorRole,
    required this.isPassed,
  });

  final String id;
  final String auditorName;
  final DateTime dateTime;
  final String gate;
  final String shipNumber;
  final String role;
  final List<_SecurityArea> areas;
  final List<String> photos;
  final String otherFindings;
  final String additionalNotes;
  final String aircraft;
  final String supervisorRole;
  final bool isPassed;

  int get passAreaCount =>
      areas.where((area) => area.overallStatus == 'PASS').length;
  int get failAreaCount =>
      areas.where((area) => area.overallStatus == 'FAIL').length;
  bool get passedOverall => areas.isEmpty ? isPassed : failAreaCount == 0;
  double get scorePercent {
    var total = 0;
    var passed = 0;
    for (final area in areas) {
      for (final result in area.results) {
        if (result.status == 'N/A') {
          continue;
        }
        total++;
        if (result.status == 'PASS') {
          passed++;
        }
      }
    }
    if (total == 0) {
      return areas.isEmpty ? 0 : (passAreaCount / areas.length) * 100;
    }
    return (passed / total) * 100;
  }
}

class _AuditResult {
  const _AuditResult({
    required this.label,
    required this.status,
    this.photos = const <String>[],
    this.tags = const <String>[],
  });

  final String label;
  final String status;
  final List<String> photos;
  final List<String> tags;
}

class _SecurityArea {
  const _SecurityArea({
    required this.areaId,
    required this.sectionLabel,
    required this.results,
    this.photos = const <String>[],
  });

  final String areaId;
  final String sectionLabel;
  final List<_AuditResult> results;
  final List<String> photos;

  String get overallStatus {
    if (results.any((item) => item.status == 'FAIL')) {
      return 'FAIL';
    }
    if (results.any((item) => item.status == 'PASS') || photos.isNotEmpty) {
      return 'PASS';
    }
    return 'N/A';
  }

  List<String> get allPhotos {
    final seen = <String>{};
    final merged = <String>[];
    for (final photo in [...photos, ...results.expand((item) => item.photos)]) {
      final trimmed = photo.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed)) {
        merged.add(trimmed);
      }
    }
    return merged;
  }
}

class MyAuditsScreen extends StatefulWidget {
  const MyAuditsScreen({super.key});

  @override
  State<MyAuditsScreen> createState() => _MyAuditsScreenState();
}

class _MyAuditsScreenState extends State<MyAuditsScreen> {
  final AppApiService _api = Get.find<AppApiService>();
  final SessionService _session = Get.find<SessionService>();

  bool _isLoading = true;
  String? _errorMessage;
  AuditCategory _selectedCategory = AuditCategory.all;
  List<MyAuditItem> _audits = const <MyAuditItem>[];

  @override
  void initState() {
    super.initState();
    _loadAudits();
  }

  Future<void> _loadAudits() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final responses = await Future.wait([
        _api.listCabinQualityAudits(queryParameters: _baseQuery),
        _api.listLavSafetyObservations(queryParameters: _baseQuery),
        _api.listCabinSecurityTrainings(queryParameters: _baseQuery),
      ]);

      final combined = <MyAuditItem>[
        ..._mapCabinQualityItems(responses[0]),
        ..._mapLavSafetyItems(responses[1]),
        ..._mapCabinSecurityItems(responses[2]),
      ]..sort((a, b) => b.dateTime.compareTo(a.dateTime));

      if (!mounted) {
        return;
      }

      setState(() => _audits = combined);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _audits = const <MyAuditItem>[];
          _errorMessage = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _audits = const <MyAuditItem>[];
          _errorMessage = 'Unable to load your submitted audits right now.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> get _baseQuery {
    final userName = _session.fullName.trim();
    return {
      'page': 1,
      'limit': 100,
      if (userName.isNotEmpty) 'auditorName': userName,
    };
  }

  List<MyAuditItem> _mapCabinQualityItems(Map<String, dynamic> response) {
    return _itemsFrom(response).map((item) {
      final auditAt = _parseDate(item['auditAt']);
      final cleanType = item['cleanType']?.toString().trim() ?? '';
      final gate = _formatGateLabel(item['gateCode']?.toString() ?? '');
      final shipNumber = item['shipNumber']?.toString().trim() ?? '';
      final flightNumber = item['flightNumber']?.toString().trim() ?? '';

      return MyAuditItem(
        id: item['id']?.toString() ?? '',
        category: AuditCategory.cabinQuality,
        title: 'Cabin Quality Audit',
        subtitle: [
          if (cleanType.isNotEmpty) cleanType,
          if (flightNumber.isNotEmpty) 'Flight $flightNumber',
        ].join(' • '),
        dateTime: auditAt,
        status: item['status']?.toString().trim().toUpperCase() ?? 'SUBMITTED',
        accentColor: const Color(0xFF2563EB),
        icon: Icons.fact_check_outlined,
        gate: gate,
        shipNumber: shipNumber,
        thumbnailUrl: _firstThumbnail(item),
      );
    }).toList();
  }

  List<MyAuditItem> _mapLavSafetyItems(Map<String, dynamic> response) {
    return _itemsFrom(response).map((item) {
      final observedAt = _parseDate(item['observedAt']);
      final driver = item['driverName']?.toString().trim() ?? '';
      final gate = _formatGateLabel(item['gateCode']?.toString() ?? '');

      return MyAuditItem(
        id: item['id']?.toString() ?? '',
        category: AuditCategory.lavSafety,
        title: 'LAV Safety Observation',
        subtitle: driver.isEmpty ? 'Observation submitted' : 'Driver: $driver',
        dateTime: observedAt,
        status: 'SUBMITTED',
        accentColor: const Color(0xFF0EA5E9),
        icon: Icons.clean_hands_outlined,
        gate: gate,
        thumbnailUrl: _firstThumbnail(item),
      );
    }).toList();
  }

  List<MyAuditItem> _mapCabinSecurityItems(Map<String, dynamic> response) {
    return _itemsFrom(response).map((item) {
      final trainingAt = _parseDate(item['trainingAt']);
      final gate = _formatGateLabel(item['gateCode']?.toString() ?? '');
      final result = item['overallResult']?.toString().trim().toUpperCase();
      final shipNumber = item['shipNumber']?.toString().trim() ?? '';

      return MyAuditItem(
        id: item['id']?.toString() ?? '',
        category: AuditCategory.cabinSecurity,
        title: 'Cabin Security Search Training',
        subtitle: result == null || result.isEmpty
            ? 'Training submitted'
            : 'Overall result: $result',
        dateTime: trainingAt,
        status: result == null || result.isEmpty ? 'SUBMITTED' : result,
        accentColor: const Color(0xFF7C3AED),
        icon: Icons.security_outlined,
        gate: gate,
        shipNumber: shipNumber,
        thumbnailUrl: _firstThumbnail(item),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _itemsFrom(Map<String, dynamic> response) {
    return List<Map<String, dynamic>>.from(
      response['items'] as List? ?? const <dynamic>[],
    );
  }

  DateTime _parseDate(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _firstThumbnail(Map<String, dynamic> item) {
    final thumbnails = List<dynamic>.from(
      item['thumbnails'] as List? ?? const <dynamic>[],
    );
    final fileId = thumbnails
        .map((entry) => entry.toString().trim())
        .firstWhere((entry) => entry.isNotEmpty, orElse: () => '');
    return fileId.isEmpty ? '' : _api.buildFileContentUrl(fileId);
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

  List<MyAuditItem> get _visibleAudits {
    if (_selectedCategory == AuditCategory.all) {
      return _audits;
    }
    return _audits
        .where((audit) => audit.category == _selectedCategory)
        .toList();
  }

  int _countFor(AuditCategory category) {
    if (category == AuditCategory.all) {
      return _audits.length;
    }
    return _audits.where((audit) => audit.category == category).length;
  }

  void _openAudit(MyAuditItem item) {
    switch (item.category) {
      case AuditCategory.cabinQuality:
        Get.to(() => CabinQualityAuditScreen(auditId: item.id));
        break;
      case AuditCategory.lavSafety:
        _openLavDetail(item);
        break;
      case AuditCategory.cabinSecurity:
        _openSecurityDetail(item);
        break;
      case AuditCategory.all:
        break;
    }
  }

  Future<void> _openLavDetail(MyAuditItem item) async {
    try {
      _showLoadingDialog();
      final response = await _api.getLavSafetyObservation(item.id);
      final detail = _mapLavDetail(response);
      _closeLoadingDialog();
      _showLavDetailSheet(detail, item.accentColor);
    } on ApiException catch (error) {
      _closeLoadingDialog();
      _showLoadError('Observation Unavailable', error.message);
    } catch (_) {
      _closeLoadingDialog();
      _showLoadError(
        'Observation Unavailable',
        'Unable to load this LAV safety observation right now.',
      );
    }
  }

  Future<void> _openSecurityDetail(MyAuditItem item) async {
    try {
      _showLoadingDialog();
      final response = await _api.getCabinSecurityTraining(item.id);
      final detail = _mapSecurityDetail(response);
      _closeLoadingDialog();
      _showSecurityDetailSheet(detail, item.accentColor);
    } on ApiException catch (error) {
      _closeLoadingDialog();
      _showLoadError('Training Unavailable', error.message);
    } catch (_) {
      _closeLoadingDialog();
      _showLoadError(
        'Training Unavailable',
        'Unable to load this cabin security search training right now.',
      );
    }
  }

  void _showLoadingDialog() {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
  }

  void _closeLoadingDialog() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  void _showLoadError(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  _LavDetail _mapLavDetail(Map<String, dynamic> item) {
    final observedAt = _parseDate(item['observedAt']);
    final files = _listOfMaps(item['files']);
    final responses = _listOfMaps(item['responses']);
    final parsedNotes = _parseLavNotes(item['additionalNotes']?.toString());
    final signatureFileId = item['signatureFileId']?.toString().trim() ?? '';

    return _LavDetail(
      id: item['id']?.toString() ?? '',
      auditorName:
          item['auditorNameSnapshot']?.toString().trim() ?? 'Unknown Auditor',
      dateTime: observedAt,
      gate: _formatGateLabel(item['gateCodeSnapshot']?.toString() ?? ''),
      driverName: item['driverName']?.toString().trim() ?? 'Unknown Driver',
      shipNumber: item['shipNumber']?.toString().trim() ?? '',
      role: item['auditorRoleSnapshot']?.toString().trim() ?? '',
      results: responses.map(_mapLavResult).toList(),
      photos: _fileUrls(files),
      signatureUrl: signatureFileId.isEmpty
          ? ''
          : _api.buildFileContentUrl(signatureFileId),
      otherFindings: item['otherFindings']?.toString().trim() ?? '',
      additionalNotes: parsedNotes.$2,
      supervisor: parsedNotes.$1,
    );
  }

  _AuditResult _mapLavResult(Map<String, dynamic> item) {
    final checklistItem = item['checklistItem'] is Map
        ? _asMap(item['checklistItem'])
        : <String, dynamic>{};
    return _AuditResult(
      label: checklistItem['label']?.toString().trim() ?? 'Checklist Item',
      status: _normalizeStatus(item['response']?.toString() ?? ''),
      photos: _fileUrls(_listOfMaps(item['files'])),
    );
  }

  _SecurityDetail _mapSecurityDetail(Map<String, dynamic> item) {
    final trainingAt = _parseDate(item['trainingAt']);
    final parsedNotes = _parseSecurityNotes(
      item['additionalNotes']?.toString(),
    );
    final detailAreas = _parseSecurityAreas(item['detailedResultsJson']);
    final fallbackAreas = _listOfMaps(
      item['results'],
    ).map(_mapFallbackSecurityArea).toList();

    return _SecurityDetail(
      id: item['id']?.toString() ?? '',
      auditorName:
          item['auditorNameSnapshot']?.toString().trim() ?? 'Unknown Auditor',
      dateTime: trainingAt,
      gate: _formatGateLabel(item['gateCodeSnapshot']?.toString() ?? ''),
      shipNumber: item['shipNumber']?.toString().trim() ?? '',
      role: item['auditorRoleSnapshot']?.toString().trim() ?? '',
      areas: detailAreas.isNotEmpty ? detailAreas : fallbackAreas,
      photos: _fileUrls(_listOfMaps(item['files'])),
      otherFindings: item['otherFindings']?.toString().trim() ?? '',
      additionalNotes: parsedNotes.$3,
      aircraft: parsedNotes.$1,
      supervisorRole: parsedNotes.$2,
      isPassed: item['overallResult'] == 'PASS',
    );
  }

  List<_SecurityArea> _parseSecurityAreas(dynamic raw) {
    if (raw is! List) {
      return const <_SecurityArea>[];
    }

    return raw
        .map(_asMap)
        .where((entry) => entry.isNotEmpty)
        .map((entry) {
          final areaId = entry['areaId']?.toString().trim() ?? '';
          final sectionLabel = entry['sectionLabel']?.toString().trim() ?? '';
          final results =
              List<dynamic>.from(
                    entry['checkItems'] as List? ?? const <dynamic>[],
                  )
                  .map(_asMap)
                  .where((check) => check.isNotEmpty)
                  .map(
                    (check) => _AuditResult(
                      label: check['itemName']?.toString().trim() ?? 'Item',
                      status: _normalizeStatus(
                        check['status']?.toString() ?? '',
                      ),
                      photos: _fileIdsToUrls(check['imageFileIds']),
                      tags:
                          List<dynamic>.from(
                                check['hashtags'] as List? ?? const <dynamic>[],
                              )
                              .map((tag) => tag.toString().trim())
                              .where((tag) => tag.isNotEmpty)
                              .toList(),
                    ),
                  )
                  .toList();

          return _SecurityArea(
            areaId: areaId.isEmpty ? _deriveAreaId(sectionLabel) : areaId,
            sectionLabel: sectionLabel.isEmpty
                ? _deriveSectionLabel(areaId)
                : sectionLabel,
            results: results,
            photos: _fileIdsToUrls(entry['imageFileIds']),
          );
        })
        .where((area) => area.results.isNotEmpty || area.photos.isNotEmpty)
        .toList();
  }

  _SecurityArea _mapFallbackSecurityArea(Map<String, dynamic> item) {
    final label = item['areaLabelSnapshot']?.toString().trim() ?? 'Area';
    return _SecurityArea(
      areaId: _deriveAreaId(label),
      sectionLabel: _deriveSectionLabel(label),
      photos: _fileUrls(_listOfMaps(item['files'])),
      results: [
        _AuditResult(
          label: 'Search Result',
          status: _normalizeStatus(item['result']?.toString() ?? ''),
        ),
      ],
    );
  }

  (String, String) _parseLavNotes(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return ('', '');
    }
    var supervisor = '';
    final lines = <String>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Supervisor/Lead:')) {
        supervisor = trimmed.substring('Supervisor/Lead:'.length).trim();
      } else if (trimmed.isNotEmpty) {
        lines.add(trimmed);
      }
    }
    return (supervisor, lines.join('\n'));
  }

  (String, String, String) _parseSecurityNotes(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return ('', '', '');
    }
    var aircraft = '';
    var supervisorRole = '';
    final lines = <String>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Aircraft:')) {
        aircraft = trimmed.substring('Aircraft:'.length).trim();
      } else if (trimmed.startsWith('Supervisor Role:')) {
        supervisorRole = trimmed.substring('Supervisor Role:'.length).trim();
      } else if (!trimmed.startsWith('Area Summary:') && trimmed.isNotEmpty) {
        lines.add(trimmed);
      }
    }
    return (aircraft, supervisorRole, lines.join('\n'));
  }

  List<Map<String, dynamic>> _listOfMaps(dynamic raw) {
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }
    return raw.map(_asMap).where((entry) => entry.isNotEmpty).toList();
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

  List<String> _fileUrls(List<Map<String, dynamic>> files) {
    return files
        .map((entry) => entry['fileId']?.toString().trim() ?? '')
        .where((fileId) => fileId.isNotEmpty)
        .map(_api.buildFileContentUrl)
        .toList();
  }

  List<String> _fileIdsToUrls(dynamic raw) {
    return List<dynamic>.from(raw as List? ?? const <dynamic>[])
        .map((fileId) => fileId.toString().trim())
        .where((fileId) => fileId.isNotEmpty)
        .map(_api.buildFileContentUrl)
        .toList();
  }

  String _normalizeStatus(String value) {
    switch (value.trim().toUpperCase()) {
      case 'PASS':
      case 'YES':
        return 'PASS';
      case 'FAIL':
      case 'NO':
        return 'FAIL';
      default:
        return 'N/A';
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
        if (row <= 6) return 'First Class';
        if (row <= 15) return 'Delta Comfort';
        return 'Main Cabin';
      }
      return 'Cabin Seat';
    }
    if (normalized.contains('first class') || normalized.contains('business')) {
      return 'First Class';
    }
    if (normalized.contains('comfort')) return 'Delta Comfort';
    if (normalized.contains('main cabin') || normalized.contains('economy')) {
      return 'Main Cabin';
    }
    if (normalized.contains('galley')) return 'Galley';
    if (normalized.contains('lav')) return 'Lav';
    if (normalized.contains('overhead')) return 'Overhead Bins';
    if (normalized.contains('pocket')) return 'Seat Pockets';
    if (normalized.contains('crew')) return 'Crew Rest Area';
    if (normalized.contains('emergency')) return 'Emergency Equipment';
    return label.trim().isEmpty ? 'Area' : label.trim();
  }

  void _showLavDetailSheet(_LavDetail detail, Color accentColor) {
    Get.bottomSheet(
      _AuditDetailSheet(
        title: 'LAV Safety Observation',
        accentColor: accentColor,
        child: Column(
          children: [
            _DetailScoreCard(
              title: detail.passedOverall
                  ? 'Observation Passed'
                  : 'Observation Failed',
              subtitle:
                  '${detail.results.length} checklist items - ${detail.failCount} failed',
              score: detail.scorePercent,
              isPassed: detail.passedOverall,
            ),
            _DetailInfoCard(
              rows: [
                _DetailRow('Auditor', detail.auditorName),
                _DetailRow(
                  'Date',
                  DateFormat('MMM d, y').format(detail.dateTime),
                ),
                _DetailRow(
                  'Time',
                  DateFormat('h:mm a').format(detail.dateTime),
                ),
                _DetailRow('Gate', detail.gate),
                _DetailRow('Driver', detail.driverName),
                if (detail.shipNumber.isNotEmpty)
                  _DetailRow('Ship Number', detail.shipNumber),
                if (detail.role.isNotEmpty) _DetailRow('Role', detail.role),
                if (detail.supervisor.isNotEmpty)
                  _DetailRow('Supervisor/Lead', detail.supervisor),
              ],
            ),
            _ResultsCard(
              title: 'Checklist Results',
              results: detail.results,
              emptyText:
                  'No checklist results were found for this observation.',
            ),
            if (detail.photos.isNotEmpty)
              _PhotoCard(title: 'Observation Photos', photos: detail.photos),
            if (detail.signatureUrl.isNotEmpty)
              _PhotoCard(title: 'Signature', photos: [detail.signatureUrl]),
            if (detail.otherFindings.isNotEmpty)
              _NotesCard(title: 'Other Findings', text: detail.otherFindings),
            if (detail.additionalNotes.isNotEmpty)
              _NotesCard(
                title: 'Additional Notes',
                text: detail.additionalNotes,
              ),
            _ReadOnlyNotice(accentColor: accentColor),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showSecurityDetailSheet(_SecurityDetail detail, Color accentColor) {
    Get.bottomSheet(
      _AuditDetailSheet(
        title: 'Cabin Security Search Training',
        accentColor: accentColor,
        child: Column(
          children: [
            _DetailScoreCard(
              title: detail.passedOverall ? 'Search Passed' : 'Search Failed',
              subtitle:
                  '${detail.areas.length} areas inspected - ${detail.failAreaCount} failed',
              score: detail.scorePercent,
              isPassed: detail.passedOverall,
            ),
            _DetailInfoCard(
              rows: [
                _DetailRow('Auditor', detail.auditorName),
                _DetailRow(
                  'Date',
                  DateFormat('MMM d, y').format(detail.dateTime),
                ),
                _DetailRow(
                  'Time',
                  DateFormat('h:mm a').format(detail.dateTime),
                ),
                _DetailRow('Gate', detail.gate),
                if (detail.shipNumber.isNotEmpty)
                  _DetailRow('Ship Number', detail.shipNumber),
                if (detail.aircraft.isNotEmpty)
                  _DetailRow('Aircraft', detail.aircraft),
                if (detail.role.isNotEmpty) _DetailRow('Role', detail.role),
                if (detail.supervisorRole.isNotEmpty)
                  _DetailRow('Supervisor Role', detail.supervisorRole),
              ],
            ),
            _SecurityAreasCard(areas: detail.areas),
            if (detail.photos.isNotEmpty)
              _PhotoCard(title: 'Training Photos', photos: detail.photos),
            if (detail.otherFindings.isNotEmpty)
              _NotesCard(title: 'Other Findings', text: detail.otherFindings),
            if (detail.additionalNotes.isNotEmpty)
              _NotesCard(
                title: 'Additional Notes',
                text: detail.additionalNotes,
              ),
            _ReadOnlyNotice(accentColor: accentColor),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.mainAppColor,
          onRefresh: _loadAudits,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildSummary()),
              SliverToBoxAdapter(child: _buildFilters()),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildMessageState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Audits unavailable',
                    message: _errorMessage!,
                    actionLabel: 'Try Again',
                    onAction: _loadAudits,
                  ),
                )
              else if (_visibleAudits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildMessageState(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'No audits found',
                    message:
                        'Your submitted audits will appear here after they are saved.',
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 28.h),
                  sliver: SliverList.separated(
                    itemCount: _visibleAudits.length,
                    separatorBuilder: (_, _) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) =>
                        _buildAuditCard(_visibleAudits[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 18.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EDF5))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.mainAppColor,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Audits',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  _session.fullName.isEmpty
                      ? 'Submitted audit history'
                      : 'Submitted by ${_session.fullName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.from_heading,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadAudits,
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

  Widget _buildSummary() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 12.h),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Total',
              value: _countFor(AuditCategory.all).toString(),
              color: AppColors.mainAppColor,
              icon: Icons.insights_rounded,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _SummaryTile(
              label: 'Quality',
              value: _countFor(AuditCategory.cabinQuality).toString(),
              color: const Color(0xFF2563EB),
              icon: Icons.fact_check_outlined,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _SummaryTile(
              label: 'Safety',
              value: _countFor(AuditCategory.lavSafety).toString(),
              color: const Color(0xFF0EA5E9),
              icon: Icons.clean_hands_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      _FilterData(AuditCategory.all, 'All'),
      _FilterData(AuditCategory.cabinQuality, 'Cabin Quality'),
      _FilterData(AuditCategory.lavSafety, 'LAV Safety'),
      _FilterData(AuditCategory.cabinSecurity, 'Security'),
    ];

    return SizedBox(
      height: 48.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = filter.category == _selectedCategory;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text('${filter.label} (${_countFor(filter.category)})'),
            labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.dark,
            ),
            selectedColor: AppColors.mainAppColor,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? AppColors.mainAppColor
                  : const Color(0xFFE1E8F2),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999.r),
            ),
            onSelected: (_) {
              setState(() => _selectedCategory = filter.category);
            },
          );
        },
      ),
    );
  }

  Widget _buildAuditCard(MyAuditItem item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: () => _openAudit(item),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeadingVisual(item),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        _StatusBadge(
                          label: item.status,
                          color: item.accentColor,
                        ),
                      ],
                    ),
                    SizedBox(height: 7.h),
                    Text(
                      item.subtitle.isEmpty ? 'Audit submitted' : item.subtitle,
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
                          icon: Icons.calendar_today_outlined,
                          label: item.dateLabel,
                        ),
                        _MetaPill(
                          icon: Icons.schedule_outlined,
                          label: item.timeLabel,
                        ),
                        if (item.gate.isNotEmpty)
                          _MetaPill(
                            icon: Icons.location_on_outlined,
                            label: item.gate,
                          ),
                        if (item.shipNumber.isNotEmpty)
                          _MetaPill(
                            icon: Icons.flight_outlined,
                            label: 'Ship ${item.shipNumber}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
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

  Widget _buildLeadingVisual(MyAuditItem item) {
    final imageHeaders = _api.buildImageHeaders();
    return Container(
      width: 58.w,
      height: 58.w,
      decoration: BoxDecoration(
        color: item.accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: item.thumbnailUrl.isEmpty
          ? Icon(item.icon, color: item.accentColor, size: 26.sp)
          : Image.network(
              item.thumbnailUrl,
              fit: BoxFit.cover,
              headers: imageHeaders,
              errorBuilder: (_, _, _) =>
                  Icon(item.icon, color: item.accentColor, size: 26.sp),
            ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: EdgeInsets.all(28.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              color: AppColors.mainAppColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.mainAppColor, size: 32.sp),
          ),
          SizedBox(height: 18.h),
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
              fontWeight: FontWeight.w500,
              color: AppColors.from_heading,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 18.h),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.mainAppColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterData {
  const _FilterData(this.category, this.label);

  final AuditCategory category;
  final String label;
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}

class _AuditDetailSheet extends StatelessWidget {
  const _AuditDetailSheet({
    required this.title,
    required this.accentColor,
    required this.child,
  });

  final String title;
  final Color accentColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE8EDF5))),
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
                        Container(
                          width: 38.w,
                          height: 38.w,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.assignment_turned_in_outlined,
                            color: accentColor,
                            size: 20.sp,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            title,
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
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailScoreCard extends StatelessWidget {
  const _DetailScoreCard({
    required this.title,
    required this.subtitle,
    required this.score,
    required this.isPassed,
  });

  final String title;
  final String subtitle;
  final double score;
  final bool isPassed;

  @override
  Widget build(BuildContext context) {
    final color = isPassed ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
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
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '${score.toStringAsFixed(0)}%',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
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
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
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

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({required this.rows});

  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.where((row) => row.value.trim().isNotEmpty);
    return _DetailCard(
      title: 'Audit Information',
      child: Column(
        children: visibleRows
            .map(
              (row) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104.w,
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
  const _ResultsCard({
    required this.title,
    required this.results,
    required this.emptyText,
  });

  final String title;
  final List<_AuditResult> results;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: title,
      child: results.isEmpty
          ? Text(
              emptyText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.from_heading,
              ),
            )
          : Column(
              children: results.map((result) => _ResultTile(result)).toList(),
            ),
    );
  }
}

class _SecurityAreasCard extends StatelessWidget {
  const _SecurityAreasCard({required this.areas});

  final List<_SecurityArea> areas;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'Inspected Areas',
      child: areas.isEmpty
          ? Text(
              'No inspected areas were found for this training.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.from_heading,
              ),
            )
          : Column(
              children: areas.map((area) => _SecurityAreaTile(area)).toList(),
            ),
    );
  }
}

class _SecurityAreaTile extends StatelessWidget {
  const _SecurityAreaTile(this.area);

  final _SecurityArea area;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(area.overallStatus);
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 12.w),
        childrenPadding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        leading: Icon(Icons.event_seat_outlined, color: color, size: 20.sp),
        title: Text(
          area.sectionLabel,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        subtitle: Text(
          [
            if (area.areaId.isNotEmpty) 'Area ${area.areaId}',
            '${area.allPhotos.length} photos',
          ].join(' - '),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.from_heading,
          ),
        ),
        trailing: _StatusBadge(label: area.overallStatus, color: color),
        children: [
          ...area.results.map((result) => _ResultTile(result)),
          if (area.allPhotos.isNotEmpty)
            _InlinePhotoStrip(photos: area.allPhotos),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile(this.result);

  final _AuditResult result;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(result.status);
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
              _StatusBadge(label: result.status, color: color),
            ],
          ),
          if (result.tags.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: result.tags
                  .map(
                    (tag) =>
                        _TinyChip(label: tag.startsWith('#') ? tag : '#$tag'),
                  )
                  .toList(),
            ),
          ],
          if (result.photos.isNotEmpty) ...[
            SizedBox(height: 10.h),
            _InlinePhotoStrip(photos: result.photos),
          ],
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.title, required this.photos});

  final String title;
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: title,
      child: _InlinePhotoStrip(photos: photos, large: true),
    );
  }
}

class _InlinePhotoStrip extends StatelessWidget {
  const _InlinePhotoStrip({required this.photos, this.large = false});

  final List<String> photos;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final imageHeaders = Get.find<AppApiService>().buildImageHeaders();
    final size = large ? 112.w : 76.w;
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Image.network(
              photos[index],
              width: size,
              height: size,
              fit: BoxFit.cover,
              headers: imageHeaders,
              errorBuilder: (_, _, _) => Container(
                width: size,
                height: size,
                color: const Color(0xFFE8EDF5),
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.from_heading,
                  size: 24.sp,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: title,
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.dark,
          height: 1.5,
        ),
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, color: accentColor, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'This is a view-only copy of the submitted audit.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: accentColor,
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

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.mainAppColor,
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status.trim().toUpperCase()) {
    case 'PASS':
      return const Color(0xFF16A34A);
    case 'FAIL':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF64748B);
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18.sp),
          SizedBox(height: 10.h),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

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
        label,
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
