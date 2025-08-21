// test/abus_core_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:abus/abus.dart';
import 'dart:async';

void main() {
  group('ABUS Core Functionality Tests', () {
    setUp(() {
      // Reset manager before each test
      ABUSManager.reset();
    });

    tearDown(() {
      // Clean up after each test
      ABUSManager.instance.dispose();
    });

    group('InteractionDefinition Tests', () {
      test('should create generic interaction with map payload', () {
        final interaction = InteractionBuilder()
            .withId('test_interaction')
            .withPayload({'userId': '123', 'action': 'create'})
            .withTimeout(const Duration(seconds: 10))
            .withPriority(5)
            .addTag('user')
            .addTag('crud')
            .build();

        expect(interaction.id, equals('test_interaction'));
        expect(interaction.timeout, equals(const Duration(seconds: 10)));
        expect(interaction.priority, equals(5));
        expect(interaction.tags, contains('user'));
        expect(interaction.tags, contains('crud'));
        expect(interaction.validate(), isTrue);

        final payload = interaction.getPayload<Map<String, dynamic>>();
        expect(payload?['userId'], equals('123'));
        expect(payload?['action'], equals('create'));
      });

      test('should create interaction with custom class payload', () {
        final user =
            TestUser(id: '456', name: 'John Doe', email: 'john@example.com');
        final interaction = InteractionBuilder()
            .withId('user_interaction')
            .withPayload(user)
            .build();

        expect(interaction.id, equals('user_interaction'));
        final retrievedUser = interaction.getPayload<TestUser>();
        expect(retrievedUser, equals(user));
        expect(interaction.payloadType, contains('TestUser'));
      });

      test('should validate interactions correctly', () {
        // Valid interaction
        final valid = InteractionBuilder()
            .withId('valid_interaction')
            .withPayload({'data': 'test'}).build();
        expect(valid.validate(), isTrue);
        expect(valid.getValidationErrors(), isEmpty);

        // Invalid interaction (empty ID)
        expect(() => InteractionBuilder().withPayload({'data': 'test'}).build(),
            throwsA(isA<ArgumentError>()));
      });

      test('should create CRUD interactions using predefined types', () {
        final createInteraction = InteractionTypes.crud(
          action: InteractionTypes.create,
          resourceType: 'user',
          resourceId: '123',
          payload: {'name': 'John Doe'},
          optimistic: true,
        );

        expect(createInteraction.id, equals('create_user_123'));
        expect(createInteraction.supportsOptimistic, isTrue);
        expect(createInteraction.tags, contains('crud'));
        expect(createInteraction.tags, contains('create'));

        final payload = createInteraction.getPayload<Map<String, dynamic>>();
        expect(payload?['action'], equals('create'));
        expect(payload?['resourceType'], equals('user'));
        expect(payload?['resourceId'], equals('123'));
      });

      test('should serialize and deserialize interactions to/from JSON', () {
        final originalUser =
            TestUser(id: '789', name: 'Jane Doe', email: 'jane@example.com');
        final original = InteractionBuilder()
            .withId('json_test')
            .withPayload(originalUser)
            .withTimeout(const Duration(seconds: 15))
            .withPriority(3)
            .addTag('serialization')
            .build();

        final json = original.toJson();
        final restored = GenericInteraction.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.timeout, equals(original.timeout));
        expect(restored.priority, equals(original.priority));
        expect(restored.tags, equals(original.tags));

        // Note: Class payload will be serialized as Map without registration
        final rawData = restored.payload as Map<String, dynamic>;
        expect(rawData['id'], equals('789'));
        expect(rawData['name'], equals('Jane Doe'));
        expect(rawData['email'], equals('jane@example.com'));
      });
    });

    group('ABUSResult Tests', () {
      test('should create successful results with different payload types', () {
        // Map payload
        final mapResult = ABUSResult.success(
          data: {'message': 'Success', 'count': 42},
          interactionId: 'test_123',
          metadata: {'source': 'test'},
        );

        expect(mapResult.isSuccess, isTrue);
        expect(mapResult.interactionId, equals('test_123'));
        expect(mapResult.getData<Map<String, dynamic>>(), isNotNull);
        expect(mapResult.getData<Map<String, dynamic>>()!['message'],
            equals('Success'));
        expect(mapResult.metadata?['source'], equals('test'));

        // Class payload
        final user =
            TestUser(id: '1', name: 'Test User', email: 'test@example.com');
        final classResult =
            ABUSResult.success(data: user, interactionId: 'user_123');

        expect(classResult.isSuccess, isTrue);
        expect(classResult.getData<TestUser>(), equals(user));
        expect(classResult.isData<TestUser>(), isTrue);
      });

      test('should create error results', () {
        final errorResult = ABUSResult.error(
          'Something went wrong',
          interactionId: 'error_123',
          metadata: {'errorCode': 500},
        );

        expect(errorResult.isSuccess, isFalse);
        expect(errorResult.error, equals('Something went wrong'));
        expect(errorResult.interactionId, equals('error_123'));
        expect(errorResult.metadata?['errorCode'], equals(500));
      });

      test('should create rollback results', () {
        final rollbackResult = ABUSResult.rollback(
          interactionId: 'rollback_123',
          metadata: {'reason': 'timeout'},
        );

        expect(rollbackResult.isSuccess, isFalse);
        expect(rollbackResult.error, equals('Rollback'));
        expect(rollbackResult.interactionId, equals('rollback_123'));
        expect(rollbackResult.metadata?['rollback'], isTrue);
        expect(rollbackResult.metadata?['reason'], equals('timeout'));
      });

      test('should serialize and deserialize results to/from JSON', () {
        final originalUser =
            TestUser(id: '321', name: 'JSON User', email: 'json@example.com');
        final original = ABUSResult.success(
          data: originalUser,
          interactionId: 'json_result',
          metadata: {'version': '1.0'},
        );

        final json = original.toJson();
        final restored = ABUSResult.fromJson(json);

        expect(restored.isSuccess, equals(original.isSuccess));
        expect(restored.interactionId, equals(original.interactionId));
        expect(restored.metadata?['version'], equals('1.0'));

        // Data should be available as Map after JSON round-trip
        final rawData = restored.rawData as Map<String, dynamic>;
        expect(rawData['id'], equals('321'));
        expect(rawData['name'], equals('JSON User'));
        expect(rawData['email'], equals('json@example.com'));
      });
    });

    group('ABUSManager Tests', () {
      test('should register and handle API handlers', () async {
        final manager = ABUSManager.instance;
        bool apiCalled = false;

        // Register a simple API handler
        manager.registerApiHandler((interaction) async {
          apiCalled = true;
          expect(interaction.id, equals('api_test'));
          return ABUSResult.success(
            data: {'response': 'API handled'},
            interactionId: interaction.id,
          );
        });

        final interaction = InteractionBuilder()
            .withId('api_test')
            .withPayload({'request': 'test'}).build();

        final result = await manager.execute(interaction);

        expect(apiCalled, isTrue);
        expect(result.isSuccess, isTrue);
        expect(result.getData<Map<String, dynamic>>()!['response'],
            equals('API handled'));
      });

      test('should handle custom handlers with optimistic updates', () async {
        final manager = ABUSManager.instance;
        final testHandler = TestAbusHandler();
        manager.registerHandler(testHandler);

        final interaction = InteractionBuilder()
            .withId('optimistic_test')
            .withPayload({'action': 'update'})
            .withOptimistic(true)
            .build();

        final result = await manager.execute(interaction, optimistic: true);

        expect(result.isSuccess, isTrue);
        expect(testHandler.optimisticCalled, isTrue);
        expect(testHandler.commitCalled, isTrue);
        expect(testHandler.rollbackCalled, isFalse);
      });

      test('should handle rollback on API failure', () async {
        final manager = ABUSManager.instance;
        final testHandler = TestAbusHandler();
        manager.registerHandler(testHandler);

        // Register an API handler that fails
        manager.registerApiHandler((interaction) async {
          return ABUSResult.error('API failed', interactionId: interaction.id);
        });

        final interaction = InteractionBuilder()
            .withId('rollback_test')
            .withPayload({'action': 'update'})
            .withOptimistic(true)
            .build();

        final result = await manager.execute(interaction, optimistic: true);

        expect(result.isSuccess, isFalse);
        expect(result.error, equals('API failed'));
        expect(testHandler.optimisticCalled, isTrue);
        expect(testHandler.rollbackCalled, isTrue);
        expect(testHandler.commitCalled, isFalse);
      });

      test('should prevent duplicate interactions from processing', () async {
        final manager = ABUSManager.instance;
        final completer = Completer<ABUSResult>();

        // Register a handler that waits
        manager.registerApiHandler((interaction) => completer.future);

        final interaction = InteractionBuilder()
            .withId('duplicate_test')
            .withPayload({'data': 'test'}).build();

        // Start first execution
        final future1 = manager.execute(interaction);

        // Try to start same interaction again
        final result2 = await manager.execute(interaction);

        // Second should fail immediately
        expect(result2.isSuccess, isFalse);
        expect(result2.error, contains('already processing'));

        // Complete the first one
        completer.complete(ABUSResult.success(
          data: {'completed': true},
          interactionId: interaction.id,
        ));

        final result1 = await future1;
        expect(result1.isSuccess, isTrue);
      });

      test('should handle timeouts correctly', () async {
        final manager = ABUSManager.instance;

        // Register a handler that takes too long
        manager.registerApiHandler((interaction) async {
          await Future.delayed(const Duration(seconds: 2));
          return ABUSResult.success(
            data: {'delayed': true},
            interactionId: interaction.id,
          );
        });

        final interaction = InteractionBuilder()
            .withId('timeout_test')
            .withPayload({'data': 'test'})
            .withTimeout(const Duration(milliseconds: 100))
            .build();

        final result = await manager.execute(interaction);

        expect(result.isSuccess, isFalse);
        expect(result.error, equals('Timeout'));
      });

      test('should emit results through stream', () async {
        final manager = ABUSManager.instance;
        final streamResults = <ABUSResult>[];

        // Listen to result stream
        final subscription = manager.resultStream.listen((result) {
          streamResults.add(result);
        });

        manager.registerApiHandler((interaction) async {
          return ABUSResult.success(
            data: {'stream': 'test'},
            interactionId: interaction.id,
          );
        });

        final interaction = InteractionBuilder()
            .withId('stream_test')
            .withPayload({'data': 'test'}).build();

        await manager.execute(interaction);

        // Wait a bit for stream emission
        await Future.delayed(const Duration(milliseconds: 10));

        expect(streamResults, hasLength(1));
        expect(streamResults.first.isSuccess, isTrue);
        expect(streamResults.first.interactionId, equals('stream_test'));

        await subscription.cancel();
      });

      test('should manage memory with snapshot limits', () async {
        final manager = ABUSManager.instance;
        final testHandler = TestAbusHandler();
        manager.registerHandler(testHandler);

        // Create many interactions to test memory management
        for (int i = 0; i < 150; i++) {
          final interaction = InteractionBuilder()
              .withId('memory_test_$i')
              .withPayload({'index': i})
              .withOptimistic(true)
              .build();

          await manager.execute(interaction, optimistic: true);
        }

        // Should have cleaned up old snapshots
        expect(manager.pendingCount, lessThanOrEqualTo(100));
      });

      test('should handle manual rollback', () async {
        final manager = ABUSManager.instance;
        final testHandler = TestAbusHandler();
        manager.registerHandler(testHandler);

        final interaction = InteractionBuilder()
            .withId('manual_rollback_test')
            .withPayload({'action': 'test'})
            .withOptimistic(true)
            .build();

        // Execute with optimistic update but don't auto-rollback
        final result = await manager.execute(interaction,
            optimistic: true, autoRollback: false);

        expect(result.isSuccess, isTrue);
        expect(testHandler.optimisticCalled, isTrue);
        expect(testHandler.commitCalled, isTrue);

        // Manually rollback
        final interactionId = manager.pendingInteractions.first;
        final rollbackSuccess = await manager.rollback(interactionId);

        expect(rollbackSuccess, isTrue);
        expect(testHandler.rollbackCalled, isTrue);
      });
    });

    group('ABUS Static Methods Tests', () {
      test('should provide convenient static methods', () async {
        bool apiCalled = false;

        ABUS.registerApiHandler((interaction) async {
          apiCalled = true;
          return ABUSResult.success(
            data: {'static': 'test'},
            interactionId: interaction.id,
          );
        });

        final interaction = ABUS
            .builder()
            .withId('static_test')
            .withPayload({'method': 'static'}).build();

        final result = await ABUS.execute(interaction);

        expect(apiCalled, isTrue);
        expect(result.isSuccess, isTrue);
        expect(
            result.getData<Map<String, dynamic>>()!['static'], equals('test'));
      });

      test('should reset manager properly', () {
        final manager1 = ABUSManager.instance;
        ABUS.registerApiHandler((interaction) async {
          return ABUSResult.success(data: {}, interactionId: interaction.id);
        });

        expect(manager1.apiHandlerCount, equals(1));

        ABUSManager.reset();
        final manager2 = ABUSManager.instance;

        expect(identical(manager1, manager2), isFalse);
        expect(manager2.apiHandlerCount, equals(0));
      });
    });

    group('Complex Scenarios', () {
      test('should handle multiple handlers with different capabilities',
          () async {
        final manager = ABUSManager.instance;

        final userHandler = SpecificTestHandler('user');
        final orderHandler = SpecificTestHandler('order');
        final globalHandler = TestAbusHandler();

        manager.registerHandler(userHandler);
        manager.registerHandler(orderHandler);
        manager.registerHandler(globalHandler);

        // User interaction - should be handled by userHandler
        final userInteraction = InteractionBuilder()
            .withId('user_action')
            .withPayload({'type': 'user', 'action': 'create'}).build();

        await manager.execute(userInteraction);
        expect(userHandler.handledInteractions, hasLength(1));
        expect(orderHandler.handledInteractions, hasLength(0));
        expect(globalHandler.optimisticCalled,
            isTrue); // Global handler handles all

        // Reset for next test
        userHandler.reset();
        orderHandler.reset();
        globalHandler.reset();

        // Order interaction - should be handled by orderHandler
        final orderInteraction = InteractionBuilder()
            .withId('order_action')
            .withPayload({'type': 'order', 'action': 'update'}).build();

        await manager.execute(orderInteraction);
        expect(userHandler.handledInteractions, hasLength(0));
        expect(orderHandler.handledInteractions, hasLength(1));
        expect(globalHandler.optimisticCalled, isTrue);
      });

      test('should handle interaction with complex custom class', () async {
        final manager = ABUSManager.instance;
        final testHandler = TestAbusHandler();
        manager.registerHandler(testHandler);

        final complexData = ComplexTestData(
          id: 'complex_123',
          metadata: {'version': '1.0', 'type': 'test'},
          items: [
            TestUser(id: '1', name: 'User 1', email: 'user1@test.com'),
            TestUser(id: '2', name: 'User 2', email: 'user2@test.com'),
          ],
          timestamp: DateTime.now(),
        );

        final interaction = InteractionBuilder()
            .withId('complex_test')
            .withPayload(complexData)
            .build();

        final result = await manager.execute(interaction);

        expect(result.isSuccess, isTrue);
        expect(testHandler.optimisticCalled, isTrue);
        expect(testHandler.commitCalled, isTrue);

        final retrievedData = interaction.getPayload<ComplexTestData>();
        expect(retrievedData, equals(complexData));
        expect(retrievedData?.items, hasLength(2));
        expect(retrievedData?.metadata['version'], equals('1.0'));
      });
    });
  });
}

