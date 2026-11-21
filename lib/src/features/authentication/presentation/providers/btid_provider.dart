// lib/src/features/authentication/presentation/providers/btid_provider.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:qrypta/src/core/data/models/actor_ref.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:qrypta/src/core/data/models/holder_profile.dart';
import 'package:qrypta/src/core/services/identity/btid_issuance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _btidBoxName = 'btid_credential_box';
const String _btidStorageKey = 'active_btid_credential';

final btidCredentialProvider =
    StateNotifierProvider<BtidCredentialNotifier, BtidCredentialModel?>((ref) {
  return BtidCredentialNotifier();
});

final btidIssuanceServiceProvider = Provider<BtidIssuanceService>((ref) {
  return BtidIssuanceService();
});

/// Provider referensi aktor zero-PII untuk audit (Phase 4.4).
final actorRefProvider = Provider<ActorRef?>((ref) {
  final cred = ref.watch(btidCredentialProvider);
  if (cred == null || cred.walletAddress.isEmpty || cred.btidNumber.isEmpty) return null;
  return ActorRef.fromCredential(
    walletAddress: cred.walletAddress,
    btidNumber: cred.btidNumber,
    name: cred.fullName,
  );
});

/// Provider profil pemegang identitas resmi (Phase 5B.4).
final holderProfileProvider = Provider<HolderProfile?>((ref) {
  final cred = ref.watch(btidCredentialProvider);
  if (cred == null || cred.walletAddress.isEmpty || cred.btidNumber.isEmpty) return null;
  return HolderProfile.fromCredential(
    fullName: cred.fullName,
    walletAddress: cred.walletAddress,
    btidNumber: cred.btidNumber,
  );
});

class BtidCredentialNotifier extends StateNotifier<BtidCredentialModel?> {
  String? _lastStorageError;

  BtidCredentialNotifier() : super(null) {
    loadCredential();
  }

  Future<void> loadCredential() async {
    try {
      if (Hive.isBoxOpen(_btidBoxName)) {
        final box = Hive.box(_btidBoxName);
        final raw = box.get(_btidStorageKey);
        if (raw != null) {
          state = BtidCredentialModel.fromJson(Map<String, dynamic>.from(raw));
          return;
        }
      } else {
        final box = await Hive.openBox(_btidBoxName);
        final raw = box.get(_btidStorageKey);
        if (raw != null) {
          state = BtidCredentialModel.fromJson(Map<String, dynamic>.from(raw));
          return;
        }
      }
    } on Object catch (e) {
      developer.log('Hive loadCredential failed, trying SharedPreferences: $e', name: 'BtidProvider');
      try {
        final prefs = await SharedPreferences.getInstance();
        final rawString = prefs.getString(_btidStorageKey);
        if (rawString != null) {
          state = BtidCredentialModel.fromJson(jsonDecode(rawString));
          return;
        }
      } on Object catch (e2) {
        developer.log('SharedPreferences loadCredential failed: $e2', name: 'BtidProvider');
        _lastStorageError = e2.toString();
      }
    }
  }

  Future<void> saveCredential(BtidCredentialModel credential) async {
    state = credential;
    try {
      Box box;
      if (Hive.isBoxOpen(_btidBoxName)) {
        box = Hive.box(_btidBoxName);
      } else {
        box = await Hive.openBox(_btidBoxName);
      }
      await box.put(_btidStorageKey, credential.toJson());
    } on Object catch (e) {
      developer.log('Hive saveCredential failed, trying SharedPreferences: $e', name: 'BtidProvider');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_btidStorageKey, jsonEncode(credential.toJson()));
      } on Object catch (e2) {
        developer.log('SharedPreferences saveCredential failed: $e2', name: 'BtidProvider');
        _lastStorageError = e2.toString();
      }
    }
  }

  Future<void> updateLevyStatus(
    String status, {
    String? receiptRef,
    String? txHash,
  }) async {
    if (state == null) return;
    final updated = state!.copyWith(
      levyStatus: status,
      levyReceiptRef: receiptRef ?? state!.levyReceiptRef,
      levyTxHash: txHash ?? state!.levyTxHash,
    );
    await saveCredential(updated);
  }

  Future<void> clearCredential() async {
    state = null;
    try {
      if (Hive.isBoxOpen(_btidBoxName)) {
        await Hive.box(_btidBoxName).delete(_btidStorageKey);
      }
    } on Object catch (e) {
      developer.log('Hive clearCredential failed: $e', name: 'BtidProvider');
      _lastStorageError = e.toString();
    }
  }
}
