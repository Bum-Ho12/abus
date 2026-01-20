// lib/core/abus_storage.dart

import 'dart:async';

/// Base interface for ABUS storage implementations.
///
/// Supports persistent storage of interactions, feedback, and other states.
/// Can be used for cross-app communication on devices.
abstract class AbusStorage {
  /// Save data under a specific key.
  Future<void> save(String key, Map<String, dynamic> data);

  /// Load data for a specific key.
  Future<Map<String, dynamic>?> load(String key);

  /// Delete data for a specific key.
  Future<void> delete(String key);

  /// List all available keys in this storage.
  Future<List<String>> listKeys();

  /// Clear all data in this storage.
  Future<void> clear();

  /// Watch for changes in a specific key.
  Stream<Map<String, dynamic>?> watch(String key);

  /// Watch for any changes in the storage.
  Stream<String> watchAll();

  /// Manually trigger a synchronization of the storage state.
  ///
  /// Useful for cross-app storage where changes might happen externally.
  Future<void> sync() async {}
}
