// test/enhanced_backward_compatibility_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:abus/abus.dart';

void main() {
  group('Enhanced Backward Compatibility Tests - No Registration Required', () {
    test('Legacy interaction creation with data should work', () {
      // OLD API - should still work
      final interaction = InteractionBuilder()
          .withId('test_interaction')
          .withData({'userId': '123', 'action': 'create'})
          .addData('timestamp', DateTime.now().millisecondsSinceEpoch)
          .build();

      // Legacy data access should work
      expect(interaction.data, isA<Map<String, dynamic>>());
      expect(interaction.data['userId'], equals('123'));
      expect(interaction.data['action'], equals('create'));
      expect(interaction.data.containsKey('timestamp'), isTrue);
    });

    test('Legacy ABUSResult with Map data should work', () {
      // OLD API - should still work
      final result = ABUSResult.success(
        data: {'message': 'success', 'id': 42},
        interactionId: 'test_123',
      );

      // Legacy data access should work
      expect(result.data, isA<Map<String, dynamic>?>());
      expect(result.data!['message'], equals('success'));
      expect(result.data!['id'], equals(42));
      expect(result.isSuccess, isTrue);
    });

    test('NEW API with classes should work', () {
      // Define a custom class
      final user = TestUser(id: '123', name: 'John Doe');

      // NEW API - with class payloads
      final interaction =
          InteractionBuilder().withId('user_update').withPayload(user).build();

      // New API access - the exact same object
      final retrievedUser = interaction.getPayload<TestUser>();
      expect(retrievedUser, equals(user));
      expect(interaction.payloadType, contains('TestUser'));
    });

    test('NEW API with ABUSResult class data should work', () {
      final responseData = TestApiResponse(
        status: 200,
        message: 'User created successfully',
        userId: 'user_456',
      );

      final result = ABUSResult.success(
        data: responseData,
        interactionId: 'create_user',
      );

      // New API access - the exact same object
      final response = result.getData<TestApiResponse>();
      expect(response, equals(responseData));
      expect(response?.status, equals(200));
      expect(response?.message, equals('User created successfully'));
    });

    test('Mixed usage - old and new APIs should coexist', () {
      // Create with old API
      final oldInteraction = InteractionBuilder()
          .withId('old_style')
          .withData({'key': 'value'}).build();

      // Create with new API
      final newInteraction = InteractionBuilder()
          .withId('new_style')
          .withPayload(TestUser(id: '999', name: 'Jane Doe'))
          .build();

      // Both should work
      expect(oldInteraction.data['key'], equals('value'));
      expect(newInteraction.getPayload<TestUser>()?.name, equals('Jane Doe'));

      // Legacy data getter should return empty map for non-map payloads
      expect(newInteraction.data, isA<Map<String, dynamic>>());
      expect(newInteraction.data.isEmpty, isTrue);
    });

    test('JSON serialization should work without registration', () {
      // Old format
      final oldInteraction = InteractionBuilder()
          .withId('json_test_old')
          .withData({'type': 'old', 'value': 123}).build();

      final oldJson = oldInteraction.toJson();
      final restoredOld = GenericInteraction.fromJson(oldJson);
      expect(restoredOld.data['type'], equals('old'));

      // New format with class (NO registration needed)
      final newInteraction = InteractionBuilder()
          .withId('json_test_new')
          .withPayload(TestUser(id: 'json_user', name: 'JSON Test'))
          .build();

      final newJson = newInteraction.toJson();
      final restoredNew = GenericInteraction.fromJson(newJson);

      // The class won't be reconstructed (since no registration),
      // but the data should be available as a Map
      final restoredUser = restoredNew.getPayload<TestUser>();
      expect(restoredUser, isNull); // Can't reconstruct without registration

      // But the data should be available as Map
      final rawData = restoredNew.payload;
      expect(rawData, isA<Map<String, dynamic>>());
      final dataMap = rawData as Map<String, dynamic>;
      expect(dataMap['id'], equals('json_user'));
      expect(dataMap['name'], equals('JSON Test'));
    });

    test('Classes with toJson should serialize and be accessible as Map', () {
      final user =
          TestUserWithToJson(id: 'serialize_test', name: 'Serialize Test');
      final payload = SmartPayload.from(user);

      final json = payload.toJson();
      expect(json['type'], equals('TestUserWithToJson'));
      expect(json['isClass'], equals(true));
      expect(json['classData'], isA<Map<String, dynamic>>());

      final restored = SmartPayload.fromJson(json);

      // Can't get as original class (no registration)
      final restoredUser = restored.as<TestUserWithToJson>();
      expect(restoredUser, isNull);

      // But can access the data as Map
      final rawData = restored.raw;
      expect(rawData, isA<Map<String, dynamic>>());
      final dataMap = rawData as Map<String, dynamic>;
      expect(dataMap['id'], equals('serialize_test'));
      expect(dataMap['name'], equals('Serialize Test'));
    });

    test('Classes without toJson should still work via toString parsing', () {
      final user = TestUser(id: 'parse_test', name: 'Parse Test');
      final payload = SmartPayload.from(user);

      final json = payload.toJson();
      expect(json['type'], equals('TestUser'));
      expect(json['isClass'], equals(true));

      final restored = SmartPayload.fromJson(json);
      final rawData = restored.raw;
      expect(rawData, isA<Map<String, dynamic>>());

      final dataMap = rawData as Map<String, dynamic>;
      // Should have parsed the toString() output
      expect(dataMap['id'], equals('parse_test'));
      expect(dataMap['name'], equals('Parse Test'));
    });

    test('Legacy ABUS static methods should work', () {
      // Test deprecated but functional methods
      final successResult = ABUS.successResult(
        data: {'legacy': 'test'},
        interactionId: 'legacy_success',
      );

      final errorResult = ABUS.errorResult(
        'Legacy error',
        interactionId: 'legacy_error',
      );

      expect(successResult.isSuccess, isTrue);
      expect(successResult.data!['legacy'], equals('test'));
      expect(errorResult.isSuccess, isFalse);
      expect(errorResult.error, equals('Legacy error'));
    });

    test('Error handling for mixed payload types', () {
      final builder = InteractionBuilder()
          .withId('error_test')
          .withData({'initial': 'map'});

      // Should throw error when trying to add data to non-map payload
      builder.withPayload(TestUser(id: '1', name: 'Test'));

      expect(
        () => builder.addData('key', 'value'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Round-trip with classes maintains data integrity', () {
      final originalUser = TestUser(id: 'round_trip', name: 'Round Trip Test');

      // Create interaction with class
      final interaction = InteractionBuilder()
          .withId('round_trip_test')
          .withPayload(originalUser)
          .build();

      // Serialize to JSON
      final json = interaction.toJson();

      // Deserialize from JSON
      final restored = GenericInteraction.fromJson(json);

      // Get the data as Map (since no registration)
      final dataMap = restored.payload as Map<String, dynamic>;

      // Verify data integrity
      expect(dataMap['id'], equals('round_trip'));
      expect(dataMap['name'], equals('Round Trip Test'));

      // Can manually reconstruct if needed
      final manualUser = TestUser(
        id: dataMap['id'],
        name: dataMap['name'],
      );
      expect(manualUser, equals(originalUser));
    });
  });
}

// Test classes for the compatibility tests
class TestUser {
  final String id;
  final String name;

  TestUser({required this.id, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'TestUser(id: $id, name: $name)';
}

// Test class WITH toJson method
class TestUserWithToJson {
  final String id;
  final String name;

  TestUserWithToJson({required this.id, required this.name});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestUserWithToJson &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'TestUserWithToJson(id: $id, name: $name)';
}

class TestApiResponse {
  final int status;
  final String message;
  final String userId;

  TestApiResponse({
    required this.status,
    required this.message,
    required this.userId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestApiResponse &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          message == other.message &&
          userId == other.userId;

  @override
  int get hashCode => status.hashCode ^ message.hashCode ^ userId.hashCode;

  @override
  String toString() =>
      'TestApiResponse(status: $status, message: $message, userId: $userId)';
}
