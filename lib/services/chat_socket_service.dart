import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'app_api_service.dart';
import 'session_service.dart';

class ChatSocketService extends GetxService {
  ChatSocketService({SessionService? sessionService})
    : _sessionService = sessionService ?? Get.find<SessionService>();

  final SessionService _sessionService;
  final RxBool isConnected = false.obs;

  final StreamController<Map<String, dynamic>> _presenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _conversationUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageDeliveredController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageReadController =
      StreamController<Map<String, dynamic>>.broadcast();
  final Set<String> _joinedConversationIds = <String>{};

  io.Socket? _socket;
  String? _connectedToken;
  String? _connectedUrl;

  Stream<Map<String, dynamic>> get presenceUpdates =>
      _presenceController.stream;
  Stream<Map<String, dynamic>> get messageCreated =>
      _messageCreatedController.stream;
  Stream<Map<String, dynamic>> get conversationUpdated =>
      _conversationUpdatedController.stream;
  Stream<Map<String, dynamic>> get messageDelivered =>
      _messageDeliveredController.stream;
  Stream<Map<String, dynamic>> get messageRead => _messageReadController.stream;

  Future<void> ensureConnected() async {
    final String token = _sessionService.accessToken?.trim() ?? '';
    if (token.isEmpty) {
      disconnect();
      return;
    }

    final String socketUrl = AppApiService.chatSocketUrl;
    final bool sameConfig =
        _connectedToken == token && _connectedUrl == socketUrl;

    if (_socket != null && sameConfig) {
      if (!(_socket?.connected ?? false)) {
        _log('Reconnecting chat socket to $socketUrl');
        _socket?.connect();
      }
      return;
    }

    disconnect();

    _connectedToken = token;
    _connectedUrl = socketUrl;

    _log(
      'Connecting chat socket to $socketUrl '
      '(derived from API base ${AppApiService.baseUrl})',
    );

    final io.Socket socket = io.io(socketUrl, <String, dynamic>{
      // Allow polling fallback on physical devices or tunnels where a direct
      // websocket upgrade is flaky. The backend is still the same Socket.IO
      // gateway; this just makes the transport negotiation more resilient.
      'transports': <String>['websocket', 'polling'],
      'autoConnect': false,
      'forceNew': true,
      'upgrade': true,
      'rememberUpgrade': false,
      'path': '/socket.io',
      'reconnection': true,
      'reconnectionAttempts': 999999,
      'reconnectionDelay': 1000,
      'timeout': 15000,
      'auth': <String, dynamic>{'token': 'Bearer $token'},
      if (!kIsWeb)
        'extraHeaders': <String, String>{'Authorization': 'Bearer $token'},
    });

    _registerSocketListeners(socket);
    _socket = socket;
    socket.connect();
  }

  void joinConversation(String conversationId) {
    final String normalizedId = conversationId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    _joinedConversationIds.add(normalizedId);
    ensureConnected();
    _emitJoinConversation(normalizedId);
  }

  void leaveConversation(String conversationId) {
    _joinedConversationIds.remove(conversationId.trim());
  }

  void disconnect() {
    isConnected.value = false;
    _socket?.clearListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectedToken = null;
    _connectedUrl = null;
  }

  void _registerSocketListeners(io.Socket socket) {
    socket.onConnect((_) {
      isConnected.value = true;
      _log('Chat socket connected');
      for (final String conversationId in _joinedConversationIds) {
        _emitJoinConversation(conversationId);
      }
    });

    socket.onDisconnect((dynamic reason) {
      isConnected.value = false;
      _log('Chat socket disconnected: $reason');
    });

    socket.onReconnect((dynamic attempt) {
      isConnected.value = true;
      _log('Chat socket reconnected after $attempt attempt(s)');
    });

    socket.onReconnectAttempt((dynamic attempt) {
      _log('Chat socket reconnect attempt: $attempt');
    });

    socket.onReconnectError((dynamic error) {
      _log('Chat socket reconnect error: $error');
    });

    socket.onReconnectFailed((dynamic _) {
      _log('Chat socket reconnect failed');
    });

    socket.onConnectError((dynamic error) {
      isConnected.value = false;
      _log('Chat socket connect error: $error');
    });

    socket.onError((dynamic error) {
      _log('Chat socket error: $error');
    });

    socket.on('presence.updated', (dynamic payload) {
      _presenceController.add(_asMap(payload));
    });
    socket.on('message.created', (dynamic payload) {
      _messageCreatedController.add(_asMap(payload));
    });
    socket.on('conversation.updated', (dynamic payload) {
      _conversationUpdatedController.add(_asMap(payload));
    });
    socket.on('message.delivered', (dynamic payload) {
      _messageDeliveredController.add(_asMap(payload));
    });
    socket.on('message.read', (dynamic payload) {
      _messageReadController.add(_asMap(payload));
    });
  }

  void _emitJoinConversation(String conversationId) {
    if (!(_socket?.connected ?? false)) {
      return;
    }

    _socket?.emit('conversation.join', <String, dynamic>{
      'conversationId': conversationId,
    });
    _log('Joined conversation room $conversationId');
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic entry) => MapEntry(key.toString(), entry),
      );
    }
    return <String, dynamic>{};
  }

  void _log(String message) {
    debugPrint('[CHAT][SOCKET] $message');
  }

  @override
  void onClose() {
    disconnect();
    _presenceController.close();
    _messageCreatedController.close();
    _conversationUpdatedController.close();
    _messageDeliveredController.close();
    _messageReadController.close();
    super.onClose();
  }
}
