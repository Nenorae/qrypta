// lib/src/core/data/models/actor_ref.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:web3dart/crypto.dart';

class ActorRef {
  final String walletAddress;
  final String? btidNumber;
  final String? name;
  final String actorRef;

  const ActorRef({
    required this.walletAddress,
    this.btidNumber,
    this.name,
    required this.actorRef,
  });

  factory ActorRef.fromCredential({
    required String walletAddress,
    required String btidNumber,
    String? name,
    String salt = 'QRYPTA_BALI_SALT_2026',
  }) {
    final raw = '$walletAddress:$btidNumber:$salt';
    final hashBytes = keccak256(Uint8List.fromList(utf8.encode(raw)));
    final hashHex = '0x${bytesToHex(hashBytes).substring(0, 16)}';
    return ActorRef(
      walletAddress: walletAddress,
      btidNumber: btidNumber,
      name: name,
      actorRef: hashHex,
    );
  }

  factory ActorRef.fromWallet({
    required String walletAddress,
    String? name,
    String salt = 'QRYPTA_BALI_SALT_2026',
  }) {
    final raw = '$walletAddress:$salt';
    final hashBytes = keccak256(Uint8List.fromList(utf8.encode(raw)));
    final hashHex = '0x${bytesToHex(hashBytes).substring(0, 16)}';
    return ActorRef(
      walletAddress: walletAddress,
      name: name,
      actorRef: hashHex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletAddress': walletAddress,
      'btidNumber': btidNumber,
      'name': name,
      'actorRef': actorRef,
    };
  }

  factory ActorRef.fromJson(Map<String, dynamic> json) {
    return ActorRef(
      walletAddress: json['walletAddress'] as String? ?? '',
      btidNumber: json['btidNumber'] as String?,
      name: json['name'] as String?,
      actorRef: json['actorRef'] as String? ?? '',
    );
  }

  @override
  String toString() => 'ActorRef(wallet: $walletAddress, btid: $btidNumber, ref: $actorRef)';
}
