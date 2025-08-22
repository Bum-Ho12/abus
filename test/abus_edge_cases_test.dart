// test/abus_edge_cases_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abus/abus.dart';
import 'dart:async';

void main() {
  group('ABUS Edge Cases and Performance Tests', () {
    setUp(() {
      ABUSManager.reset();
    });

    tearDown(() {
      ABUSManager.instance.dispose();
    });

    group('Edge Cases', () {
      test('should handle null and empty payloads gracefully', () {
        // Null payload
        final nullInteraction =
            InteractionBuilder().withId('null_test').withPayload(null).build();

        expect(nullInteraction.payload, isNull);
        expect(nullInteraction.validate(), isTrue);

        // Empty map payload
        final emptyMapInteraction = InteractionBuilder()
            .withId('empty_map_test')
            .withPayload(<String, dynamic>{}).build();

        expect(
            emptyMapInteraction.getPayload<Map<String, dynamic>>(), isNotNull);
        expect(emptyMapInteraction.getPayload<Map<String, dynamic>>()!.isEmpty,
            isTrue);

        // Empty string payload
        final emptyStringInteraction = InteractionBuilder()
            .withId('empty_string_test')
            .withPayload('')
            .build();

        expect(emptyStringInteraction.getPayload<String>(), equals(''));
      });

      test('should handle very large payloads', () {
        final largeMap = <String, dynamic>{};
        for (int i = 0; i < 10000; i++) {
          largeMap['key_$i'] =
              'value_$i with some additional text to make it larger';
        }

        final interaction = InteractionBuilder()
            .withId('large_payload_test')
            .withPayload(largeMap)
            .build();

        expect(interaction.validate(), isTrue);
        final retrievedPayload = interaction.getPayload<Map<String, dynamic>>();
        expect(retrievedPayload, isNotNull);
        expect(retrievedPayload!.length, equals(10000));
        expect(retrievedPayload['key_9999'], contains('value_9999'));

        // Test JSON serialization with large payload
        final json = interaction.toJson();
        expect(json, isNotNull);

        final restored = GenericInteraction.fromJson(json);
        final restoredPayload = restored.payload as Map<String, dynamic>;
        expect(restoredPayload.length, equals(10000));
      });

      test('should handle deeply nested objects', () {
        final deeplyNested = _createDeeplyNestedObject(10);

        final interaction = InteractionBuilder()
            .withId('deep_nested_test')
            .withPayload(deeplyNested)
            .build();

        expect(interaction.validate(), isTrue);
        final retrieved = interaction.getPayload<Map<String, dynamic>>();
        expect(_getNestedValue(retrieved!, 10), equals('deep_value'));
      });

      test('should handle circular references gracefully', () {
        final objectA = <String, dynamic>{'name': 'A'};
        final objectB = <String, dynamic>{'name': 'B', 'ref': objectA};
        objectA['ref'] = objectB; // Create circular reference

        // Should not throw, but might serialize differently
        expect(() {
          final interaction = InteractionBuilder()
              .withId('circular_test')
              .withPayload(objectA)
              .build();

          // Basic operations should work
          expect(interaction.validate(), isTrue);
          final payload = interaction.getPayload<Map<String, dynamic>>();
          expect(payload?['name'], equals('A'));
        }, returnsNormally);
      });

      test('should handle concurrent manager operations', () async {
        final manager = ABUSManager.instance;

        // Register handler that simulates some work
        manager.registerApiHandler((interaction) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return ABUSResult.success(
            data: {'handled': interaction.id},
            interactionId: interaction.id,
          );
        });

        // Execute many interactions concurrently
        final futures = <Future<ABUSResult>>[];
        for (int i = 0; i < 50; i++) {
          final interaction = InteractionBuilder()
              .withId('concurrent_$i')
              .withPayload({'index': i}).build();

          futures.add(manager.execute(interaction));
        }

        final concurrentResults = await Future.wait(futures);

        expect(concurrentResults.length, equals(50));
        expect(concurrentResults.every((r) => r.isSuccess), isTrue);

        // Check all results are unique
        final ids = concurrentResults.map((r) => r.interactionId).toSet();
        expect(ids.length, equals(50));
      });

      test('should handle manager disposal gracefully', () async {
        final manager = ABUSManager.instance;

        manager.registerApiHandler((interaction) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return ABUSResult.success(
            data: {'disposed': false},
            interactionId: interaction.id,
          );
        });

        final interaction = InteractionBuilder()
            .withId('disposal_test')
            .withPayload({'test': 'disposal'}).build();

        // Start execution
        final future = manager.execute(interaction);

        // Dispose manager while execution is in progress
        manager.dispose();

        final result = await future;

        // Should complete with error since manager was disposed
        expect(result.isSuccess, isFalse);
        expect(result.error, contains('disposed'));
      });

      test('should handle malformed JSON gracefully', () {
        final validJson = {
          'id': 'test_interaction',
          'payload': {
            'type': 'Map<String, dynamic>',
            'isClass': false,
            'data': {'key': 'value'},
            'validationErrors': []
          },
          'data': {'key': 'value'},
          'timeout': null,
          'supportsOptimistic': true,
          'priority': 0,
          'tags': [],
        };

        // Should work fine
        expect(() => GenericInteraction.fromJson(validJson), returnsNormally);

        // Missing required fields
        final incompleteJson = <String, dynamic>{'id': 'test'};
        expect(
            () => GenericInteraction.fromJson(incompleteJson), returnsNormally);

        // Invalid field types (should handle gracefully)
        final invalidJson = <String, dynamic>{
          'id': 123, // Should be string
          'payload': 'not_a_map',
          'tags': 'not_a_list',
        };
        expect(
            () => GenericInteraction.fromJson(invalidJson), throwsA(anything));
      });
    });

    group('Performance Tests', () {
      test('should handle rapid sequential executions efficiently', () async {
        final manager = ABUSManager.instance;
        final stopwatch = Stopwatch()..start();

        manager.registerApiHandler((interaction) async {
          return ABUSResult.success(
            data: {'timestamp': DateTime.now().millisecondsSinceEpoch},
            interactionId: interaction.id,
          );
        });

        // Execute 1000 interactions sequentially
        for (int i = 0; i < 1000; i++) {
          final interaction = InteractionBuilder()
              .withId('perf_$i')
              .withPayload({'index': i}).build();

          await manager.execute(interaction);
        }

        stopwatch.stop();
        debugPrint(
            '1000 sequential executions took: ${stopwatch.elapsedMilliseconds}ms');

        // Should complete within reasonable time (adjust threshold as needed)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds max
      });

      test('should manage memory efficiently with many handlers', () {
        final manager = ABUSManager.instance;
        final initialHandlerCount = manager.handlerCount;

        // Register many handlers
        for (int i = 0; i < 100; i++) {
          final handler = TestPerformanceHandler('handler_$i');
          manager.registerHandler(handler);
        }

        expect(manager.handlerCount, equals(initialHandlerCount + 100));

        // Handlers with same ID should be replaced, not duplicated
        for (int i = 0; i < 50; i++) {
          final handler = TestPerformanceHandler('handler_$i'); // Same IDs
          manager.registerHandler(handler);
        }

        expect(manager.handlerCount,
            equals(initialHandlerCount + 100)); // Still 100
      });

      test('should limit snapshots to prevent memory leaks', () async {
        final manager = ABUSManager.instance;
        final handler = TestPerformanceHandler('memory_test');
        manager.registerHandler(handler);

        // Execute more interactions than the snapshot limit (100)
        for (int i = 0; i < 150; i++) {
          final interaction = InteractionBuilder()
              .withId('memory_test_$i')
              .withPayload({'index': i})
              .withOptimistic(true)
              .build();

          await manager.execute(interaction,
              optimistic: true, autoRollback: false);
        }

        // Should have cleaned up old snapshots
        expect(manager.pendingCount, lessThanOrEqualTo(100));

        // Cleanup remaining snapshots
        manager.clearPending();
        expect(manager.pendingCount, equals(0));
      });

      test('should handle stream subscriptions efficiently', () async {
        final manager = ABUSManager.instance;
        final receivedResults = <ABUSResult>[];

        // Create multiple stream subscriptions
        final subscriptions = <StreamSubscription>[];
        for (int i = 0; i < 10; i++) {
          final subscription = manager.resultStream.listen((result) {
            receivedResults.add(result);
          });
          subscriptions.add(subscription);
        }

        manager.registerApiHandler((interaction) async {
          return ABUSResult.success(
            data: {'stream_test': true},
            interactionId: interaction.id,
          );
        });

        final interaction = InteractionBuilder()
            .withId('stream_perf_test')
            .withPayload({'test': 'streams'}).build();

        await manager.execute(interaction);

        // Each subscription should receive the result
        expect(receivedResults.length, equals(10));

        // Cancel all subscriptions
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }

        // Execute another interaction - should not add more results
        await manager.execute(InteractionBuilder()
            .withId('stream_after_cancel')
            .withPayload({'test': 'after_cancel'}).build());

        expect(receivedResults.length, equals(10)); // Still 10
      });

      test('should validate interactions efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Create and validate many interactions
        for (int i = 0; i < 10000; i++) {
          final interaction = InteractionBuilder()
              .withId('validation_$i')
              .withPayload({'index': i, 'data': 'test_data_$i'})
              .addTag('performance')
              .build();

          expect(interaction.validate(), isTrue);
          expect(interaction.getValidationErrors(), isEmpty);
        }

        stopwatch.stop();
        debugPrint(
            '10000 validations took: ${stopwatch.elapsedMilliseconds}ms');

        // Should be very fast
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // 1 second max
      });
    });

    group('Error Recovery Tests', () {
      test('should recover from handler exceptions gracefully', () async {
        final manager = ABUSManager.instance;
        final faultyHandler = FaultyTestHandler();
        manager.registerHandler(faultyHandler);

        final interaction = InteractionBuilder()
            .withId('faulty_test')
            .withPayload({'test': 'exception'}).build();

        // Should not throw, but continue execution
        final result = await manager.execute(interaction);

        // Should still succeed with API handler
        expect(result.isSuccess, isTrue);
        expect(faultyHandler.exceptionThrown, isTrue);
      });

      test('should handle timeout recovery', () async {
        final manager = ABUSManager.instance;

        manager.registerApiHandler((interaction) async {
          if (interaction.id.contains('timeout')) {
            await Future.delayed(const Duration(seconds: 2));
          }
          return ABUSResult.success(
            data: {'handled': true},
            interactionId: interaction.id,
          );
        });

        final timeoutInteraction = InteractionBuilder()
            .withId('timeout_test')
            .withPayload({'test': 'timeout'})
            .withTimeout(const Duration(milliseconds: 100))
            .build();

        final result = await manager.execute(timeoutInteraction);

        expect(result.isSuccess, isFalse);
        expect(result.error, equals('Timeout'));

        // Should be able to execute other interactions normally
        final normalInteraction = InteractionBuilder()
            .withId('normal_test')
            .withPayload({'test': 'normal'}).build();

        final normalResult = await manager.execute(normalInteraction);
        expect(normalResult.isSuccess, isTrue);
      });

      test('should handle rollback failures gracefully', () async {
        final manager = ABUSManager.instance;
        final faultyRollbackHandler = FaultyRollbackHandler();
        manager.registerHandler(faultyRollbackHandler);

        // Register API handler that fails
        manager.registerApiHandler((interaction) async {
          return ABUSResult.error('API failed', interactionId: interaction.id);
        });

        final interaction = InteractionBuilder()
            .withId('faulty_rollback_test')
            .withPayload({'test': 'rollback_failure'}).build();

        final result = await manager.execute(interaction, optimistic: true);

        expect(result.isSuccess, isFalse);
        expect(result.error, equals('API failed'));
        expect(faultyRollbackHandler.optimisticCalled, isTrue);
        expect(faultyRollbackHandler.rollbackFailed, isTrue);
      });
    });
  });
}

