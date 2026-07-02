import 'dart:convert';
import 'dart:io';

import 'package:aea/core/contract_version.dart';
import 'package:aea/models/models.dart';
import 'package:aea/services/route_service.dart';
import 'package:aea/services/workflow_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────
// Contract-tests móviles (API-CONTRACT-MOBILE.md §10.5).
//
// Cada fixture golden de test/contract/fixtures/ — espejado desde el web
// por scripts/sync-contract-fixtures — se parsea con el fromJson REAL de
// la app. Los campos congelados del §9 usan casts no-nullables: si el
// server (fixture) deja de mandar uno, el parse lanza y el test falla.
// Campos extra (aditivos) nunca deben romper el parser.
// ─────────────────────────────────────────────────────────────────────

const _fixturesDir = 'test/contract/fixtures';

Map<String, dynamic> _loadBody(String name) {
  final raw = File('$_fixturesDir/$name.json').readAsStringSync();
  final fixture = jsonDecode(raw) as Map<String, dynamic>;
  expect(
    fixture['contractVersion'],
    contractVersion,
    reason: 'el fixture $name declara otra CONTRACT_VERSION — '
        'resincronizar fixtures o bumpear lib/core/contract_version.dart',
  );
  return fixture['body'] as Map<String, dynamic>;
}

Map<String, dynamic> _data(Map<String, dynamic> body) =>
    body['data'] as Map<String, dynamic>;

