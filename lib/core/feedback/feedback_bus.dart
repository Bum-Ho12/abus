// lib/feedback/feedback_bus.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import 'package:abus/core/feedback/feedback_types.dart';

/// Configuration for the feedback bus
class FeedbackBusConfig {
  /// Maximum number of events in queue
  final int maxQueueSize;

  /// Default timeout for events
  final Duration defaultTimeout;

  /// Whether to enable deduplication
  final bool enableDeduplication;

  /// Time window for deduplication
  final Duration deduplicationWindow;

  /// Whether to log debug information
  final bool debug;

  /// Maximum concurrent displayed events
  final int maxConcurrentEvents;

  const FeedbackBusConfig({
    this.maxQueueSize = 50,
    this.defaultTimeout = const Duration(minutes: 5),
    this.enableDeduplication = true,
    this.deduplicationWindow = const Duration(seconds: 5),
    this.debug = false,
    this.maxConcurrentEvents = 3,
  });
}

/// Statistics for monitoring feedback bus performance
class FeedbackBusStats {
  final int queuedEvents;
  final int activeEvents;
  final int totalProcessed;
  final int duplicatesRejected;
  final int timeoutEvents;
  final DateTime lastActivity;

  const FeedbackBusStats({
    required this.queuedEvents,
    required this.activeEvents,
    required this.totalProcessed,
    required this.duplicatesRejected,
    required this.timeoutEvents,
    required this.lastActivity,
  });

  Map<String, dynamic> toJson() => {
        'queuedEvents': queuedEvents,
        'activeEvents': activeEvents,
        'totalProcessed': totalProcessed,
        'duplicatesRejected': duplicatesRejected,
        'timeoutEvents': timeoutEvents,
        'lastActivity': lastActivity.toIso8601String(),
      };
}

/// Central bus for managing all feedback events
class FeedbackBus {
  static FeedbackBus? _instance;
  static FeedbackBus get instance => _instance ??= FeedbackBus._();

  FeedbackBus._();

  /// Configuration
  FeedbackBusConfig _config = const FeedbackBusConfig();

  /// Priority queue for events (higher priority first)
  final Queue<FeedbackEvent> _eventQueue = Queue<FeedbackEvent>();

  /// Currently active/displayed events
  final Map<String, FeedbackEvent> _activeEvents = {};

  /// Deduplication cache
  final Map<String, DateTime> _deduplicationCache = {};

  /// Event timers for cleanup
  final Map<String, Timer> _eventTimers = {};

  /// Processing flag
  bool _isProcessing = false;

  /// Disposed flag
  bool _disposed = false;

  /// Statistics
  int _totalProcessed = 0;
  int _duplicatesRejected = 0;
  int _timeoutEvents = 0;
  DateTime _lastActivity = DateTime.now();

  /// Event streams
  late final StreamController<FeedbackEvent> _eventController =
      StreamController<FeedbackEvent>.broadcast();
  late final StreamController<FeedbackEvent> _dismissController =
      StreamController<FeedbackEvent>.broadcast();
  late final StreamController<FeedbackEvent> _timeoutController =
      StreamController<FeedbackEvent>.broadcast();
  late final StreamController<FeedbackBusStats> _statsController =
      StreamController<FeedbackBusStats>.broadcast();

  /// Stream of events to be displayed
  Stream<FeedbackEvent> get eventStream => _eventController.stream;

  /// Stream of dismissed events
  Stream<FeedbackEvent> get dismissStream => _dismissController.stream;

  /// Stream of timed out events
  Stream<FeedbackEvent> get timeoutStream => _timeoutController.stream;

  /// Stream of bus statistics
  Stream<FeedbackBusStats> get statsStream => _statsController.stream;

  /// Configure the feedback bus
  void configure(FeedbackBusConfig config) {
    if (_disposed) return;
    _config = config;
    _cleanupDeduplicationCache();
  }

  /// Add an event to the queue
  Future<bool> addEvent(FeedbackEvent event) async {
    if (_disposed) return false;

    try {
      // Check deduplication
      if (_config.enableDeduplication && _isDuplicate(event)) {
        _duplicatesRejected++;
        _updateStats();
        if (_config.debug) {
          debugPrint('FeedbackBus: Duplicate event rejected: ${event.id}');
        }
        return false;
      }

      // Check queue size
      if (_eventQueue.length >= _config.maxQueueSize) {
        // Remove lowest priority event
        _removeLowestPriorityEvent();
      }

      // Add to deduplication cache
      if (_config.enableDeduplication) {
        final dedupKey = event.generateDeduplicationKey();
        _deduplicationCache[dedupKey] = DateTime.now();
      }

      // Insert in priority order
      _insertEventInPriorityOrder(event);

      _lastActivity = DateTime.now();
      _updateStats();

      if (_config.debug) {
        debugPrint(
            'FeedbackBus: Event queued: ${event.id} (Priority: ${event.priority.name})');
      }

      // Start processing
      unawaited(_processQueue());

      return true;
    } catch (e) {
      if (_config.debug) {
        debugPrint('FeedbackBus: Error adding event: $e');
      }
      return false;
    }
  }

