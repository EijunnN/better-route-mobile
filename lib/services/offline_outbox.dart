import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/pending_close.dart';
import 'api_service.dart';
import 'route_service.dart';
import 'workflow_service.dart';

enum OutboxResult { synced, queued }

/// How a single drain attempt ended. `retryTransport` (no network) aborts
/// the whole flush — the remaining entries would fail the same way — while
/// `retryEntry` (409/5xx on this close) lets the flush move on so one stuck
/// head doesn't hold every later close hostage for the next timer cycle.
enum _FlushOutcome { synced, dropped, superseded, retryEntry, retryTransport }

/// Rejection at enqueue time: a FAILED close without a reason while the
/// cached delivery policy declares failure reasons. Persisting it would be a
/// guaranteed 400 → drop on drain — the failure would never reach dispatch.
class MissingFailureReasonException implements Exception {
  final String message =
      'El reporte de fallo requiere un motivo de la política de entrega.';

  @override
  String toString() => message;
}

/// Disk-backed outbox for stop closes, so a driver can mark a delivery
/// COMPLETED/FAILED in a no-signal zone: the close (and its photos) are
/// persisted locally and synced automatically when connectivity returns.
///
/// No `connectivity_plus`: we retry on a timer, on app resume, on route
/// reload, and right after each close — mirroring the existing location-queue
/// pattern. Idempotent against lost acks (the backend no-ops a re-sent
/// terminal transition, so a retry can't create a duplicate delivery visit).
class OfflineOutbox {
  static final OfflineOutbox _instance = OfflineOutbox._internal();
  factory OfflineOutbox() => _instance;
  OfflineOutbox._internal()
      : _routeService = RouteService(),
        _failureReasonRequired = _policyRequiresFailureReason;

  @visibleForTesting
  OfflineOutbox.forTesting({
    required RouteService routeService,
    bool Function()? failureReasonRequired,
  })  : _routeService = routeService,
        _failureReasonRequired = failureReasonRequired ?? (() => false);

  static bool _policyRequiresFailureReason() =>
      WorkflowService().cachedFailureReasons.isNotEmpty;

  final RouteService _routeService;
  final bool Function() _failureReasonRequired;
  final List<PendingClose> _entries = [];
  bool _loaded = false;
  bool _flushing = false;
  Timer? _timer;

  /// Number of pending (not-yet-synced) closes. UI watches this.
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  /// Fired once per flush that synced at least one close (spec §5: after a
  /// successful drain the route must be refetched — the server row is the
  /// only render source for a synced stop).
  final List<VoidCallback> _drainListeners = [];

  String? lastError;

  void addDrainListener(VoidCallback listener) =>
      _drainListeners.add(listener);

