const String kSeatMapToiletAsset = 'assets/icons/toilet.svg';
const String kSeatMapGalleyAsset = 'assets/icons/chiken.svg';
const String kSeatMapJumpSeatAsset = 'assets/icons/jump-seat.svg';
const Map<String, double> kDefaultCabinQualityAreaWeights = {
  'lav': 25,
  'galley': 20,
  'main_cabin': 18,
  'first_class': 15,
  'comfort': 12,
  'other': 10,
};

class AircraftSeatMap {
  const AircraftSeatMap({
    required this.name,
    required this.sections,
    this.hasFirstClassArc = false,
    this.areaWeights = kDefaultCabinQualityAreaWeights,
  });

  final String name;
  final List<SeatSection> sections;
  final bool hasFirstClassArc;
  final Map<String, double> areaWeights;

  factory AircraftSeatMap.fromJson(
    Map<String, dynamic> json, {
    required String fallbackName,
  }) {
    final sections = _asListOfMaps(
      json['sections'],
    ).map(SeatSection.fromJson).toList();
    if (sections.isEmpty) {
      throw const FormatException('Aircraft seat map requires sections');
    }

    return AircraftSeatMap(
      name: _asString(json['name']) ?? fallbackName,
      hasFirstClassArc: _asBool(json['hasFirstClassArc']) ?? false,
      areaWeights: {
        ...kDefaultCabinQualityAreaWeights,
        ..._asDoubleMap(json['areaWeights']),
      },
      sections: sections,
    );
  }
}

class SeatSection {
  const SeatSection({
    required this.name,
    required this.startRow,
    required this.endRow,
    required this.leftCols,
    required this.rightCols,
    this.areaType,
    this.hasExitBefore = false,
    this.hasExitAfter = false,
    this.amenitiesBefore,
    this.amenitiesAfter,
    this.skipRows,
  });

  final String name;
  final int startRow;
  final int endRow;
  final List<String> leftCols;
  final List<String> rightCols;
  final String? areaType;
  final bool hasExitBefore;
  final bool hasExitAfter;
  final List<AmenityRow>? amenitiesBefore;
  final List<AmenityRow>? amenitiesAfter;
  final List<int>? skipRows;

  factory SeatSection.fromJson(Map<String, dynamic> json) {
    final leftCols = _asStringList(json['leftCols']);
    final rightCols = _asStringList(json['rightCols']);
    if (leftCols.isEmpty || rightCols.isEmpty) {
      throw const FormatException(
        'Seat section requires left and right columns',
      );
    }

    final startRow = _asInt(json['startRow']);
    final endRow = _asInt(json['endRow']);
    if (startRow == null ||
        endRow == null ||
        startRow <= 0 ||
        endRow < startRow) {
      throw const FormatException('Seat section has invalid row range');
    }

    return SeatSection(
      name: _asString(json['name']) ?? '',
      startRow: startRow,
      endRow: endRow,
      leftCols: leftCols,
      rightCols: rightCols,
      areaType: _asString(json['areaType']),
      hasExitBefore: _asBool(json['hasExitBefore']) ?? false,
      hasExitAfter: _asBool(json['hasExitAfter']) ?? false,
      amenitiesBefore: _asListOfMaps(
        json['amenitiesBefore'],
      ).map(AmenityRow.fromJson).toList(),
      amenitiesAfter: _asListOfMaps(
        json['amenitiesAfter'],
      ).map(AmenityRow.fromJson).toList(),
      skipRows: _asIntList(json['skipRows']),
    );
  }
}

class AmenityRow {
  const AmenityRow({
    this.leftSvg,
    this.leftId,
    this.rightSvg,
    this.rightId,
    this.centerOnly = false,
    this.customLabel,
  });

  final String? leftSvg;
  final String? leftId;
  final String? rightSvg;
  final String? rightId;
  final bool centerOnly;
  final String? customLabel;

