// lib/core/abus_result.dart
/// Result of an interaction execution
class InteractionResult {
  final bool isSuccess;
  final Map<String, dynamic>? data;
  final String? error;
  final DateTime timestamp;
  final String? interactionId;

  InteractionResult._({
    required this.isSuccess,
    this.data,
    this.error,
    required this.timestamp,
    this.interactionId,
  });

  factory InteractionResult.success({
    Map<String, dynamic>? data,
    String? interactionId,
  }) {
    return InteractionResult._(
      isSuccess: true,
      data: data,
      timestamp: DateTime.now(),
      interactionId: interactionId,
    );
  }

  factory InteractionResult.error(
    String error, {
    String? interactionId,
  }) {
    return InteractionResult._(
      isSuccess: false,
      error: error,
      timestamp: DateTime.now(),
      interactionId: interactionId,
    );
  }

  @override
  String toString() => 'InteractionResult(success: $isSuccess, error: $error)';
}
