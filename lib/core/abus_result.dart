// lib/core/abus_result.dart

/// Result of an interaction execution
class ABUSResult {
  final bool isSuccess;
  final Map<String, dynamic>? data;
  final Object? payload;
  final String? error;
  final DateTime timestamp;
  final String? interactionId;
  final Map<String, dynamic>? metadata;

  ABUSResult._({
    required this.isSuccess,
    this.data,
    this.payload,
    this.error,
    required this.timestamp,
    this.interactionId,
    this.metadata,
  });

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

  /// Create a rollback result
  /// This is used to indicate that an interaction was rolled back
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

  /// Typed payload getter with type checking
  T? getPayload<T>() {
    if (payload is T) {
      return payload as T;
    }
    return null;
  }

  /// Get payload type
  Type? get payloadType => payload?.runtimeType;

  /// Check if payload is of specific type
  bool hasPayloadType<T>() => payload is T;

  /// Create a copy with updated values
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

  /// Convert to JSON for serialization
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

  /// Create from JSON
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