// Test Classes and Helpers

class TestUser {
  final String id;
  final String name;
  final String email;

  TestUser({required this.id, required this.name, required this.email});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ email.hashCode;

  @override
  String toString() => 'TestUser(id: $id, name: $name, email: $email)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
      };
}

class ComplexTestData {
  final String id;
  final Map<String, dynamic> metadata;
  final List<TestUser> items;
  final DateTime timestamp;

  ComplexTestData({
    required this.id,
    required this.metadata,
    required this.items,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComplexTestData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          metadata.toString() == other.metadata.toString() &&
          items.length == other.items.length &&
          timestamp.millisecondsSinceEpoch ==
              other.timestamp.millisecondsSinceEpoch;

  @override
  int get hashCode =>
      id.hashCode ^ metadata.hashCode ^ items.hashCode ^ timestamp.hashCode;

  @override
  String toString() =>
      'ComplexTestData(id: $id, metadata: $metadata, items: $items, timestamp: $timestamp)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'metadata': metadata,
        'items': items.map((item) => item.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
      };
}

class TestAbusHandler extends CustomAbusHandler {
  bool optimisticCalled = false;
  bool rollbackCalled = false;
  bool commitCalled = false;
  bool apiCalled = false;
  List<InteractionDefinition> handledInteractions = [];

  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    optimisticCalled = true;
    handledInteractions.add(interaction);
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
    apiCalled = true;
    return Future.value(ABUSResult.success(
      data: {'handler': 'test', 'interaction': interaction.id},
      interactionId: interaction.id,
    ));
  }

  void reset() {
    optimisticCalled = false;
    rollbackCalled = false;
    commitCalled = false;
    apiCalled = false;
    handledInteractions.clear();
  }
}

class SpecificTestHandler extends CustomAbusHandler {
  final String handlerType;
  List<InteractionDefinition> handledInteractions = [];

  SpecificTestHandler(this.handlerType);

  @override
  String get handlerId => '${handlerType}_handler';

  @override
  bool canHandle(InteractionDefinition interaction) {
    final payload = interaction.getPayload<Map<String, dynamic>>();
    return payload?['type'] == handlerType;
  }

  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    handledInteractions.add(interaction);
  }

  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    return Future.value(ABUSResult.success(
      data: {'handlerType': handlerType, 'handled': true},
      interactionId: interaction.id,
    ));
  }

  void reset() {
    handledInteractions.clear();
  }
}
