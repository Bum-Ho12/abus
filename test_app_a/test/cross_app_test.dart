// example/test/cross_app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:abus/abus.dart';

void main() {
  group('ABUS Cross-App Communication Tests', () {
    setUp(() {
      ABUSManager.reset();
    });

    tearDown(() {
      ABUSManager.reset();
    });

    test('should create and execute basic interactions', () async {
      // Register test API handler
      ABUS.registerApiHandler((interaction) async {
        return ABUSResult.success(
          data: {'handled': true, 'id': interaction.id},
          interactionId: interaction.id,
        );
      });

      final interaction = ABUS
          .builder()
          .withId('test_interaction')
          .withData({'test': 'data'}).build();

      final result = await ABUS.execute(interaction);

      expect(result.isSuccess, isTrue);
      expect(result.data?['handled'], isTrue);
      expect(result.data?['id'], equals('test_interaction'));
    });

    test('should handle mock cross-app events', () async {
      ABUS.registerApiHandler((interaction) async {
        if (interaction.id == 'send_app_event') {
          return ABUSResult.success(
            data: {'sent': true},
            interactionId: interaction.id,
          );
        }
        return ABUSResult.error('Unsupported interaction');
      });

      final mockEvent = {
        'id': 'test_intent',
        'type': 'IntentEvent',
        'sourceApp': 'test_app',
        'data': {
          'action': 'com.test.ACTION',
          'extras': {'key': 'value'},
        },
      };

      final interaction = ABUS
          .builder()
          .withId('send_app_event')
          .withData({'event': mockEvent}).build();

      final result = await ABUS.execute(interaction);
      expect(result.isSuccess, isTrue);
    });

    test('should validate interactions properly', () {
      final validInteraction = ABUS
          .builder()
          .withId('valid_test')
          .withData({'data': 'valid'}).build();

      expect(validInteraction.validate(), isTrue);
      expect(validInteraction.getValidationErrors(), isEmpty);

      // Test builder validation
      expect(() => ABUS.builder().build(), throwsA(isA<ArgumentError>()));
    });
  });
}