  void removeDrainListener(VoidCallback listener) =>
      _drainListeners.remove(listener);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.offlineOutbox);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _entries
          ..clear()
          ..addAll(
            list.map((e) => PendingClose.fromJson(e as Map<String, dynamic>)),
          );
      } catch (_) {
        // Corrupt payload — drop it rather than crash the close flow.
      }
    }
    _loaded = true;
    _notify();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.offlineOutbox,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
  }

  void _notify() => pendingCount.value = _entries.length;

  bool hasPendingFor(String stopId) => _entries.any((e) => e.stopId == stopId);

  /// Live entries keyed by stop, loading from disk first so a cold-start
  /// merge (spec §5) doesn't miss closes queued in a prior session.
  Future<Map<String, PendingClose>> pendingByStopId() async {
    await _ensureLoaded();
    return {for (final e in _entries) e.stopId: e};
  }

  /// Enqueue a close and try to sync it immediately. Returns
  /// [OutboxResult.synced] when it reached the server, or
  /// [OutboxResult.queued] when it stays pending (no signal).
  Future<OutboxResult> submitClose(PendingClose entry) async {
    // FIX-2: gate at enqueue time. A FAILED close without a reason (when the
    // cached policy has failureReasons) would drain as a 400 → definitive
    // drop, silently losing the failure report.
    if (entry.status == 'FAILED' &&
        _failureReasonRequired() &&
        (entry.failureReason == null || entry.failureReason!.trim().isEmpty)) {
      throw MissingFailureReasonException();
    }

    await _ensureLoaded();
    // Dedup by stop — a stop has at most one pending close. A replacement
    // bumps the generation so an in-flight drain of the old entry aborts
    // instead of clobbering this one.
    final priorIndex = _entries.indexWhere((e) => e.stopId == entry.stopId);
    final stamped = priorIndex >= 0
        ? entry.copyWith(generation: _entries[priorIndex].generation + 1)
        : entry;
    if (priorIndex >= 0) _entries.removeAt(priorIndex);
    _entries.add(stamped);
    await _persist();
    _notify();

    final outcome = await _flushOne(stamped);
    return outcome == _FlushOutcome.retryEntry ||
            outcome == _FlushOutcome.retryTransport
        ? OutboxResult.queued
        : OutboxResult.synced;
  }

  /// Try to sync every queued close. Safe to call repeatedly.
  Future<void> flush() async {
    await _ensureLoaded();
    if (_flushing || _entries.isEmpty) return;
    _flushing = true;
    var syncedAny = false;
    try {
      for (final entry in List<PendingClose>.from(_entries)) {
        if (!_isCurrent(entry)) continue;
        final outcome = await _flushOne(entry);
        if (outcome == _FlushOutcome.synced) syncedAny = true;
        // No network — the rest would fail the same way. A per-entry HTTP
        // failure (409/5xx) moves on so it can't starve the later closes.
        if (outcome == _FlushOutcome.retryTransport) break;
      }
    } finally {
      _flushing = false;
    }
    if (syncedAny) {
      for (final listener in List<VoidCallback>.from(_drainListeners)) {
        listener();
      }
    }
  }

  Future<_FlushOutcome> _flushOne(PendingClose entry) async {
    var current = entry;
    try {
      // 1. Upload photos not yet uploaded (resume-safe via uploadedByPath).
      // FIX-1: presign with index = position + 1, like the online path —
      // without it the R2 key is deterministic per trackingId and photos
      // 2..N overwrite the first.
      for (var i = 0; i < entry.photoPaths.length; i++) {
        if (!_isCurrent(current)) return _FlushOutcome.superseded;
        final path = entry.photoPaths[i];
        if (current.uploadedByPath.containsKey(path)) continue;
        final file = File(path);
        if (!await file.exists()) continue; // file gone — skip this photo
        final url = await _routeService.uploadEvidencePhoto(
          photo: file,
          trackingId: entry.trackingId,
          index: i + 1,
        );
        final map = Map<String, String>.from(current.uploadedByPath)
          ..[path] = url;
        current = current.copyWith(uploadedByPath: map);
        _replaceIfCurrent(current);
        await _persist();
      }

      final evidenceUrls = current.photoPaths
          .map((p) => current.uploadedByPath[p])
          .whereType<String>()
          .toList();

      // A re-close replaced this entry while we were uploading — its own
      // flush owns the PATCH now.
      if (!_isCurrent(current)) return _FlushOutcome.superseded;

      // 2. PATCH the close. The backend no-ops a re-sent terminal status, so
      // a retry after a lost ack can't create a duplicate delivery visit.
      if (current.status == 'COMPLETED') {
        await _routeService.completeStop(
          stopId: current.stopId,
          evidenceUrls: evidenceUrls,
          notes: current.notes,
          gpsLatitude: current.gpsLatitude,
          gpsLongitude: current.gpsLongitude,
          customFields: current.customFields,
        );
      } else {
        await _routeService.failStop(
          stopId: current.stopId,
          reason: current.failureReason ?? '',
          evidenceUrls: evidenceUrls.isNotEmpty ? evidenceUrls : null,
          notes: current.notes,
          gpsLatitude: current.gpsLatitude,
          gpsLongitude: current.gpsLongitude,
        );
      }

      if (_removeIfCurrent(current)) {
        await _persist();
        _notify();
      }
      return _FlushOutcome.synced;
    } catch (e) {
      if (!_isCurrent(current)) return _FlushOutcome.superseded;
      if (_isRetryable(e)) {
        // Bump from `current`, not `entry`: `current` carries the photo
        // uploads persisted during this attempt (resume-safe, spec §3).
        final bumped = current.copyWith(retryCount: current.retryCount + 1);
        if (bumped.retryCount > AppConstants.outboxMaxRetries) {
          // Give up to avoid an infinite loop; surface the failure.
          lastError = 'No se pudo sincronizar el cierre de ${entry.stopId}: $e';
          _removeIfCurrent(current);
          await _persist();
          _notify();
          return _FlushOutcome.dropped;
        }
        _replaceIfCurrent(bumped);
        await _persist();
        return _isTransportFailure(e)
            ? _FlushOutcome.retryTransport
            : _FlushOutcome.retryEntry;
      }
      // 4xx — the server rejected the close (validation/transition). Drop it
      // so it doesn't loop forever, and surface the reason.
      lastError = e.toString();
      _removeIfCurrent(current);
      await _persist();
      _notify();
      return _FlushOutcome.dropped;
    }
  }

  /// Spec §2: transitorio = sin response, status null o >=500, excepción
  /// desconocida, y 409 (lock optimista — el próximo intento puede ganar).
  /// Definitivo = cualquier otro 4xx.
  bool _isRetryable(Object e) {
    if (e is DioException) {
      if (e.response == null) return true; // transport/network failure
      final inner = e.error;
      if (inner is ApiException) return _isRetryableStatus(inner.statusCode);
      return _isRetryableStatus(e.response?.statusCode);
    }
    if (e is ApiException) {
      return _isRetryableStatus(e.statusCode);
    }
    return true; // unknown — treat as transient
  }

  bool _isRetryableStatus(int? status) =>
      status == null || status >= 500 || status == 409;

  /// Transport-level failure (never reached the server) vs an HTTP answer
  /// for this specific entry. Only the former justifies aborting the flush.
  bool _isTransportFailure(Object e) =>
      e is DioException && e.response == null;

  /// The queue still holds this exact entry (same stop, same generation).
  /// False means a re-close replaced it while this attempt was in flight.
  bool _isCurrent(PendingClose entry) => _entries.any(
        (e) => e.id == entry.id && e.generation == entry.generation,
      );

  void _replaceIfCurrent(PendingClose entry) {
    final i = _entries.indexWhere(
      (e) => e.id == entry.id && e.generation == entry.generation,
    );
    if (i >= 0) _entries[i] = entry;
  }

  bool _removeIfCurrent(PendingClose entry) {
    final before = _entries.length;
    _entries.removeWhere(
      (e) => e.id == entry.id && e.generation == entry.generation,
    );
    return _entries.length != before;
  }

  /// Start the periodic background flush. Idempotent. Kicks once immediately
  /// to cover an app cold-start that has queued closes from a prior session.
  void startAutoFlush() {
    _timer ??= Timer.periodic(
      const Duration(seconds: AppConstants.outboxFlushIntervalSeconds),
      (_) => flush(),
    );
    flush();
  }

  void stopAutoFlush() {
    _timer?.cancel();
    _timer = null;
  }
}
