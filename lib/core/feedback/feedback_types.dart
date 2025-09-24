// lib/feedback/feedback_types.dart

/// Priority levels for feedback events
enum FeedbackPriority {
  low(0),
  normal(1),
  high(2),
  critical(3);

  const FeedbackPriority(this.value);
  final int value;
}

/// Types of feedback events supported by the system
enum FeedbackType {
  snackbar,
  dialog,
  banner,
  toast,
  notification,
  overlay,
  bottomSheet,
}

/// Severity levels for feedback events
enum FeedbackSeverity {
  info,
  success,
  warning,
  error,
  critical,
}

/// Position for displaying feedback
enum FeedbackPosition {
  top,
  center,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Base class for all feedback events
abstract class FeedbackEvent {
  /// Unique identifier for this feedback event
  final String id;

  /// Type of feedback (snackbar, dialog, etc.)
  final FeedbackType type;

  /// Priority for ordering in queue
  final FeedbackPriority priority;

  /// Severity level
  final FeedbackSeverity severity;

  /// Main message content
  final String message;

  /// Optional title
  final String? title;

  /// Optional subtitle or description
  final String? subtitle;

  /// Duration to display (null = persistent)
  final Duration? duration;

  /// Position to display the feedback
  final FeedbackPosition position;

  /// Whether this event can be dismissed by user
  final bool dismissible;

  /// Whether this event should auto-dismiss
  final bool autoDismiss;

  /// Tags for categorization and filtering
  final Set<String> tags;

  /// Custom data payload
  final Map<String, dynamic>? data;

  /// Timestamp when event was created
  final DateTime timestamp;

  /// Optional timeout for the event
  final Duration? timeout;

  /// Whether to replace similar events
  final bool replaceSimilar;

  /// Deduplication key for preventing duplicates
  final String? deduplicationKey;

