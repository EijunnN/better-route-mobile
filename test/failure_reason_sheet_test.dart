import 'package:aea/models/route_stop.dart';
import 'package:aea/widgets/sheets/sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────
// Spec §4: el gate de motivo va en el formulario, PERO con reasons vacío
// (cold start offline, policy no cacheada) se apaga — igual que el gate
// del outbox. Sin esto el driver no puede reportar un FAILED offline.
// ─────────────────────────────────────────────────────────────────────

const _stop = RouteStop(
  id: 'stop-1',
  sequence: 1,
  status: StopStatus.inProgress,
  address: 'Av. Siempre Viva 742',
  latitude: -12.0,
  longitude: -77.0,
);

Widget _harness({
  required List<String> reasons,
  required void Function(FailureResult?) onResult,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await showModalBottomSheet<FailureResult>(
                context: context,
                isScrollControlled: true,
                builder: (_) => FailureReasonSheet(
                  stop: _stop,
                  reasons: reasons,
                ),
              );
              onResult(result);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('cold start sin motivos: permite reportar sin selección',
      (tester) async {
    FailureResult? result;
    var closed = false;
    await tester.pumpWidget(
      _harness(
        reasons: const [],
        onResult: (r) {
          result = r;
          closed = true;
        },
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reportar fallo'));
    await tester.pumpAndSettle();

    expect(closed, isTrue, reason: 'el sheet confirma y se cierra');
    expect(result, isNotNull);
    expect(result!.reason, isNull);
  });

  testWidgets('con motivos configurados sigue exigiendo selección',
      (tester) async {
    var closed = false;
    await tester.pumpWidget(
      _harness(
        reasons: const ['Cliente ausente', 'Dirección incorrecta'],
        onResult: (_) => closed = true,
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reportar fallo'));
    await tester.pumpAndSettle();

    expect(find.text('Motivo requerido'), findsOneWidget);
    expect(closed, isFalse, reason: 'sin selección el sheet no confirma');

    // Con selección sí confirma.
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente ausente'));
    await tester.pump();
    await tester.tap(find.text('Reportar fallo'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });
}