  String get effectiveAmenityId =>
      rightId ?? leftId ?? customLabel ?? 'Amenity';

  String get effectiveSvgAsset => rightSvg ?? leftSvg ?? kSeatMapToiletAsset;

  factory AmenityRow.fromJson(Map<String, dynamic> json) {
    return AmenityRow(
      leftSvg: _asString(json['leftSvg']),
      leftId: _asString(json['leftId']),
      rightSvg: _asString(json['rightSvg']),
      rightId: _asString(json['rightId']),
      centerOnly: _asBool(json['centerOnly']) ?? false,
      customLabel: _asString(json['customLabel']),
    );
  }
}

final Map<String, AircraftSeatMap> defaultAircraftSeatMaps = {
  'Boeing 757-300 (75Y)': const AircraftSeatMap(
    name: 'Boeing 757-300 (75Y)',
    hasFirstClassArc: true,
    sections: [
      SeatSection(
        name: 'First Class',
        startRow: 1,
        endRow: 6,
        leftCols: ['A', 'B'],
        rightCols: ['C', 'D'],
        areaType: 'first_class',
        amenitiesBefore: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV FWD',
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley FWD',
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat FWD L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat FWD R',
          ),
        ],
        hasExitBefore: true,
        amenitiesAfter: [
          AmenityRow(customLabel: 'Closet'),
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV MID L',
            rightSvg: kSeatMapToiletAsset,
            rightId: 'LAV MID R',
          ),
        ],
      ),
      SeatSection(
        name: 'Delta Comfort',
        startRow: 14,
        endRow: 21,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'comfort',
        hasExitBefore: true,
        skipRows: [14],
      ),
      SeatSection(
        name: 'Delta Main',
        startRow: 22,
        endRow: 40,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'main_cabin',
        amenitiesAfter: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV AFT L',
            rightSvg: kSeatMapToiletAsset,
            rightId: 'LAV AFT R',
          ),
        ],
        hasExitAfter: true,
      ),
      SeatSection(
        name: '',
        startRow: 41,
        endRow: 49,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'main_cabin',
        amenitiesAfter: [
          AmenityRow(
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley AFT',
            centerOnly: true,
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat AFT L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat AFT R',
          ),
        ],
        hasExitAfter: true,
      ),
    ],
  ),
  'Boeing 737-800': const AircraftSeatMap(
    name: 'Boeing 737-800',
    sections: [
      SeatSection(
        name: 'First Class',
        startRow: 1,
        endRow: 4,
        leftCols: ['A', 'B'],
        rightCols: ['C', 'D'],
        areaType: 'first_class',
        amenitiesBefore: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV FWD',
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley FWD',
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat FWD L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat FWD R',
          ),
        ],
        hasExitBefore: true,
      ),
      SeatSection(
        name: 'Main Cabin',
        startRow: 7,
        endRow: 20,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'main_cabin',
        hasExitBefore: true,
      ),
      SeatSection(
        name: '',
        startRow: 21,
        endRow: 33,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'main_cabin',
        hasExitAfter: true,
        amenitiesAfter: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV AFT L',
            rightSvg: kSeatMapToiletAsset,
            rightId: 'LAV AFT R',
          ),
          AmenityRow(
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley AFT',
            centerOnly: true,
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat AFT L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat AFT R',
          ),
        ],
      ),
    ],
  ),
  'Airbus A320': const AircraftSeatMap(
    name: 'Airbus A320',
    sections: [
      SeatSection(
        name: 'Business Class',
        startRow: 1,
        endRow: 3,
        leftCols: ['A', 'B'],
        rightCols: ['C', 'D'],
        areaType: 'first_class',
        amenitiesBefore: [
          AmenityRow(
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley FWD',
            centerOnly: true,
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat FWD L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat FWD R',
          ),
        ],
      ),
      SeatSection(
        name: 'Economy',
        startRow: 8,
        endRow: 18,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'main_cabin',
        hasExitBefore: true,
      ),
      SeatSection(
        name: '',
        startRow: 19,
        endRow: 30,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'main_cabin',
        hasExitAfter: true,
        amenitiesAfter: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV L',
            rightSvg: kSeatMapToiletAsset,
            rightId: 'LAV R',
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat AFT L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat AFT R',
          ),
        ],
      ),
    ],
  ),
  'Airbus A321-200': const AircraftSeatMap(
    name: 'Airbus A321-200',
    sections: [
      SeatSection(
        name: 'First Class',
        startRow: 1,
        endRow: 5,
        leftCols: ['A', 'B'],
        rightCols: ['C', 'D'],
        areaType: 'first_class',
        amenitiesBefore: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV FWD',
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley FWD',
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat FWD L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat FWD R',
          ),
        ],
      ),
      SeatSection(
        name: 'Comfort+',
        startRow: 10,
        endRow: 16,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'comfort',
        hasExitBefore: true,
      ),
      SeatSection(
        name: 'Main Cabin',
        startRow: 17,
        endRow: 37,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'main_cabin',
        hasExitAfter: true,
        amenitiesAfter: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV AFT L',
            rightSvg: kSeatMapToiletAsset,
            rightId: 'LAV AFT R',
          ),
          AmenityRow(
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley AFT',
            centerOnly: true,
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat AFT L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat AFT R',
          ),
        ],
      ),
    ],
  ),
  'Airbus A319': const AircraftSeatMap(
    name: 'Airbus A319',
    sections: [
      SeatSection(
        name: 'First Class',
        startRow: 1,
        endRow: 3,
        leftCols: ['A', 'B'],
        rightCols: ['C', 'D'],
        areaType: 'first_class',
        amenitiesBefore: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV FWD',
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley FWD',
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat FWD L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat FWD R',
          ),
        ],
      ),
      SeatSection(
        name: 'Main Cabin',
        startRow: 8,
        endRow: 20,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'main_cabin',
        hasExitBefore: true,
      ),
      SeatSection(
        name: '',
        startRow: 21,
        endRow: 26,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'main_cabin',
        hasExitAfter: true,
        amenitiesAfter: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV AFT L',
            rightSvg: kSeatMapToiletAsset,
            rightId: 'LAV AFT R',
          ),
          AmenityRow(
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley AFT',
            centerOnly: true,
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat AFT L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat AFT R',
          ),
        ],
      ),
    ],
  ),
  'Airbus A220-300': const AircraftSeatMap(
    name: 'Airbus A220-300',
    sections: [
      SeatSection(
        name: 'First Class',
        startRow: 1,
        endRow: 4,
        leftCols: ['A', 'B'],
        rightCols: ['C', 'D'],
        areaType: 'first_class',
        amenitiesBefore: [
          AmenityRow(
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley FWD',
            centerOnly: true,
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat FWD L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat FWD R',
          ),
        ],
      ),
      SeatSection(
        name: 'Comfort+',
        startRow: 8,
        endRow: 12,
        leftCols: ['A', 'B'],
        rightCols: ['C', 'D', 'E'],
        areaType: 'comfort',
        hasExitBefore: true,
      ),
      SeatSection(
        name: 'Main Cabin',
        startRow: 13,
        endRow: 28,
        leftCols: ['A', 'B'],
        rightCols: ['C', 'D', 'E'],
        areaType: 'main_cabin',
        hasExitAfter: true,
        amenitiesAfter: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV AFT',
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley AFT',
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat AFT L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat AFT R',
          ),
        ],
      ),
    ],
  ),
  'Boeing 737-900ER': const AircraftSeatMap(
    name: 'Boeing 737-900ER',
    sections: [
      SeatSection(
        name: 'First Class',
        startRow: 1,
        endRow: 4,
        leftCols: ['A', 'B'],
        rightCols: ['C', 'D'],
        areaType: 'first_class',
        amenitiesBefore: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV FWD',
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley FWD',
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat FWD L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat FWD R',
          ),
        ],
        hasExitBefore: true,
      ),
      SeatSection(
        name: 'Comfort+',
        startRow: 7,
        endRow: 15,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'comfort',
        hasExitBefore: true,
      ),
      SeatSection(
        name: 'Main Cabin',
        startRow: 16,
        endRow: 39,
        leftCols: ['A', 'B', 'C'],
        rightCols: ['D', 'E', 'F'],
        areaType: 'main_cabin',
        hasExitAfter: true,
        amenitiesAfter: [
          AmenityRow(
            leftSvg: kSeatMapToiletAsset,
            leftId: 'LAV AFT L',
            rightSvg: kSeatMapToiletAsset,
            rightId: 'LAV AFT R',
          ),
          AmenityRow(
            rightSvg: kSeatMapGalleyAsset,
            rightId: 'Galley AFT',
            centerOnly: true,
          ),
          AmenityRow(
            leftSvg: kSeatMapJumpSeatAsset,
            leftId: 'Jump Seat AFT L',
            rightSvg: kSeatMapJumpSeatAsset,
            rightId: 'Jump Seat AFT R',
          ),
        ],
      ),
    ],
  ),
};