  FeedbackEvent({
    required this.id,
    required this.type,
    required this.message,
    this.title,
    this.subtitle,
    this.priority = FeedbackPriority.normal,
    this.severity = FeedbackSeverity.info,
    this.duration,
    this.position = FeedbackPosition.bottom,
    this.dismissible = true,
    this.autoDismiss = true,
    this.tags = const {},
    this.data,
    DateTime? timestamp,
    this.timeout,
    this.replaceSimilar = false,
    this.deduplicationKey,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a copy with updated properties
  FeedbackEvent copyWith({
    String? id,
    FeedbackType? type,
    String? message,
    String? title,
    String? subtitle,
    FeedbackPriority? priority,
    FeedbackSeverity? severity,
    Duration? duration,
    FeedbackPosition? position,
    bool? dismissible,
    bool? autoDismiss,
    Set<String>? tags,
    Map<String, dynamic>? data,
    Duration? timeout,
    bool? replaceSimilar,
    String? deduplicationKey,
  });

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson();

  /// Generate deduplication key based on content
  String generateDeduplicationKey() {
    return deduplicationKey ?? '$type-$message-${title ?? ''}-${severity.name}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Snackbar feedback event
class SnackbarEvent extends FeedbackEvent {
  /// Action text (e.g., "Undo", "Retry")
  final String? actionText;

  /// Callback for action button
  final VoidCallback? onAction;

  /// Whether to show close button
  final bool showCloseButton;

  /// Background color
  final String? backgroundColor;

  /// Text color
  final String? textColor;

  SnackbarEvent({
    required super.id,
    required super.message,
    super.title,
    super.subtitle,
    super.priority,
    super.severity,
    super.duration = const Duration(seconds: 4),
    super.position,
    super.dismissible,
    super.autoDismiss,
    super.tags,
    super.data,
    super.timestamp,
    super.timeout,
    super.replaceSimilar,
    super.deduplicationKey,
    this.actionText,
    this.onAction,
    this.showCloseButton = false,
    this.backgroundColor,
    this.textColor,
  }) : super(
          type: FeedbackType.snackbar,
        );

  @override
  SnackbarEvent copyWith({
    String? id,
    FeedbackType? type,
    String? message,
    String? title,
    String? subtitle,
    FeedbackPriority? priority,
    FeedbackSeverity? severity,
    Duration? duration,
    FeedbackPosition? position,
    bool? dismissible,
    bool? autoDismiss,
    Set<String>? tags,
    Map<String, dynamic>? data,
    Duration? timeout,
    bool? replaceSimilar,
    String? deduplicationKey,
    String? actionText,
    VoidCallback? onAction,
    bool? showCloseButton,
    String? backgroundColor,
    String? textColor,
  }) {
    return SnackbarEvent(
      id: id ?? this.id,
      message: message ?? this.message,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      priority: priority ?? this.priority,
      severity: severity ?? this.severity,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      dismissible: dismissible ?? this.dismissible,
      autoDismiss: autoDismiss ?? this.autoDismiss,
      tags: tags ?? this.tags,
      data: data ?? this.data,
      timeout: timeout ?? this.timeout,
      replaceSimilar: replaceSimilar ?? this.replaceSimilar,
      deduplicationKey: deduplicationKey ?? this.deduplicationKey,
      actionText: actionText ?? this.actionText,
      onAction: onAction ?? this.onAction,
      showCloseButton: showCloseButton ?? this.showCloseButton,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'message': message,
      'title': title,
      'subtitle': subtitle,
      'priority': priority.name,
      'severity': severity.name,
      'duration': duration?.inMilliseconds,
      'position': position.name,
      'dismissible': dismissible,
      'autoDismiss': autoDismiss,
      'tags': tags.toList(),
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'timeout': timeout?.inMilliseconds,
      'replaceSimilar': replaceSimilar,
      'deduplicationKey': deduplicationKey,
      'actionText': actionText,
      'showCloseButton': showCloseButton,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
    };
  }
}

/// Dialog feedback event
class DialogEvent extends FeedbackEvent {
  /// Primary action text
  final String? primaryActionText;

  /// Secondary action text
  final String? secondaryActionText;

  /// Primary action callback
  final VoidCallback? onPrimaryAction;

  /// Secondary action callback
  final VoidCallback? onSecondaryAction;

  /// Whether dialog is modal
  final bool modal;

  /// Whether to show outside Flutter context
  final bool barrierDismissible;

  DialogEvent({
    required super.id,
    required super.message,
    super.title,
    super.subtitle,
    super.priority,
    super.severity,
    super.duration,
    super.position = FeedbackPosition.center,
    super.dismissible,
    super.autoDismiss = false,
    super.tags,
    super.data,
    super.timestamp,
    super.timeout,
    super.replaceSimilar = true,
    super.deduplicationKey,
    this.primaryActionText,
    this.secondaryActionText,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.modal = true,
    this.barrierDismissible = true,
  }) : super(
          type: FeedbackType.dialog,
        );

  @override
  DialogEvent copyWith({
    String? id,
    FeedbackType? type,
    String? message,
    String? title,
    String? subtitle,
    FeedbackPriority? priority,
    FeedbackSeverity? severity,
    Duration? duration,
    FeedbackPosition? position,
    bool? dismissible,
    bool? autoDismiss,
    Set<String>? tags,
    Map<String, dynamic>? data,
    Duration? timeout,
    bool? replaceSimilar,
    String? deduplicationKey,
    String? primaryActionText,
    String? secondaryActionText,
    VoidCallback? onPrimaryAction,
    VoidCallback? onSecondaryAction,
    bool? modal,
    bool? barrierDismissible,
  }) {
    return DialogEvent(
      id: id ?? this.id,
      message: message ?? this.message,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      priority: priority ?? this.priority,
      severity: severity ?? this.severity,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      dismissible: dismissible ?? this.dismissible,
      autoDismiss: autoDismiss ?? this.autoDismiss,
      tags: tags ?? this.tags,
      data: data ?? this.data,
      timeout: timeout ?? this.timeout,
      replaceSimilar: replaceSimilar ?? this.replaceSimilar,
      deduplicationKey: deduplicationKey ?? this.deduplicationKey,
      primaryActionText: primaryActionText ?? this.primaryActionText,
      secondaryActionText: secondaryActionText ?? this.secondaryActionText,
      onPrimaryAction: onPrimaryAction ?? this.onPrimaryAction,
      onSecondaryAction: onSecondaryAction ?? this.onSecondaryAction,
      modal: modal ?? this.modal,
      barrierDismissible: barrierDismissible ?? this.barrierDismissible,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'message': message,
      'title': title,
      'subtitle': subtitle,
      'priority': priority.name,
      'severity': severity.name,
      'duration': duration?.inMilliseconds,
      'position': position.name,
      'dismissible': dismissible,
      'autoDismiss': autoDismiss,
      'tags': tags.toList(),
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'timeout': timeout?.inMilliseconds,
      'replaceSimilar': replaceSimilar,
      'deduplicationKey': deduplicationKey,
      'primaryActionText': primaryActionText,
      'secondaryActionText': secondaryActionText,
      'modal': modal,
      'barrierDismissible': barrierDismissible,
    };
  }
}

/// Banner feedback event
class BannerEvent extends FeedbackEvent {
  /// Whether banner is persistent
  final bool persistent;

  /// Action text
  final String? actionText;

  /// Action callback
  final VoidCallback? onAction;

  BannerEvent({
    required super.id,
    required super.message,
    super.title,
    super.subtitle,
    super.priority,
    super.severity,
    super.duration,
    super.position = FeedbackPosition.top,
    super.dismissible,
    super.autoDismiss = false,
    super.tags,
    super.data,
    super.timestamp,
    super.timeout,
    super.replaceSimilar = true,
    super.deduplicationKey,
    this.persistent = false,
    this.actionText,
    this.onAction,
  }) : super(
          type: FeedbackType.banner,
        );

  @override
  BannerEvent copyWith({
    String? id,
    FeedbackType? type,
    String? message,
    String? title,
    String? subtitle,
    FeedbackPriority? priority,
    FeedbackSeverity? severity,
    Duration? duration,
    FeedbackPosition? position,
    bool? dismissible,
    bool? autoDismiss,
    Set<String>? tags,
    Map<String, dynamic>? data,
    Duration? timeout,
    bool? replaceSimilar,
    String? deduplicationKey,
    bool? persistent,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return BannerEvent(
      id: id ?? this.id,
      message: message ?? this.message,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      priority: priority ?? this.priority,
      severity: severity ?? this.severity,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      dismissible: dismissible ?? this.dismissible,
      autoDismiss: autoDismiss ?? this.autoDismiss,
      tags: tags ?? this.tags,
      data: data ?? this.data,
      timeout: timeout ?? this.timeout,
      replaceSimilar: replaceSimilar ?? this.replaceSimilar,
      deduplicationKey: deduplicationKey ?? this.deduplicationKey,
      persistent: persistent ?? this.persistent,
      actionText: actionText ?? this.actionText,
      onAction: onAction ?? this.onAction,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'message': message,
      'title': title,
      'subtitle': subtitle,
      'priority': priority.name,
      'severity': severity.name,
      'duration': duration?.inMilliseconds,
      'position': position.name,
      'dismissible': dismissible,
      'autoDismiss': autoDismiss,
      'tags': tags.toList(),
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'timeout': timeout?.inMilliseconds,
      'replaceSimilar': replaceSimilar,
      'deduplicationKey': deduplicationKey,
      'persistent': persistent,
      'actionText': actionText,
    };
  }
}

/// Toast feedback event
class ToastEvent extends FeedbackEvent {
  ToastEvent({
    required super.id,
    required super.message,
    super.title,
    super.subtitle,
    super.priority,
    super.severity,
    super.duration = const Duration(seconds: 2),
    super.position,
    super.dismissible = false,
    super.autoDismiss,
    super.tags,
    super.data,
    super.timestamp,
    super.timeout,
    super.replaceSimilar,
    super.deduplicationKey,
  }) : super(
          type: FeedbackType.toast,
        );

  @override
  ToastEvent copyWith({
    String? id,
    FeedbackType? type,
    String? message,
    String? title,
    String? subtitle,
    FeedbackPriority? priority,
    FeedbackSeverity? severity,
    Duration? duration,
    FeedbackPosition? position,
    bool? dismissible,
    bool? autoDismiss,
    Set<String>? tags,
    Map<String, dynamic>? data,
    Duration? timeout,
    bool? replaceSimilar,
    String? deduplicationKey,
  }) {
    return ToastEvent(
      id: id ?? this.id,
      message: message ?? this.message,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      priority: priority ?? this.priority,
      severity: severity ?? this.severity,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      dismissible: dismissible ?? this.dismissible,
      autoDismiss: autoDismiss ?? this.autoDismiss,
      tags: tags ?? this.tags,
      data: data ?? this.data,
      timeout: timeout ?? this.timeout,
      replaceSimilar: replaceSimilar ?? this.replaceSimilar,
      deduplicationKey: deduplicationKey ?? this.deduplicationKey,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'message': message,
      'title': title,
      'subtitle': subtitle,
      'priority': priority.name,
      'severity': severity.name,
      'duration': duration?.inMilliseconds,
      'position': position.name,
      'dismissible': dismissible,
      'autoDismiss': autoDismiss,
      'tags': tags.toList(),
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'timeout': timeout?.inMilliseconds,
      'replaceSimilar': replaceSimilar,
      'deduplicationKey': deduplicationKey,
    };
  }
}

/// Callback type for when feedback events are dismissed
typedef FeedbackDismissCallback = void Function(FeedbackEvent event);

/// Callback type for when feedback events timeout
typedef FeedbackTimeoutCallback = void Function(FeedbackEvent event);

/// Callback type for when feedback events are shown
typedef FeedbackShownCallback = void Function(FeedbackEvent event);

/// Void callback type alias
typedef VoidCallback = void Function();
