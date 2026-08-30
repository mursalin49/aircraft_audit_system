import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../config/app_env.dart';
import 'api_exception.dart';
import 'cloudinary_upload_service.dart';
import 'session_service.dart';

class AppApiService {
  AppApiService({
    http.Client? client,
    SessionService? sessionService,
    CloudinaryUploadService? cloudinaryUploadService,
  }) : _client = client ?? http.Client(),
       _sessionService = sessionService ?? Get.find<SessionService>(),
       _cloudinaryUploadService =
           cloudinaryUploadService ?? CloudinaryUploadService();

  final http.Client _client;
  final SessionService _sessionService;
  final CloudinaryUploadService _cloudinaryUploadService;
  Completer<bool>? _refreshCompleter;
  static String? _cachedBaseUrl;

  static String get baseUrl => _cachedBaseUrl ??= _resolveBaseUrl();

  static String get socketBaseUrl => _deriveSocketBaseUrl(baseUrl);

  static String get chatSocketUrl =>
      '${socketBaseUrl.replaceFirst(RegExp(r'/$'), '')}/chat';

  static String _resolveBaseUrl() {
    final configured = AppEnv.apiBaseUrl;
    if (configured.isNotEmpty) {
      debugPrint(
        'Using API base URL: ${_normalizeBaseUrl(configured)}'
        '${AppEnv.loadedAsset.isNotEmpty ? ' (resolved via --dart-define or ${AppEnv.loadedAsset})' : ''}',
      );
      return _normalizeBaseUrl(configured);
    }

    debugPrint(
      'No API_BASE_URL configured. Falling back to default host. '
      'Set API_BASE_URL in ${AppEnv.loadedAsset} or pass --dart-define=API_BASE_URL=...',
    );

    final defaultHost = kReleaseMode
        ? 'https://showing-whenever-presently-correction.trycloudflare.com/api'
        : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'https://showing-whenever-presently-correction.trycloudflare.com/api'
        : 'https://showing-whenever-presently-correction.trycloudflare.com/api';
    return _normalizeBaseUrl(defaultHost);
  }

  static String _normalizeBaseUrl(String value) {
    return value.endsWith('/') ? value : '$value/';
  }

  static String _deriveSocketBaseUrl(String apiBaseUrl) {
    final Uri apiUri = Uri.parse(_normalizeBaseUrl(apiBaseUrl));
    final List<String> segments = apiUri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: true);

    if (segments.isNotEmpty && segments.last.toLowerCase() == 'api') {
      segments.removeLast();
    }

    final String normalizedPath = segments.isEmpty
        ? '/'
        : '/${segments.join('/')}';

