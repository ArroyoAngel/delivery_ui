import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Tracks the rider's GPS position while in rider mode.
///
/// On [start]:
///   1. Retries any segment that was pending from a previous session (offline
///      persistence via SharedPreferences).
///   2. Reads `location_interval_seconds` from the API (captured once per session).
///   3. Starts a continuous position stream to keep [_lastPosition] fresh.
///   4. Samples that position every [_intervalSeconds] seconds into a local buffer.
///   5. Flushes the buffer (one path segment) to the backend every 5 minutes.
///
/// The interval is fixed for the entire session. If the admin changes it in
/// system_config, it takes effect the next time [start] is called (i.e. after
/// the rider ends and re-activates rider mode).
///
/// Offline persistence: before each POST the pending segment is written to
/// SharedPreferences under [_pendingKey]. It is cleared only after a
/// successful response. On [start] any leftover pending segment is retried
/// first so no data is lost across app kills or crashes.
class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final _api = ApiClient();

  static const _pendingKey = 'location_pending_segment';

  final List<String> _buffer = []; // "lat,lng" strings
  DateTime? _segmentStart;
  geo.Position? _lastPosition;

  StreamSubscription<geo.Position>? _positionSub;
  Timer? _sampleTimer;   // records a point every _intervalSeconds
  Timer? _flushTimer;    // uploads segment every 5 minutes

  bool _running = false;
  int _intervalSeconds = 5; // captured from API on start()

  /// Start tracking. Retries any offline-pending segment, reads the current
  /// interval from the API, then begins sampling GPS every [_intervalSeconds]
  /// and flushing every 5 minutes.
  Future<void> start() async {
    if (_running) return;
    final hasPermission = await _ensurePermission();
    if (!hasPermission) return;

    // Retry pending segment from a previous (possibly killed) session
    await _retryPending();

    // Capture interval ONCE for this session
    _intervalSeconds = await _fetchIntervalSeconds();

    _running = true;
    _buffer.clear();
    _segmentStart = null;
    _lastPosition = null;

    // Continuous stream just to keep _lastPosition fresh (no distance filter)
    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.medium,
        distanceFilter: 0,
      ),
    ).listen((pos) {
      _lastPosition = pos;
    });

    // Sample position every _intervalSeconds
    _sampleTimer = Timer.periodic(Duration(seconds: _intervalSeconds), (_) {
      final pos = _lastPosition;
      if (pos == null) return;
      _segmentStart ??= DateTime.now().toUtc();
      _buffer.add('${pos.latitude},${pos.longitude}');
    });

    // Flush every 5 minutes
    _flushTimer = Timer.periodic(const Duration(minutes: 5), (_) => flush());
  }

  /// Stop tracking and flush remaining segment.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
    await flush();
  }

  /// Upload current buffer as one path segment and clear it.
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final path = List<String>.from(_buffer).join(';');
    final startedAt = _segmentStart!.toIso8601String();
    final endedAt = DateTime.now().toUtc().toIso8601String();
    _buffer.clear();
    _segmentStart = null;

    await _postSegment(
      path: path,
      startedAt: startedAt,
      endedAt: endedAt,
      intervalSeconds: _intervalSeconds,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Persist segment to disk, POST it, then clear on success.
  /// On failure, the on-disk record stays for the next retry.
  Future<void> _postSegment({
    required String path,
    required String startedAt,
    required String endedAt,
    required int intervalSeconds,
  }) async {
    final payload = {
      'path': path,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'intervalSeconds': intervalSeconds,
    };

    // Save to disk BEFORE attempting the network call
    await _savePending(payload);

    try {
      await _api.post('/rider/location/batch', payload);
      // Success — clear the on-disk record
      await _clearPending();
    } catch (_) {
      // Keep the on-disk record; it will be retried on next start()
      // Restore buffer in memory so in-session retry via flush() also works
      _buffer.insertAll(0, path.split(';'));
      _segmentStart = DateTime.parse(startedAt);
    }
  }

  /// Retry a pending segment saved from a previous session.
  Future<void> _retryPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      await _api.post('/rider/location/batch', map);
      await _clearPending();
    } catch (_) {
      // Still offline — keep the record for the next attempt
    }
  }

  Future<void> _savePending(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, jsonEncode(payload));
  }

  Future<void> _clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  Future<int> _fetchIntervalSeconds() async {
    try {
      final res = await _api.get('/rider/location/config') as Map<String, dynamic>;
      final val = (res['intervalSeconds'] as num?)?.toInt() ?? 5;
      return val.clamp(1, 300);
    } catch (_) {
      return 5; // fallback if API unavailable
    }
  }

  Future<bool> _ensurePermission() async {
    var perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      perm = await geo.Geolocator.requestPermission();
    }
    return perm != geo.LocationPermission.denied &&
        perm != geo.LocationPermission.deniedForever;
  }
}