void main() {
  // Un closure por fixture. El test de cobertura de abajo exige que todo
  // .json del directorio espejado tenga su entrada acá.
  final byFixture = <String, void Function(Map<String, dynamic> body)>{
    'auth-login': (body) {
      final auth = AuthResponse.fromJson(body);
      expect(auth.user.id, isNotEmpty);
      expect(auth.user.companyId, isNotEmpty);
      expect(auth.user.email, contains('@'));
      expect(auth.user.name, isNotEmpty);
      expect(auth.user.isDriver, isTrue, reason: 'rol CONDUCTOR exacto (§2)');
      expect(auth.accessToken, isNotEmpty);
      expect(auth.refreshToken, isNotEmpty);
      expect(auth.expiresIn, greaterThan(0));
    },
    'auth-refresh': (body) {
      // Mismos casts no-nullables que AuthService.refreshToken /
      // ApiService._refreshedAccessToken.
      expect(body['accessToken'] as String, isNotEmpty);
      expect(body['refreshToken'] as String, isNotEmpty);
    },
    'auth-logout': (body) {
      // La app ignora el body del logout; se congela solo la señal de éxito.
      expect(body['success'], isTrue);
    },
    'auth-me': (body) {
      // /me devuelve el shape de User + extras (active, permissions…): el
      // parser debe tolerarlos.
      final user = User.fromJson(body);
      expect(user.isDriver, isTrue);
      expect(user.companyId, isNotEmpty);
    },
    'my-route': (body) {
      final routeData = DriverRouteData.fromJson(body);
      expect(routeData.driver.id, isNotEmpty);
      expect(routeData.driver.name, isNotEmpty);

      final route = routeData.route!;
      expect(route.id, isNotEmpty);
      expect(route.jobId, isNotEmpty);
      expect(route.geometry, isNotEmpty);
      expect(route.stops, hasLength(2));

      final first = route.stops.first;
      expect(first.id, isNotEmpty);
      expect(first.sequence, 1);
      expect(first.address, isNotEmpty);
      // Coordenadas viajan como string en my-route (§1) y deben parsear.
      expect(first.latitude, closeTo(-12.045511, 1e-9));
      expect(first.longitude, closeTo(-77.028240, 1e-9));
      expect(first.order!.id, isNotEmpty);
      expect(first.timeWindow!.hasWindow, isTrue);
      expect(first.liveEtaAt, isNotNull);

      final completed = route.stops[1];
      expect(completed.status.isCompleted, isTrue);
      expect(completed.evidenceUrls, hasLength(1));
      expect(completed.timeWindow!.hasWindow, isFalse);

      expect(routeData.vehicle!.origin!.hasCoordinates, isTrue);
      expect(routeData.metrics!.totalStops, 2);
      expect(routeData.currentStop!.id, first.id);
    },
    'my-orders': (body) {
      // La app no consume my-orders hoy (no hay modelo Dart); se valida la
      // estructura para detectar drift si algún día se adopta.
      final data = _data(body);
      final order = (data['orders'] as List).first as Map<String, dynamic>;
      expect(order['id'], isA<String>());
      expect(order['trackingId'], isA<String>());
      expect(order['status'], isA<String>());
      expect((order['stop'] as Map<String, dynamic>)['status'], isA<String>());
      // §4: time windows de la Order son horas crudas, NO ISO-8601.
      final timeWindow = order['timeWindow'] as Map<String, dynamic>;
      expect(timeWindow['start'], matches(RegExp(r'^\d{2}:\d{2}')));
      // Familia híbrida (§1): total viaja DENTRO de data.
      expect(data['total'], isA<int>());
      expect(data['summary'], isA<Map<String, dynamic>>());
    },
    'route-stop-patch': (body) {
      final stop = RouteStop.fromJson(_data(body));
      // Congelados §9: data.{id,sequence,address}.
      expect(stop.id, isNotEmpty);
      expect(stop.sequence, 2);
      expect(stop.address, isNotEmpty);
      expect(stop.status.isCompleted, isTrue);
      expect(stop.notes, isNotEmpty);
      expect(stop.evidenceUrls, hasLength(1));
      expect(stop.customFields!['dni_receptor'], isNotEmpty);
    },
    'route-stop-get': (body) {
      final stop = RouteStop.fromJson(_data(body));
      expect(stop.id, isNotEmpty);
      expect(stop.status.isCompleted, isTrue);
      // La order embebida del GET trae más campos que la de my-route: el
      // parser debe tolerarlos y conservar el id congelado.
      expect(stop.order!.id, isNotEmpty);
      expect(stop.completedAt, isNotNull);
    },
    'route-stop-reopen': (body) {
      final stop = RouteStop.fromJson(_data(body));
      expect(stop.status.isPending, isTrue);
      expect(stop.startedAt, isNull);
      expect(stop.completedAt, isNull);
      expect(stop.evidenceUrls, isNull);
    },
    'route-stop-history': (body) {
      // Sin modelo Dart (la app no muestra el historial); validación
      // estructural del envelope híbrido { data, total } (§1).
      final rows = (body['data'] as List).cast<Map<String, dynamic>>();
      expect(rows, hasLength(2));
      expect(body['total'], rows.length);
      for (final row in rows) {
        expect(row['id'], isA<String>());
        expect(row['newStatus'], isA<String>());
        expect(DateTime.tryParse(row['createdAt'] as String), isNotNull);
      }
    },
    'driver-location-post': (body) {
      expect(body['success'], isTrue);
      expect(body['locationId'], isA<String>());
      expect(DateTime.tryParse(body['savedAt'] as String), isNotNull);
    },
    'driver-location-get': (body) {
      final location = body['location'] as Map<String, dynamic>;
      expect(location['latitude'], isA<num>());
      expect(location['longitude'], isA<num>());
      // FIX-6: los ceros se persisten como 0, no como null.
      expect(location['altitude'], 0);
      expect(location['speed'], 0);
      expect(location['heading'], 0);
      expect(DateTime.tryParse(location['recordedAt'] as String), isNotNull);
    },
    'delivery-policy': (body) {
      final data = _data(body);
      final states = WorkflowService().parseDeliveryPolicy(data);
      expect(
        states.map((s) => s.code).toList(),
        ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED'],
      );

      final completed = states.firstWhere((s) => s.code == 'COMPLETED');
      expect(completed.isTerminal, isTrue);
      expect(completed.requiresPhoto, isTrue);
      expect(completed.label, 'Entregado');

      final failed = states.firstWhere((s) => s.code == 'FAILED');
      expect(failed.requiresReason, isTrue);
      expect(failed.requiresNotes, isTrue);
      expect(failed.reasonOptions, isNotEmpty);
      expect(WorkflowService().cachedFailureReasons, failed.reasonOptions);

      // FIX-9 (aditivo): el server sirve quickReplies y el fallback
      // embebido del móvil debe espejarlo — si esta igualdad se rompe,
      // actualizar chatQuickReplies en lib/models/chat_message.dart.
      final wire = (data['quickReplies'] as List).cast<Map<String, dynamic>>();
      expect(
        wire.map((q) => '${q['code']}|${q['label']}').toList(),
        chatQuickReplies.map((q) => '${q.code}|${q.label}').toList(),
      );
    },
    'field-definitions': (body) {
      final defs = (body['data'] as List)
          .map((f) => FieldDefinition.fromJson(f as Map<String, dynamic>))
          .toList();
      expect(defs, hasLength(2));
      for (final def in defs) {
        // Congelados §9: id, code, label.
        expect(def.id, isNotEmpty);
        expect(def.code, isNotEmpty);
        expect(def.label, isNotEmpty);
      }
      expect(defs[0].isText, isTrue);
      expect(defs[0].required, isTrue);
      expect(defs[1].isSelect, isTrue);
      expect(defs[1].options, hasLength(3));
      expect(defs[1].defaultValue, 'Centro');
    },
    'presigned-url': (body) {
      final presigned = PresignedUrlResponse.fromJson(body);
      // Los 6 campos congelados (§9).
      expect(presigned.uploadUrl, startsWith('https://'));
      expect(presigned.publicUrl, startsWith('https://'));
      expect(presigned.key, isNotEmpty);
      expect(presigned.expiresIn, greaterThan(0));
      expect(presigned.maxFileSize, greaterThan(0));
      expect(presigned.contentType, 'image/jpeg');
    },
    'chat-messages-get': (body) {
      final messages = (body['data'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
      expect(messages, hasLength(2));

      final inbound = messages[0];
      expect(inbound.isInbound, isTrue);
      expect(inbound.kind, ChatMessageKind.text);
      expect(inbound.readAt, isNotNull);

      final outbound = messages[1];
      expect(outbound.direction, ChatDirection.toDispatch);
      expect(outbound.isTemplate, isTrue);
      expect(outbound.templateCode, 'ON_THE_WAY');
      expect(outbound.readAt, isNull);
    },
    'chat-messages-post': (body) {
      final message = ChatMessage.fromJson(_data(body));
      expect(message.direction, ChatDirection.toDispatch);
      expect(message.body, isNotEmpty);
      expect(message.companyId, isNotEmpty);
    },
    'chat-read': (body) {
      expect(body['ok'], isTrue);
    },
    'chat-broadcast': (body) {
      expect(body['ok'], isTrue);
      expect(body['reached'], isA<int>());
    },
    'realtime-token': (body) {
      // Mismo chequeo que ChatService.getRealtimeToken: token no-vacío (§9).
      expect(body['token'] as String, isNotEmpty);
    },
    'realtime-subscription-token': (body) {
      expect(body['token'] as String, isNotEmpty);
    },
  };

  group('fixtures golden (§10.5)', () {
    for (final entry in byFixture.entries) {
      test(entry.key, () => entry.value(_loadBody(entry.key)));
    }
  });

  test('todo fixture espejado tiene su contract-test', () {
    final onDisk = Directory(_fixturesDir)
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.json'))
        .map((name) => name.substring(0, name.length - '.json'.length))
        .toSet();
    expect(onDisk, byFixture.keys.toSet());
  });

  test('campos extra (aditivos) no rompen los parsers', () {
    Map<String, dynamic> withExtras(Map<String, dynamic> body) {
      final copy = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
      copy['campoFuturo'] = {'anidado': true};
      return copy;
    }

    final login = withExtras(_loadBody('auth-login'));
    (login['user'] as Map<String, dynamic>)['badgeUrl'] = 'https://x/y.png';
    expect(() => AuthResponse.fromJson(login), returnsNormally);

    final route = withExtras(_loadBody('my-route'));
    final stops = ((route['data'] as Map<String, dynamic>)['route']
        as Map<String, dynamic>)['stops'] as List;
    (stops.first as Map<String, dynamic>)['prioridadFutura'] = 99;
    expect(() => DriverRouteData.fromJson(route), returnsNormally);
  });
}
