# aea — Driver Cockpit (móvil de BetterRoute)

App **Flutter** del conductor para BetterRoute (SaaS de ruteo de última milla). Es
el cliente que consume la API del backend web (`../planeamiento`): agenda del día,
navegación, cierre de entregas con evidencia, cola offline, tracking GPS y chat con
despacho. Textos de cara al conductor en **español** (LATAM).

**Arquitectura:** Servicios singleton → Riverpod `StateNotifierProvider` → `go_router`
→ `Dio`. Tema **dark-only** con `shadcn_flutter`.

---

## ⚠️ REGLA #1 — NO se usa CODEGEN

`pubspec.yaml` declara `freezed`, `json_serializable`, `riverpod_generator`,
`riverpod_annotation` y `build_runner`, y `README.md` menciona
`dart run build_runner build`. **Esto es engañoso: el repo NO usa codegen.**

- **CERO** archivos `*.g.dart` / `*.freezed.dart`, **cero** directivas `part '...'`,
  **cero** anotaciones `@freezed` / `@riverpod` en todo `lib/`.
- **Los modelos son clases planas escritas a mano** (`final` + `const` ctor +
  `factory fromJson` + `toJson` + `copyWith`). Ej: `lib/models/route_stop.dart`.
- **Los providers son `StateNotifier` a mano** + `StateNotifierProvider`. Ej:
  `lib/providers/route_provider.dart`.

> **NUNCA** corras `build_runner`, ni escribas modelos `freezed` o providers
> `@riverpod`, ni agregues `part`. Es el error más probable de un agente que
> lee `pubspec` + `README` sin auditar `lib/`.

**Casos borde de la regla (decididos 2026-07-01):**

- **Purgar, no tolerar:** las deps de codegen del `pubspec` (`freezed`,
  `json_serializable`, `riverpod_generator`, `riverpod_annotation`,
  `build_runner`) **deben eliminarse** (tarea Opus), junto con la línea
  `dart run build_runner build` del `README.md`. Pre-deploy: se borra, no
  se documenta alrededor.
- **`part` / `part of`:** prohibidos también para split manual de libraries.
  Un archivo que crece se divide en archivos normales + barrel, no en parts.
- **Tests:** mocking con **`mocktail`** (sin codegen). Nunca `mockito`
  (requiere build_runner).
- **Única exención:** `flutter gen-l10n` (i18n oficial de Flutter) quedaría
  permitido si algún día se internacionaliza — es tooling de primera parte,
  no build_runner. Hasta entonces los textos siguen hardcodeados en español.
- **Artefactos colaterales:** si un upgrade o tool genera `*.g.dart` /
  `*.freezed.dart`, eso es un bug a corregir en el origen — borrarlos, no
  commitearlos ni agregarlos a `.gitignore` (ocultaría la regresión).

---

## Precedencia de fuentes (ante conflicto)

**Código fuente (`lib/`) > este `CLAUDE.md` > `README.md` > `SETUP.md` (stale).**

Para el **dominio compartido** (Order, Stop, Visit, estados, evidencia), la fuente
es `docs/DOMAIN-MOBILE.md` (derivado del `docs/CONTEXT.md` del web).

Para el **wire de la API** (shapes, envelopes, campos congelados, flujo
offline, realtime, RBAC del conductor) la fuente es
**`docs/API-CONTRACT-MOBILE.md`** (espejo byte-idéntico; el canónico vive en
`planeamiento/docs/`). Tocar `lib/services/` o `lib/models/` que hablan con
el backend ⇒ consultar el contrato; cambiar un shape ⇒ bump de
`CONTRACT_VERSION` en ambos repos.

> **Drifts conocidos — no razones desde estos docs:**
> - `SETUP.md` dice que los tokens se guardan en `SharedPreferences` → **FALSO**:
>   van en `flutter_secure_storage` (`lib/services/storage_service.dart`).
>   `SharedPreferences` solo se usa para el offline outbox y el flag de onboarding.
> - La tabla de endpoints de `SETUP.md` omite el prefijo `/api` (el código usa
>   `/api/...` en `lib/core/constants.dart`).
> - Naming inconsistente: `pubspec` = `aea`, clase `EntregasApp`, título
>   `BetterRoute`, README "Driver Cockpit". Nombre canónico del producto: **BetterRoute**.

---

## Convenciones de código

