import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';

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

/// Simple in-memory cache with a queued, throttled background worker for
/// computing directory sizes. Call `requestSize(path, cb)` to get notified
/// when the size is available. `clear()` clears the cache and pending listeners.
class SizeCache {
  SizeCache._();
  static final SizeCache instance = SizeCache._();

  final Map<String, int> _cache = {};
  final Map<String, List<void Function(int)>> _listeners = {};
  final List<String> _queue = [];
  int _running = 0;
  int concurrency = 2; // tune this for IO throughput; adjustable at runtime

  void setConcurrency(int c) {
    concurrency = c.clamp(1, 8);
    // try to start more if possible
    Future.microtask(_maybeStartNext);
  }

  void requestSize(String path, void Function(int) cb) {
    // if cached, return immediately
    if (_cache.containsKey(path)) {
      cb(_cache[path]!);
      return;
    }

    // register listener
    _listeners.putIfAbsent(path, () => []).add(cb);

    // if already queued, nothing else
    if (_queue.contains(path)) return;

    _queue.add(path);
    _maybeStartNext();
  }

  void _maybeStartNext() {
    while (_running < concurrency && _queue.isNotEmpty) {
      final path = _queue.removeAt(0);
      _running++;
      compute<String, int>(_computeDirectorySize, path).then((size) {
        _cache[path] = size;
        final listeners = _listeners.remove(path) ?? [];
        for (final l in listeners) {
          try {
            l(size);
          } catch (_) {}
        }
      }).whenComplete(() {
        _running--;
        // schedule next
        Future.microtask(_maybeStartNext);
      });
    }
  }

  void clear() {
    _cache.clear();
    _listeners.clear();
    _queue.clear();
    _running = 0;
  }
}
