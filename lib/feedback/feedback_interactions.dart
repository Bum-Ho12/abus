// lib/feedback/feedback_interactions.dart

import 'package:abus/core/abus_definition.dart';
import 'package:abus/feedback/feedback_events.dart';

/// Interaction for showing feedback events
class ShowFeedbackInteraction extends GenericInteraction {
  ShowFeedbackInteraction({
    required FeedbackEvent event,
    bool replace = false,
  }) : super(
          id: 'show_feedback_${event.runtimeType.toString().toLowerCase()}',
          data: {
            'event': event.toJson(),
            'replace': replace,
            'deduplicationKey': event.deduplicationKey,
          },
          supportsOptimistic: true,
          priority: event.priority,
          tags: {
            'feedback',
            event.runtimeType.toString().toLowerCase(),
            ...event.tags
          },
        );

  FeedbackEvent get event {
    final eventData = data['event'] as Map<String, dynamic>;
    final type = eventData['type'] as String;

    switch (type) {
      case 'SnackbarEvent':
        return _createSnackbarEvent(eventData);
      case 'BannerEvent':
        return _createBannerEvent(eventData);
      case 'ToastEvent':
        return _createToastEvent(eventData);
      default:
        throw ArgumentError('Unknown feedback event type: $type');
    }
  }

  static SnackbarEvent _createSnackbarEvent(Map<String, dynamic> data) {
    return SnackbarEvent(
      id: data['id'],
      message: data['message'],
      type:
          SnackbarType.values.firstWhere((t) => t.name == data['snackbarType']),
      actionLabel: data['actionLabel'],
      priority: data['priority'] ?? 0,
      duration: data['duration'] != null
          ? Duration(milliseconds: data['duration'])
          : null,
      tags: Set<String>.from(data['tags'] ?? []),
      dismissible: data['dismissible'] ?? true,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  static BannerEvent _createBannerEvent(Map<String, dynamic> data) {
    return BannerEvent(
      id: data['id'],
      message: data['message'],
      type: BannerType.values.firstWhere((t) => t.name == data['bannerType']),
      priority: data['priority'] ?? 1,
      duration: data['duration'] != null
          ? Duration(milliseconds: data['duration'])
          : null,
      tags: Set<String>.from(data['tags'] ?? []),
      dismissible: data['dismissible'] ?? true,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  static ToastEvent _createToastEvent(Map<String, dynamic> data) {
    return ToastEvent(
      id: data['id'],
      message: data['message'],
      type: ToastType.values.firstWhere((t) => t.name == data['toastType']),
      priority: data['priority'] ?? 0,
      duration: data['duration'] != null
          ? Duration(milliseconds: data['duration'])
          : null,
      tags: Set<String>.from(data['tags'] ?? []),
      dismissible: data['dismissible'] ?? false,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }
}

/// Interaction for dismissing feedback
class DismissFeedbackInteraction extends GenericInteraction {
  DismissFeedbackInteraction({
    String? eventId,
    Set<String>? tags,
    bool dismissAll = false,
  }) : super(
          id: 'dismiss_feedback',
          data: {
            if (eventId != null) 'eventId': eventId,
            if (tags != null) 'tags': tags.toList(),
            'dismissAll': dismissAll,
          },
          supportsOptimistic: true,
          tags: {'feedback', 'dismiss'},
        );
}
