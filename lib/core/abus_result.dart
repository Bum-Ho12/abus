// lib/core/abus_result.dart

/// Result wrapper for ABUS interaction executions.
///
/// Contains the outcome of an interaction execution including success status,
/// data, payload, error information, and metadata.
library;

/// Result of an interaction execution.
///
/// Encapsulates all information about the outcome of an interaction,
/// including success/failure status, any returned data or payload,
/// error messages, and execution metadata.
///
/// Example usage:
/// ```dart
/// // Success result
/// final success = ABUSResult.success(
///   data: {'user_id': 123},
///   payload: user,
/// );
///
/// // Error result
/// final error = ABUSResult.error('User not found');
///
/// // Check result
/// if (success.isSuccess) {
///   final userId = success.data?['user_id'];
///   final user = success.getPayload<User>();
/// }
/// ```
class ABUSResult {
  /// Whether the interaction completed successfully.
  final bool isSuccess;

  /// Generic data returned from the interaction.
  ///
  /// Usually contains JSON-serializable data from API responses
  /// or other operation results.
  final Map<String, dynamic>? data;

  /// Typed payload object returned from the interaction.
  ///
  /// Can contain any object type. Use [getPayload] for type-safe access.
  final Object? payload;

  /// Error message if the interaction failed.
  ///
  /// Null if [isSuccess] is true.
  final String? error;

  /// Timestamp when the result was created.
  final DateTime timestamp;

  /// ID of the interaction that generated this result.
  final String? interactionId;

  /// Additional metadata about the execution.
  ///
  /// May contain debugging information, performance metrics,
  /// rollback status, or other execution details.
  final Map<String, dynamic>? metadata;

  /// Private constructor for internal use.
  ABUSResult._({
    required this.isSuccess,
    this.data,
    this.payload,
    this.error,
    required this.timestamp,
    this.interactionId,
    this.metadata,
  });

  /// Creates a successful result.
  ///
  /// Used when an interaction completes successfully.
  ///
  /// Example:
  /// ```dart
  /// final result = ABUSResult.success(
  ///   data: {'message': 'User created'},
  ///   payload: user,
  ///   interactionId: 'create_user_123',
  ///   metadata: {'execution_time': 150},
  /// );
  /// ```
  ///
  /// Parameters:
  /// - [data]: Optional data map from the operation
  /// - [payload]: Optional typed payload object
  /// - [interactionId]: Optional ID of the interaction
  /// - [metadata]: Optional additional metadata
  factory ABUSResult.success({
    Map<String, dynamic>? data,
    Object? payload,
    String? interactionId,
    Map<String, dynamic>? metadata,
  }) {
    return ABUSResult._(
      isSuccess: true,
      data: data,
      payload: payload,
      timestamp: DateTime.now(),
      interactionId: interactionId,
      metadata: metadata,
    );
  }

  /// Creates an error result.
  ///
  /// Used when an interaction fails with an error.
  ///
  /// Example:
  /// ```dart
  /// final result = ABUSResult.error(
  ///   'Network connection failed',
  ///   interactionId: 'fetch_users',
  ///   metadata: {'retry_count': 3},
  /// );
  /// ```
  ///
  /// Parameters:
  /// - [error]: Human-readable error message
  /// - [interactionId]: Optional ID of the failed interaction
  /// - [metadata]: Optional additional error metadata
  factory ABUSResult.error(
    String error, {
    String? interactionId,
    Map<String, dynamic>? metadata,
  }) {
    return ABUSResult._(
      isSuccess: false,
      error: error,
      timestamp: DateTime.now(),
      interactionId: interactionId,
      metadata: metadata,
    );
  }

  /// Creates a rollback result.
  ///
  /// Used to indicate that an interaction was rolled back due to failure
  /// or timeout. This is a special type of error result.
  ///
  /// Example:
  /// ```dart
  /// final result = ABUSResult.rollback(
  ///   interactionId: 'create_user_123',
  ///   metadata: {'rollback_reason': 'API timeout'},
  /// );
  /// ```
  ///
  /// Parameters:
  /// - [interactionId]: Optional ID of the rolled back interaction
  /// - [metadata]: Optional rollback metadata
  factory ABUSResult.rollback({
    String? interactionId,
    Map<String, dynamic>? metadata,
  }) {
    return ABUSResult._(
      isSuccess: false,
      error: 'Rollback',
      timestamp: DateTime.now(),
      interactionId: interactionId,
      metadata: {
        ...?metadata,
        'rollback': true,
      },
    );
  }

