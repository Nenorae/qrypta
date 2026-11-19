// lib/src/core/data/models/holder_profile.dart

import 'package:qrypta/src/core/data/models/actor_ref.dart';

/// Model profil pemegang identitas Bali Tourist ID (Phase 5B.4).
/// Menyimpan identitas aktif pemegang kartu di penyimpanan aman sebagai
/// sumber otoritatif aktor zero-PII untuk audit transaksi.
class HolderProfile {
  final String name;
  final String walletAddress;
  final String credentialId;
  final String actorRef;
  final String btidNumber;

  const HolderProfile({
    required this.name,
    required this.walletAddress,
    required this.credentialId,
    required this.actorRef,
    required this.btidNumber,
  });

  factory HolderProfile.fromCredential({
    required String fullName,
    required String walletAddress,
    required String btidNumber,
    String? credentialId,
  }) {
    final actor = ActorRef.fromCredential(
      walletAddress: walletAddress,
      btidNumber: btidNumber,
      name: fullName,
    );
    return HolderProfile(
      name: fullName,
      walletAddress: walletAddress,
      credentialId: credentialId ?? btidNumber,
      actorRef: actor.actorRef,
      btidNumber: btidNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'walletAddress': walletAddress,
      'credentialId': credentialId,
      'actorRef': actorRef,
      'btidNumber': btidNumber,
    };
  }

  factory HolderProfile.fromJson(Map<String, dynamic> json) {
    return HolderProfile(
      name: json['name'] as String? ?? '',
      walletAddress: json['walletAddress'] as String? ?? '',
      credentialId: json['credentialId'] as String? ?? '',
      actorRef: json['actorRef'] as String? ?? '',
      btidNumber: json['btidNumber'] as String? ?? '',
    );
  }

  @override
  String toString() =>
      'HolderProfile(name: $name, walletAddress: $walletAddress, btid: $btidNumber, actorRef: $actorRef)';
}
