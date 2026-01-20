// lib/core/abus_definition.dart

/// Core interaction definitions and builders for the ABUS system.
///
/// This file contains the base interfaces and implementations for defining
/// interactions that can be executed by ABUS handlers.
library;

/// Base interface for all interaction definitions.
///
/// An interaction represents a unit of work that can be executed with
/// optimistic updates, rollbacks, and API calls. Implementations include
/// [GenericInteraction] for simple data-based interactions and
/// [ClassInteraction] for typed payload interactions.
abstract class InteractionDefinition {
  /// Unique identifier for this interaction type.
  ///
  /// This should be descriptive and unique within your application.
  /// Example: 'create_user', 'update_profile', 'delete_post'
  String get id;

  /// Serializes the interaction data to JSON format.
  ///
  /// Used for logging, debugging, and network transmission.
  /// Must return a JSON-serializable map.
  Map<String, dynamic> toJson();

  /// Creates a rollback interaction (optional).
  ///
  /// If provided, this interaction will be executed if the main
  /// interaction fails and needs to be rolled back.
  ///
  /// Returns null if rollback is not supported.
  InteractionDefinition? createRollback() => null;

  /// Timeout duration for the interaction (optional).
  ///
  /// If specified, the interaction will fail if it takes longer
  /// than this duration to complete.
  ///
  /// Returns null to use system default timeout.
  Duration? get timeout => null;

  /// Whether this interaction supports optimistic updates.
  ///
  /// When true, the UI will be updated immediately before the
  /// API call completes. If the API call fails, changes are rolled back.
  ///
  /// Defaults to true.
  bool get supportsOptimistic => true;

  /// Priority level for execution order (higher = more priority).
  ///
  /// When multiple interactions are queued, higher priority
  /// interactions are executed first.
  ///
  /// Defaults to 0.
  int get priority => 0;

  /// Tags for categorizing interactions.
  ///
  /// Useful for filtering, logging, and batch operations.
  /// Example: {'user', 'profile', 'update'}
  ///
  /// Defaults to empty set.
  Set<String> get tags => const {};

  /// Validates the interaction data.
  ///
  /// Returns true if the interaction is valid and can be executed.
  /// Override this method to add custom validation logic.
  ///
  /// Defaults to true.
  bool validate() => true;

  /// Gets validation error messages.
  ///
  /// Returns a list of human-readable error messages explaining
  /// why the interaction is invalid. Called when [validate] returns false.
  ///
  /// Defaults to empty list.
  List<String> getValidationErrors() => [];

  /// Gets the payload object (if any) for class-based interactions.
  ///
  /// Returns the typed payload for [ClassInteraction] instances,
  /// null for [GenericInteraction] instances.
  Object? get payload => null;

  /// Gets the payload type for type checking.
  ///
  /// Returns the runtime type of the payload, or null if no payload exists.
  Type? get payloadType => payload?.runtimeType;
}

/// Generic interaction for common use cases with Map-based data.
///
/// Use this for simple interactions where you don't need typed payloads.
/// The data is stored as a [Map<String, dynamic>] which can contain
/// any JSON-serializable values.
///
/// Example:
/// ```dart
/// final interaction = GenericInteraction(
///   id: 'create_user',
///   data: {
///     'name': 'John Doe',
///     'email': 'john@example.com',
///     'age': 30,
///   },
///   timeout: Duration(seconds: 10),
///   tags: {'user', 'create'},
/// );
/// ```
class GenericInteraction extends InteractionDefinition {
  @override
  final String id;

  /// The interaction data as a map.
  ///
  /// Should contain all the information needed to execute this interaction.
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

  /// Creates a new generic interaction.
  ///
  /// Parameters:
  /// - [id]: Unique identifier for the interaction
  /// - [data]: Map containing the interaction data
  /// - [rollback]: Optional rollback interaction
  /// - [timeout]: Optional timeout duration
  /// - [supportsOptimistic]: Whether optimistic updates are supported (default: true)
  /// - [priority]: Execution priority (default: 0)
  /// - [tags]: Set of tags for categorization (default: empty)
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

  /// Creates a [GenericInteraction] from JSON data.
  ///
  /// Example:
  /// ```dart
  /// final json = {
  ///   'id': 'create_user',
  ///   'data': {'name': 'John'},
  ///   'timeout': 5000,
  ///   'priority': 1,
  /// };
  /// final interaction = GenericInteraction.fromJson(json);
  /// ```
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

/// Class-based interaction for typed payloads.
///
/// Use this when you want type safety and have a specific class
/// representing your interaction data.
///
/// Example:
/// ```dart
/// class User {
///   final String name;
///   final String email;
///
///   User(this.name, this.email);
///
///   Map<String, dynamic> toJson() => {'name': name, 'email': email};
/// }
///
/// final interaction = ClassInteraction<User>(
///   id: 'create_user',
///   payload: User('John', 'john@example.com'),
/// );
/// ```
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

  /// Optional converter for JSON serialization.
  ///
  /// If not provided, assumes T has a toJson() method or is JSON-serializable.
  final Map<String, dynamic> Function(T)? _toJsonConverter;

