// test/unit/abus_definition_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:abus/core/abus_definition.dart';

void main() {
  group('InteractionDefinition Tests', () {
    group('GenericInteraction', () {
      test('should create valid generic interaction', () {
        final interaction = GenericInteraction(
          id: 'test_action',
          data: {'key': 'value'},
        );

        expect(interaction.id, equals('test_action'));
        expect(interaction.data['key'], equals('value'));
        expect(interaction.validate(), isTrue);
        expect(interaction.getValidationErrors(), isEmpty);
      });

      test('should fail validation with empty id', () {
        final interaction = GenericInteraction(
          id: '',
          data: {'key': 'value'},
        );

        expect(interaction.validate(), isFalse);
        expect(
            interaction.getValidationErrors(), contains('ID cannot be empty'));
      });

      test('should serialize to JSON correctly', () {
        final interaction = GenericInteraction(
          id: 'test',
          data: {'value': 42},
          priority: 5,
          tags: {'crud', 'create'},
        );

        final json = interaction.toJson();
        expect(json['id'], equals('test'));
        expect(json['data']['value'], equals(42));
        expect(json['priority'], equals(5));
        expect(json['tags'], contains('crud'));
      });
    });

    group('ClassInteraction', () {
      test('should create typed interaction', () {
        final testPayload = TestPayload('test', 42);
        final interaction = ClassInteraction<TestPayload>(
          id: 'typed_test',
          payload: testPayload,
        );

        expect(interaction.id, equals('typed_test'));
        expect(interaction.payload, equals(testPayload));
        expect(interaction.payloadType, equals(TestPayload));
        expect(interaction.validate(), isTrue);
      });

      test('should serialize payload with toJson', () {
        final testPayload = TestPayload('test', 42);
        final interaction = ClassInteraction<TestPayload>(
          id: 'typed_test',
          payload: testPayload,
        );

        final json = interaction.toJson();
        expect(json['payload']['name'], equals('test'));
        expect(json['payload']['value'], equals(42));
        expect(json['payloadType'], equals('TestPayload'));
      });
    });

    group('InteractionBuilder', () {
      test('should build generic interaction', () {
        final interaction = InteractionBuilder()
            .withId('builder_test')
            .addData('key', 'value')
            .withPriority(10)
            .addTag('test')
            .build();

        expect(interaction.id, equals('builder_test'));
        expect(interaction is GenericInteraction, isTrue);
        final generic = interaction as GenericInteraction;
        expect(generic.data['key'], equals('value'));
        expect(interaction.priority, equals(10));
        expect(interaction.tags, contains('test'));
      });

      test('should build class interaction', () {
        final payload = TestPayload('builder', 100);
        final interaction = InteractionBuilder<TestPayload>()
            .withId('class_test')
            .withPayload(payload)
            .build();

        expect(interaction is ClassInteraction, isTrue);
        final classInteraction = interaction as ClassInteraction<TestPayload>;
        expect(classInteraction.payload, equals(payload));
      });

      test('should throw on missing ID', () {
        expect(
          () => InteractionBuilder().addData('key', 'value').build(),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('InteractionTypes', () {
      test('should create CRUD interaction', () {
        final interaction = InteractionTypes.crud(
          action: 'create',
          resourceType: 'user',
          resourceId: '123',
          payload: {'name': 'John'},
        );

        expect(interaction.id, equals('create_user_123'));
        expect(interaction.data['action'], equals('create'));
        expect(interaction.data['resourceType'], equals('user'));
        expect(interaction.tags, contains('crud'));
        expect(interaction.tags, contains('create'));
      });

      test('should create typed CRUD interaction', () {
        final payload = TestPayload('CRUD', 200);
        final interaction = InteractionTypes.crudWithPayload(
          action: 'update',
          resourceType: 'item',
          payload: payload,
        );

        expect(interaction.id, equals('update_item'));
        expect(interaction.payload, equals(payload));
        expect(interaction.tags, contains('crud'));
        expect(interaction.tags, contains('update'));
      });
    });
  });
}

class TestPayload {
  final String name;
  final int value;

  TestPayload(this.name, this.value);

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestPayload &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value == other.value;

  @override
  int get hashCode => name.hashCode ^ value.hashCode;
}
