---
name: nueva-pantalla
description: Usala cuando vayas a crear una pantalla nueva en lib/screens/ (screen de go_router nueva, flujo nuevo del conductor). Cubre el patrón de screen + registro en el router + manejo offline si la pantalla cierra paradas.
---

# Pantalla nueva

Fuentes canónicas: `CLAUDE.md` §Convenciones de código ("Navegación") e
invariantes 1–2. Esta skill las aterriza.

**Ejemplos de referencia:**
- `lib/screens/end_of_day_screen.dart` — `ConsumerWidget` chico y limpio:
  lee providers con `ref.watch`, deriva en el `build`, usa los tokens de
  `lib/core/design/tokens.dart`.
- `lib/screens/stop_detail_screen.dart` — pantalla con mutaciones offline
  (outbox + optimistic update).
- `lib/router/router.dart` — cómo se registra todo.

## Paso 1 — La pantalla

- `ConsumerWidget` (o `ConsumerStatefulWidget` si hay controllers/lifecycle).
- Estado global por `ref.watch(<x>Provider)`; derivaciones simples
  (conteos, filtros) se calculan en el `build`, no en un provider nuevo.
- **Textos de cara al conductor en español** (LATAM). Tema dark-only:
  colores/tipos/radios de `AppColors` / `AppTypography` / `AppRadius`
  (`lib/core/design/tokens.dart`) — nada de `Colors.*` hardcodeado.
- Widgets compartidos en `lib/widgets/` (barrel `widgets.dart`); widgets
  privados de la pantalla en `lib/screens/<pantalla>/widgets/` (como
  `stop_detail/widgets/`).
- Si crece, dividí en archivos normales + barrel — **nunca** `part`.

## Paso 2 — Registro en el router (`lib/router/router.dart`)

1. Constante en `AppRoutes` (+ helper de path si lleva parámetro):

```dart
static const String widgetDetail = '/widget/:id';
static String widgetDetailPath(String id) => '/widget/$id';
```

2. `GoRoute` con `CustomTransitionPage` — fade para pantallas raíz, slide
   horizontal para detalles (ver `stopDetail` en el router):

```dart
GoRoute(
  path: AppRoutes.widgetDetail,
  name: 'widgetDetail',
  pageBuilder: (context, state) {
    final id = state.pathParameters['id']!;
    return CustomTransitionPage(
      key: state.pageKey,
      child: WidgetDetailScreen(id: id),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  },
),
```

3. La lógica de redirect ya escucha `authProvider`: pantallas autenticadas
   quedan protegidas sin tocar nada. Solo tocá el `redirect` si la
   pantalla debe ser accesible deslogueado (hoy solo login).
4. Navegación desde código: `context.push(AppRoutes.widgetDetailPath(id))` /
   `context.go(...)` — nunca strings inline.

## Paso 3 — ¿La pantalla cierra paradas o muta con conectividad dudosa?

Invariantes 1–2 de `CLAUDE.md` (patrón concreto en
`stop_detail_screen.dart`, ~línea 254):

```dart
final result = await OfflineOutbox().submitClose(entry);
ref.read(routeProvider.notifier).applyLocalClose(/* optimista */);
```

- `COMPLETED`/`FAILED` **siempre** por `OfflineOutbox.submitClose`
  (persiste antes de enviar) + `applyLocalClose` (update optimista).
  **Nunca** el `PATCH` directo — el outbox depende de la idempotencia
  server-side para reintentar.
- **Evidencia antes de cerrar:** la foto sube a R2 (`getPresignedUrl` →
  `PUT` → `publicUrl`) y debe completarse antes del cierre. Dejá propagar
  la excepción; nunca `null` ni `evidenceUrls` vacío.
- Estados terminales no se reabren desde el móvil.
- Indicador de pendientes: `ValueListenableBuilder` sobre
  `OfflineOutbox().pendingCount` (ver `home_screen.dart`).
- Spec de comportamiento del outbox: `docs/specs/offline-outbox.spec.md`.

Si la pantalla consume un endpoint nuevo del backend: consultá
`docs/API-CONTRACT-MOBILE.md` antes — shape nuevo = bump de
`CONTRACT_VERSION` coordinado con `planeamiento`.

## Cierre

1. Import de la pantalla en `router.dart` (las screens no van al barrel de
   widgets).
2. `flutter analyze`.
3. Probar el flujo de navegación de ida y vuelta (deep-link si hay push:
   ver `PushRouter().attachRouter`).
