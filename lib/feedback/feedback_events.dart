// lib/feedback/feedback_events.dart

import 'dart:ui';

/// Base class for all feedback events
abstract class FeedbackEvent {
  /// Unique identifier for this feedback event
  final String id;

  /// Message to display
  final String message;

  /// Priority for ordering (higher = more important)
  final int priority;

  /// Duration to show the feedback
  final Duration? duration;

  /// Tags for categorization and deduplication
  final Set<String> tags;

  /// Whether this event can be dismissed by user
  final bool dismissible;

  /// Metadata for additional properties
  final Map<String, dynamic> metadata;

  const FeedbackEvent({
    required this.id,
    required this.message,
    this.priority = 0,
    this.duration,
    this.tags = const {},
    this.dismissible = true,
    this.metadata = const {},
  });

  /// Create deduplication key for this event
  String get deduplicationKey => '$runtimeType:$message:${tags.join(',')}';

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'priority': priority,
        'duration': duration?.inMilliseconds,
        'tags': tags.toList(),
        'dismissible': dismissible,
        'metadata': metadata,
        'type': runtimeType.toString(),
      };
}

/// Snackbar feedback event
class SnackbarEvent extends FeedbackEvent {
  final SnackbarType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SnackbarEvent({
    required super.id,
    required super.message,
    this.type = SnackbarType.info,
    this.actionLabel,
    this.onAction,
    super.priority,
    super.duration = const Duration(seconds: 4),
    super.tags,
    super.dismissible,
    super.metadata,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'snackbarType': type.name,
        'actionLabel': actionLabel,
      };
}

/// Banner feedback event
class BannerEvent extends FeedbackEvent {
  final BannerType type;
  final List<BannerAction> actions;

  const BannerEvent({
    required super.id,
    required super.message,
    this.type = BannerType.info,
    this.actions = const [],
    super.priority = 1, // Banners typically higher priority than snackbars
    super.duration, // Banners often persist until dismissed
    super.tags,
    super.dismissible = true,
    super.metadata,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'bannerType': type.name,
        'actionsCount': actions.length,
      };
}

/// Toast feedback event (platform agnostic)
class ToastEvent extends FeedbackEvent {
  final ToastType type;

  const ToastEvent({
    required super.id,
    required super.message,
    this.type = ToastType.info,
    super.priority,
    super.duration = const Duration(seconds: 2),
    super.tags,
    super.dismissible = false, // Toasts auto-dismiss
    super.metadata,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'toastType': type.name,
      };
}

// Enums and supporting classes
enum SnackbarType { info, success, warning, error }

enum BannerType { info, success, warning, error }

enum ToastType { info, success, warning, error }

class BannerAction {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  const BannerAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });
}
