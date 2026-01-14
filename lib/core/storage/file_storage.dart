// lib/core/storage/file_storage.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:abus/core/abus_storage.dart';
import 'package:path/path.dart' as p;

/// File-based implementation of [AbusStorage] using [Directory].
class FileStorage extends AbusStorage {
  final Directory directory;
  final Map<String, StreamController<Map<String, dynamic>?>> _controllers = {};
  final StreamController<String> _allController =
      StreamController<String>.broadcast();

  FileStorage(this.directory) {
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
  }

  File _getFile(String key) => File(p.join(directory.path, '$key.json'));

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    final file = _getFile(key);
    await file.writeAsString(jsonEncode(data));
    _getController(key).add(data);
    _allController.add(key);
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    final file = _getFile(key);
    if (!file.existsSync()) return null;
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    final file = _getFile(key);
    if (file.existsSync()) {
      await file.delete();
    }
    _getController(key).add(null);
    _allController.add(key);
  }

  @override
  Future<List<String>> listKeys() async {
    if (!directory.existsSync()) return [];
    return directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList();
  }

  @override
  Future<void> clear() async {
    if (directory.existsSync()) {
      final keys = await listKeys();
      directory.deleteSync(recursive: true);
      directory.createSync(recursive: true);
      for (final key in keys) {
        _getController(key).add(null);
        _allController.add(key);
      }
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

  /// Notify listeners that data has changed for a key.
  void notifyListeners(String key, Map<String, dynamic>? data) {
    _getController(key).add(data);
    if (data != null) {
      _allController.add(key);
    }
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
