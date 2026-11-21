// lib/src/core/outbox/outbox_repository.dart

import 'dart:developer' as developer;
import 'package:hive_ce/hive.dart';
import 'outbox_item.dart';

/// Repository untuk penyimpanan dan antrean item Outbox menggunakan Hive (Phase 2.3).
class OutboxRepository {
  static const String boxName = 'outbox_box';
  static const String _logTag = 'OutboxRepository';

  final Box? _injectedBox;
  final Map<String, OutboxItem> _memoryFallback = {};
  String? _lastStorageError;

  String? get lastStorageError => _lastStorageError;

  OutboxRepository({Box? box}) : _injectedBox = box;

  Future<Box> _getBox() async {
    if (_injectedBox != null) return _injectedBox!;
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    return await Hive.openBox(boxName);
  }

  /// Memasukkan item baru ke antrean outbox.
  Future<void> enqueue(OutboxItem item) async {
    _memoryFallback[item.id] = item;
    try {
      final box = await _getBox();
      await box.put(item.id, item.toJson());
    } on Object catch (e) {
      developer.log('Penyimpanan item outbox gagal, tersimpan di memori fallback: $e', name: _logTag);
      _lastStorageError = e.toString();
    }
  }

  /// Memperbarui state item outbox (attempts, status, nextAttemptAt).
  Future<void> update(OutboxItem item) async {
    _memoryFallback[item.id] = item;
    try {
      final box = await _getBox();
      await box.put(item.id, item.toJson());
    } on Object catch (e) {
      developer.log('Pembaruan item outbox gagal: $e', name: _logTag);
      _lastStorageError = e.toString();
    }
  }

  /// Mengambil semua item pending yang sudah jatuh tempo untuk dikirim ulang.
  Future<List<OutboxItem>> getPendingDueItems({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final all = await getAllItems();
    return all.where((item) {
      return item.status == OutboxStatus.pending &&
          !item.nextAttemptAt.isAfter(effectiveNow);
    }).toList();
  }

  /// Mengambil seluruh item di outbox.
  Future<List<OutboxItem>> getAllItems() async {
    final Map<String, OutboxItem> results = Map.from(_memoryFallback);
    try {
      final box = await _getBox();
      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final item = OutboxItem.fromJson(Map<String, dynamic>.from(data));
          results[item.id] = item;
        }
      }
    } on Object catch (e) {
      developer.log('Pengambilan seluruh outbox dari Hive gagal: $e', name: _logTag);
      _lastStorageError = e.toString();
    }

    final list = results.values.toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Mengambil satu item outbox berdasarkan ID.
  Future<OutboxItem?> getItemById(String id) async {
    try {
      final box = await _getBox();
      final data = box.get(id);
      if (data is Map) {
        return OutboxItem.fromJson(Map<String, dynamic>.from(data));
      }
    } on Object catch (e) {
      developer.log('Pengambilan item outbox gagal: $e', name: _logTag);
      _lastStorageError = e.toString();
    }
    return _memoryFallback[id];
  }

  /// Menghapus item dari antrean outbox.
  Future<void> deleteItem(String id) async {
    _memoryFallback.remove(id);
    try {
      final box = await _getBox();
      await box.delete(id);
    } on Object catch (e) {
      developer.log('Penghapusan item outbox gagal: $e', name: _logTag);
      _lastStorageError = e.toString();
    }
  }
}
