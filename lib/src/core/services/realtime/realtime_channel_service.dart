// lib/src/core/services/realtime/realtime_channel_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:qrypta/src/core/config/app_config.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/error/network_exception_adapter.dart';

/// Status koneksi transport real-time (Phase 7.2 #1).
enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Tipe payload websocket yang didukung oleh protokol handshake.
enum RealtimeEventType {
  consentRequest,
  consentApproved,
  consentRejected,
  consentRevoked,
  heartbeat,
  unknown,
}

/// Abstraksi soket dua arah untuk mempermudah pengujian unit & chaos testing (L1/L2/L3).
abstract class IRealtimeSocket {
  Stream<dynamic> get stream;
  void add(dynamic data);
  Future<void> close([int? status, String? reason]);
}

/// Implementasi wrapper WebSocket bawaan Dart IO.
class IoRealtimeSocket implements IRealtimeSocket {
  final WebSocket _ws;
  IoRealtimeSocket(this._ws);

  @override
  Stream<dynamic> get stream => _ws;

  @override
  void add(dynamic data) => _ws.add(data);

  @override
  Future<void> close([int? status, String? reason]) => _ws.close(status, reason);
}

typedef SocketConnector = Future<IRealtimeSocket> Function(Uri uri, {Map<String, dynamic>? headers});

/// Layanan komunikasi dua arah real-time antara Tourist App, Backend ezsign-core,
/// dan Merchant Scanner (Phase 7.1 & 7.2 / F-15).
///
/// Menegakkan Golden Rule R1, R2, R7, dan R8:
/// - Menggantikan 100% simulasi in-app berbasis delay timer dengan event jaringan asli.
/// - Mendukung koneksi WebSocket/SSE saat foreground, pemulihan pesan via polling interval,
///   dan integrasi push notification saat background.
/// - Reconnect eksponensial otomatis (1s -> 2s -> 4s -> ... maks 30s).
/// - Heartbeat berkala (ping-pong) untuk mendeteksi soket mati.
class RealtimeChannelService {
  static const String _logTag = 'RealtimeChannelService';

  final http.Client _httpClient;
  final SocketConnector _socketConnector;
  final String _wsBaseUrl;
  final String _httpBaseUrl;

  IRealtimeSocket? _socket;
  StreamSubscription? _socketSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _pollingFallbackTimer;

  RealtimeConnectionStatus _status = RealtimeConnectionStatus.disconnected;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;
  String? _subscribedWallet;
  String? _subscribedBtid;
  DateTime? _lastSyncTimestamp;
  String? _lastError;

  final StreamController<RealtimeConnectionStatus> _statusController =
      StreamController<RealtimeConnectionStatus>.broadcast();
  final StreamController<ConsentRequestModel> _requestStreamController =
      StreamController<ConsentRequestModel>.broadcast();
  final Set<String> _processedRequestIds = <String>{};