// Helper methods for deep nesting tests
Map<String, dynamic> _createDeeplyNestedObject(int depth) {
  if (depth <= 0) {
    return {'value': 'deep_value'};
  }
  return {'level_$depth': _createDeeplyNestedObject(depth - 1)};
}

dynamic _getNestedValue(Map<String, dynamic> obj, int depth) {
  if (depth <= 0) {
    return obj['value'];
  }
  final nested = obj['level_$depth'] as Map<String, dynamic>?;
  return nested != null ? _getNestedValue(nested, depth - 1) : null;
}

// Test handler classes
class TestPerformanceHandler extends CustomAbusHandler {
  final String _id;

  TestPerformanceHandler(this._id);

  @override
  String get handlerId => _id;

  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    return Future.value(ABUSResult.success(
      data: {'handler': _id, 'performance': true},
      interactionId: interaction.id,
    ));
  }
}

class FaultyTestHandler extends CustomAbusHandler {
  bool exceptionThrown = false;

  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    exceptionThrown = true;
    throw Exception('Simulated handler exception');
  }

  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    return Future.value(ABUSResult.success(
      data: {'faulty_handler': true},
      interactionId: interaction.id,
    ));
  }
}

class FaultyRollbackHandler extends CustomAbusHandler {
  bool optimisticCalled = false;
  bool rollbackFailed = false;

  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    optimisticCalled = true;
  }

  @override
  Future<void> handleRollback(
      String interactionId, InteractionDefinition interaction) async {
    rollbackFailed = true;
    throw Exception('Simulated rollback failure');
  }

  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    return null; // Let other handlers handle API
  }
}