  /// Creates a new class-based interaction.
  ///
  /// Parameters:
  /// - [id]: Unique identifier for the interaction
  /// - [payload]: The typed payload object
  /// - [rollback]: Optional rollback interaction
  /// - [timeout]: Optional timeout duration
  /// - [supportsOptimistic]: Whether optimistic updates are supported (default: true)
  /// - [priority]: Execution priority (default: 0)
  /// - [tags]: Set of tags for categorization (default: empty)
  /// - [toJsonConverter]: Optional custom JSON converter function
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

/// Builder for creating interactions with a fluent API.
///
/// Provides a convenient way to construct interactions step by step.
/// Can create both [GenericInteraction] and [ClassInteraction] instances
/// depending on whether you use [withData] or [withPayload].
///
/// Example:
/// ```dart
/// // Generic interaction
/// final genericInteraction = InteractionBuilder()
///   .withId('update_user')
///   .withData({'name': 'Jane'})
///   .withTimeout(Duration(seconds: 5))
///   .addTag('user')
///   .build();
///
/// // Class interaction
/// final classInteraction = InteractionBuilder<User>()
///   .withId('create_user')
///   .withPayload(User('John', 'john@example.com'))
///   .withPriority(1)
///   .build();
/// ```
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

  /// Sets the interaction ID.
  ///
  /// The ID should be unique and descriptive.
  InteractionBuilder<T> withId(String id) {
    _id = id;
    return this;
  }

  /// Sets the interaction data for generic interactions.
  ///
  /// This clears any previously set payload and creates a [GenericInteraction].
  InteractionBuilder<T> withData(Map<String, dynamic> data) {
    _data = data;
    _payload = null; // Clear payload when setting data
    return this;
  }

  /// Adds a single key-value pair to the interaction data.
  InteractionBuilder<T> addData(String key, dynamic value) {
    _data[key] = value;
    return this;
  }

  /// Sets the typed payload for class-based interactions.
  ///
  /// This clears any previously set data and creates a [ClassInteraction].
  ///
  /// Parameters:
  /// - [payload]: The typed payload object
  /// - [converter]: Optional custom JSON converter function
  InteractionBuilder<T> withPayload(
    T payload, {
    Map<String, dynamic> Function(T)? converter,
  }) {
    _payload = payload;
    _data = {}; // Clear data when setting payload
    _toJsonConverter = converter;
    return this;
  }

  /// Sets the rollback interaction.
  InteractionBuilder<T> withRollback(InteractionDefinition rollback) {
    _rollback = rollback;
    return this;
  }

  /// Sets the timeout duration.
  InteractionBuilder<T> withTimeout(Duration timeout) {
    _timeout = timeout;
    return this;
  }

  /// Sets whether optimistic updates are supported.
  InteractionBuilder<T> withOptimistic(bool supports) {
    _supportsOptimistic = supports;
    return this;
  }

  /// Sets the execution priority.
  InteractionBuilder<T> withPriority(int priority) {
    _priority = priority;
    return this;
  }

  /// Sets the tags set, replacing any existing tags.
  InteractionBuilder<T> withTags(Set<String> tags) {
    _tags = tags;
    return this;
  }

  /// Adds a single tag.
  InteractionBuilder<T> addTag(String tag) {
    _tags.add(tag);
    return this;
  }

  /// Adds multiple tags.
  InteractionBuilder<T> addTags(Iterable<String> tags) {
    _tags.addAll(tags);
    return this;
  }

  /// Builds the interaction.
  ///
  /// Creates either a [GenericInteraction] or [ClassInteraction] depending
  /// on whether a payload or data was set.
  ///
  /// Throws [ArgumentError] if the ID is missing or validation fails.
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

  /// Resets the builder to its initial state for reuse.
  ///
  /// Returns this builder instance for method chaining.
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

/// Predefined interaction types and factory methods for common scenarios.
///
/// Provides convenience methods for creating standard CRUD operations
/// and other common interaction patterns.
///
/// Types available:
/// - [create]
/// - [update]
/// - [delete]
/// - [fetch]
/// - [sync]
/// - [upload]
/// - [download]
class InteractionTypes {
  /// Private constructor to prevent instantiation.
  InteractionTypes._();

  // Common interaction type constants
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
  static const String fetch = 'fetch';
  static const String sync = 'sync';
  static const String upload = 'upload';
  static const String download = 'download';

  /// Creates a CRUD interaction with [Map<String, dynamic>] data.
  ///
  /// Automatically generates an ID in the format: `{action}_{resourceType}_{resourceId?}`
  ///
  /// Example:
  /// ```dart
  /// final createUser = InteractionTypes.crud(
  ///   action: 'create',
  ///   resourceType: 'user',
  ///   payload: {'name': 'John', 'email': 'john@example.com'},
  /// );
  /// // ID: 'create_user'
  ///
  /// final updatePost = InteractionTypes.crud(
  ///   action: 'update',
  ///   resourceType: 'post',
  ///   resourceId: '123',
  ///   payload: {'title': 'Updated Title'},
  /// );
  /// // ID: 'update_post_123'
  /// ```
  ///
  /// Parameters:
  /// - [action]: The CRUD action (create, update, delete, etc.)
  /// - [resourceType]: The type of resource being operated on
  /// - [resourceId]: Optional specific resource identifier
  /// - [payload]: Optional data payload
  /// - [optimistic]: Whether to use optimistic updates (default: true)
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

  /// Creates a CRUD interaction with typed payload.
  ///
  /// Similar to [crud] but uses a typed payload instead of a map.
  ///
  /// Example:
  /// ```dart
  /// class User {
  ///   final String name, email;
  ///   User(this.name, this.email);
  ///   Map<String, dynamic> toJson() => {'name': name, 'email': email};
  /// }
  ///
  /// final createUser = InteractionTypes.crudWithPayload<User>(
  ///   action: 'create',
  ///   resourceType: 'user',
  ///   payload: User('John', 'john@example.com'),
  /// );
  /// ```
  ///
  /// Parameters:
  /// - [action]: The CRUD action (create, update, delete, etc.)
  /// - [resourceType]: The type of resource being operated on
  /// - [payload]: The typed payload object
  /// - [resourceId]: Optional specific resource identifier
  /// - [optimistic]: Whether to use optimistic updates (default: true)
  /// - [converter]: Optional custom JSON converter function
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
