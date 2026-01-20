// test/unit/storage_test.dart
import 'dart:io';
import 'package:abus/abus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('InMemoryStorage', () {
    late InMemoryStorage storage;

    setUp(() {
      storage = InMemoryStorage();
    });

    test('save and load', () async {
      final data = {'foo': 'bar'};
      await storage.save('key1', data);
      final loaded = await storage.load('key1');
      expect(loaded, data);
    });

    test('delete', () async {
      await storage.save('key1', {'a': 1});
      await storage.delete('key1');
      final loaded = await storage.load('key1');
      expect(loaded, isNull);
    });

    test('watch', () async {
      final stream = storage.watch('key1');
      final expectation = expectLater(
        stream,
        emitsInOrder([
          {'a': 1},
          {'a': 2},
          isNull,
        ]),
      );

      await storage.save('key1', {'a': 1});
      await storage.save('key1', {'a': 2});
      await storage.delete('key1');

      await expectation;
    });
  });

  group('FileStorage', () {
    late Directory tempDir;
    late FileStorage storage;

    setUp(() {
      tempDir = Directory(p.join(Directory.systemTemp.path,
          'abus_test_storage_${DateTime.now().millisecondsSinceEpoch}'));
      storage = FileStorage(tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('persistence', () async {
      final data = {'hello': 'world'};
      await storage.save('p1', data);

      // Load from new instance
      final storage2 = FileStorage(tempDir);
      final loaded = await storage2.load('p1');
      expect(loaded, data);
    });

    test('listKeys', () async {
      await storage.save('k1', {'v': 1});
      await storage.save('k2', {'v': 2});
      final keys = await storage.listKeys();
      expect(keys, containsAll(['k1', 'k2']));
    });
  });
}