Map<String, AircraftSeatMap> buildAircraftSeatMapsFromApi(
  List<Map<String, dynamic>> aircraftTypes, {
  Map<String, AircraftSeatMap>? fallbackMaps,
}) {
  final fallback = fallbackMaps ?? defaultAircraftSeatMaps;
  final resolved = <String, AircraftSeatMap>{};

  for (final aircraft in aircraftTypes) {
    final name = _asString(aircraft['name']) ?? '';
    if (name.isEmpty) {
      continue;
    }

    final rawSeatMap = aircraft['seatMap'];
    if (rawSeatMap is Map) {
      try {
        resolved[name] = AircraftSeatMap.fromJson(
          Map<String, dynamic>.from(rawSeatMap),
          fallbackName: name,
        );
        continue;
      } catch (_) {
        // Fall back to the bundled map when the API payload is malformed.
      }
    }

    final fallbackMap = fallback[name];
    if (fallbackMap != null) {
      resolved[name] = fallbackMap;
      continue;
    }

    resolved[name] = AircraftSeatMap(
      name: name,
      areaWeights: kDefaultCabinQualityAreaWeights,
      sections: const [
        SeatSection(
          name: 'Cabin Layout Pending',
          startRow: 1,
          endRow: 1,
          leftCols: ['A'],
          rightCols: ['B'],
          areaType: 'main_cabin',
        ),
      ],
    );
  }

  if (resolved.isEmpty) {
    return Map<String, AircraftSeatMap>.from(fallback);
  }

  return resolved;
}

List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map((entry) => entry.map((key, item) => MapEntry(key.toString(), item)))
      .toList();
}

List<String> _asStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }

  return value
      .map((entry) => entry.toString().trim().toUpperCase())
      .where((entry) => entry.isNotEmpty)
      .toList();
}

List<int> _asIntList(dynamic value) {
  if (value is! List) {
    return const <int>[];
  }

  return value
      .map(_asInt)
      .whereType<int>()
      .where((entry) => entry > 0)
      .toSet()
      .toList()
    ..sort();
}

Map<String, double> _asDoubleMap(dynamic value) {
  if (value is! Map) {
    return const <String, double>{};
  }

  final normalized = <String, double>{};
  value.forEach((key, item) {
    final parsed = _asDouble(item);
    if (parsed != null && parsed >= 0) {
      normalized[key.toString().trim()] = parsed;
    }
  });
  return normalized;
}

double? _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '');
}

String? _asString(dynamic value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

bool? _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    if (value.trim().toLowerCase() == 'true') {
      return true;
    }
    if (value.trim().toLowerCase() == 'false') {
      return false;
    }
  }
  return null;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}
