// lib/src/core/transaction/state_machine/tx_intent_repository.dart

import 'dart:developer' as developer;
import 'package:hive_ce/hive.dart';
import 'tx_intent.dart';
import 'tx_state.dart';

/// Repository untuk persistensi dan retrieval [TxIntent] menggunakan Hive.
class TxIntentRepository {
  static const String boxName = 'tx_intents';
  static const String _logTag = 'TxIntentRepository';

  final Box? _injectedBox;
  final Map<String, TxIntent> _memoryFallback = {};

  TxIntentRepository({Box? box}) : _injectedBox = box;

  Future<Box> _getBox() async {
    if (_injectedBox != null) return _injectedBox!;
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    return await Hive.openBox(boxName);
  }

  /// Menyimpan atau memperbarui intent transaksi ke Hive.
  Future<void> saveIntent(TxIntent intent) async {
    _memoryFallback[intent.intentId] = intent;
    try {
      final box = await _getBox();
      await box.put(intent.intentId, intent.toJson());
    } on Object catch (e) {
      developer.log('Penyimpanan Hive gagal, tersimpan di memori fallback: $e', name: _logTag);
    }
  }

  /// Mengambil intent berdasarkan intentId.
  Future<TxIntent?> getIntent(String intentId) async {
    try {
      final box = await _getBox();
      final data = box.get(intentId);
      if (data is Map) {
        return TxIntent.fromJson(Map<String, dynamic>.from(data));
      }
    } on Object catch (e) {
      developer.log('Pembacaan intent dari Hive gagal: $e', name: _logTag);
    }
    return _memoryFallback[intentId];
  }

  /// Mencari intent berdasarkan referensi bisnis (mis. levyRef atau payRef).
  Future<TxIntent?> findIntentByRef(String ref) async {
    final all = await getAllIntents();
    for (final intent in all) {
      if (intent.ref == ref) {
        return intent;
      }
    }
    return null;
  }

  /// Mengambil semua intent yang memiliki salah satu state target.
  Future<List<TxIntent>> getIntentsByState(List<TxState> states) async {
    final all = await getAllIntents();
    return all.where((intent) => states.contains(intent.state)).toList();
  }

  /// Mengambil transaksi yang belum selesai (broadcasting, pending, timeout) untuk recovery.
  Future<List<TxIntent>> getUnresolvedIntents() async {
    return getIntentsByState([
      TxState.broadcasting,
      TxState.pending,
      TxState.timeout,
    ]);
  }

  /// Mengambil seluruh riwayat intent tersimpan.
  Future<List<TxIntent>> getAllIntents() async {
    final Map<String, TxIntent> results = Map.from(_memoryFallback);
    try {
      final box = await _getBox();
      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final intent = TxIntent.fromJson(Map<String, dynamic>.from(data));
          results[intent.intentId] = intent;
        }
      }
    } on Object catch (e) {
      developer.log('Pengambilan seluruh intent dari Hive gagal: $e', name: _logTag);
    }

    final list = results.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Menghapus intent dari storage.
  Future<void> deleteIntent(String intentId) async {
    _memoryFallback.remove(intentId);
    try {
      final box = await _getBox();
      await box.delete(intentId);
    } on Object catch (e) {
      developer.log('Penghapusan intent dari Hive gagal: $e', name: _logTag);
    }
  }
}
