const Map<String, double> kDefaultCabinQualityAreaWeights = {
  'lav': 25,
  'galley': 20,
  'main_cabin': 18,
  'first_class': 15,
  'comfort': 12,
  'other': 10,
};

class CabinQualityScoreAreaInput {
  const CabinQualityScoreAreaInput({
    required this.areaId,
    required this.sectionLabel,
    required this.itemStatuses,
    this.areaGroup,
  });

  final String areaId;
  final String sectionLabel;
  final String? areaGroup;
  final List<String> itemStatuses;
}

class CabinQualityAreaScore {
  const CabinQualityAreaScore({
    required this.areaId,
    required this.sectionLabel,
    required this.areaGroup,
    required this.configuredGroupWeight,
    required this.groupAreaCount,
    required this.areaWeight,
    required this.applicableItemCount,
    required this.passedItemCount,
    required this.failedItemCount,
    required this.naItemCount,
    required this.scorePercent,
    required this.earnedPoints,
    required this.possiblePoints,
    required this.status,
  });

  final String areaId;
  final String sectionLabel;
  final String areaGroup;
  final double configuredGroupWeight;
  final int groupAreaCount;
  final double areaWeight;
  final int applicableItemCount;
  final int passedItemCount;
  final int failedItemCount;
  final int naItemCount;
  final double scorePercent;
  final double earnedPoints;
  final double possiblePoints;
  final String status;
}

class CabinQualityScoreSummary {
  const CabinQualityScoreSummary({
    required this.scorePercent,
    required this.score,
    required this.status,
    required this.earnedPoints,
    required this.possiblePoints,
    required this.applicableAreaCount,
    required this.failedAreaCount,
    required this.areaWeights,
    required this.areas,
  });

  final double scorePercent;
  final int score;
  final String status;
  final double earnedPoints;
  final double possiblePoints;
  final int applicableAreaCount;
  final int failedAreaCount;
  final Map<String, double> areaWeights;
  final List<CabinQualityAreaScore> areas;
}

double _roundTo(double value, int digits) {
  final factor = digits == 0 ? 1.0 : List<double>.filled(digits, 10).fold(1.0, (acc, item) => acc * item);
  return (value * factor).round() / factor;
}

Map<String, double> normalizeCabinQualityAreaWeights(
  Map<String, dynamic>? raw,
) {
  final normalized = <String, double>{
    ...kDefaultCabinQualityAreaWeights,
  };

  raw?.forEach((key, value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed != null && parsed >= 0) {
      normalized[key] = parsed;
    }
  });

  return normalized;
}

String inferCabinQualityAreaGroup({
  required String areaId,
  required String sectionLabel,
  String? explicitGroup,
}) {
  final normalizedExplicit = explicitGroup?.trim().toLowerCase();
  if (normalizedExplicit != null &&
      kDefaultCabinQualityAreaWeights.containsKey(normalizedExplicit)) {
    return normalizedExplicit;
  }

  final normalized = '$areaId $sectionLabel'.toLowerCase();
  if (normalized.contains('lav') ||
      normalized.contains('restroom') ||
      normalized.contains('toilet')) {
    return 'lav';
  }
  if (normalized.contains('galley')) {
    return 'galley';
  }
  if (normalized.contains('first') || normalized.contains('business')) {
    return 'first_class';
  }
  if (normalized.contains('comfort')) {
    return 'comfort';
  }
  if (normalized.contains('main cabin')) {
    return 'main_cabin';
  }
  return 'other';
}