  RealtimeChannelService({
    http.Client? httpClient,
    SocketConnector? socketConnector,
    String? wsBaseUrl,
    String? httpBaseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _socketConnector = socketConnector ?? _defaultSocketConnector,
        _wsBaseUrl = wsBaseUrl ?? _deriveWsUrl(httpBaseUrl ?? AppConfig.ezsignUrl),
        _httpBaseUrl = httpBaseUrl ?? AppConfig.ezsignUrl;

  static Future<IRealtimeSocket> _defaultSocketConnector(Uri uri, {Map<String, dynamic>? headers}) async {
    final ws = await WebSocket.connect(uri.toString(), headers: headers);
    return IoRealtimeSocket(ws);
  }

  static String _deriveWsUrl(String httpUrl) {
    if (httpUrl.isEmpty) return 'wss://staging.qrypta.local/ws/handshake';
    if (httpUrl.startsWith('https://')) {
      return httpUrl.replaceFirst('https://', 'wss://') + '/ws/handshake';
    } else if (httpUrl.startsWith('http://')) {
      return httpUrl.replaceFirst('http://', 'ws://') + '/ws/handshake';
    }
    return 'wss://$httpUrl/ws/handshake';
  }

  /// Status koneksi saat ini.
  RealtimeConnectionStatus get status => _status;

  /// Stream perubahan status koneksi real-time.
  Stream<RealtimeConnectionStatus> get statusStream => _statusController.stream;

  /// Stream event permintaan verifikasi/consent yang masuk secara real-time dari merchant.
  Stream<ConsentRequestModel> get requestStream => _requestStreamController.stream;

  /// Dompet yang saat ini aktif berlangganan pada kanal.
  String? get subscribedWallet => _subscribedWallet;

  /// Menginisiasi koneksi WebSocket dan mendaftarkan dompet wisatawan ke kanal broadcast.
  Future<void> connect({
    required String walletAddress,
    String? btid,
    String? authToken,
  }) async {
    if (_isDisposed) return;

    final cleanWallet = walletAddress.trim().toLowerCase();
    _subscribedWallet = cleanWallet;
    _subscribedBtid = btid;

    _updateStatus(RealtimeConnectionStatus.connecting);

    try {
      final queryParams = <String, String>{
        'wallet': cleanWallet,
        if (btid != null && btid.isNotEmpty) 'btid': btid,
      };

      final uri = Uri.parse(_wsBaseUrl).replace(queryParameters: queryParams);
      developer.log('Menghubungkan ke Realtime Handshake WS: $uri', name: _logTag);

      _socket = await _socketConnector(uri, headers: {
        'Accept': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      });

      _updateStatus(RealtimeConnectionStatus.connected);
      _reconnectAttempts = 0;

      // 1. Kirim paket handshake subscription
      final subscribePayload = jsonEncode({
        'action': 'subscribe',
        'wallet': cleanWallet,
        'btid': btid ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
      _socket?.add(subscribePayload);

      // 2. Dengarkan stream data dari server
      _socketSubscription = _socket?.stream.listen(
        _handleIncomingSocketMessage,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
        cancelOnError: false,
      );

      // 3. Mulai heartbeat berkala (ping setiap 25 detik)
      _startHeartbeat();

      // 4. Sinkronisasi pesan tertunda yang mungkin terlewat saat offline
      await syncMissedRequests(walletAddress: cleanWallet, since: _lastSyncTimestamp);
    } on Object catch (e) {
      developer.log('Koneksi WebSocket gagal: $e', name: _logTag);
      _scheduleReconnect();
    }
  }

  /// Memproses pesan teks atau binary yang diterima dari WebSocket.
  void _handleIncomingSocketMessage(dynamic rawData) {
    if (rawData == null) return;
    try {
      final String text = rawData is String ? rawData : utf8.decode(rawData as List<int>);
      final dynamic decoded = jsonDecode(text);

      if (decoded is! Map<String, dynamic>) return;

      final action = decoded['action']?.toString() ?? decoded['type']?.toString();

      if (action == 'pong' || action == 'heartbeat_ack') {
        // Heartbeat ACK diterima, koneksi sehat
        return;
      }

      // Deteksi permintaan verifikasi merchant masuk
      if (action == 'consent_request' || decoded.containsKey('requestId') || decoded.containsKey('sessionId')) {
        final request = ConsentRequestModel.fromJson(decoded);

        // Abaikan jika permintaan telah kedaluwarsa atau duplikat
        if (request.isExpired) {
          developer.log('Permintaan consent kedaluwarsa diabaikan: ${request.requestId}', name: _logTag);
          return;
        }

        if (_processedRequestIds.contains(request.requestId)) {
          developer.log('Permintaan consent duplikat diabaikan: ${request.requestId}', name: _logTag);
          return;
        }

        _processedRequestIds.add(request.requestId);
        _lastSyncTimestamp = DateTime.now();

        developer.log(
          'Permintaan consent real-time diterima dari ${request.merchantName} (${request.merchantId})',
          name: _logTag,
        );

        _requestStreamController.add(request);
      }
    } on Object catch (e) {
      developer.log('Gagal mengurai pesan WebSocket masuk: $e', name: _logTag);
      _lastError = 'Gagal mengurai pesan WebSocket masuk: $e';
    }
  }

  void _handleSocketError(dynamic error) {
    developer.log('WebSocket stream error: $error', name: _logTag);
    _scheduleReconnect();
  }

  void _handleSocketDone() {
    developer.log('WebSocket ditutup oleh remote host', name: _logTag);
    if (_status == RealtimeConnectionStatus.connected) {
      _scheduleReconnect();
    }
  }

  /// Menjadwalkan rekoneksi dengan backoff eksponensial (Phase 7.2 #1).
  void _scheduleReconnect() {
    if (_isDisposed) return;

    _cleanupSocket();
    _updateStatus(RealtimeConnectionStatus.reconnecting);

    _reconnectTimer?.cancel();
    final delaySeconds = min(30, pow(2, min(_reconnectAttempts, 5)).toInt());
    _reconnectAttempts++;

    developer.log(
      'Menjadwalkan rekoneksi ke-$_reconnectAttempts dalam $delaySeconds detik...',
      name: _logTag,
    );

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed && _subscribedWallet != null) {
        connect(
          walletAddress: _subscribedWallet!,
          btid: _subscribedBtid,
        );
      }
    });

    // Aktifkan polling fallback jika soket terputus
    if (_subscribedWallet != null) {
      startPollingFallback(walletAddress: _subscribedWallet!);
    }
  }

  /// Heartbeat ping berkala setiap 25 detik untuk mendeteksi soket zombie.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_status == RealtimeConnectionStatus.connected && _socket != null) {
        try {
          _socket?.add(jsonEncode({
            'action': 'ping',
            'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          }));
        } on Object catch (e) {
          developer.log('Gagal mengirim heartbeat ping: $e', name: _logTag);
          _scheduleReconnect();
        }
      }
    });
  }

