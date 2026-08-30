import 'dart:async';

import 'package:get/get.dart';

import '../models/aviationstack_model.dart';
import '../services/api_exception.dart';
import '../services/app_api_service.dart';
import '../services/session_service.dart';

class AirportState {
  final RxString status = 'idle'.obs;
  final RxList<AviationFlight> arrivals = <AviationFlight>[].obs;
  final RxList<AviationFlight> departures = <AviationFlight>[].obs;
  final Rx<DateTime?> lastUpdated = Rx<DateTime?>(null);
  final Rx<String?> error = Rx<String?>(null);
  final RxString timezone = ''.obs;
  final RxString windowStart = ''.obs;
  final RxString windowEnd = ''.obs;

  List<AviationFlight> get allFlights => [...arrivals, ...departures];

  void setLoading() {
    status.value = 'loading';
    error.value = null;
  }

  void setSuccess(
    List<AviationFlight> arr,
    List<AviationFlight> dep, {
    DateTime? updatedAt,
    String? timezoneLabel,
    String? windowStartLabel,
    String? windowEndLabel,
  }) {
    status.value = 'success';
    arrivals.assignAll(arr);
    departures.assignAll(dep);
    lastUpdated.value = updatedAt ?? DateTime.now();
    timezone.value = (timezoneLabel ?? '').trim();
    windowStart.value = (windowStartLabel ?? '').trim();
    windowEnd.value = (windowEndLabel ?? '').trim();
  }

  void setError(String message) {
    status.value = 'error';
    error.value = message;
  }
}

class AviationController extends GetxController {
  final AppApiService _api = Get.find<AppApiService>();
  final SessionService _session = Get.find<SessionService>();

  final activeAirport = AirportState();
  final RxInt secondsUntilCacheExpiry = 0.obs;

  Timer? _cacheCountdownTimer;

  @override
  void onInit() {
    super.onInit();
    fetchFlights();
  }

  @override
  void onClose() {
    _cacheCountdownTimer?.cancel();
    super.onClose();
  }

  void _startCacheCountdown(int nextExpiryInSeconds) {
    _cacheCountdownTimer?.cancel();
    secondsUntilCacheExpiry.value = nextExpiryInSeconds;

    _cacheCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (secondsUntilCacheExpiry.value > 0) {
        secondsUntilCacheExpiry.value--;
      } else {
        _cacheCountdownTimer?.cancel();
      }
    });
  }

  Future<void> fetchFlights() async {
    if (_session.activeStationCode.isEmpty) {
      activeAirport.setError('No active station selected.');
      return;
    }

    if (_session.availableContracts.isNotEmpty &&
        _session.activeContract.isEmpty) {
      activeAirport.setError(
        'Select an airline contract to load inbound flights.',
      );
      return;
    }

    activeAirport.setLoading();

    try {
      final response = await _api.getStationFlights().timeout(
        const Duration(seconds: 20),
      );

      final arrivals = _parseFlights(response['arrivals']);
      final departures = _parseFlights(response['departures']);
      final cache = response['cache'];
      final timezone = response['timezone']?.toString().trim() ?? '';
      final windowStart = response['windowStart']?.toString().trim() ?? '';
      final windowEnd = response['windowEnd']?.toString().trim() ?? '';

      if (cache is Map<String, dynamic>) {
        final nextExpiryInSeconds =
            _readPositiveInt(cache['remainingSeconds']) ??
            _readPositiveInt(cache['ttlSeconds']) ??
            300;

        if (nextExpiryInSeconds > 0) {
          _startCacheCountdown(nextExpiryInSeconds);
        } else {
          _cacheCountdownTimer?.cancel();
          secondsUntilCacheExpiry.value = 0;
        }

        activeAirport.setSuccess(
          arrivals,
          departures,
          updatedAt: _parseDateTime(cache['fetchedAt']),
          timezoneLabel: timezone,
          windowStartLabel: windowStart,
          windowEndLabel: windowEnd,
        );
        return;
      }

      activeAirport.setSuccess(
        arrivals,
        departures,
        timezoneLabel: timezone,
        windowStartLabel: windowStart,
        windowEndLabel: windowEnd,
      );
      _cacheCountdownTimer?.cancel();
      secondsUntilCacheExpiry.value = 0;
    } on ApiException catch (error) {
      _cacheCountdownTimer?.cancel();
      secondsUntilCacheExpiry.value = 0;
      activeAirport.setError(error.message);
    } on TimeoutException {
      _cacheCountdownTimer?.cancel();
      secondsUntilCacheExpiry.value = 0;
      activeAirport.setError('Flight request timed out.');
    } catch (_) {
      _cacheCountdownTimer?.cancel();
      secondsUntilCacheExpiry.value = 0;
      activeAirport.setError('Unable to load flights right now.');
    }
  }

  List<AviationFlight> _parseFlights(dynamic raw) {
    if (raw is! List) {
      return const <AviationFlight>[];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => AviationFlight.fromApiJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  int? _readPositiveInt(dynamic value) {
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  String timeAgo(DateTime? time) {
    if (time == null) return 'Never';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }
}
