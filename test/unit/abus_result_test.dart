// test/unit/abus_result_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:abus/core/abus_result.dart';

void main() {
  group('ABUSResult Tests', () {
    test('should create success result', () {
      final result = ABUSResult.success(
        data: {'message': 'Success'},
        interactionId: 'test_id',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!['message'], equals('Success'));
      expect(result.interactionId, equals('test_id'));
      expect(result.error, isNull);
    });

    test('should create error result', () {
      final result = ABUSResult.error(
        'Something went wrong',
        interactionId: 'error_test',
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, equals('Something went wrong'));
      expect(result.interactionId, equals('error_test'));
      expect(result.data, isNull);
    });

    test('should create rollback result', () {
      final result = ABUSResult.rollback(
        interactionId: 'rollback_test',
        metadata: {'reason': 'timeout'},
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, equals('Rollback'));
      expect(result.metadata!['rollback'], isTrue);
      expect(result.metadata!['reason'], equals('timeout'));
    });

    test('should handle typed payloads', () {
      final payload = TestPayload('test', 42);
      final result = ABUSResult.success(payload: payload);

      expect(result.hasPayloadType<TestPayload>(), isTrue);
      expect(result.getPayload<TestPayload>(), equals(payload));
      expect(result.getPayload<String>(), isNull);
      expect(result.payloadType, equals(TestPayload));
    });

    test('should handle null payloads', () {
      final result = ABUSResult.success();

      expect(result.hasPayloadType<String>(), isFalse);
      expect(result.getPayload<String>(), isNull);
      expect(result.payloadType, isNull);
      expect(result.payload, isNull);
    });

    test('should serialize to JSON with payload', () {
      final payload = TestPayload('json', 100);
      final result = ABUSResult.success(
        data: {'test': true},
        payload: payload,
        interactionId: 'json_test',
      );

      final json = result.toJson();
      expect(json['isSuccess'], isTrue);
      expect(json['data']['test'], isTrue);
      expect(json['payload']['name'], equals('json'));
      expect(json['payloadType'], equals('TestPayload'));
      expect(json['interactionId'], equals('json_test'));
    });

    test('should serialize to JSON without payload', () {
      final result = ABUSResult.success(
        data: {'simple': 'test'},
        interactionId: 'simple_test',
      );

      final json = result.toJson();
      expect(json['isSuccess'], isTrue);
      expect(json['data']['simple'], equals('test'));
      expect(json['interactionId'], equals('simple_test'));
      expect(json.containsKey('payload'), isFalse);
      expect(json.containsKey('payloadType'), isFalse);
    });

    test('should handle payload without toJson method', () {
      final payload = SimplePayload('test');
      final result = ABUSResult.success(payload: payload);

      final json = result.toJson();
      expect(json['payloadType'], equals('SimplePayload'));
      expect(json['hasPayload'], isTrue);
      expect(json.containsKey('payload'), isFalse); // No toJson available
    });

    test('should create from JSON', () {
      final originalJson = {
        'isSuccess': true,
        'data': {'test': 'value'},
        'payload': {'name': 'restored', 'value': 200},
        'timestamp': DateTime.now().toIso8601String(),
        'interactionId': 'restored_test',
        'metadata': {'source': 'test'},
      };

      final result = ABUSResult.fromJson(originalJson);

      expect(result.isSuccess, isTrue);
      expect(result.data!['test'], equals('value'));
      expect(result.interactionId, equals('restored_test'));
      expect(result.metadata!['source'], equals('test'));
      expect(result.payload, isNotNull);
    });

    test('should create copy with updates', () {
      final original = ABUSResult.success(data: {'original': true});
      final copy = original.copyWith(
        data: {'updated': true},
        interactionId: 'copy_test',
      );

      expect(original.data!['original'], isTrue);
      expect(copy.data!['updated'], isTrue);
      expect(copy.interactionId, equals('copy_test'));
      expect(copy.isSuccess, isTrue); // Preserved from original
    });

    test('should preserve timestamp in copyWith', () async {
      final original = ABUSResult.success();
      final originalTime = original.timestamp;

      // Wait a moment to ensure time difference
      await Future.delayed(const Duration(milliseconds: 1));

      final copy = original.copyWith(data: {'new': 'data'});

      expect(copy.timestamp, equals(originalTime));
    });

    test('should handle equality correctly', () {
      final payload1 = TestPayload('same', 1);
      final payload2 = TestPayload('same', 1);
      final payload3 = TestPayload('different', 2);

      final result1 = ABUSResult.success(
        payload: payload1,
        interactionId: 'test',
      );
      final result2 = ABUSResult.success(
        payload: payload2,
        interactionId: 'test',
      );
      final result3 = ABUSResult.success(
        payload: payload3,
        interactionId: 'test',
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('should handle toString correctly', () {
      final result = ABUSResult.success(
        payload: TestPayload('test', 1),
        interactionId: 'string_test',
      );

      final string = result.toString();
      expect(string, contains('success: true'));
      expect(string, contains('id: string_test'));
      expect(string, contains('hasPayload: true'));
    });

    test('should handle error result toString', () {
      final result = ABUSResult.error(
        'Test error',
        interactionId: 'error_string_test',
      );

      final string = result.toString();
      expect(string, contains('success: false'));
      expect(string, contains('error: Test error'));
      expect(string, contains('id: error_string_test'));
      expect(string, contains('hasPayload: false'));
    });

    test('should handle metadata properly', () {
      final result = ABUSResult.success(
        metadata: {
          'source': 'test',
          'timestamp': 12345,
          'tags': ['tag1', 'tag2'],
        },
      );

      expect(result.metadata!['source'], equals('test'));
      expect(result.metadata!['timestamp'], equals(12345));
      expect(result.metadata!['tags'], equals(['tag1', 'tag2']));
    });

    test('should handle complex payload types', () {
      final complexPayload = ComplexPayload(
        TestPayload('nested', 42),
        ['item1', 'item2'],
        {'meta': 'data'},
      );

      final result = ABUSResult.success(payload: complexPayload);

      expect(result.hasPayloadType<ComplexPayload>(), isTrue);
      expect(result.getPayload<ComplexPayload>(), equals(complexPayload));

      final retrieved = result.getPayload<ComplexPayload>()!;
      expect(retrieved.nested.name, equals('nested'));
      expect(retrieved.list.length, equals(2));
      expect(retrieved.map['meta'], equals('data'));
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

class SimplePayload {
  final String data;
  SimplePayload(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimplePayload &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;
}

class ComplexPayload {
  final TestPayload nested;
  final List<String> list;
  final Map<String, dynamic> map;

  ComplexPayload(this.nested, this.list, this.map);

  Map<String, dynamic> toJson() => {
        'nested': nested.toJson(),
        'list': list,
        'map': map,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComplexPayload &&
          runtimeType == other.runtimeType &&
          nested == other.nested &&
          _listEquals(list, other.list) &&
          _mapEquals(map, other.map);

  @override
  int get hashCode => nested.hashCode ^ list.hashCode ^ map.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
