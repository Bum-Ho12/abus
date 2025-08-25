// lib/core/abus_definition.dart
/// Base interface for all interaction definitions
/// Implementations:
abstract class InteractionDefinition {
  /// Unique identifier for this interaction type
  String get id;

  /// Serializes the interaction data
  Map<String, dynamic> toJson();

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

  /// Get the payload object (if any) - for class-based interactions
  Object? get payload => null;

  /// Get the payload type for type checking
  Type? get payloadType => payload?.runtimeType;
}

/// Generic interaction for common use cases
class GenericInteraction extends InteractionDefinition {
  @override
  final String id;
  final Map<String, dynamic> data;
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
    required this.data,
    InteractionDefinition? rollback,
    this.timeout,
    this.supportsOptimistic = true,
    this.priority = 0,
    this.tags = const {},
  }) : _rollback = rollback;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
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
    return id.isNotEmpty && data.isNotEmpty;
  }

  @override
  List<String> getValidationErrors() {
    final errors = <String>[];
    if (id.isEmpty) errors.add('ID cannot be empty');
    if (data.isEmpty) errors.add('Data cannot be empty');
    return errors;
  }

  /// Create from JSON
  factory GenericInteraction.fromJson(Map<String, dynamic> json) {
    return GenericInteraction(
      id: json['id'] as String,
      data: json['data'] as Map<String, dynamic>,
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

/// Class-based interaction for typed payloads
class ClassInteraction<T> extends InteractionDefinition {
  @override
  final String id;
  final T _payload;
  final InteractionDefinition? _rollback;
  @override
  final Duration? timeout;
  @override
  final bool supportsOptimistic;
  @override
  final int priority;
  @override
  final Set<String> tags;

  /// Optional converter for JSON serialization
  /// If not provided, assumes T has toJson() method or is JSON-serializable
  final Map<String, dynamic> Function(T)? _toJsonConverter;

  ClassInteraction({
    required this.id,
    required T payload,
    InteractionDefinition? rollback,
    this.timeout,
    this.supportsOptimistic = true,
    this.priority = 0,
    this.tags = const {},
    Map<String, dynamic> Function(T)? toJsonConverter,
  })  : _payload = payload,
        _rollback = rollback,
        _toJsonConverter = toJsonConverter;

  @override
  T get payload => _payload;

  @override
  Type get payloadType => T;

  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> payloadJson;

    if (_toJsonConverter != null) {
      payloadJson = _toJsonConverter!(_payload);
    } else if (_payload is Map<String, dynamic>) {
      payloadJson = _payload as Map<String, dynamic>;
    } else {
      // Try to call toJson() method if it exists
      try {
        final dynamic obj = _payload;
        payloadJson = obj.toJson() as Map<String, dynamic>;
      } catch (e) {
        // Fallback to string representation
        payloadJson = {'value': _payload.toString(), 'type': T.toString()};
      }
    }

    return {
      'id': id,
      'payload': payloadJson,
      'payloadType': T.toString(),
      'timeout': timeout?.inMilliseconds,
      'supportsOptimistic': supportsOptimistic,
      'priority': priority,
      'tags': tags.toList(),
    };
  }

  @override
  InteractionDefinition? createRollback() => _rollback;

  @override
  bool validate() {
    return id.isNotEmpty && _payload != null;
  }

  @override
  List<String> getValidationErrors() {
    final errors = <String>[];
    if (id.isEmpty) errors.add('ID cannot be empty');
    if (_payload == null) errors.add('Payload cannot be null');
    return errors;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassInteraction<T> &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          _payload == other._payload;

  @override
  int get hashCode => id.hashCode ^ _payload.hashCode;
}

/// Builder for creating interactions easily
class InteractionBuilder<T> {
  String? _id;
  Map<String, dynamic> _data = {};
  T? _payload;
  InteractionDefinition? _rollback;
  Duration? _timeout;
  bool _supportsOptimistic = true;
  int _priority = 0;
  Set<String> _tags = {};
  Map<String, dynamic> Function(T)? _toJsonConverter;

  InteractionBuilder<T> withId(String id) {
    _id = id;
    return this;
  }

  InteractionBuilder<T> withData(Map<String, dynamic> data) {
    _data = data;
    _payload = null; // Clear payload when setting data
    return this;
  }

  InteractionBuilder<T> addData(String key, dynamic value) {
    _data[key] = value;
    return this;
  }

  /// Add typed payload for class-based interactions
  InteractionBuilder<T> withPayload(
    T payload, {
    Map<String, dynamic> Function(T)? converter,
  }) {
    _payload = payload;
    _data = {}; // Clear data when setting payload
    _toJsonConverter = converter;
    return this;
  }

  InteractionBuilder<T> withRollback(InteractionDefinition rollback) {
    _rollback = rollback;
    return this;
  }

  InteractionBuilder<T> withTimeout(Duration timeout) {
    _timeout = timeout;
    return this;
  }

  InteractionBuilder<T> withOptimistic(bool supports) {
    _supportsOptimistic = supports;
    return this;
  }

  InteractionBuilder<T> withPriority(int priority) {
    _priority = priority;
    return this;
  }

  InteractionBuilder<T> withTags(Set<String> tags) {
    _tags = tags;
    return this;
  }

  InteractionBuilder<T> addTag(String tag) {
    _tags.add(tag);
    return this;
  }

  InteractionBuilder<T> addTags(Iterable<String> tags) {
    _tags.addAll(tags);
    return this;
  }

  InteractionDefinition build() {
    if (_id == null) throw ArgumentError('Interaction ID is required');

    InteractionDefinition interaction;

    if (_payload != null) {
      // Create class-based interaction
      interaction = ClassInteraction<T>(
        id: _id!,
        payload: _payload as T,
        rollback: _rollback,
        timeout: _timeout,
        supportsOptimistic: _supportsOptimistic,
        priority: _priority,
        tags: _tags,
        toJsonConverter: _toJsonConverter,
      );
    } else {
      // Create generic interaction
      interaction = GenericInteraction(
        id: _id!,
        data: _data,
        rollback: _rollback,
        timeout: _timeout,
        supportsOptimistic: _supportsOptimistic,
        priority: _priority,
        tags: _tags,
      );
    }

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
    _data = {};
    _payload = null;
    _rollback = null;
    _timeout = null;
    _supportsOptimistic = true;
    _priority = 0;
    _tags = {};
    _toJsonConverter = null;
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

  /// Create a CRUD interaction with Map&lt;String, dynamic&gt; data
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
        .build() as GenericInteraction;
  }

  /// Create a CRUD interaction with typed payload
  static ClassInteraction<T> crudWithPayload<T>({
    required String action,
    required String resourceType,
    required T payload,
    String? resourceId,
    bool optimistic = true,
    Map<String, dynamic> Function(T)? converter,
  }) {
    return InteractionBuilder<T>()
        .withId(
            '${action}_$resourceType${resourceId != null ? '_$resourceId' : ''}')
        .withPayload(payload, converter: converter)
        .withOptimistic(optimistic)
        .addTag('crud')
        .addTag(action)
        .build() as ClassInteraction<T>;
  }
}
