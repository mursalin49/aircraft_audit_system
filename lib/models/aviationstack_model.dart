import 'package:intl/intl.dart';

class AviationFlight {
  final String id;
  final String direction;
  final String airlineName;
  final String flightNumber;
  final String departureAirport;
  final String departureIata;
  final DateTime? departureTime;
  final String departureTerminal;
  final String departureGate;

  final String arrivalAirport;
  final String arrivalIata;
  final DateTime? arrivalTime;
  final String arrivalTerminal;
  final String arrivalGate;

  final String status;
  final String shipNumber;

  AviationFlight({
    required this.id,
    required this.direction,
    required this.airlineName,
    required this.flightNumber,
    required this.departureAirport,
    required this.departureIata,
    this.departureTime,
    required this.departureTerminal,
    required this.departureGate,
    required this.arrivalAirport,
    required this.arrivalIata,
    this.arrivalTime,
    required this.arrivalTerminal,
    required this.arrivalGate,
    required this.status,
    required this.shipNumber,
  });

  factory AviationFlight.fromJson(Map<String, dynamic> json) {
    // Safely parse date times
    DateTime? parseDateTime(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      try {
        return DateTime.parse(raw).toLocal();
      } catch (_) {
        return null;
      }
    }

    // Safely cast nested objects as Maps, fallback to empty map
    Map<String, dynamic> safeMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    final airline = safeMap(json['airline']);
    final flight = safeMap(json['flight']);
    final departure = safeMap(json['departure']);
    final arrival = safeMap(json['arrival']);
    final aircraft = safeMap(json['aircraft']);

    // Flight number fallback: try IATA first, then ICAO
    final strIata = (flight['iata']?.toString() ?? "").trim();
    final strIcao = (flight['icao']?.toString() ?? "").trim();
    final parsedFlightNumber = strIata.isNotEmpty
        ? strIata
        : (strIcao.isNotEmpty ? strIcao : "N/A");

    return AviationFlight(
      id: parsedFlightNumber,
      direction: "arrival",
      airlineName: airline['name']?.toString() ?? "Unknown Airline",
      flightNumber: parsedFlightNumber,

      // Departure fields
      departureAirport: departure['airport']?.toString() ?? "N/A",
      departureIata: departure['iata']?.toString() ?? "—",
      departureTime: parseDateTime(departure['scheduled']?.toString()),
      departureTerminal: departure['terminal']?.toString() ?? "—",
      departureGate: departure['gate']?.toString() ?? "—",

      // Arrival fields
      arrivalAirport: arrival['airport']?.toString() ?? "N/A",
      arrivalIata: arrival['iata']?.toString() ?? "—",
      arrivalTime: parseDateTime(arrival['scheduled']?.toString()),
      arrivalTerminal: arrival['terminal']?.toString() ?? "—",
      arrivalGate: arrival['gate']?.toString() ?? "—",

      status: json['flight_status']?.toString() ?? "unknown",
      shipNumber: aircraft['registration']?.toString() ?? "N/A",
    );
  }

  factory AviationFlight.fromApiJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic raw) {
      final value = raw?.toString().trim() ?? "";
      if (value.isEmpty) return null;
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return null;
      }
    }

    Map<String, dynamic> safeMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    String readString(String key, {String fallback = "N/A"}) {
      final value = json[key]?.toString().trim() ?? "";
      return value.isEmpty ? fallback : value;
    }

    String readNestedString(
      Map<String, dynamic> source,
      String key, {
      required String fallback,
    }) {
      final value = source[key]?.toString().trim() ?? "";
      return value.isEmpty ? fallback : value;
    }

    String readLocationValue({
      required Map<String, dynamic> source,
      required String nestedKey,
      required String flatKey,
    }) {
      final nestedValue = readNestedString(source, nestedKey, fallback: "");
      if (nestedValue.isNotEmpty) {
        return nestedValue;
      }

      return readString(flatKey, fallback: "—");
    }

    final departure = safeMap(json['departure']);
    final arrival = safeMap(json['arrival']);

    return AviationFlight(
      id: readString('id', fallback: readString('flightNumber')),
      direction: readString('direction', fallback: "arrival").toLowerCase(),
      airlineName: readString('airlineName', fallback: "Unknown Airline"),
      flightNumber: readString('flightNumber'),
      departureAirport: readString('departureAirport'),
      departureIata: readString('departureIata'),
      departureTime: parseDateTime(json['departureTime']),
      departureTerminal: readLocationValue(
        source: departure,
        nestedKey: 'terminal',
        flatKey: 'departureTerminal',
      ),
      departureGate: readLocationValue(
        source: departure,
        nestedKey: 'gate',
        flatKey: 'departureGate',
      ),
      arrivalAirport: readString('arrivalAirport'),
      arrivalIata: readString('arrivalIata'),
      arrivalTime: parseDateTime(json['arrivalTime']),
      arrivalTerminal: readLocationValue(
        source: arrival,
        nestedKey: 'terminal',
        flatKey: 'arrivalTerminal',
      ),
      arrivalGate: readLocationValue(
        source: arrival,
        nestedKey: 'gate',
        flatKey: 'arrivalGate',
      ),
      status: readString('status', fallback: "unknown"),
      shipNumber: readString('shipNumber'),
    );
  }

  bool get isDeparture => direction.toLowerCase() == 'departure';

  bool get isArrival => !isDeparture;

  String _displayValue(String value, {String fallback = "—"}) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return fallback;
    }

    final lower = normalized.toLowerCase();
    if (lower == "n/a" || lower == "unknown" || normalized == "—") {
      return fallback;
    }

    return normalized;
  }

  String get displayDepartureTerminal => _displayValue(departureTerminal);

  String get displayDepartureGate => _displayValue(departureGate);

  String get displayArrivalTerminal => _displayValue(arrivalTerminal);

  String get displayArrivalGate => _displayValue(arrivalGate);

  String get operationalTerminal =>
      isDeparture ? displayDepartureTerminal : displayArrivalTerminal;

  String get operationalGate =>
      isDeparture ? displayDepartureGate : displayArrivalGate;

  DateTime? get operationalTime => isDeparture ? departureTime : arrivalTime;

  String get formattedOperationalTime =>
      isDeparture ? formattedDepartureTime : formattedArrivalTime;

  // === Computed Properties / Formatting ===

  String get formattedDepartureTime {
    if (departureTime == null) return "—:—";
    return DateFormat('HH:mm').format(departureTime!);
  }

  String get formattedArrivalTime {
    if (arrivalTime == null) return "—:—";
    return DateFormat('HH:mm').format(arrivalTime!);
  }

  /// Calculates string representing e.g. "Departs in 23 min" or empty if > 60min
  String get relativeDepartureLabel {
    if (departureTime == null) return "";
    final diff = departureTime!.difference(DateTime.now());

    if (diff.isNegative) return "Departed";

    final inMinutes = diff.inMinutes;
    if (inMinutes <= 60) {
      return "Departs in $inMinutes min";
    }
    return ""; // Empty string tells UI not to show the relative badge
  }

  /// True if departing in less than 30 minutes (UI uses Amber color for this)
  bool get isDepartingSoon {
    if (departureTime == null) return false;
    final diff = departureTime!.difference(DateTime.now());
    return !diff.isNegative && diff.inMinutes < 30;
  }
}