  /// Check if event is duplicate
  bool _isDuplicate(FeedbackEvent event) {
    final dedupKey = event.generateDeduplicationKey();
    final lastSeen = _deduplicationCache[dedupKey];

    if (lastSeen == null) return false;

    final timeSince = DateTime.now().difference(lastSeen);
    return timeSince < _config.deduplicationWindow;
  }

  /// Insert event in priority order
  void _insertEventInPriorityOrder(FeedbackEvent event) {
    if (_eventQueue.isEmpty) {
      _eventQueue.add(event);
      return;
    }

    // Convert to list for easier insertion
    final events = _eventQueue.toList();
    _eventQueue.clear();

    // Find insertion point
    int insertIndex = 0;
    for (int i = 0; i < events.length; i++) {
      if (event.priority.value > events[i].priority.value ||
          (event.priority.value == events[i].priority.value &&
              event.timestamp.isBefore(events[i].timestamp))) {
        insertIndex = i;
        break;
      }
      insertIndex = i + 1;
    }

    events.insert(insertIndex, event);
    _eventQueue.addAll(events);
  }

  /// Remove lowest priority event from queue
  void _removeLowestPriorityEvent() {
    if (_eventQueue.isEmpty) return;

    FeedbackEvent? lowestPriority;
    FeedbackEvent? toRemove;

    for (final event in _eventQueue) {
      if (lowestPriority == null ||
          event.priority.value < lowestPriority.priority.value) {
        lowestPriority = event;
        toRemove = event;
      }
    }

    if (toRemove != null) {
      _eventQueue.remove(toRemove);
      if (_config.debug) {
        debugPrint(
            'FeedbackBus: Removed lowest priority event: ${toRemove.id}');
      }
    }
  }

