import 'package:get_storage/get_storage.dart';

class AuditDraftType {
  static const String lavSafetyObservation = 'lav_safety_observation';
  static const String cabinQualityAudit = 'cabin_quality_audit';
  static const String cabinSecuritySearchTraining =
      'cabin_security_search_training';
  static const String hiddenObjectAudit = 'hidden_object_audit';

  static String titleFor(String type) {
    switch (type) {
      case lavSafetyObservation:
        return 'LAV Safety Observation';
      case cabinQualityAudit:
        return 'Cabin Quality Audit';
      case cabinSecuritySearchTraining:
        return 'Cabin Security Search Training';
      case hiddenObjectAudit:
        return 'Hidden Object Audit';
      default:
        return 'Audit Draft';
    }
  }
}

class AuditDraftRecord {
  AuditDraftRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.savedAt,
    required this.payload,
    this.subtitle,
    this.shipNumber,
    this.flightNumber,
    this.gate,
  });

  final String id;
  final String type;
  final String title;
  final DateTime savedAt;
  final String? subtitle;
  final String? shipNumber;
  final String? flightNumber;
  final String? gate;
  final Map<String, dynamic> payload;

  factory AuditDraftRecord.fromMap(Map<String, dynamic> map) {
    return AuditDraftRecord(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Audit Draft',
      subtitle: map['subtitle']?.toString(),
      shipNumber: map['shipNumber']?.toString(),
      flightNumber: map['flightNumber']?.toString(),
      gate: map['gate']?.toString(),
      savedAt:
          DateTime.tryParse(map['savedAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      payload: AuditDraftStore.normalizeMap(map['payload']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'shipNumber': shipNumber,
      'flightNumber': flightNumber,
      'gate': gate,
      'savedAt': savedAt.toIso8601String(),
      'payload': payload,
    };
  }
}

class AuditDraftStore {
  static const String _storageKey = 'audit_drafts_v1';
  static final GetStorage _box = GetStorage();

  static List<AuditDraftRecord> allDrafts() {
    final raw = _box.read(_storageKey);
    if (raw is! Map) {
      return const <AuditDraftRecord>[];
    }

    final drafts = <AuditDraftRecord>[];
    raw.forEach((key, value) {
      if (value is! Map) {
        return;
      }
      final normalized = normalizeMap(value);
      normalized['id'] = key.toString();
      drafts.add(AuditDraftRecord.fromMap(normalized));
    });
    drafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return drafts;
  }

  static AuditDraftRecord? getDraft(String id) {
    final raw = _box.read(_storageKey);
    if (raw is! Map) {
      return null;
    }
    final value = raw[id];
    if (value is! Map) {
      return null;
    }
    final normalized = normalizeMap(value)..['id'] = id;
    return AuditDraftRecord.fromMap(normalized);
  }

  static bool hasDraft(String id) => getDraft(id) != null;

  static Map<String, dynamic>? getPayload(String id) => getDraft(id)?.payload;

  static void saveDraft({
    required String id,
    required String type,
    required Map<String, dynamic> payload,
    String? title,
    String? subtitle,
    String? shipNumber,
    String? flightNumber,
    String? gate,
  }) {
    final raw = _box.read(_storageKey);
    final drafts = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    drafts[id] = AuditDraftRecord(
      id: id,
      type: type,
      title: title ?? AuditDraftType.titleFor(type),
      subtitle: subtitle,
      shipNumber: shipNumber,
      flightNumber: flightNumber,
      gate: gate,
      savedAt: DateTime.now(),
      payload: payload,
    ).toMap();

    _box.write(_storageKey, drafts);
  }

  static void clearDraft(String id) {
    final raw = _box.read(_storageKey);
    if (raw is! Map) {
      return;
    }
    final drafts = raw.map((key, value) => MapEntry(key.toString(), value));
    drafts.remove(id);
    if (drafts.isEmpty) {
      _box.remove(_storageKey);
      return;
    }
    _box.write(_storageKey, drafts);
  }

  static Map<String, dynamic> normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }
}