  /// Sinkronisasi pesan yang terlewat via REST API (Phase 7.2 #1 / D-5).
  Future<List<ConsentRequestModel>> syncMissedRequests({
    required String walletAddress,
    DateTime? since,
  }) async {
    final cleanWallet = walletAddress.trim().toLowerCase();
    final queryParams = <String, String>{
      'wallet': cleanWallet,
      if (since != null) 'since': since.toUtc().toIso8601String(),
    };

    final uri = Uri.parse('$_httpBaseUrl/verification/requests').replace(queryParameters: queryParams);

    try {
      final response = await NetworkExceptionAdapter.guard(
        () => _httpClient.get(uri, headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> items = decoded is List
            ? decoded
            : (decoded is Map<String, dynamic> && decoded['requests'] is List
                ? decoded['requests']
                : (decoded['data'] is List ? decoded['data'] : []));

        final List<ConsentRequestModel> newRequests = [];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final req = ConsentRequestModel.fromJson(item);
            if (!req.isExpired && !_processedRequestIds.contains(req.requestId)) {
              _processedRequestIds.add(req.requestId);
              newRequests.add(req);
              _requestStreamController.add(req);
            }
          }
        }
        _lastSyncTimestamp = DateTime.now();
        return newRequests;
      }
    } on Object catch (e) {
      developer.log('Sinkronisasi pesan tertunda gagal: $e', name: _logTag);
      _lastError = 'Sinkronisasi pesan tertunda gagal: $e';
    }
    return [];
  }

  /// Cadangan transport: polling berkala (setiap N detik) jika WebSocket tidak tersedia (D-5).
  void startPollingFallback({
    required String walletAddress,
    Duration interval = const Duration(seconds: 5),
  }) {
    _pollingFallbackTimer?.cancel();
    _pollingFallbackTimer = Timer.periodic(interval, (_) async {
      if (_isDisposed) return;
      await syncMissedRequests(
        walletAddress: walletAddress,
        since: _lastSyncTimestamp,
      );
    });
  }

  /// Menghentikan polling cadangan.
  void stopPollingFallback() {
    _pollingFallbackTimer?.cancel();
    _pollingFallbackTimer = null;
  }

  void _cleanupSocket() {
    _heartbeatTimer?.cancel();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    try {
      _socket?.close();
    } on Object catch (e) {
      developer.log('Pembersihan soket: $e', name: _logTag);
      _lastError = 'Pembersihan soket: $e';
    }
    _socket = null;
  }

  void _updateStatus(RealtimeConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      if (!_statusController.isClosed) {
        _statusController.add(newStatus);
      }
    }
  }

  /// Memutuskan koneksi dan membersihkan seluruh resource transport.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    stopPollingFallback();
    _cleanupSocket();
    _subscribedWallet = null;
    _subscribedBtid = null;
    _updateStatus(RealtimeConnectionStatus.disconnected);
  }

  /// Menutup service permanen.
  void dispose() {
    _isDisposed = true;
    disconnect();
    _statusController.close();
    _requestStreamController.close();
  }
}
