// lib/core/storage/in_memory_storage.dart

import 'dart:async';
import 'package:abus/core/abus_storage.dart';

/// Default in-memory implementation of [AbusStorage].
class InMemoryStorage extends AbusStorage {
  final Map<String, Map<String, dynamic>> _data = {};
  final Map<String, StreamController<Map<String, dynamic>?>> _controllers = {};
  final StreamController<String> _allController =
      StreamController<String>.broadcast();

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    _data[key] = Map<String, dynamic>.from(data);
    _getController(key).add(_data[key]);
    _allController.add(key);
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    return _data[key];
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
    _getController(key).add(null);
    _allController.add(key);
  }

  @override
  Future<List<String>> listKeys() async {
    return _data.keys.toList();
  }

  @override
  Future<void> clear() async {
    final keys = _data.keys.toList();
    _data.clear();
    for (final key in keys) {
      _getController(key).add(null);
      _allController.add(key);
    }
  }

  @override
  Stream<Map<String, dynamic>?> watch(String key) {
    return _getController(key).stream;
  }

  @override
  Stream<String> watchAll() {
    return _allController.stream;
  }

  StreamController<Map<String, dynamic>?> _getController(String key) {
    return _controllers.putIfAbsent(
        key, () => StreamController<Map<String, dynamic>?>.broadcast());
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _allController.close();
  }
}
