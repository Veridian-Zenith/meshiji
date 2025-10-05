import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'logger.dart';

// Helper to compute directory size in a background isolate
int _computeDirectorySize(String path) {
  try {
    final dir = Directory(path);
    if (!dir.existsSync()) return 0;
    int total = 0;
    for (final entry in dir.listSync(recursive: true, followLinks: false)) {
      try {
        if (entry is File) total += entry.lengthSync();
      } catch (_) {}
    }
    return total;
  } catch (_) {
    return 0;
  }
}

/// Advanced in-memory cache with a queued, throttled background worker for
/// computing directory sizes. Features:
/// - 5-minute cache expiration
/// - Automatic invalidation when folder contents change
/// - File modification time tracking
/// Call `requestSize(path, cb)` to get notified when the size is available.
/// `clear()` clears the cache and pending listeners.
class SizeCache {
  SizeCache._();
  static final SizeCache instance = SizeCache._();

  final Map<String, int> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, DateTime> _folderModifiedTimes = {};
  final Map<String, List<void Function(int)>> _listeners = {};
  final List<String> _queue = [];
  int _running = 0;
  int concurrency = 2; // tune this for IO throughput; adjustable at runtime
  static const Duration _cacheExpiration = Duration(minutes: 5);

  void setConcurrency(int c) {
    concurrency = c.clamp(1, 8);
    // try to start more if possible
    Future.microtask(_maybeStartNext);
  }

  void requestSize(String path, void Function(int) cb) {
    // Check if we have a valid cached value
    if (_isCacheValid(path)) {
      Logger.instance.debug('Using cached size for: $path');
      cb(_cache[path]!);
      return;
    }

    // Remove stale cache entry
    if (_cache.containsKey(path)) {
      _cache.remove(path);
      _cacheTimestamps.remove(path);
      _folderModifiedTimes.remove(path);
      Logger.instance.debug('Removed stale cache for: $path');
    }

    // register listener
    _listeners.putIfAbsent(path, () => []).add(cb);

    // if already queued, nothing else
    if (_queue.contains(path)) return;

    _queue.add(path);
    _maybeStartNext();
  }

  bool _isCacheValid(String path) {
    // Check if we have a cached value
    if (!_cache.containsKey(path)) return false;

    // Check if cache has expired (5 minutes)
    final cacheTime = _cacheTimestamps[path];
    if (cacheTime == null || DateTime.now().difference(cacheTime) > _cacheExpiration) {
      Logger.instance.debug('Cache expired for: $path');
      return false;
    }

    // Check if folder has been modified since cache
    try {
      final currentModified = Directory(path).statSync().modified;
      final cachedModified = _folderModifiedTimes[path];

      if (cachedModified == null || currentModified.isAfter(cachedModified)) {
        Logger.instance.debug('Folder modified since cache for: $path');
        return false;
      }
    } catch (e) {
      Logger.instance.warning('Error checking folder modification time for $path: $e');
      return false;
    }

    return true;
  }

  void _maybeStartNext() {
    while (_running < concurrency && _queue.isNotEmpty) {
      final path = _queue.removeAt(0);
      _running++;
      compute<String, int>(_computeDirectorySize, path).then((size) {
        // Store cache with timestamp and folder modification time
        _cache[path] = size;
        _cacheTimestamps[path] = DateTime.now();
        try {
          _folderModifiedTimes[path] = Directory(path).statSync().modified;
        } catch (e) {
          Logger.instance.warning('Error getting folder modification time for $path: $e');
        }

        final listeners = _listeners.remove(path) ?? [];
        for (final l in listeners) {
          try {
            l(size);
          } catch (_) {}
        }

        Logger.instance.debug('Cached size for $path: $size bytes');
      }).whenComplete(() {
        _running--;
        // schedule next
        Future.microtask(_maybeStartNext);
      });
    }
  }

  void clear() {
    _cache.clear();
    _cacheTimestamps.clear();
    _folderModifiedTimes.clear();
    _listeners.clear();
    _queue.clear();
    _running = 0;
  }
}
