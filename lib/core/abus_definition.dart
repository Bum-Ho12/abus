// lib/core/abus_definition.dart
import 'package:abus/core/abus_payload.dart';

/// Base interface for all interaction definitions
abstract class InteractionDefinition {
  /// Unique identifier for this interaction type
  String get id;

  /// Serializes the interaction data
  Map<String, dynamic> toJson();

  /// Get the payload (any type)
  dynamic get payload;

  /// Get typed payload
  T? getPayload<T>() {
    if (payload is SmartPayload) {
      return (payload as SmartPayload).as<T>();
    } else if (payload is T) {
      return payload as T;
    }
    return null;
  }

  /// Creates a rollback interaction (optional)
  InteractionDefinition? createRollback() => null;

  /// Timeout for the interaction (optional)
  Duration? get timeout => null;

  /// Whether this interaction supports optimistic updates
  bool get supportsOptimistic => true;

  /// Priority level for execution order (higher = more priority)
  int get priority => 0;

  /// Tags for categorizing interactions
  Set<String> get tags => const {};

  /// Validation method
  bool validate() => true;

  /// Get validation errors
  List<String> getValidationErrors() => [];
}

/// Generic interaction for common use cases
class GenericInteraction extends InteractionDefinition {
  @override
  final String id;
  final SmartPayload _smartPayload;
  final InteractionDefinition? _rollback;
  @override
  final Duration? timeout;
  @override
  final bool supportsOptimistic;
  @override
  final int priority;
  @override
  final Set<String> tags;

  GenericInteraction({
    required this.id,
    dynamic payload,
    Map<String, dynamic>? data, // Keep for backward compatibility
    InteractionDefinition? rollback,
    this.timeout,
    this.supportsOptimistic = true,
    this.priority = 0,
    this.tags = const {},
  })  : _smartPayload = SmartPayload.from(payload ?? data ?? {}),
        _rollback = rollback;

  @override
  dynamic get payload => _smartPayload.raw;

  /// BACKWARD COMPATIBILITY: Legacy data property
  /// Returns Map &lt; String, dynamic &gt; for backward compatibility
  @Deprecated('Use getPayload<Map<String, dynamic>>() or payload instead')
  Map<String, dynamic> get data {
    final payloadData = _smartPayload.raw;
    if (payloadData is Map<String, dynamic>) {
      return payloadData;
    } else if (payloadData is Map) {
      return Map<String, dynamic>.from(payloadData);
    }
    // For non-map payloads, return empty map to maintain compatibility
    return <String, dynamic>{};
  }

  /// Get typed payload
  @override
  T? getPayload<T>() => _smartPayload.as<T>();

  /// Check if payload is of specific type
  bool isPayload<T>() => _smartPayload.isOf<T>();

