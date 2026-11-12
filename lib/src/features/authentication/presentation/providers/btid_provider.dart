// lib/src/features/authentication/presentation/providers/btid_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:qrypta/src/core/data/models/btid_credential_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _btidBoxName = 'btid_credential_box';
const String _btidStorageKey = 'active_btid_credential';

final btidCredentialProvider =
    StateNotifierProvider<BtidCredentialNotifier, BtidCredentialModel?>((ref) {
  return BtidCredentialNotifier();
});

class BtidCredentialNotifier extends StateNotifier<BtidCredentialModel?> {
  BtidCredentialNotifier() : super(null) {
    loadCredential();
  }

  Future<void> loadCredential() async {
    try {
      // 1. Coba baca dari Hive
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
    } catch (_) {
      // Fallback ke SharedPreferences jika Hive belum siap di test environment
      try {
        final prefs = await SharedPreferences.getInstance();
        final rawString = prefs.getString(_btidStorageKey);
        if (rawString != null) {
          state = BtidCredentialModel.fromJson(jsonDecode(rawString));
          return;
        }
      } catch (_) {}
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
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_btidStorageKey, jsonEncode(credential.toJson()));
      } catch (_) {}
    }
  }

  Future<void> updateLevyStatus(String status, {String? receiptRef}) async {
    if (state == null) return;
    final updated = state!.copyWith(
      levyStatus: status,
      levyReceiptRef: receiptRef ?? state!.levyReceiptRef,
    );
    await saveCredential(updated);
  }

  Future<void> clearCredential() async {
    state = null;
    try {
      if (Hive.isBoxOpen(_btidBoxName)) {
        await Hive.box(_btidBoxName).delete(_btidStorageKey);
      }
    } catch (_) {}
  }
}
