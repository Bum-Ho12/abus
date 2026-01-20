// lib/core/storage/android_shared_storage.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:abus/core/storage/file_storage.dart';
import 'package:path/path.dart' as p;

/// Android-specific implementation of [AbusStorage] for cross-app communication.
///
/// This storage uses a shared directory on the Android file system.
/// Applications sharing the same Storage permissions or signed by the same
/// developer can use this to exchange data even when one app is inactive.
class AndroidSharedStorage extends FileStorage {
  final Duration syncInterval;
  Timer? _syncTimer;

  AndroidSharedStorage(
    super.directory, {
    this.syncInterval = const Duration(seconds: 10),
  }) {
    _startAutoSync();
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(syncInterval, (_) => sync());
  }

  // Cache of last known content hash/string to avoid redundant updates
  final Map<String, int> _lastContentHashes = {};

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    final file = File(p.join(directory.path, '$key.json'));
    final content = jsonEncode(data);

    // Update local cache immediately to prevent self-notification
    _lastContentHashes[key] = content.hashCode;

    // Use random access file for locking
    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.write);
      await raf.lock(FileLock.exclusive);
      await raf.truncate(0);
      await raf.writeString(content);
      // Notify internal listeners (FileStorage implementation)
      super.notifyListeners(key, data);
    } finally {
      await raf?.unlock();
      await raf?.close();
    }
  }

  @override
  Future<void> sync() async {
    if (!directory.existsSync()) return;

    final files = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));

    final currentKeys = <String>{};

    for (final file in files) {
      final key = p.basenameWithoutExtension(file.path);
      currentKeys.add(key);

      try {
        // Read file content
        final content = await file.readAsString();
        final contentHash = content.hashCode;

        // Skip if content hasn't changed
        if (_lastContentHashes[key] == contentHash) {
          continue;
        }

        // Update cache and parse
        _lastContentHashes[key] = contentHash;
        final data = jsonDecode(content) as Map<String, dynamic>;

        // Notify with new data
        notifyListeners(key, data);
      } catch (e) {
        // Ignore malformed files or read errors
      }
    }

    // Clean up cache for deleted files
    _lastContentHashes.removeWhere((key, _) => !currentKeys.contains(key));
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
