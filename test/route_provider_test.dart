import 'dart:convert';
import 'dart:io';

import 'package:aea/core/constants.dart';
import 'package:aea/models/driver_info.dart';
import 'package:aea/models/pending_close.dart';
import 'package:aea/models/route_data.dart';
import 'package:aea/models/route_stop.dart';
import 'package:aea/providers/route_provider.dart';
import 'package:aea/services/offline_outbox.dart';
import 'package:aea/services/route_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────
// Spec: docs/specs/offline-outbox.spec.md §5 — interacción outbox ↔
// estado local del provider (merge de my-route + refetch post-drain).
// ─────────────────────────────────────────────────────────────────────

class FakeRouteService implements RouteService {
  DriverRouteData Function()? onGetMyRoute;
  Future<void> Function()? onCompleteStop;

  @override
  Future<DriverRouteData> getMyRoute() async => onGetMyRoute!();

  @override
  Future<RouteStop> completeStop({
    required String stopId,
    required List<String> evidenceUrls,
    String? notes,
    String? gpsLatitude,
    String? gpsLongitude,
    Map<String, dynamic>? customFields,
  }) async {
    if (onCompleteStop != null) await onCompleteStop!();
    return stop(stopId, StopStatus.completed);
  }

  @override
  Future<String> uploadEvidencePhoto({
    required File photo,
    required String trackingId,
    int? index,
  }) async =>
      'https://r2.example.com/$trackingId-$index.jpg';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} no se fakea acá');
}

DioException networkError() => DioException(
      requestOptions: RequestOptions(path: '/api/route-stops/x'),
      type: DioExceptionType.connectionError,
    );

RouteStop stop(String id, StopStatus status) => RouteStop(
      id: id,
      sequence: 1,
      status: status,
      address: 'Av. Siempre Viva 742',
      latitude: -12.0,
      longitude: -77.0,
    );

DriverRouteData routeData(List<RouteStop> stops) => DriverRouteData(
      driver: const DriverInfo(id: 'driver-1', name: 'Chofer'),
      route: RouteInfo(
        id: 'route-1',
        jobId: 'job-1',
        jobCreatedAt: DateTime(2026, 7, 1),
        stops: stops,
      ),
    );

PendingClose pendingCloseFor(String stopId) => PendingClose(
      id: stopId,
      stopId: stopId,
      trackingId: 'TRK-$stopId',
      status: 'COMPLETED',
      notes: 'dejado en portería',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRouteService fake;

  OfflineOutbox outbox() => OfflineOutbox.forTesting(
        routeService: fake,
        failureReasonRequired: () => false,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeRouteService();
  });

  // §5, incluye cold start: la cola vive en disco de una sesión anterior y
  // el provider no tiene estado local todavía — el merge sale del outbox.
  test('loadRoute no resucita stops con cierre pendiente en el outbox (§5)',
      () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.offlineOutbox: jsonEncode([
        pendingCloseFor('stop-2').toJson(),
      ]),
    });
    fake.onCompleteStop = () async => throw networkError(); // sigue sin señal
    fake.onGetMyRoute = () => routeData([
          stop('stop-1', StopStatus.pending),
          // El server aún no vio el cierre: lo tiene IN_PROGRESS.
          stop('stop-2', StopStatus.inProgress),
        ]);

    final notifier = RouteNotifier(fake, outbox: outbox());
    addTearDown(notifier.dispose);
    await notifier.loadRoute();
    await pumpEventQueue();

    final byId = {for (final s in notifier.state.stops) s.id: s};
    expect(byId['stop-2']!.status, StopStatus.completed,
        reason: 'el estado local terminal se conserva mientras viva la entrada');
    expect(byId['stop-2']!.notes, 'dejado en portería');
    expect(byId['stop-1']!.status, StopStatus.pending,
        reason: 'los stops sin cierre pendiente rinden la verdad del server');
  });

  test('tras un drain exitoso el provider refetchea my-route (§5)', () async {
    final ob = outbox();
    fake.onCompleteStop = () async => throw networkError();
    await ob.submitClose(pendingCloseFor('stop-2'));

    var fetches = 0;
    fake.onGetMyRoute = () {
      fetches++;
      // Verdad del server: IN_PROGRESS hasta que el drain complete.
      return routeData([
        stop(
          'stop-2',
          fetches == 1 ? StopStatus.inProgress : StopStatus.completed,
        ),
      ]);
    };

    final notifier = RouteNotifier(fake, outbox: ob);
    addTearDown(notifier.dispose);
    await notifier.loadRoute();
    await pumpEventQueue();

    // Vuelve la señal: el drain sincroniza y el listener refetchea.
    fake.onCompleteStop = null;
    await ob.flush();
    await pumpEventQueue();

    expect(fetches, greaterThanOrEqualTo(2),
        reason: 'el drain exitoso dispara el refetch');
    expect(notifier.state.stops.single.status, StopStatus.completed);
  });

  test('transitionStop rechaza systemState terminal (va por el outbox)',
      () async {
    final notifier = RouteNotifier(fake, outbox: outbox());
    addTearDown(notifier.dispose);

    await expectLater(
      notifier.transitionStop(
        stopId: 'stop-1',
        workflowStateId: 'ws-1',
        systemState: 'COMPLETED',
      ),
      throwsArgumentError,
    );
    await expectLater(
      notifier.transitionStop(
        stopId: 'stop-1',
        workflowStateId: 'ws-1',
        systemState: 'FAILED',
      ),
      throwsArgumentError,
    );
  });
}
