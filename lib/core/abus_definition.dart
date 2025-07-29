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

  GenericInteraction({
    required this.id,
    required this.data,
    InteractionDefinition? rollback,
    this.timeout,
    this.supportsOptimistic = true,
  }) : _rollback = rollback;

  @override
  Map<String, dynamic> toJson() => data;

  @override
  InteractionDefinition? createRollback() => _rollback;
}

/// Builder for creating interactions easily
class InteractionBuilder {
  String? _id;
  Map<String, dynamic> _data = {};
  InteractionDefinition? _rollback;
  Duration? _timeout;
  bool _supportsOptimistic = true;

  InteractionBuilder withId(String id) {
    _id = id;
    return this;
  }

  InteractionBuilder withData(Map<String, dynamic> data) {
    _data = data;
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

  GenericInteraction build() {
    if (_id == null) throw ArgumentError('Interaction ID is required');
    return GenericInteraction(
      id: _id!,
      data: _data,
      rollback: _rollback,
      timeout: _timeout,
      supportsOptimistic: _supportsOptimistic,
    );
  }
}
