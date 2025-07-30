// lib/core/abus_result.dart
/// Result of an interaction execution
class InteractionResult {
  final bool isSuccess;
  final Map<String, dynamic>? data;
  final String? error;
  final DateTime timestamp;
  final String? interactionId;
  final Map<String, dynamic>? metadata;

  InteractionResult._({
    required this.isSuccess,
    this.data,
    this.error,
    required this.timestamp,
    this.interactionId,
    this.metadata,
  });

  factory InteractionResult.success({
    Map<String, dynamic>? data,
    String? interactionId,
    Map<String, dynamic>? metadata,
  }) {
    return InteractionResult._(
      isSuccess: true,
      data: data,
      timestamp: DateTime.now(),
      interactionId: interactionId,
      metadata: metadata,
    );
  }

  factory InteractionResult.error(
    String error, {
    String? interactionId,
    Map<String, dynamic>? metadata,
  }) {
    return InteractionResult._(
      isSuccess: false,
      error: error,
      timestamp: DateTime.now(),
      interactionId: interactionId,
      metadata: metadata,
    );
  }

  /// Create a copy with updated values
  InteractionResult copyWith({
    bool? isSuccess,
    Map<String, dynamic>? data,
    String? error,
    DateTime? timestamp,
    String? interactionId,
    Map<String, dynamic>? metadata,
  }) {
    return InteractionResult._(
      isSuccess: isSuccess ?? this.isSuccess,
      data: data ?? this.data,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
      interactionId: interactionId ?? this.interactionId,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'data': data,
      'error': error,
      'timestamp': timestamp.toIso8601String(),
      'interactionId': interactionId,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory InteractionResult.fromJson(Map<String, dynamic> json) {
    return InteractionResult._(
      isSuccess: json['isSuccess'] as bool,
      data: json['data'] as Map<String, dynamic>?,
      error: json['error'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      interactionId: json['interactionId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() =>
      'InteractionResult(success: $isSuccess, error: $error, id: $interactionId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InteractionResult &&
          runtimeType == other.runtimeType &&
          isSuccess == other.isSuccess &&
          error == other.error &&
          interactionId == other.interactionId;

  @override
  int get hashCode =>
      isSuccess.hashCode ^ error.hashCode ^ interactionId.hashCode;
}
