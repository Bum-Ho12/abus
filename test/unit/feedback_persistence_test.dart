// test/unit/feedback_persistence_test.dart
import 'package:abus/abus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackManager Persistence', () {
    late InMemoryStorage storage;

    setUp(() async {
      storage = InMemoryStorage();
      ABUS.manager.setStorage(storage);
      await FeedbackBus.initialize();
      FeedbackManager.instance.clearQueue();
    });

    test('feedback persists to storage', () async {
      await FeedbackBus.showSnackbar(message: 'Persisted snackbar');

      // Check storage directly
      final data = await storage.load('abus_feedback_queue');
      expect(data, isNotNull);
      final queue = data!['queue'] as List;
      expect(queue.any((e) => e['message'] == 'Persisted snackbar'), isTrue);
    });

    test('feedback loads from storage on init', () async {
      // Mock existing data in storage
      await storage.save('abus_feedback_queue', {
        'queue': [
          {
            'type': 'SnackbarEvent',
            'id': 's1',
            'message': 'Stored snackbar',
            'snackbarType': 'info',
            'priority': 0,
            'tags': [],
            'metadata': {},
            'dismissible': true,
          }
        ],
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Re-initialize (simulating app restart)
      await FeedbackManager.instance.initStorage();

      expect(
          FeedbackBus.queue.any((e) => e.message == 'Stored snackbar'), isTrue);
    });

    test('cross-app synchronization', () async {
      // Instance 1 shows a snackbar
      await FeedbackBus.showSnackbar(message: 'App 1 Message');

      // Simulate external change in storage (another app)
      await storage.save('abus_feedback_queue', {
        'queue': [
          {
            'type': 'SnackbarEvent',
            'id': 's2',
            'message': 'App 2 Message',
            'snackbarType': 'warning',
            'priority': 1,
            'tags': [],
            'metadata': {},
            'dismissible': true,
          }
        ],
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Wait for stream to emit
      await Future.delayed(const Duration(milliseconds: 100));

      expect(
          FeedbackBus.queue.any((e) => e.message == 'App 2 Message'), isTrue);
    });
  });
}
