import 'dart:convert';
import 'dart:io';

import 'package:abus/abus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AndroidSharedStorage Optimization', () {
    late Directory tempDir;
    late AndroidSharedStorage storage;

    setUp(() {
      tempDir = Directory(p.join(Directory.systemTemp.path,
          'abus_test_opt_${DateTime.now().millisecondsSinceEpoch}'));
      if (!tempDir.existsSync()) {
        tempDir.createSync(recursive: true);
      }
      // Disable auto-sync for precise testing
      storage = AndroidSharedStorage(tempDir, syncInterval: const Duration(hours: 1));
    });

    tearDown(() {
      storage.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('sync should only notify on actual changes', () async {
      final key = 'test_key';
      final file = File(p.join(tempDir.path, '$key.json'));
      final data1 = {'value': 1};
      final data2 = {'value': 2};

      // 1. Initial Create
      await file.writeAsString(jsonEncode(data1));

      // Capture events
      final events = <Map<String, dynamic>?>[];
      final sub = storage.watch(key).listen(events.add);

      // First sync - should detect file
      await storage.sync();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(events.length, 1);
      expect(events.last, data1);

      // Second sync - currently no change in file, should NOT notify
      await storage.sync();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(events.length, 1,
          reason: 'Should not emit event if content is identical');

      // 2. Modify File
      await file.writeAsString(jsonEncode(data2));

      // Third sync - content changed, SHOULD notify
      await storage.sync();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(events.length, 2);
      expect(events.last, data2);

      await sub.cancel();
    });

    test('save should update local cache to prevent self-notification',
        () async {
      final key = 'self_save';
      final data = {'foo': 'bar'};

      // Capture events
      final events = <Map<String, dynamic>?>[];
      final sub = storage.watch(key).listen(events.add);

      // Save via storage API
      await storage.save(key, data);
      await Future.delayed(const Duration(milliseconds: 50));

      // Should have emitted one event from the save itself (inherited from FileStorage)
      expect(events.length, 1);
      expect(events.last, data);

      // Sync - should NOT emit again because we just saved it and updated cache
      await storage.sync();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(events.length, 1,
          reason: 'Save should update cache to avoid re-reading own write');

      await sub.cancel();
    });

    test('locking should work (basic sanity check)', () async {
      // access to file lock API doesn't crash
      final key = 'lock_test';
      final data = {'a': 1};
      await storage.save(key, data);

      final loaded = await storage.load(key);
      expect(loaded, data);
    });
  });
}
