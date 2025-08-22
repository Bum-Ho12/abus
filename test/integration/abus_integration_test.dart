// test/integration/abus_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:abus/abus.dart';

void main() {
  group('ABUS Integration Tests', () {
    setUp(() {
      ABUSManager.reset();
    });

    tearDown(() {
      ABUS.manager.dispose();
    });

    test('should handle end-to-end optimistic flow', () async {
      final handler = IntegrationTestHandler();
      ABUS.registerHandler(handler);

      // Create interaction
      final interaction = ABUS
          .builder()
          .withId('integration_test')
          .addData('operation', 'create_user')
          .addData('user_data', {'name': 'John', 'email': 'john@test.com'})
          .withOptimistic(true)
          .addTag('user')
          .build();

      // Execute with optimistic updates
      final result = await ABUS.execute(interaction);

      expect(result.isSuccess, isTrue);
      expect(
          handler.executionOrder,
          equals([
            'optimistic',
            'api',
            'commit',
          ]));
      expect(handler.userData['name'], equals('John'));
    });

    test('should handle rollback on failure', () async {
      final handler = IntegrationTestHandler()..shouldFailApi = true;
      ABUS.registerHandler(handler);

      final interaction = ABUS
          .builder()
          .withId('rollback_integration')
          .addData('operation', 'create_user')
          .addData('user_data', {'name': 'Jane'}).build();

      final result = await ABUS.execute(interaction);

      expect(result.isSuccess, isFalse);
      expect(handler.executionOrder, contains('rollback'));
      expect(handler.userData, isEmpty);
    });

    test('should handle multiple handlers', () async {
      final handler1 = IntegrationTestHandler();
      final handler2 = SecondaryTestHandler();

      ABUS.registerHandler(handler1);
      ABUS.registerHandler(handler2);

      final interaction = ABUS
          .builder()
          .withId('multi_handler_test')
          .addData('sync_to_secondary', true)
          .build();

      final result = await ABUS.execute(interaction);

      expect(result.isSuccess, isTrue);
      expect(handler1.executionOrder, isNotEmpty);
      expect(handler2.synced, isTrue);
    });

    test('should handle typed payloads end-to-end', () async {
      final handler = TypedPayloadHandler();
      ABUS.registerHandler(handler);

      final userPayload = UserModel('Alice', 25);
      final interaction = InteractionTypes.crudWithPayload(
        action: 'create',
        resourceType: 'user',
        payload: userPayload,
      );

      final result = await ABUS.execute(interaction);

      expect(result.isSuccess, isTrue);
      expect(result.hasPayloadType<UserModel>(), isTrue);
      final returnedUser = result.getPayload<UserModel>();
      expect(returnedUser?.name, equals('Alice'));
      expect(returnedUser?.age, equals(25));
    });

    test('should handle concurrent interactions', () async {
      final handler = ConcurrentTestHandler();
      ABUS.registerHandler(handler);

      final futures = List.generate(10, (i) {
        final interaction =
            ABUS.builder().withId('concurrent_$i').addData('index', i).build();
        return ABUS.execute(interaction);
      });

      final results = await Future.wait(futures);

      expect(results.every((r) => r.isSuccess), isTrue);
      expect(handler.processedCount, equals(10));
    });

    test('should measure performance under load', () async {
      final handler = PerformanceTestHandler();
      ABUS.registerHandler(handler);

      final stopwatch = Stopwatch()..start();

      final futures = List.generate(100, (i) {
        final interaction = ABUS
            .builder()
            .withId('perf_$i')
            .addData('data', 'test_data_$i')
            .build();
        return ABUS.execute(interaction);
      });

      final results = await Future.wait(futures);
      stopwatch.stop();

      expect(results.every((r) => r.isSuccess), isTrue);
      expect(stopwatch.elapsedMilliseconds,
          lessThan(5000)); // Should complete within 5 seconds
      expect(handler.totalProcessed, equals(100));
    });
  });
}

class IntegrationTestHandler extends CustomAbusHandler {
  final List<String> executionOrder = [];
  final Map<String, dynamic> userData = {};
  bool shouldFailApi = false;

  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    executionOrder.add('optimistic');
    if (interaction is GenericInteraction &&
        interaction.data.containsKey('user_data')) {
      userData.addAll(interaction.data['user_data'] as Map<String, dynamic>);
    }
  }

  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    executionOrder.add('api');

    if (shouldFailApi) {
      return Future.value(ABUSResult.error('Simulated API failure'));
    }

    return Future.value(ABUSResult.success(
      data: {'api_processed': true},
      interactionId: interaction.id,
    ));
  }

  @override
  Future<void> handleCommit(
      String interactionId, InteractionDefinition interaction) async {
    executionOrder.add('commit');
  }

  @override
  Future<void> handleRollback(
      String interactionId, InteractionDefinition interaction) async {
    executionOrder.add('rollback');
    userData.clear();
  }
}

class SecondaryTestHandler extends CustomAbusHandler {
  bool synced = false;

  @override
  bool canHandle(InteractionDefinition interaction) {
    return interaction is GenericInteraction &&
        interaction.data['sync_to_secondary'] == true;
  }

  @override
  Future<void> handleCommit(
      String interactionId, InteractionDefinition interaction) async {
    synced = true;
  }
}

class TypedPayloadHandler extends CustomAbusHandler {
  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    if (interaction is ClassInteraction<UserModel>) {
      return Future.value(ABUSResult.success(
        payload: interaction.payload,
        interactionId: interaction.id,
      ));
    }
    return null;
  }
}

class ConcurrentTestHandler extends CustomAbusHandler {
  int processedCount = 0;

  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) async {
    await Future.delayed(const Duration(milliseconds: 10)); // Simulate work
    processedCount++;
    return ABUSResult.success(interactionId: interaction.id);
  }
}

class PerformanceTestHandler extends CustomAbusHandler {
  int totalProcessed = 0;

  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) async {
    // Minimal processing for performance test
    totalProcessed++;
    return ABUSResult.success(
      data: {'processed_at': DateTime.now().millisecondsSinceEpoch},
      interactionId: interaction.id,
    );
  }
}

class UserModel {
  final String name;
  final int age;

  UserModel(this.name, this.age);

  Map<String, dynamic> toJson() => {'name': name, 'age': age};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age;

  @override
  int get hashCode => name.hashCode ^ age.hashCode;
}
