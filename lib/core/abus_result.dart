// lib/core/abus_result.dart
import 'package:abus/core/abus_payload.dart';

/// Result of an interaction execution
class ABUSResult {
  final bool isSuccess;
  final SmartPayload? _smartPayload;
  final String? error;
  final DateTime timestamp;
  final String? interactionId;
  final Map<String, dynamic>? metadata;

  ABUSResult._({
    required this.isSuccess,
    SmartPayload? payload,
    this.error,
    required this.timestamp,
    this.interactionId,
    this.metadata,
  }) : _smartPayload = payload;

  /// BACKWARD COMPATIBILITY: Legacy data property
  /// Returns Map &lt; String, dynamic &gt;? for backward compatibility
  @Deprecated('Use getData<Map<String, dynamic>>() or rawData instead')
  Map<String, dynamic>? get data {
    final rawData = _smartPayload?.raw;
    if (rawData is Map<String, dynamic>) {
      return rawData;
    } else if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    return null; // For non-map payloads, return null to maintain compatibility
  }

  /// Get the raw payload data (new API)
  dynamic get rawData => _smartPayload?.raw;

  /// Get typed data
  T? getData<T>() => _smartPayload?.as<T>();

  /// Check if data is of specific type
  bool isData<T>() => _smartPayload?.isOf<T>() ?? false;

  /// Get data type name
  String? get dataType => _smartPayload?.type;

  /// BACKWARD COMPATIBILITY: Support both old Map &lt; String, dynamic &gt; and new dynamic data
  factory ABUSResult.success({
    dynamic data,
    Map<String, dynamic>? legacyData, // For explicit backward compatibility
    String? interactionId,
    Map<String, dynamic>? metadata,
  }) {
    // Prioritize the new 'data' parameter, but fallback to legacyData if provided
    final payloadData = data ?? legacyData;
    final payload = payloadData != null ? SmartPayload.from(payloadData) : null;

    return ABUSResult._(
      isSuccess: true,
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

  ABUSResult copyWith({
    bool? isSuccess,
    dynamic data,
    String? error,
    DateTime? timestamp,
    String? interactionId,
    Map<String, dynamic>? metadata,
  }) {
    SmartPayload? newPayload;
    if (data != null) {
      newPayload = SmartPayload.from(data);
    }

    return ABUSResult._(
      isSuccess: isSuccess ?? this.isSuccess,
      payload: newPayload ?? _smartPayload,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
      interactionId: interactionId ?? this.interactionId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'payload': _smartPayload?.toJson(),
      // BACKWARD COMPATIBILITY: Include data field in JSON
      'data': data,
      'error': error,
      'timestamp': timestamp.toIso8601String(),
      'interactionId': interactionId,
      'metadata': metadata,
    };
  }

  /// Create from JSON - supports both old and new formats
  factory ABUSResult.fromJson(Map<String, dynamic> json) {
    SmartPayload? payload;

    // Support both new 'payload' and old 'data' formats
    if (json.containsKey('payload') && json['payload'] != null) {
      final payloadJson = json['payload'] as Map<String, dynamic>;
      payload = SmartPayload.fromJson(payloadJson);
    } else if (json.containsKey('data') && json['data'] != null) {
      // BACKWARD COMPATIBILITY: Support old 'data' field
      payload = SmartPayload.from(json['data']);
    }

    return ABUSResult._(
      isSuccess: json['isSuccess'] as bool,
      payload: payload,
      error: json['error'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      interactionId: json['interactionId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() =>
      'ABUSResult(success: $isSuccess, error: $error, id: $interactionId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ABUSResult &&
          runtimeType == other.runtimeType &&
          isSuccess == other.isSuccess &&
          error == other.error &&
          interactionId == other.interactionId;

  @override
  int get hashCode =>
      isSuccess.hashCode ^ error.hashCode ^ interactionId.hashCode;
}