  /// Get payload type name
  String get payloadType => _smartPayload.type;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'payload': _smartPayload.toJson(),
        // BACKWARD COMPATIBILITY: Include data field in JSON
        'data': data,
        'timeout': timeout?.inMilliseconds,
        'supportsOptimistic': supportsOptimistic,
        'priority': priority,
        'tags': tags.toList(),
      };

  @override
  InteractionDefinition? createRollback() => _rollback;

  @override
  bool validate() {
    return id.isNotEmpty && _smartPayload.validate();
  }

  @override
  List<String> getValidationErrors() {
    final errors = <String>[];
    if (id.isEmpty) errors.add('ID cannot be empty');
    errors.addAll(_smartPayload.getValidationErrors());
    return errors;
  }

  /// Create from JSON - supports both old and new formats
  factory GenericInteraction.fromJson(Map<String, dynamic> json) {
    dynamic payloadData;

    // Support both new 'payload' and old 'data' formats
    if (json.containsKey('payload')) {
      final payloadJson = json['payload'] as Map<String, dynamic>?;
      if (payloadJson != null) {
        final smartPayload = SmartPayload.fromJson(payloadJson);
        payloadData = smartPayload.raw;
      }
    } else if (json.containsKey('data')) {
      // BACKWARD COMPATIBILITY: Support old 'data' field
      payloadData = json['data'] as Map<String, dynamic>?;
    }

    return GenericInteraction(
      id: json['id'] as String,
      payload: payloadData,
      timeout: json['timeout'] != null
          ? Duration(milliseconds: json['timeout'] as int)
          : null,
      supportsOptimistic: json['supportsOptimistic'] as bool? ?? true,
      priority: json['priority'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>().toSet() ?? {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenericInteraction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Builder for creating interactions easily
class InteractionBuilder {
  String? _id;
  dynamic _payload;
  InteractionDefinition? _rollback;
  Duration? _timeout;
  bool _supportsOptimistic = true;
  int _priority = 0;
  Set<String> _tags = {};

  InteractionBuilder withId(String id) {
    _id = id;
    return this;
  }

  /// Set payload with any type (classes, maps, primitives, ...)
  InteractionBuilder withPayload(dynamic payload) {
    _payload = payload;
    return this;
  }

  /// Set map data/original key-value (backward compatibility)
  InteractionBuilder withData(Map<String, dynamic> data) {
    _payload = data;
    return this;
  }

  /// Single key-value pair to map payload (backward compatibility)
  InteractionBuilder addData(String key, dynamic value) {
    if (_payload is Map<String, dynamic>) {
      (_payload as Map<String, dynamic>)[key] = value;
    } else if (_payload == null) {
      _payload = <String, dynamic>{key: value};
    } else {
      throw ArgumentError(
          'Cannot add data to non-map payload. Current payload type: ${_payload.runtimeType}. '
          'Use withPayload() to set a new payload or withData() to replace with a map.');
    }
    return this;
  }

  InteractionBuilder withRollback(InteractionDefinition rollback) {
    _rollback = rollback;
    return this;
  }

  InteractionBuilder withTimeout(Duration timeout) {
    _timeout = timeout;
    return this;
  }

  InteractionBuilder withOptimistic(bool supports) {
    _supportsOptimistic = supports;
    return this;
  }

  InteractionBuilder withPriority(int priority) {
    _priority = priority;
    return this;
  }

  InteractionBuilder withTags(Set<String> tags) {
    _tags = tags;
    return this;
  }

  InteractionBuilder addTag(String tag) {
    _tags.add(tag);
    return this;
  }

  InteractionBuilder addTags(Iterable<String> tags) {
    _tags.addAll(tags);
    return this;
  }

  GenericInteraction build() {
    if (_id == null) throw ArgumentError('Interaction ID is required');

    final interaction = GenericInteraction(
      id: _id!,
      payload: _payload,
      rollback: _rollback,
      timeout: _timeout,
      supportsOptimistic: _supportsOptimistic,
      priority: _priority,
      tags: _tags,
    );

    // Validate before returning
    if (!interaction.validate()) {
      throw ArgumentError(
          'Invalid interaction: ${interaction.getValidationErrors().join(', ')}');
    }

    return interaction;
  }

  /// Reset builder for reuse
  InteractionBuilder reset() {
    _id = null;
    _payload = null;
    _rollback = null;
    _timeout = null;
    _supportsOptimistic = true;
    _priority = 0;
    _tags = {};
    return this;
  }
}

/// Predefined interaction types for common scenarios
class InteractionTypes {
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
  static const String fetch = 'fetch';
  static const String sync = 'sync';
  static const String upload = 'upload';
  static const String download = 'download';

  /// Create a CRUD interaction
  static GenericInteraction crud({
    required String action,
    required String resourceType,
    String? resourceId,
    Map<String, dynamic>? payload,
    bool optimistic = true,
  }) {
    return InteractionBuilder()
        .withId(
            '${action}_$resourceType${resourceId != null ? '_$resourceId' : ''}')
        .withData({
          'action': action,
          'resourceType': resourceType,
          if (resourceId != null) 'resourceId': resourceId,
          if (payload != null) 'payload': payload,
        })
        .withOptimistic(optimistic)
        .addTag('crud')
        .addTag(action)
        .build();
  }
}