    return apiUri
        .replace(path: normalizedPath, queryParameters: null, fragment: null)
        .toString()
        .replaceFirst(RegExp(r'/$'), '');
  }

  static List<String> _resolveBaseUrlCandidates() {
    final primary = baseUrl;
    final candidates = <String>[primary];
    final baseUri = Uri.tryParse(primary);
    if (baseUri == null ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return candidates;
    }

    final normalizedHost = baseUri.host.trim().toLowerCase();
    if (!_isAndroidLocalDevelopmentHost(normalizedHost)) {
      return candidates;
    }

    for (final alternateHost in <String>[
      '127.0.0.1',
      'localhost',
      '10.0.2.2',
    ]) {
      if (alternateHost == normalizedHost) {
        continue;
      }

      candidates.add(
        _normalizeBaseUrl(baseUri.replace(host: alternateHost).toString()),
      );
    }

    return candidates;
  }

  static bool _isAndroidLocalDevelopmentHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host == '0.0.0.0';
  }

  Uri buildUri(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    String? baseUrlOverride,
  }) {
    final baseUri = Uri.parse(baseUrlOverride ?? baseUrl);
    final uri = baseUri.resolve(endpoint);
    final normalizedQuery = <String, String>{};

    queryParameters?.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is Iterable) {
        final joined = value
            .where((entry) => entry != null)
            .map((entry) => entry.toString())
            .where((entry) => entry.trim().isNotEmpty)
            .join(',');
        if (joined.isNotEmpty) {
          normalizedQuery[key] = joined;
        }
        return;
      }

      final stringValue = value.toString().trim();
      if (stringValue.isNotEmpty) {
        normalizedQuery[key] = stringValue;
      }
    });

    return uri.replace(
      queryParameters: normalizedQuery.isEmpty ? null : normalizedQuery,
    );
  }

  String buildFileContentUrl(String fileId) {
    return buildUri('files/$fileId/content').toString();
  }

  Map<String, String> buildImageHeaders() {
    final token = _sessionService.accessToken;
    if (token == null || token.isEmpty) {
      return const <String, String>{};
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> login({
    required String userId,
    required String password,
    required bool rememberMe,
  }) async {
    final data = await _send(
      'POST',
      'auth/login',
      body: {'userId': userId, 'password': password, 'rememberMe': rememberMe},
      authenticated: false,
      retryOnUnauthorized: false,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> refreshSession(String refreshToken) async {
    final data = await _send(
      'POST',
      'auth/refresh',
      body: {'refreshToken': refreshToken},
      authenticated: false,
      retryOnUnauthorized: false,
    );
    return _asMap(data);
  }

  Future<void> logout() async {
    final refreshToken = _sessionService.refreshToken;
    try {
      await _send(
        'POST',
        'auth/logout',
        body: refreshToken == null ? const {} : {'refreshToken': refreshToken},
      );
    } catch (_) {
      // Local session should still be cleared even if the server is unavailable.
    } finally {
      _sessionService.clear();
    }
  }

  Future<Map<String, dynamic>> me() async {
    final data = await _send('GET', 'auth/me');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    final data = await _send('GET', 'profile');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getAdminOverview({
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      'admin-dashboard/overview',
      queryParameters: queryParameters,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getAdminAuditRecords({
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      'admin-dashboard/audit-records',
      queryParameters: queryParameters,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getAdminAuditDetail({
    required String id,
    required String type,
  }) async {
    final data = await _send(
      'GET',
      'admin-dashboard/audit-detail',
      queryParameters: {'id': id, 'type': type},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getReportsSummary({
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      'reports/summary',
      queryParameters: queryParameters,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getReportsOverview({
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      'reports/overview',
      queryParameters: queryParameters,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getReportMetricDetail({
    required String bundleKey,
    required String metricKey,
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      'reports/bundles/$bundleKey/metrics/$metricKey',
      queryParameters: queryParameters,
    );
    return _asMap(data);
  }

  Future<ApiDownloadedFile> downloadReportBundlePdf({
    required String bundleKey,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _sendBytes(
      'GET',
      'reports/bundles/$bundleKey/export',
      queryParameters: queryParameters,
    );

    return ApiDownloadedFile(
      bytes: response.bodyBytes,
      fileName:
          _extractFileName(response.headers['content-disposition']) ??
          '$bundleKey-report.pdf',
    );
  }

  Future<Map<String, dynamic>> updateMyProfile(
    Map<String, dynamic> payload,
  ) async {
    final data = await _send('PATCH', 'profile', body: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> requestForgotPassword(String email) async {
    final data = await _send(
      'POST',
      'auth/forgot-password/request',
      body: {'email': email},
      authenticated: false,
      retryOnUnauthorized: false,
    );
    return _asMap(data);
  }

  Future<void> requestForgotUid(String email) {
    return _send(
      'POST',
      'auth/forgot-uid/request',
      body: {'email': email},
      authenticated: false,
      retryOnUnauthorized: false,
    );
  }

  Future<void> confirmForgotPassword({
    required String token,
    required String newPassword,
  }) {
    return _send(
      'POST',
      'auth/forgot-password/confirm',
      body: {'token': token, 'newPassword': newPassword},
      authenticated: false,
      retryOnUnauthorized: false,
    );
  }

  Future<String> fetchNoEmailAccessMessage() async {
    final response = await _send(
      'GET',
      'auth/no-email-access-message',
      authenticated: false,
      retryOnUnauthorized: false,
    );
    if (response is String) {
      return response;
    }
    if (response is Map && response['message'] is String) {
      return response['message'] as String;
    }
    return 'Please contact your management for assistance.';
  }

  Future<List<Map<String, dynamic>>> getMyStations() async {
    final data = await _send('GET', 'stations/my');
    final stations = _asMap(data)['stations'];
    return _asListOfMaps(stations);
  }

  Future<Map<String, dynamic>?> getActiveStation() async {
    final data = await _send('GET', 'stations/active');
    if (data == null) {
      return null;
    }
    return _asMap(data);
  }

  Future<Map<String, dynamic>> selectStation(
    String stationId, {
    String? contract,
  }) async {
    final data = await _send(
      'POST',
      'stations/select',
      body: {
        'stationId': stationId,
        if (contract != null && contract.trim().isNotEmpty)
          'contract': contract,
      },
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getStationFlights({
    bool forceRefresh = false,
    int? limit,
  }) async {
    final data = await _send(
      'GET',
      'flights/active',
      queryParameters: {
        if (forceRefresh) 'forceRefresh': true,
        if (limit case final int value) 'limit': value,
      },
    );
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getCleanTypes() async {
    final data = await _send('GET', 'master-data/clean-types');
    return _asListOfMaps(data);
  }

  Future<List<Map<String, dynamic>>> getAircraftTypes() async {
    final data = await _send('GET', 'master-data/aircraft-types');
    return _asListOfMaps(data);
  }

  Future<List<Map<String, dynamic>>> getFleetAircraft() async {
    final data = await _send('GET', 'master-data/fleet-aircraft');
    return _asListOfMaps(data);
  }

  Future<List<Map<String, dynamic>>> getCabinQualityChecklistItems() async {
    final data = await _send(
      'GET',
      'master-data/cabin-quality-checklist-items',
    );
    return _asListOfMaps(data);
  }

  Future<List<Map<String, dynamic>>> getLavSafetyChecklistItems() async {
    final data = await _send('GET', 'master-data/lav-safety-checklist-items');
    return _asListOfMaps(data);
  }

  Future<List<Map<String, dynamic>>> getSecuritySearchAreas() async {
    final data = await _send('GET', 'master-data/security-search-areas');
    return _asListOfMaps(data);
  }

  Future<List<Map<String, dynamic>>> getGates(String stationId) async {
    final data = await _send(
      'GET',
      'master-data/gates',
      queryParameters: {'stationId': stationId},
    );
    return _asListOfMaps(data);
  }

  Future<List<Map<String, dynamic>>> listPublishedDynamicForms() async {
    final data = await _send('GET', 'dynamic-forms/published');
    return _asListOfMaps(data);
  }

  Future<Map<String, dynamic>> getPublishedDynamicForm(String formId) async {
    final data = await _send('GET', 'dynamic-forms/published/$formId');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> submitPublishedDynamicForm(
    String formId, {
    required Map<String, dynamic> answers,
    Map<String, dynamic>? metadata,
  }) async {
    final data = await _send(
      'POST',
      'dynamic-forms/published/$formId/submissions',
      body: <String, dynamic>{
        'answers': answers,
        if (metadata case final Map<String, dynamic> value) 'metadata': value,
      },
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> listMyDynamicFormSubmissions({
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      'dynamic-forms/my-submissions',
      queryParameters: queryParameters,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> listAllDynamicFormSubmissions({
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      'dynamic-forms/submissions',
      queryParameters: queryParameters,
    );
    return _asMap(data);
  }

  Future<CloudinarySignedUploadPayload>
  getCloudinarySignedUploadPayload() async {
    final data = await _send('POST', 'upload/signed-url', body: const {});
    final payload = CloudinarySignedUploadPayload.fromMap(_asMap(data));
    if (!payload.isValid) {
      throw const ApiException(
        'Backend returned an invalid Cloudinary signed upload payload.',
      );
    }
    return payload;
  }

  Future<Map<String, dynamic>> uploadFile(
    File file, {
    required String category,
    ProgressCallback? onSendProgress,
    bool skipCompression = false,
  }) async {
    CloudinaryUploadResult uploadedAsset;
    try {
      final signedPayload = _cloudinaryUploadService.hasUnsignedUploadConfig
          ? null
          : await getCloudinarySignedUploadPayload();
      uploadedAsset = await _cloudinaryUploadService.uploadFile(
        file,
        onProgress: onSendProgress,
        signedPayload: signedPayload,
        skipCompression: skipCompression,
      );
    } on DioException catch (error) {
      final message = error.response?.data is Map
          ? (error.response?.data['error']?['message']?.toString() ??
                error.message)
          : error.message;
      throw ApiException(
        message?.trim().isNotEmpty == true
            ? message!.trim()
            : 'Unable to upload the file to Cloudinary right now.',
      );
    }

    final data = await _send(
      'POST',
      'files/register',
      body: {
        'cloudinaryUrl': uploadedAsset.secureUrl,
        'category': category,
        'originalFileName': uploadedAsset.originalFileName,
        'mimeType': uploadedAsset.mimeType,
        'sizeBytes': uploadedAsset.bytes,
        if (uploadedAsset.publicId.isNotEmpty)
          'publicId': uploadedAsset.publicId,
        if (uploadedAsset.format.isNotEmpty) 'format': uploadedAsset.format,
        if (uploadedAsset.resourceType.isNotEmpty)
          'resourceType': uploadedAsset.resourceType,
      },
    );
    final registered = _asMap(data);
    if (!registered.containsKey('cloudinaryUrl')) {
      registered['cloudinaryUrl'] = uploadedAsset.secureUrl;
    }
    return registered;
  }

  Future<Map<String, dynamic>> listCabinQualityAudits({
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      'cabin-quality-audits',
      queryParameters: queryParameters,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getCabinQualityAudit(String id) async {
    final data = await _send('GET', 'cabin-quality-audits/$id');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createCabinQualityAudit(
    Map<String, dynamic> payload,
  ) async {
    final data = await _send('POST', 'cabin-quality-audits', body: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> listLavSafetyObservations({
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      'lav-safety-observations',
      queryParameters: queryParameters,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getLavSafetyObservation(String id) async {
    final data = await _send('GET', 'lav-safety-observations/$id');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createLavSafetyObservation(
    Map<String, dynamic> payload,
  ) async {
    final data = await _send('POST', 'lav-safety-observations', body: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> listCabinSecurityTrainings({
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      'cabin-security-search-trainings',
      queryParameters: queryParameters,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getCabinSecurityTraining(String id) async {
    final data = await _send('GET', 'cabin-security-search-trainings/$id');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createCabinSecurityTraining(
    Map<String, dynamic> payload,
  ) async {
    final data = await _send(
      'POST',
      'cabin-security-search-trainings',
      body: payload,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> listHiddenObjectAudits({
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      'hidden-object-audits',
      queryParameters: queryParameters,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getHiddenObjectAudit(String id) async {
    final data = await _send('GET', 'hidden-object-audits/$id');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createHiddenObjectAudit(
    Map<String, dynamic> payload,
  ) async {
    final data = await _send('POST', 'hidden-object-audits', body: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> confirmHiddenObjectLocation({
    required String auditId,
    required String locationId,
    required Map<String, dynamic> payload,
  }) async {
    final data = await _send(
      'POST',
      'hidden-object-audits/$auditId/locations/$locationId/confirm',
      body: payload,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> activateHiddenObjectAudit(String auditId) async {
    final data = await _send(
      'POST',
      'hidden-object-audits/$auditId/activate',
      body: const {},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> markHiddenObjectFound({
    required String auditId,
    required String locationId,
  }) async {
    final data = await _send(
      'POST',
      'hidden-object-audits/$auditId/locations/$locationId/found',
      body: const {},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> closeHiddenObjectAudit(String auditId) async {
    final data = await _send(
      'POST',
      'hidden-object-audits/$auditId/close',
      body: const {},
    );
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> searchEmployees(String query) async {
    final data = await _send(
      'GET',
      'employees/search',
      queryParameters: {'q': query},
    );
    return _asListOfMaps(data);
  }

  Future<List<Map<String, dynamic>>> listChatUsers({String? query}) async {
    final data = await _send(
      'GET',
      'employees/chat-users',
      queryParameters: {'q': query},
    );
    return _asListOfMaps(data);
  }

  Future<List<Map<String, dynamic>>> listConversations({
    String? tab,
    String? query,
  }) async {
    final data = await _send(
      'GET',
      'chat/conversations',
      queryParameters: {'tab': tab, 'q': query},
    );
    return _asListOfMaps(data);
  }

  Future<Map<String, dynamic>> createDirectConversation(String userId) async {
    final data = await _send(
      'POST',
      'chat/conversations/direct',
      body: {'userId': userId},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getConversation(String id) async {
    final data = await _send('GET', 'chat/conversations/$id');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getConversationMessages(
    String id, {
    String? cursor,
    int? limit,
  }) async {
    final data = await _send(
      'GET',
      'chat/conversations/$id/messages',
      queryParameters: {'cursor': cursor, 'limit': limit},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> sendTextMessage(
    String conversationId,
    String text,
  ) async {
    final trimmed = text.trim();
    final preview = trimmed.length <= 100
        ? trimmed
        : '${trimmed.substring(0, 100)}...';
    final data = await _send(
      'POST',
      'chat/conversations/$conversationId/messages',
      body: {
        'messageType': 'TEXT',
        'encryptedPayload': trimmed,
        'previewText': preview,
      },
    );
    return _asMap(data);
  }

  Future<void> markMessageDelivered(String messageId) {
    return _send('POST', 'chat/messages/$messageId/delivered', body: const {});
  }

  Future<void> markMessageRead(String messageId) {
    return _send('POST', 'chat/messages/$messageId/read', body: const {});
  }

  Future<dynamic> _send(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};

    if (authenticated) {
      final accessToken = _sessionService.accessToken;
      if (accessToken?.isNotEmpty ?? false) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    http.Response? response;
    Uri? activeUri;
    final attemptedUris = <Uri>[];
    final candidateBaseUrls = _resolveBaseUrlCandidates();

    for (final candidateBaseUrl in candidateBaseUrls) {
      final candidateUri = buildUri(
        endpoint,
        queryParameters: queryParameters,
        baseUrlOverride: candidateBaseUrl,
      );
      attemptedUris.add(candidateUri);

      _logRequest(
        method: method,
        uri: candidateUri,
        queryParameters: queryParameters,
        body: body,
        authenticated: authenticated,
      );

      try {
        switch (method.toUpperCase()) {
          case 'GET':
            response = await _client.get(candidateUri, headers: headers);
            break;
          case 'POST':
            headers['Content-Type'] = 'application/json';
            response = await _client.post(
              candidateUri,
              headers: headers,
              body: jsonEncode(body ?? const {}),
            );
            break;
          case 'PATCH':
            headers['Content-Type'] = 'application/json';
            response = await _client.patch(
              candidateUri,
              headers: headers,
              body: jsonEncode(body ?? const {}),
            );
            break;
          default:
            throw ApiException('Unsupported request method: $method');
        }

        activeUri = candidateUri;
        _logResponse(method: method, uri: candidateUri, response: response);
        break;
      } on SocketException {
        _logTransportError(
          method: method,
          uri: candidateUri,
          error: 'SocketException: Unable to reach backend',
        );
        continue;
      } on HttpException catch (error) {
        _logTransportError(
          method: method,
          uri: candidateUri,
          error: error.toString(),
        );
        throw const ApiException(
          'Unable to complete the request because the server connection failed.',
        );
      }
    }

    if (response == null || activeUri == null) {
      throw ApiException(_buildBackendUnreachableMessage(attemptedUris));
    }

    if (response.statusCode == 401 &&
        authenticated &&
        retryOnUnauthorized &&
        await _refreshAccessToken()) {
      _logInfo(
        '[API][RETRY] ${method.toUpperCase()} $activeUri -> retrying after token refresh',
      );
      return _send(
        method,
        endpoint,
        body: body,
        queryParameters: queryParameters,
        authenticated: authenticated,
        retryOnUnauthorized: false,
      );
    }

    final parsed = _decodeResponse(response.body);
    try {
      return _unwrapResponse(response.statusCode, parsed);
    } on ApiException catch (error) {
      _logApiError(
        method: method,
        uri: activeUri,
        error: error,
        responseBody: parsed,
      );
      rethrow;
    }
  }

  Future<http.Response> _sendBytes(
    String method,
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/pdf, application/octet-stream',
    };

    if (authenticated) {
      final accessToken = _sessionService.accessToken;
      if (accessToken?.isNotEmpty ?? false) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    http.Response? response;
    Uri? activeUri;
    final attemptedUris = <Uri>[];
    final candidateBaseUrls = _resolveBaseUrlCandidates();

    for (final candidateBaseUrl in candidateBaseUrls) {
      final candidateUri = buildUri(
        endpoint,
        queryParameters: queryParameters,
        baseUrlOverride: candidateBaseUrl,
      );
      attemptedUris.add(candidateUri);

      _logRequest(
        method: method,
        uri: candidateUri,
        queryParameters: queryParameters,
        authenticated: authenticated,
      );

      try {
        switch (method.toUpperCase()) {
          case 'GET':
            response = await _client.get(candidateUri, headers: headers);
            break;
          default:
            throw ApiException('Unsupported request method: $method');
        }

        activeUri = candidateUri;
        _logBinaryResponse(
          method: method,
          uri: candidateUri,
          response: response,
        );
        break;
      } on SocketException {
        _logTransportError(
          method: method,
          uri: candidateUri,
          error: 'SocketException: Unable to reach backend',
        );
        continue;
      } on HttpException catch (error) {
        _logTransportError(
          method: method,
          uri: candidateUri,
          error: error.toString(),
        );
        throw const ApiException(
          'Unable to complete the request because the server connection failed.',
        );
      }
    }

    if (response == null || activeUri == null) {
      throw ApiException(_buildBackendUnreachableMessage(attemptedUris));
    }

    if (response.statusCode == 401 &&
        authenticated &&
        retryOnUnauthorized &&
        await _refreshAccessToken()) {
      _logInfo(
        '[API][RETRY] ${method.toUpperCase()} $activeUri -> retrying after token refresh',
      );
      return _sendBytes(
        method,
        endpoint,
        queryParameters: queryParameters,
        authenticated: authenticated,
        retryOnUnauthorized: false,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    final parsed = _decodeResponse(utf8.decode(response.bodyBytes));
    final error = parsed is Map<String, dynamic>
        ? ApiException(
            _extractErrorMessage(parsed),
            statusCode: response.statusCode,
            code: parsed['code'] as String?,
            details: parsed['details'],
          )
        : ApiException(
            'Request failed with status ${response.statusCode}',
            statusCode: response.statusCode,
          );

    _logApiError(
      method: method,
      uri: activeUri,
      error: error,
      responseBody: parsed,
    );
    throw error;
  }

  void _logRequest({
    required String method,
    required Uri uri,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    required bool authenticated,
  }) {
    final summary = <String>[
      '[API][REQUEST] ${method.toUpperCase()} $uri',
      'auth=${authenticated ? 'on' : 'off'}',
      if (queryParameters != null && queryParameters.isNotEmpty)
        'query=${_stringifyForLog(queryParameters)}',
      if (body != null && body.isNotEmpty) 'body=${_stringifyForLog(body)}',
    ].join(' | ');
    _logInfo(summary);
  }

  void _logResponse({
    required String method,
    required Uri uri,
    required http.Response response,
  }) {
    final responseBody = response.body.trim();
    final summary = <String>[
      '[API][RESPONSE] ${method.toUpperCase()} $uri',
      'status=${response.statusCode}',
      if (responseBody.isNotEmpty) 'body=${_truncate(responseBody)}',
    ].join(' | ');
    _logInfo(summary);
  }

  void _logBinaryResponse({
    required String method,
    required Uri uri,
    required http.Response response,
  }) {
    final summary = <String>[
      '[API][RESPONSE] ${method.toUpperCase()} $uri',
      'status=${response.statusCode}',
      'bytes=${response.bodyBytes.length}',
      if (response.headers['content-type']?.isNotEmpty ?? false)
        'contentType=${response.headers['content-type']}',
      if (response.headers['content-disposition']?.isNotEmpty ?? false)
        'contentDisposition=${response.headers['content-disposition']}',
    ].join(' | ');
    _logInfo(summary);
  }

  void _logApiError({
    required String method,
    required Uri uri,
    required ApiException error,
    dynamic responseBody,
  }) {
    final summary = <String>[
      '[API][ERROR] ${method.toUpperCase()} $uri',
      if (error.statusCode != null) 'status=${error.statusCode}',
      if (error.code?.isNotEmpty ?? false) 'code=${error.code}',
      'message=${error.message.replaceAll('\n', ' | ')}',
      if (responseBody != null)
        'response=${_stringifyForLog(responseBody, isErrorPayload: true)}',
    ].join(' | ');
    _logInfo(summary);
  }

  void _logTransportError({
    required String method,
    required Uri uri,
    required String error,
  }) {
    _logInfo('[API][TRANSPORT] ${method.toUpperCase()} $uri | $error');
  }

  void _logInfo(String message) {
    debugPrint(message);
  }

  String _buildBackendUnreachableMessage(List<Uri> attemptedUris) {
    final attemptedHosts = attemptedUris
        .map(
          (uri) =>
              '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}',
        )
        .toSet()
        .join(', ');
    final configuredBaseUri = Uri.tryParse(baseUrl);
    final configuredHost = configuredBaseUri?.host.trim().toLowerCase() ?? '';
    final assetLabel = AppEnv.loadedAsset.isEmpty ? '.env' : AppEnv.loadedAsset;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (_isAndroidLocalDevelopmentHost(configuredHost)) {
        final portSegment = configuredBaseUri?.hasPort == true
            ? ':${configuredBaseUri!.port}'
            : '';
        final scheme = configuredBaseUri?.scheme.isNotEmpty == true
            ? configuredBaseUri!.scheme
            : 'http';
        return 'Unable to reach the backend. Tried $attemptedHosts. '
            'This is usually not a permission issue. On a real Android phone, '
            '`10.0.2.2` only works in the emulator. Use your computer\'s LAN IP '
            'like `$scheme://192.168.x.x$portSegment/api`, or run '
            '`adb reverse tcp${portSegment.isEmpty ? ':3000' : portSegment} '
            'tcp${portSegment.isEmpty ? ':3000' : portSegment}` and point '
            'API_BASE_URL to `$scheme://127.0.0.1$portSegment/api`. '
            'Current config came from $assetLabel.';
      }

      return 'Unable to reach the backend at $attemptedHosts. '
          'The Android app already has network permission, so this is more likely '
          'a device-to-server reachability issue or a stale API_BASE_URL build value. '
          'Confirm the phone can open the backend host directly and rebuild with the '
          'correct `--dart-define-from-file` or `--dart-define=API_BASE_URL=...`. '
          'Current config came from $assetLabel.';
    }

    return 'Unable to reach the backend at $attemptedHosts. '
        'Check the API base URL and server status. Current config came from '
        '$assetLabel.';
  }

  String _stringifyForLog(dynamic value, {bool isErrorPayload = false}) {
    try {
      if (value is Map) {
        final sanitized = value.map<String, dynamic>((key, entry) {
          final normalizedKey = key.toString().toLowerCase();
          if (_isSensitiveKey(normalizedKey)) {
            return MapEntry(key.toString(), '***');
          }
          return MapEntry(key.toString(), entry);
        });
        return _truncate(jsonEncode(sanitized));
      }
      if (value is List) {
        return _truncate(jsonEncode(value));
      }
      final text = value?.toString() ?? '';
      return isErrorPayload
          ? _truncate(text)
          : _truncate(_maskSensitiveText(text));
    } catch (_) {
      return _truncate(value?.toString() ?? '');
    }
  }

  bool _isSensitiveKey(String key) {
    return key.contains('password') ||
        key.contains('token') ||
        key.contains('authorization') ||
        key.contains('signature') ||
        key.contains('api_key');
  }

  String _maskSensitiveText(String text) {
    return text
        .replaceAllMapped(
          RegExp(
            r'"(password|token|authorization|signature|api_key)"\s*:\s*"[^"]*"',
            caseSensitive: false,
          ),
          (match) => '"${match.group(1)}":"***"',
        )
        .replaceAllMapped(
          RegExp(r'(Bearer)\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
          (_) => 'Bearer ***',
        );
  }

  String _truncate(String value, {int maxLength = 500}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}...';
  }

  dynamic _decodeResponse(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  dynamic _unwrapResponse(int statusCode, dynamic parsed) {
    if (statusCode >= 200 && statusCode < 300) {
      if (parsed is Map<String, dynamic> && parsed.containsKey('success')) {
        if (parsed['success'] == false) {
          throw ApiException(
            _extractErrorMessage(parsed),
            statusCode: statusCode,
            code: parsed['code'] as String?,
            details: parsed['details'],
          );
        }
        return parsed['data'];
      }
      return parsed;
    }

    if (parsed is Map<String, dynamic>) {
      throw ApiException(
        _extractErrorMessage(parsed),
        statusCode: statusCode,
        code: parsed['code'] as String?,
        details: parsed['details'],
      );
    }

    throw ApiException(
      'Request failed with status $statusCode',
      statusCode: statusCode,
    );
  }

  String _extractErrorMessage(Map<String, dynamic> parsed) {
    final rawMessage = parsed['message'];
    final details = parsed['details'];

    final baseMessage = rawMessage is String && rawMessage.trim().isNotEmpty
        ? rawMessage.trim()
        : 'Request failed';

    if (details is List) {
      final detailLines = details
          .map((detail) => detail?.toString().trim() ?? '')
          .where((detail) => detail.isNotEmpty)
          .toList();
      if (detailLines.isNotEmpty) {
        return '$baseMessage\n${detailLines.join('\n')}';
      }
    } else if (details is String && details.trim().isNotEmpty) {
      return '$baseMessage\n${details.trim()}';
    }

    return baseMessage;
  }

  String? _extractFileName(String? contentDisposition) {
    if (contentDisposition == null || contentDisposition.trim().isEmpty) {
      return null;
    }

    final utf8Match = RegExp(
      r"filename\*\s*=\s*UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    if (utf8Match != null) {
      return _sanitizeFileName(Uri.decodeFull(utf8Match.group(1)!.trim()));
    }

    final fileNameMatch = RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    if (fileNameMatch != null) {
      return _sanitizeFileName(fileNameMatch.group(1)!.trim());
    }

    return null;
  }

  String _sanitizeFileName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'report-export.pdf';
    }

    final normalized = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
    return normalized.toLowerCase().endsWith('.pdf')
        ? normalized
        : '$normalized.pdf';
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = _sessionService.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      _expireSession();
      return false;
    }

    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    () async {
      try {
        final refreshed = await refreshSession(refreshToken);
        _sessionService.saveAuth(
          accessToken: (refreshed['accessToken'] as String?) ?? '',
          refreshToken: (refreshed['refreshToken'] as String?) ?? '',
          rememberMe: _sessionService.rememberMe,
        );
        completer.complete(true);
      } catch (_) {
        _expireSession();
        completer.complete(false);
      } finally {
        _refreshCompleter = null;
      }
    }();

    return completer.future;
  }

  void _expireSession() {
    _sessionService.clear();

    if (Get.currentRoute == '/login') {
      return;
    }

    Future.microtask(() {
      if (Get.key.currentState != null && Get.currentRoute != '/login') {
        Get.offAllNamed('/login');
      }
    });
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

  List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value.map(_asMap).toList();
  }
}

class ApiDownloadedFile {
  const ApiDownloadedFile({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}
