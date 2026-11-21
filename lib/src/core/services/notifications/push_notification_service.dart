// lib/src/core/services/notifications/push_notification_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:qrypta/src/core/config/app_config.dart';
import 'package:qrypta/src/core/data/models/consent_request_model.dart';
import 'package:qrypta/src/core/error/network_exception_adapter.dart';

/// Status ketersediaan integrasi Push Notification (FCM / Background Push) (Phase 7.2 #2).
enum PushNotificationStatus {
  uninitialized,
  registered,
  unavailable,
  error,
}

/// Layanan Push Notification untuk membangkitkan Tourist App saat background/terminated (Phase 7.2 #2).
///
/// Memfasilitasi pendaftaran token FCM perangkat ke ezsign-core server dan menangani
/// payload data notifikasi yang membuka layar consent secara langsung.
class PushNotificationService {
  static const String _logTag = 'PushNotificationService';

  final http.Client _httpClient;
  final String _baseUrl;

  PushNotificationStatus _status = PushNotificationStatus.uninitialized;
  String? _registeredToken;

  final StreamController<ConsentRequestModel> _pushRequestController =
      StreamController<ConsentRequestModel>.broadcast();

  PushNotificationService({
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.ezsignUrl;

  PushNotificationStatus get status => _status;
  String? get registeredToken => _registeredToken;
  Stream<ConsentRequestModel> get pushRequestStream => _pushRequestController.stream;

  /// Mendaftarkan token perangkat (FCM/APNS) ke server middleware.
  Future<bool> registerDeviceToken({
    required String walletAddress,
    required String btid,
    required String deviceToken,
    String platform = 'android',
  }) async {
    final cleanToken = deviceToken.trim();
    if (cleanToken.isEmpty) {
      _status = PushNotificationStatus.unavailable;
      return false;
    }

    final endpoint = Uri.parse('$_baseUrl/notifications/register-token');
    final payload = {
      'wallet': walletAddress.trim().toLowerCase(),
      'btid': btid,
      'deviceToken': cleanToken,
      'platform': platform,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    try {
      final response = await NetworkExceptionAdapter.guard(
        () => _httpClient.post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        ),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _status = PushNotificationStatus.registered;
        _registeredToken = cleanToken;
        developer.log('Device token FCM berhasil didaftarkan ke server.', name: _logTag);
        return true;
      } else {
        _status = PushNotificationStatus.error;
        developer.log('Gagal mendaftarkan device token: ${response.statusCode}', name: _logTag);
        return false;
      }
    } on Object catch (e) {
      _status = PushNotificationStatus.error;
      developer.log('Pendaftaran device token mengalami kendala jaringan: $e', name: _logTag);
      return false;
    }
  }

  /// Menangani payload data notifikasi push masuk (onMessage / onBackgroundMessage).
  void handleIncomingPushPayload(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString() ?? data['action']?.toString();
      if (type == 'consent_request' || data.containsKey('requestId') || data.containsKey('sessionId')) {
        final request = ConsentRequestModel.fromJson(data);
        if (!request.isExpired) {
          developer.log(
            'Push notification consent request diterima: ${request.requestId} dari ${request.merchantName}',
            name: _logTag,
          );
          _pushRequestController.add(request);
        }
      }
    } on Object catch (e) {
      developer.log('Gagal memproses payload push notification: $e', name: _logTag);
      _status = PushNotificationStatus.error;
    }
  }

  void dispose() {
    _pushRequestController.close();
  }
}