CabinQualityScoreSummary calculateCabinQualityScore(
  List<CabinQualityScoreAreaInput> inputs, {
  Map<String, dynamic>? rawAreaWeights,
}) {
  final areaWeights = normalizeCabinQualityAreaWeights(rawAreaWeights);
  final applicableAreaCounts = <String, int>{
    for (final key in kDefaultCabinQualityAreaWeights.keys) key: 0,
  };

  final normalizedInputs = inputs.map((input) {
    final areaGroup = inferCabinQualityAreaGroup(
      areaId: input.areaId,
      sectionLabel: input.sectionLabel,
      explicitGroup: input.areaGroup,
    );
    final applicableItemCount = input.itemStatuses.where((status) {
      final normalized = status.trim().toLowerCase();
      return normalized == 'pass' || normalized == 'fail';
    }).length;
    if (applicableItemCount > 0) {
      applicableAreaCounts[areaGroup] = (applicableAreaCounts[areaGroup] ?? 0) + 1;
    }
    return _NormalizedAreaInput(
      areaId: input.areaId,
      sectionLabel: input.sectionLabel,
      areaGroup: areaGroup,
      itemStatuses: input.itemStatuses,
      applicableItemCount: applicableItemCount,
    );
  }).toList();

  final areas = normalizedInputs.map((input) {
    final passedItemCount = input.itemStatuses.where(
      (status) => status.trim().toLowerCase() == 'pass',
    ).length;
    final failedItemCount = input.itemStatuses.where(
      (status) => status.trim().toLowerCase() == 'fail',
    ).length;
    final naItemCount = input.itemStatuses.length - passedItemCount - failedItemCount;
    final groupAreaCount = applicableAreaCounts[input.areaGroup] ?? 0;
    final configuredGroupWeight =
        areaWeights[input.areaGroup] ?? kDefaultCabinQualityAreaWeights[input.areaGroup]!;
    final areaWeight = input.applicableItemCount > 0 && groupAreaCount > 0
        ? configuredGroupWeight / groupAreaCount
        : 0.0;
    final scorePercent = input.applicableItemCount == 0
        ? 0.0
        : (passedItemCount / input.applicableItemCount) * 100;
    final earnedPoints =
        input.applicableItemCount == 0 ? 0.0 : areaWeight * (scorePercent / 100);
    final possiblePoints = input.applicableItemCount == 0 ? 0.0 : areaWeight;

    return CabinQualityAreaScore(
      areaId: input.areaId,
      sectionLabel: input.sectionLabel,
      areaGroup: input.areaGroup,
      configuredGroupWeight: _roundTo(configuredGroupWeight, 4),
      groupAreaCount: groupAreaCount,
      areaWeight: _roundTo(areaWeight, 4),
      applicableItemCount: input.applicableItemCount,
      passedItemCount: passedItemCount,
      failedItemCount: failedItemCount,
      naItemCount: naItemCount,
      scorePercent: _roundTo(scorePercent, 2),
      earnedPoints: _roundTo(earnedPoints, 4),
      possiblePoints: _roundTo(possiblePoints, 4),
      status: failedItemCount > 0
          ? 'fail'
          : passedItemCount > 0
              ? 'pass'
              : 'na',
    );
  }).toList();

  final earnedPoints = _roundTo(
    areas.fold<double>(0, (sum, area) => sum + area.earnedPoints),
    4,
  );
  final possiblePoints = _roundTo(
    areas.fold<double>(0, (sum, area) => sum + area.possiblePoints),
    4,
  );
  final scorePercent = possiblePoints <= 0
      ? 0.0
      : _roundTo((earnedPoints / possiblePoints) * 100, 2);
  final failedAreaCount = areas.where((area) => area.status == 'fail').length;

  return CabinQualityScoreSummary(
    scorePercent: scorePercent,
    score: scorePercent.round(),
    status: failedAreaCount > 0 ? 'FAIL' : 'PASS',
    earnedPoints: earnedPoints,
    possiblePoints: possiblePoints,
    applicableAreaCount: areas.where((area) => area.possiblePoints > 0).length,
    failedAreaCount: failedAreaCount,
    areaWeights: areaWeights,
    areas: areas,
  );
}

class _NormalizedAreaInput {
  const _NormalizedAreaInput({
    required this.areaId,
    required this.sectionLabel,
    required this.areaGroup,
    required this.itemStatuses,
    required this.applicableItemCount,
  });

  final String areaId;
  final String sectionLabel;
  final String areaGroup;
  final List<String> itemStatuses;
  final int applicableItemCount;
}
