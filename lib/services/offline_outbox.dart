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

  String? lastError;

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
    // Dedup by stop — a stop has at most one pending close.
    _entries.removeWhere((e) => e.stopId == entry.stopId);
    _entries.add(entry);
    await _persist();
    _notify();

    final synced = await _flushOne(entry);
    return synced ? OutboxResult.synced : OutboxResult.queued;
  }

  /// Try to sync every queued close. Safe to call repeatedly.
  Future<void> flush() async {
    await _ensureLoaded();
    if (_flushing || _entries.isEmpty) return;
    _flushing = true;
    try {
      for (final entry in List<PendingClose>.from(_entries)) {
        if (!_entries.any((e) => e.id == entry.id)) continue;
        final settled = await _flushOne(entry);
        // Still queued after attempting => offline; the rest will fail too.
        if (!settled && _entries.any((e) => e.id == entry.id)) break;
      }
    } finally {
      _flushing = false;
    }
  }

  /// Returns true when the entry no longer needs to be queued (synced, or
  /// permanently rejected). False means it stays queued (offline / 5xx).
  Future<bool> _flushOne(PendingClose entry) async {
    try {
      // 1. Upload photos not yet uploaded (resume-safe via uploadedByPath).
      // FIX-1: presign with index = position + 1, like the online path —
      // without it the R2 key is deterministic per trackingId and photos
      // 2..N overwrite the first.
      var current = entry;
      for (var i = 0; i < entry.photoPaths.length; i++) {
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
        _replace(current);
        await _persist();
      }

      final evidenceUrls = current.photoPaths
          .map((p) => current.uploadedByPath[p])
          .whereType<String>()
          .toList();

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

      _removeById(current.id);
      await _persist();
      _notify();
      return true;
    } catch (e) {
      if (_isRetryable(e)) {
        final bumped = entry.copyWith(retryCount: entry.retryCount + 1);
        if (bumped.retryCount > AppConstants.outboxMaxRetries) {
          // Give up to avoid an infinite loop; surface the failure.
          lastError = 'No se pudo sincronizar el cierre de ${entry.stopId}: $e';
          _removeById(entry.id);
          await _persist();
          _notify();
          return true;
        }
        _replace(bumped);
        await _persist();
        return false; // stays queued (offline / transient)
      }
      // 4xx — the server rejected the close (validation/transition). Drop it
      // so it doesn't loop forever, and surface the reason.
      lastError = e.toString();
      _removeById(entry.id);
      await _persist();
      _notify();
      return true;
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

  void _replace(PendingClose entry) {
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i >= 0) _entries[i] = entry;
  }

  void _removeById(String id) => _entries.removeWhere((e) => e.id == id);

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
