// lib/src/core/providers/realtime_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/services/notifications/push_notification_service.dart';
import 'package:qrypta/src/core/services/realtime/realtime_channel_service.dart';

/// Provider instance tunggal untuk layanan kanal real-time WebSocket/SSE (Phase 7.2).
final realtimeChannelServiceProvider = Provider<RealtimeChannelService>((ref) {
  final service = RealtimeChannelService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider status koneksi real-time untuk komponen UI.
final realtimeConnectionStatusProvider = StreamProvider<RealtimeConnectionStatus>((ref) {
  final service = ref.watch(realtimeChannelServiceProvider);
  return service.statusStream;
});

/// Provider instance tunggal untuk layanan push notification (Phase 7.2).
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService();
  ref.onDispose(() => service.dispose());
  return service;
});
