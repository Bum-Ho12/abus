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
    Directory directory, {
    this.syncInterval = const Duration(seconds: 10),
  }) : super(directory) {
    _startAutoSync();
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(syncInterval, (_) => sync());
  }

  @override
  Future<void> sync() async {
    if (!directory.existsSync()) return;

    final files = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));

    for (final file in files) {
      final key = p.basenameWithoutExtension(file.path);
      try {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        // Notify listeners if the file changed externally
        // Note: Simple implementation, doesn't track CRC yet
        notifyListeners(key, data);
      } catch (e) {
        // Ignore malformed files
      }
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