  /// Gets the payload cast to a specific type.
  ///
  /// Returns the payload cast to type [T] if it's compatible,
  /// otherwise returns null.
  ///
  /// Example:
  /// ```dart
  /// final user = result.getPayload<User>();
  /// if (user != null) {
  ///   print('User: ${user.name}');
  /// }
  /// ```
  ///
  /// Type parameter [T]: The expected payload type
  /// Returns the payload as [T] or null if not compatible
  T? getPayload<T>() {
    if (payload is T) {
      return payload as T;
    }
    return null;
  }

  /// Gets the runtime type of the payload.
  ///
  /// Returns null if no payload exists.
  Type? get payloadType => payload?.runtimeType;

  /// Checks if the payload is of a specific type.
  ///
  /// Example:
  /// ```dart
  /// if (result.hasPayloadType<User>()) {
  ///   final user = result.payload as User;
  /// }
  /// ```
  ///
  /// Type parameter [T]: The type to check against
  /// Returns true if payload is of type [T]
  bool hasPayloadType<T>() => payload is T;

  /// Creates a copy of this result with updated values.
  ///
  /// Useful for transforming results while preserving most properties.
  ///
  /// Example:
  /// ```dart
  /// final newResult = result.copyWith(
  ///   payload: transformedUser,
  ///   metadata: {'transformed': true},
  /// );
  /// ```
  ///
  /// Parameters: All parameters are optional and default to current values
  /// Returns a new [ABUSResult] with updated values
  ABUSResult copyWith({
    bool? isSuccess,
    Map<String, dynamic>? data,
    Object? payload,
    String? error,
    DateTime? timestamp,
    String? interactionId,
    Map<String, dynamic>? metadata,
  }) {
    return ABUSResult._(
      isSuccess: isSuccess ?? this.isSuccess,
      data: data ?? this.data,
      payload: payload ?? this.payload,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
      interactionId: interactionId ?? this.interactionId,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Converts this result to JSON format.
  ///
  /// Useful for serialization, logging, and debugging.
  /// Note that complex payload objects may not serialize completely
  /// if they don't implement toJson().
  ///
  /// Example:
  /// ```dart
  /// final json = result.toJson();
  /// print('Result: $json');
  /// ```
  ///
  /// Returns a JSON-serializable map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'isSuccess': isSuccess,
      'error': error,
      'timestamp': timestamp.toIso8601String(),
      'interactionId': interactionId,
      'metadata': metadata,
    };

    // Handle data
    if (data != null) {
      json['data'] = data;
    }

    // Handle payload - try toJson() method or leave as-is
    if (payload != null) {
      try {
        final dynamic obj = payload;
        json['payload'] = obj.toJson();
        json['payloadType'] = payload.runtimeType.toString();
      } catch (e) {
        // Payload doesn't have toJson() - store type info only
        json['payloadType'] = payload.runtimeType.toString();
        json['hasPayload'] = true;
      }
    }

    return json;
  }

  /// Creates an [ABUSResult] from JSON data.
  ///
  /// Note that payload objects will be restored as raw data
  /// and may need additional processing to restore original types.
  ///
  /// Example:
  /// ```dart
  /// final json = {'isSuccess': true, 'data': {'id': 123}};
  /// final result = ABUSResult.fromJson(json);
  /// ```
  ///
  /// Parameters:
  /// - [json]: JSON map containing result data
  ///
  /// Returns a new [ABUSResult] instance
  factory ABUSResult.fromJson(Map<String, dynamic> json) {
    return ABUSResult._(
      isSuccess: json['isSuccess'] as bool,
      data: json['data'] as Map<String, dynamic>?,
      payload: json['payload'], // Raw payload data
      error: json['error'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      interactionId: json['interactionId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() =>
      'ABUSResult(success: $isSuccess, error: $error, id: $interactionId, hasPayload: ${payload != null})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ABUSResult &&
          runtimeType == other.runtimeType &&
          isSuccess == other.isSuccess &&
          error == other.error &&
          interactionId == other.interactionId &&
          payload == other.payload;

  @override
  int get hashCode =>
      isSuccess.hashCode ^
      error.hashCode ^
      interactionId.hashCode ^
      payload.hashCode;
}