  /// Process the event queue
  Future<void> _processQueue() async {
    if (_isProcessing || _eventQueue.isEmpty || _disposed) return;

    _isProcessing = true;

    while (_eventQueue.isNotEmpty &&
        _activeEvents.length < _config.maxConcurrentEvents) {
      final event = _eventQueue.removeFirst();

      // Check if similar event should be replaced
      if (event.replaceSimilar) {
        _replaceSimilarEvent(event);
      }

      _activeEvents[event.id] = event;
      _totalProcessed++;
      _lastActivity = DateTime.now();

      // Set up timeout timer
      final timeout = event.timeout ?? _config.defaultTimeout;
      _eventTimers[event.id] = Timer(timeout, () {
        _handleEventTimeout(event.id);
      });

      // Set up auto-dismiss timer
      if (event.autoDismiss && event.duration != null) {
        Timer(event.duration!, () {
          dismiss(event.id);
        });
      }

      // Emit event
      if (!_eventController.isClosed) {
        _eventController.add(event);
      }

      if (_config.debug) {
        debugPrint('FeedbackBus: Event displayed: ${event.id}');
      }
    }

    _updateStats();
    _isProcessing = false;

    // Continue processing if more events are queued
    if (_eventQueue.isNotEmpty) {
      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_activeEvents.length < _config.maxConcurrentEvents &&
            _eventQueue.isNotEmpty) {
          timer.cancel();
          unawaited(_processQueue());
        } else if (_eventQueue.isEmpty) {
          timer.cancel();
        }
      });
    }
  }

  /// Replace similar event
  void _replaceSimilarEvent(FeedbackEvent newEvent) {
    final toRemove = <String>[];

    for (final entry in _activeEvents.entries) {
      final existing = entry.value;
      if (existing.type == newEvent.type &&
          existing.generateDeduplicationKey() ==
              newEvent.generateDeduplicationKey()) {
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      _forceRemoveEvent(id);
    }
  }

  /// Force remove event without user interaction
  void _forceRemoveEvent(String eventId) {
    final event = _activeEvents.remove(eventId);
    if (event != null) {
      _cleanupEventTimer(eventId);
      if (_config.debug) {
        debugPrint('FeedbackBus: Event force removed: $eventId');
      }
    }
  }

  /// Handle event timeout
  void _handleEventTimeout(String eventId) {
    final event = _activeEvents.remove(eventId);
    if (event != null) {
      _timeoutEvents++;
      _cleanupEventTimer(eventId);

      if (!_timeoutController.isClosed) {
        _timeoutController.add(event);
      }

      if (_config.debug) {
        debugPrint('FeedbackBus: Event timed out: $eventId');
      }

      _updateStats();

      // Continue processing queue
      unawaited(_processQueue());
    }
  }

  /// Dismiss an event
  Future<bool> dismiss(String eventId) async {
    if (_disposed) return false;

    final event = _activeEvents.remove(eventId);
    if (event == null) return false;

    _cleanupEventTimer(eventId);
    _lastActivity = DateTime.now();

    if (!_dismissController.isClosed) {
      _dismissController.add(event);
    }

    if (_config.debug) {
      debugPrint('FeedbackBus: Event dismissed: $eventId');
    }

    _updateStats();

    // Continue processing queue
    unawaited(_processQueue());

    return true;
  }

  /// Dismiss all events of a specific type
  Future<int> dismissByType(FeedbackType type) async {
    if (_disposed) return 0;

    final toRemove = <String>[];
    for (final entry in _activeEvents.entries) {
      if (entry.value.type == type) {
        toRemove.add(entry.key);
      }
    }

    int dismissed = 0;
    for (final id in toRemove) {
      if (await dismiss(id)) {
        dismissed++;
      }
    }

    return dismissed;
  }

  /// Dismiss all events with specific tag
  Future<int> dismissByTag(String tag) async {
    if (_disposed) return 0;

    final toRemove = <String>[];
    for (final entry in _activeEvents.entries) {
      if (entry.value.tags.contains(tag)) {
        toRemove.add(entry.key);
      }
    }

    int dismissed = 0;
    for (final id in toRemove) {
      if (await dismiss(id)) {
        dismissed++;
      }
    }

    return dismissed;
  }

  /// Dismiss all events
  Future<int> dismissAll() async {
    if (_disposed) return 0;

    final allIds = _activeEvents.keys.toList();
    int dismissed = 0;

    for (final id in allIds) {
      if (await dismiss(id)) {
        dismissed++;
      }
    }

    return dismissed;
  }

  /// Clear entire queue (without displaying)
  void clearQueue() {
    if (_disposed) return;

    _eventQueue.clear();
    if (_config.debug) {
      debugPrint('FeedbackBus: Queue cleared');
    }
    _updateStats();
  }

  /// Cleanup event timer
  void _cleanupEventTimer(String eventId) {
    final timer = _eventTimers.remove(eventId);
    timer?.cancel();
  }

  /// Clean up old deduplication entries
  void _cleanupDeduplicationCache() {
    if (!_config.enableDeduplication) return;

    final now = DateTime.now();
    final toRemove = <String>[];

    for (final entry in _deduplicationCache.entries) {
      if (now.difference(entry.value) > _config.deduplicationWindow) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      _deduplicationCache.remove(key);
    }
  }

  /// Update statistics and emit
  void _updateStats() {
    if (_disposed || _statsController.isClosed) return;

    final stats = FeedbackBusStats(
      queuedEvents: _eventQueue.length,
      activeEvents: _activeEvents.length,
      totalProcessed: _totalProcessed,
      duplicatesRejected: _duplicatesRejected,
      timeoutEvents: _timeoutEvents,
      lastActivity: _lastActivity,
    );

    _statsController.add(stats);
  }

  /// Get current statistics
  FeedbackBusStats getStats() {
    return FeedbackBusStats(
      queuedEvents: _eventQueue.length,
      activeEvents: _activeEvents.length,
      totalProcessed: _totalProcessed,
      duplicatesRejected: _duplicatesRejected,
      timeoutEvents: _timeoutEvents,
      lastActivity: _lastActivity,
    );
  }

  /// Get active events
  List<FeedbackEvent> getActiveEvents() {
    return _activeEvents.values.toList();
  }

  /// Get queued events
  List<FeedbackEvent> getQueuedEvents() {
    return _eventQueue.toList();
  }

  /// Check if event is active
  bool isEventActive(String eventId) {
    return _activeEvents.containsKey(eventId);
  }

  /// Get active event by ID
  FeedbackEvent? getActiveEvent(String eventId) {
    return _activeEvents[eventId];
  }

  /// Pause processing (for testing or maintenance)
  void pauseProcessing() {
    _isProcessing = true;
  }

  /// Resume processing
  void resumeProcessing() {
    _isProcessing = false;
    unawaited(_processQueue());
  }

  /// Dispose the feedback bus
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Cancel all timers
    for (final timer in _eventTimers.values) {
      timer.cancel();
    }
    _eventTimers.clear();

    // Clear data structures
    _eventQueue.clear();
    _activeEvents.clear();
    _deduplicationCache.clear();

    // Close streams
    _eventController.close();
    _dismissController.close();
    _timeoutController.close();
    _statsController.close();

    if (_config.debug) {
      debugPrint('FeedbackBus: Disposed');
    }
  }

  /// Reset to new instance (useful for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}

/// Helper function for unawaited futures
void unawaited(Future<void> future) {
  // Intentionally empty - prevents analyzer warnings
}
