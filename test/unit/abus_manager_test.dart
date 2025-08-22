// test/unit/abus_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:abus/core/abus_manager.dart';
import 'package:abus/core/abus_definition.dart';
import 'package:abus/core/abus_result.dart';

void main() {
  group('ABUSManager Tests', () {
    late ABUSManager manager;

    setUp(() {
      ABUSManager.reset();
      manager = ABUSManager.instance;
    });

    tearDown(() {
      manager.dispose();
    });

    test('should be singleton', () {
      final manager1 = ABUSManager.instance;
      final manager2 = ABUSManager.instance;
      expect(manager1, same(manager2));
    });

    test('should register and execute API handler', () async {
      final interaction = GenericInteraction(
        id: 'test_api',
        data: {'test': true},
      );

      manager.registerApiHandler((interaction) async {
        return ABUSResult.success(
          data: {'handled': true},
          interactionId: interaction.id,
        );
      });

      final result = await manager.execute(interaction);

      expect(result.isSuccess, isTrue);
      expect(result.data!['handled'], isTrue);
    });

    test('should handle execution timeout', () async {
      final interaction = GenericInteraction(
        id: 'timeout_test',
        data: {'test': true},
      );

      manager.registerApiHandler((interaction) async {
        await Future.delayed(const Duration(seconds: 2));
        return ABUSResult.success();
      });

      final result = await manager.execute(
        interaction,
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, equals('Timeout'));
    });

    test('should prevent duplicate execution', () async {
      final interaction = GenericInteraction(
        id: 'duplicate_test',
        data: {'test': true},
      );

      manager.registerApiHandler((interaction) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return ABUSResult.success();
      });

      final future1 = manager.execute(interaction);
      final future2 = manager.execute(interaction);

      final results = await Future.wait([future1, future2]);

      // One should succeed, one should fail with duplicate error
      final successes = results.where((r) => r.isSuccess).length;
      final duplicateErrors = results
          .where((r) => !r.isSuccess && r.error!.contains('already processing'))
          .length;

      expect(successes, equals(1));
      expect(duplicateErrors, equals(1));
    });

    test('should register and use custom handler', () async {
      final handler = TestHandler();
      manager.registerHandler(handler);

      final interaction = GenericInteraction(
        id: 'handler_test',
        data: {'test': true},
      );

      final result = await manager.execute(interaction);

      expect(result.isSuccess, isTrue);
      expect(result.data!['handled_by'], equals('TestHandler'));
      expect(handler.optimisticCalled, isTrue);
      expect(handler.commitCalled, isTrue);
    });

    test('should handle rollback on API failure', () async {
      final handler = TestHandler();
      manager.registerHandler(handler);

      final interaction = GenericInteraction(
        id: 'rollback_test',
        data: {'test': true},
      );

      handler.shouldFailAPI = true;

      final result = await manager.execute(interaction, optimistic: true);

      expect(result.isSuccess, isFalse);
      expect(handler.optimisticCalled, isTrue);
      expect(handler.rollbackCalled, isTrue);
      expect(handler.commitCalled, isFalse);
    });

    test('should emit results on stream', () async {
      final results = <ABUSResult>[];
      manager.resultStream.listen(results.add);

      final interaction = GenericInteraction(
        id: 'stream_test',
        data: {'test': true},
      );

      manager.registerApiHandler((interaction) async {
        return ABUSResult.success(interactionId: interaction.id);
      });

      await manager.execute(interaction);
      await Future.delayed(const Duration(milliseconds: 10)); // Wait for stream

      expect(results, hasLength(1));
      expect(results.first.isSuccess, isTrue);
      expect(results.first.interactionId, equals('stream_test'));
    });

    test('should manage memory with snapshot limits', () async {
      final handler = TestHandler();
      manager.registerHandler(handler);

      // Create more interactions than the limit (100)
      for (int i = 0; i < 105; i++) {
        final interaction = GenericInteraction(
          id: 'memory_test_$i',
          data: {'index': i},
        );

        await manager.execute(interaction, optimistic: true);
      }

      // Should not exceed memory limits
      expect(manager.pendingCount, lessThanOrEqualTo(100));
    });
  });
}

class TestHandler extends CustomAbusHandler {
  bool optimisticCalled = false;
  bool rollbackCalled = false;
  bool commitCalled = false;
  bool shouldFailAPI = false;

  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    optimisticCalled = true;
  }

  @override
  Future<void> handleRollback(
      String interactionId, InteractionDefinition interaction) async {
    rollbackCalled = true;
  }

  @override
  Future<void> handleCommit(
      String interactionId, InteractionDefinition interaction) async {
    commitCalled = true;
  }

  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    if (shouldFailAPI) {
      return Future.value(ABUSResult.error('API failed'));
    }
    return Future.value(ABUSResult.success(
      data: {'handled_by': 'TestHandler'},
      interactionId: interaction.id,
    ));
  }
}
