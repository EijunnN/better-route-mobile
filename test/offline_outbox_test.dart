import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aea/core/constants.dart';
import 'package:aea/models/pending_close.dart';
import 'package:aea/models/route_stop.dart';
import 'package:aea/services/api_service.dart';
import 'package:aea/services/offline_outbox.dart';
import 'package:aea/services/route_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────
// Spec: docs/specs/offline-outbox.spec.md §6 — unit tests del outbox.
// RouteService se fakea a mano (sin mocktail en dev_dependencies; la
// regla #1 del repo prohíbe codegen, así que tampoco mockito).
// ─────────────────────────────────────────────────────────────────────

typedef UploadCall = ({String path, int? index});

class FakeRouteService implements RouteService {
  final List<UploadCall> uploadCalls = [];
  final List<({String stopId, List<String> evidenceUrls})> completeCalls = [];
  final List<({String stopId, String reason})> failCalls = [];

  /// Hooks: cuando están seteados corren ANTES del comportamiento default
  /// (retornar éxito). Lanzar acá simula el fallo de red / HTTP.
  Future<void> Function()? onUploadEvidencePhoto;
  Future<void> Function()? onCompleteStop;
  Future<void> Function()? onFailStop;

  RouteStop _stubStop(String stopId, StopStatus status) => RouteStop(
        id: stopId,
        sequence: 1,
        status: status,
        address: 'Av. Siempre Viva 742',
        latitude: -12.0,
        longitude: -77.0,
      );

  @override
  Future<String> uploadEvidencePhoto({
    required File photo,
    required String trackingId,
    int? index,
  }) async {
    uploadCalls.add((path: photo.path, index: index));
    if (onUploadEvidencePhoto != null) await onUploadEvidencePhoto!();
    return 'https://r2.example.com/$trackingId-${index ?? 'noindex'}.jpg';
  }

  @override
  Future<RouteStop> completeStop({
    required String stopId,
    required List<String> evidenceUrls,
    String? notes,
    String? gpsLatitude,
    String? gpsLongitude,
    Map<String, dynamic>? customFields,
  }) async {
    completeCalls.add((stopId: stopId, evidenceUrls: evidenceUrls));
    if (onCompleteStop != null) await onCompleteStop!();
    return _stubStop(stopId, StopStatus.completed);
  }

  @override
  Future<RouteStop> failStop({
    required String stopId,
    required String reason,
    List<String>? evidenceUrls,
    String? notes,
    String? gpsLatitude,
    String? gpsLongitude,
  }) async {
    failCalls.add((stopId: stopId, reason: reason));
    if (onFailStop != null) await onFailStop!();
    return _stubStop(stopId, StopStatus.failed);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} no se fakea acá');
}

// ── Helpers ───────────────────────────────────────────────────────────

DioException networkError() => DioException(
      requestOptions: RequestOptions(path: '/api/route-stops/x'),
      type: DioExceptionType.connectionError,
    );

DioException httpError(int statusCode) => DioException(
      requestOptions: RequestOptions(path: '/api/route-stops/x'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/api/route-stops/x'),
        statusCode: statusCode,
      ),
      error: ApiException('HTTP $statusCode', statusCode: statusCode),
    );

