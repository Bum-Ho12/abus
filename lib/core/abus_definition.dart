// lib/core/abus_definition.dart
/// Base interface for all interaction definitions
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

/// Builder for creating interactions easily
class InteractionBuilder {
  String? _id;
  Map<String, dynamic> _data = {};
  InteractionDefinition? _rollback;
  Duration? _timeout;
  bool _supportsOptimistic = true;
  int _priority = 0;
  Set<String> _tags = {};

  InteractionBuilder withId(String id) {
    _id = id;
    return this;
  }

  InteractionBuilder withData(Map<String, dynamic> data) {
    _data = data;
    return this;
  }

  InteractionBuilder addData(String key, dynamic value) {
    _data[key] = value;
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
      data: _data,
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
    _data = {};
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