- **Modelos** (`lib/models/`, barrel `models.dart`): clase con campos `final`,
  constructor `const`, `factory fromJson` **defensivo** (cast seguro, `tryParse` de
  coordenadas/fechas con fallback, defaults para nulos), `toJson` si se envía/persiste,
  `copyWith`, getters derivados.
- **Estado** (`lib/providers/`, barrel `providers.dart`): clase `<X>State` inmutable
  con `copyWith` (incluidos flags `clearError`/`clearUser` para poder setear a null),
  `<X>Notifier extends StateNotifier<<X>State>`, y trío de providers (servicio +
  `StateNotifierProvider` + `Provider` de conveniencia para selects).
- **Servicios** (`lib/services/`): singleton `factory <S>() => _instance` + `_internal()`.
  La lógica de red vive aquí, no en providers ni widgets.
- **Red:** un solo `Dio` en `ApiService`; el interceptor inyecta `Authorization: Bearer`
  + `x-company-id` + `x-user-id` y auto-refresca en 401. Errores → `ApiException`
  (mensajes en español). Único `Dio` suelto permitido: el `PUT` directo a R2 (presigned).
- **Navegación:** `go_router` en `lib/router/router.dart` (`AppRoutes` con constantes +
  helpers de path); pantallas en `CustomTransitionPage`; la lógica de redirect escucha
  `authProvider`.
- **Barrels:** cada carpeta exporta vía índice (`models.dart`, `providers.dart`,
  `widgets.dart`, …). Al agregar un archivo, registrá su export.

## Invariantes — no romper

1. **Evidencia antes de cerrar.** La foto sube a R2 (`getPresignedUrl` → `PUT` →
   `publicUrl`) y **debe** completarse antes del cierre. Dejá propagar la excepción;
   **nunca** devuelvas `null` ni cierres con `evidenceUrls` vacío (hubo un bug así).
2. **Cierres siempre por el OfflineOutbox.** `COMPLETED`/`FAILED` pasan por
   `OfflineOutbox.submitClose` (persiste antes de enviar) + `applyLocalClose`
   (optimista). El `PATCH` terminal es **idempotente** server-side — el outbox depende
   de eso para reintentar sin duplicar `delivery_visit`. Nunca hagas el `PATCH` directo.
3. **`failureReason` verbatim.** Es un string libre en español que viene de
   `policy.failureReasons`. **No** inventes un enum ni un código (el web sí tiene enum;
   el móvil diverge a propósito — ver `docs/DOMAIN-MOBILE.md`).
4. **Estados terminales no se reabren** desde el móvil (`COMPLETED`/`FAILED`). El
   reintento same-day lo dispara el operador desde el panel, no el conductor.
5. **Tokens SOLO en `flutter_secure_storage`.** Nunca en `SharedPreferences`.
6. **Headers de tenant** en toda request (los pone el interceptor).
7. **Release fail-closed:** `main()` llama `ApiConfig.assertValid()` antes de `runApp`
   (aborta si faltan URLs o no son `https`/`wss`). No lo quites.
8. **Config por `--dart-define`** (`API_BASE_URL`, `WS_URL`), nunca URLs hardcodeadas.

> **Trampa de lifecycle:** los servicios singleton (`TrackingService`, `OfflineOutbox`)
> **retienen su estado aunque un provider de Riverpod se resetee/disponga.** Resetear un
> provider NO limpia contadores de GPS ni entradas del outbox. No asumas lo contrario.

## Comandos

- `flutter pub get` — dependencias.
- `flutter analyze` — lints (usa `flutter_lints`).
- `flutter run --dart-define=API_BASE_URL=... --dart-define=WS_URL=...` — dev
  (ver `dart_define.example.json`).
- `scripts/build-release.ps1` / `scripts/build-release.sh` — build de release.

> No hay carpeta `test/` todavía pese a que `flutter_test` es dev-dep.

## Docs

- `docs/API-CONTRACT-MOBILE.md` — **contrato del seam** con el backend
  (espejo; canónico en `planeamiento/docs/`). Envelopes, campos congelados,
  fixes normativos FIX-1..10, versionado.
- `docs/specs/offline-outbox.spec.md` — spec de comportamiento del outbox
  offline (máquina de estados, FIX-1/FIX-2, tests requeridos).
- `docs/DOMAIN-MOBILE.md` — dominio (Route Execution) heredado del web, con divergencias.
- `docs/REVIEW-RUBRIC-MOBILE.md` — checklist de correctness/seguridad pre-PR.
- `docs/AGENT-UPGRADE-PLAN.md` — plan de artefactos durables (sesión del modelo SOTA).