PendingClose close({
  String stopId = 'stop-1',
  String status = 'COMPLETED',
  String? failureReason,
  List<String> photoPaths = const [],
  Map<String, String> uploadedByPath = const {},
  int retryCount = 0,
}) =>
    PendingClose(
      id: stopId,
      stopId: stopId,
      trackingId: 'TRK-$stopId',
      status: status,
      failureReason: failureReason,
      photoPaths: photoPaths,
      uploadedByPath: uploadedByPath,
      retryCount: retryCount,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

Future<String?> rawOutbox() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(StorageKeys.offlineOutbox);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRouteService fake;

  OfflineOutbox outbox({bool failureReasonRequired = false}) =>
      OfflineOutbox.forTesting(
        routeService: fake,
        failureReasonRequired: () => failureReasonRequired,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeRouteService();
  });

  // 1. submitClose persiste ANTES de intentar red; un kill post-persist no
  //    pierde el cierre (un instance nuevo lo drena desde disco).
  test('submitClose persiste a disco antes de cualquier intento de red',
      () async {
    var persistedBeforeNetwork = false;
    fake.onCompleteStop = () async {
      final raw = await rawOutbox();
      persistedBeforeNetwork = raw != null && raw.contains('stop-1');
      throw networkError(); // "sin señal" en el primer intento
    };

    final result = await outbox().submitClose(close());

    expect(persistedBeforeNetwork, isTrue);
    expect(result, OutboxResult.queued);

    // "Kill" simulado: instancia nueva (estado en memoria perdido) — la
    // entrada sobrevive el reload y se drena desde SharedPreferences.
    fake.onCompleteStop = null;
    final reborn = outbox();
    await reborn.flush();

    expect(fake.completeCalls.map((c) => c.stopId), contains('stop-1'));
    expect(reborn.pendingCount.value, 0);
    expect(await rawOutbox(), '[]');
  });

  // 2. FIX-1: el drain presigna con index = posición+1 y respeta
  //    uploadedByPath (no re-sube lo ya subido).
  test('drain multi-foto presigna con index 1..N y respeta uploadedByPath',
      () async {
    final dir = await Directory.systemTemp.createTemp('outbox_test');
    addTearDown(() => dir.delete(recursive: true));
    final a = await File('${dir.path}/a.jpg').writeAsString('a');
    final b = await File('${dir.path}/b.jpg').writeAsString('b');
    final c = await File('${dir.path}/c.jpg').writeAsString('c');

    const preUploadedB = 'https://r2.example.com/pre-b.jpg';
    final result = await outbox().submitClose(close(
      photoPaths: [a.path, b.path, c.path],
      uploadedByPath: {b.path: preUploadedB},
    ));

    expect(result, OutboxResult.synced);
    // Solo a y c se suben, con el índice de SU posición (1 y 3) — b no.
    expect(fake.uploadCalls, [
      (path: a.path, index: 1),
      (path: c.path, index: 3),
    ]);
    // El PATCH lleva las tres URLs en orden de photoPaths.
    expect(fake.completeCalls.single.evidenceUrls, [
      'https://r2.example.com/TRK-stop-1-1.jpg',
      preUploadedB,
      'https://r2.example.com/TRK-stop-1-3.jpg',
    ]);
  });

  // 3. FIX-2: FAILED sin motivo con policy con motivos NUNCA se encola.
  test('FAILED sin motivo con policy con motivos → submitClose rechaza',
      () async {
    final gated = outbox(failureReasonRequired: true);

    await expectLater(
      gated.submitClose(close(status: 'FAILED')),
      throwsA(isA<MissingFailureReasonException>()),
    );
    // Motivo whitespace-only también cuenta como ausente.
    await expectLater(
      gated.submitClose(close(status: 'FAILED', failureReason: '   ')),
      throwsA(isA<MissingFailureReasonException>()),
    );

    expect(gated.pendingCount.value, 0);
    expect(gated.hasPendingFor('stop-1'), isFalse);
    expect(await rawOutbox(), isNull, reason: 'nunca debe persistirse');
    expect(fake.failCalls, isEmpty);

    // Control: con motivo sí pasa el gate.
    final ok = await gated.submitClose(
      close(status: 'FAILED', failureReason: 'Cliente ausente'),
    );
    expect(ok, OutboxResult.synced);
    expect(fake.failCalls.single.reason, 'Cliente ausente');
  });

  // 4. Clasificación de fallos: 4xx drop, 409/5xx/sin-response retry,
  //    retryCount > 60 drop.
  test('4xx → drop definitivo; 5xx/409/sin-response → retry; >60 → drop',
      () async {
    // 4xx → drop definitivo con lastError.
    fake.onCompleteStop = () async => throw httpError(400);
    final dropped = outbox();
    await dropped.submitClose(close(stopId: 'stop-4xx'));
    expect(dropped.pendingCount.value, 0);
    expect(dropped.lastError, isNotNull);

    // 5xx → queda encolado con retryCount++.
    fake.onCompleteStop = () async => throw httpError(500);
    final on5xx = outbox();
    expect(
      await on5xx.submitClose(close(stopId: 'stop-5xx')),
      OutboxResult.queued,
    );
    expect(on5xx.pendingCount.value, 1);
    final entries5xx = jsonDecode((await rawOutbox())!) as List;
    expect(
      (entries5xx.single as Map<String, dynamic>)['retryCount'],
      1,
      reason: 'el retry transitorio incrementa retryCount',
    );

    // 409 (lock optimista) → transitorio, sigue encolado.
    SharedPreferences.setMockInitialValues({});
    fake.onCompleteStop = () async => throw httpError(409);
    final on409 = outbox();
    expect(
      await on409.submitClose(close(stopId: 'stop-409')),
      OutboxResult.queued,
    );

    // Sin response (red caída) → transitorio, sigue encolado.
    SharedPreferences.setMockInitialValues({});
    fake.onCompleteStop = () async => throw networkError();
    final onNet = outbox();
    expect(
      await onNet.submitClose(close(stopId: 'stop-net')),
      OutboxResult.queued,
    );

    // retryCount > 60 → se dropea para no loopear infinito. Hook explícito:
    // el drop debe salir del contador, no de heredar el fallo del caso previo.
    SharedPreferences.setMockInitialValues({});
    fake.onCompleteStop = () async => throw networkError();
    final exhausted = outbox();
    await exhausted.submitClose(
      close(stopId: 'stop-exhausted', retryCount: AppConstants.outboxMaxRetries),
    );
    expect(exhausted.pendingCount.value, 0);
    expect(exhausted.lastError, contains('stop-exhausted'));
  });

  // 5. Idempotencia: tras un ack perdido, el reintento recibe el 200
  //    no-op del server (fila actual) y el outbox lo trata como éxito.
  test('reenvío de terminal idéntico tras ack perdido cuenta como éxito',
      () async {
    var attempts = 0;
    fake.onCompleteStop = () async {
      attempts++;
      // Primer intento: el server aplicó el cierre pero el ack se perdió.
      if (attempts == 1) throw networkError();
      // Reintento: el server no-opea y devuelve 200 { data: fila actual }.
    };

    final ob = outbox();
    expect(await ob.submitClose(close()), OutboxResult.queued);
    expect(ob.pendingCount.value, 1);

    await ob.flush();

    expect(attempts, 2);
    expect(ob.pendingCount.value, 0, reason: 'el 200 no-op remueve la entrada');
    expect(await rawOutbox(), '[]');
  });

  // 6. Payload corrupto en SharedPreferences → se descarta sin crash.
  test('payload corrupto en SharedPreferences se descarta sin crash',
      () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.offlineOutbox: '{esto-no-es-json',
    });
    final ob = outbox();
    await ob.flush(); // fuerza el load del payload corrupto
    expect(ob.pendingCount.value, 0);

    // Shape inválido (JSON válido pero no PendingClose) también se descarta.
    SharedPreferences.setMockInitialValues({
      StorageKeys.offlineOutbox: '[{"id": 5}]',
    });
    final ob2 = outbox();
    await ob2.flush();
    expect(ob2.pendingCount.value, 0);

    // Y el outbox sigue operativo después del descarte.
    expect(await ob2.submitClose(close()), OutboxResult.synced);
  });

  // 7. Resume-safe REAL (spec §3): un crash tras subir 2 de 3 fotos deja
  //    uploadedByPath persistido; el drain de una instancia nueva solo
  //    sube la 3ª.
  test('crash tras subir 2 de 3 fotos: el drain nuevo no re-sube 1 y 2',
      () async {
    final dir = await Directory.systemTemp.createTemp('outbox_resume');
    addTearDown(() => dir.delete(recursive: true));
    final a = await File('${dir.path}/a.jpg').writeAsString('a');
    final b = await File('${dir.path}/b.jpg').writeAsString('b');
    final c = await File('${dir.path}/c.jpg').writeAsString('c');

    var uploads = 0;
    fake.onUploadEvidencePhoto = () async {
      uploads++;
      if (uploads == 3) throw networkError(); // se corta subiendo la 3ª
    };

    final result = await outbox().submitClose(
      close(photoPaths: [a.path, b.path, c.path]),
    );
    expect(result, OutboxResult.queued);

    // Lo persistido a disco ya registra las fotos 1 y 2 (no la 3ª).
    final entries = jsonDecode((await rawOutbox())!) as List;
    final uploadedByPath = Map<String, String>.from(
      (entries.single as Map<String, dynamic>)['uploadedByPath'] as Map,
    );
    expect(uploadedByPath.keys, containsAll([a.path, b.path]));
    expect(uploadedByPath.containsKey(c.path), isFalse);

    // "Kill" + instancia nueva: solo la 3ª foto se sube, con SU índice.
    fake.onUploadEvidencePhoto = null;
    fake.uploadCalls.clear();
    final reborn = outbox();
    await reborn.flush();

    expect(fake.uploadCalls, [(path: c.path, index: 3)]);
    expect(fake.completeCalls.single.evidenceUrls, hasLength(3));
    expect(await rawOutbox(), '[]');
  });

  // 8. Head-of-line: un 409 permanente en la cabeza es fallo per-entrada,
  //    no de transporte — la cola sincroniza igual.
  test('un 409 en la cabeza no retiene los cierres siguientes', () async {
    fake.onCompleteStop = () async => throw networkError();
    final ob = outbox();
    await ob.submitClose(close(stopId: 'stop-head'));
    await ob.submitClose(close(stopId: 'stop-tail'));
    expect(ob.pendingCount.value, 2);

    // Vuelve la red: la cabeza sigue chocando con el lock optimista (409);
    // la cola debe sincronizar en el mismo flush.
    fake.onCompleteStop = () async {
      if (fake.completeCalls.last.stopId == 'stop-head') throw httpError(409);
    };
    await ob.flush();

    expect(fake.completeCalls.map((cll) => cll.stopId), contains('stop-tail'));
    expect(ob.pendingCount.value, 1, reason: 'solo la cabeza queda encolada');
  });

  test('fallo de transporte en la cabeza corta el flush entero', () async {
    fake.onCompleteStop = () async => throw networkError();
    final ob = outbox();
    await ob.submitClose(close(stopId: 'stop-a'));
    await ob.submitClose(close(stopId: 'stop-b'));
    fake.completeCalls.clear();

    await ob.flush(); // sigue sin red

    expect(
      fake.completeCalls.map((cll) => cll.stopId),
      ['stop-a'],
      reason: 'sin red no tiene sentido intentar el resto',
    );
    expect(ob.pendingCount.value, 2);
  });

  // 9. Carrera submitClose vs drain in-flight: el drain viejo (generación
  //    stale) no debe clobberear el re-cierre que lo reemplazó.
  test('re-cierre durante un drain in-flight no es clobbereado', () async {
    fake.onCompleteStop = () async => throw networkError();
    final ob = outbox();
    await ob.submitClose(close(stopId: 'stop-1', status: 'COMPLETED'));

    // Drain viejo colgado en el PATCH del cierre COMPLETED.
    final gate = Completer<void>();
    fake.onCompleteStop = () async {
      await gate.future;
      throw networkError();
    };
    final draining = ob.flush();

    // Re-cierre mientras el drain está in-flight: ahora es FAILED.
    fake.onFailStop = () async => throw networkError();
    await ob.submitClose(
      close(stopId: 'stop-1', status: 'FAILED', failureReason: 'Ausente'),
    );

    gate.complete();
    await draining;

    // La entrada viva es la FAILED nueva: el drain viejo no la removió ni
    // le pisó status/retryCount con la copia stale.
    expect(ob.pendingCount.value, 1);
    final entries = jsonDecode((await rawOutbox())!) as List;
    final entry = entries.single as Map<String, dynamic>;
    expect(entry['status'], 'FAILED');
    expect(entry['generation'], 1);
    expect(entry['retryCount'], 1,
        reason: 'solo el intento del propio submitClose');
  });

  // 10. Spec §5: tras un drain que sincronizó al menos un cierre, el outbox
  //     notifica para que el provider refetchee my-route.
  test('un drain exitoso notifica a los listeners; uno fallido no', () async {
    fake.onCompleteStop = () async => throw networkError();
    final ob = outbox();
    await ob.submitClose(close());

    var drains = 0;
    void listener() => drains++;
    ob.addDrainListener(listener);
    addTearDown(() => ob.removeDrainListener(listener));

    await ob.flush(); // sigue offline — no notifica
    expect(drains, 0);

    fake.onCompleteStop = null;
    await ob.flush(); // sincroniza — una sola notificación por flush
    expect(drains, 1);
  });
}
