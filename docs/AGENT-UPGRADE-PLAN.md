# Plan de potenciación del agente — móvil (aea) + seam cross-repo

> **Qué es esto.** Plan para usar la ventana (**una sola sesión**) de acceso a un modelo
> SOTA construyendo artefactos durables que potencien permanentemente al agente cotidiano
> (Opus 4.8) sobre este repo móvil **y sobre el contrato que comparte con el backend web**
> (`../planeamiento`). Complementa `../planeamiento/docs/AGENT-UPGRADE-PLAN.md`. **Se
> ejecuta todo en una sesión, en orden de dependencia (no día por día).**
>
> Filosofía: el SOTA entiende, juzga y ESPECIFICA (leyendo **ambos repos a la vez**, algo
> que Opus no puede); Opus ejecuta. Generado por exploración multi-agente. Fecha: 2026-07-01.

---

## Diagnóstico

- 🔴 **Harness de agente: CERO.** No había `CLAUDE.md`, `.claude/` ni `docs/`. Greenfield.
- ⚠️ **Trampa #1:** `pubspec` + `README` anuncian codegen (freezed / riverpod_generator /
  build_runner) pero el repo **no usa codegen** (cero generados, todo a mano). Un agente
  débil intentará `build_runner` → build roto. *(Ya fijado en `CLAUDE.md`.)*
- 🟢 **Dominio bien documentado… en el otro repo.** El `CONTEXT.md` del web define el
  dominio compartido; el móvil no lo tenía a mano. *(Ya heredado en `DOMAIN-MOBILE.md`.)*

## Tesis

El mayor valor único de la sesión **no** es más harness móvil aislado — es el **SEAM
cross-repo**. Opus, dirigiendo un repo, nunca ve el otro, así que no puede detectar los
bugs de contrato. El SOTA, leyendo los dos a la vez, **especifica el contrato** (la joya),
y Opus ejecuta el resto por meses.

## Bugs reales del seam ya detectados (proof of value)

| Bug | Consecuencia |
|---|---|
| Cierre **offline FAILED con motivo vacío** → server 400; el outbox descarta 4xx | La entrega fallida **se pierde** (nunca llega al server) |
| Foto **offline sin `index`** (el online sí lo pasa) → misma key R2 | **Se pierden fotos** en cierres offline multi-foto |
| Cola de GPS **solo en memoria** (el outbox de cierres sí es a disco) | Se pierde en un kill de proceso en zona sin señal |
| `PATCH /route-stops` devuelve fila **más plana** que `my-route` (misma entidad) | UI muestra un stop degradado si confía en el PATCH |
| `getToken` Centrifugo lanza en **cualquier** error, no solo 401 real | Mata el reconnect ante un blip de red |
| `Dio` refresh 401: guard `_isRefreshing` **no es single-flight** | Refresh-storms / carreras de rotación bajo 401 paralelos |
| El móvil asume que `CONDUCTOR` tiene `ORDER:read` (invisible desde aquí) | Un cambio RBAC en el web **mata una feature móvil en silencio** |

---

## Artefactos cross-repo 🅰️ (SOLO el SOTA — ve ambos repos)

1. **Contrato de API tipado del seam** — mapa de envelopes de los 14 endpoints + el drift
   de shape `PATCH` crudo vs `my-route` rico. `aea/docs/API-CONTRACT-MOBILE.md` + espejo web.
2. **Versionado `/api/v1` + contract-tests** que corran los parsers `fromJson` de Flutter
   contra respuestas grabadas del server **en el CI del web**. *(Decidir el mecanismo:
   toolchain Dart-en-CI vs generar tipos Dart desde schema — si no se decide, es enforcement
   teatral.)*
3. **Spec del flujo offline↔servidor** — idempotencia del PATCH terminal, el `index` R2
   faltante, el `FAILED`-reason-vacío → 400. `aea/docs/specs/offline-outbox.spec.md` + regla espejo.
4. **Contrato realtime Centrifugo/OneSignal versionado** — envelope kinds, derivación de
   canal, `external_id == user.id`, fix de `getToken`, **y el drift del OneSignal App ID**
   (hardcode móvil vs env server). Encaja con el subagente `realtime-channel-auth` del web.
5. **Spec del refresh de sesión 401** *(añadido por el crítico)* — single-flight real +
   rotación/revocación de `sessionId` contra Redis. Hoy era solo un antipatrón sin spec.
6. **Contrato "driver capability set" RBAC** + test server-side que asserte que `CONDUCTOR`
   concede `ROUTE:read`, `ROUTE_STOP:read+update`, `ORDER:read`, `CHAT:read+create`.
7. **DTO estable de `delivery-policy`** + catálogo de quick-replies servido desde el backend
   (hoy hand-duplicado y drifteando).

## Artefactos mobile-only 🅱️ (SOTA suelta el contrato, Opus redacta)

- `CLAUDE.md` (constitución no-codegen). ✅ *sembrado*
- `docs/DOMAIN-MOBILE.md` (Route Execution + divergencias). ✅ *sembrado*
- `docs/REVIEW-RUBRIC-MOBILE.md` (+ invariante lifecycle-singletons). ✅ *sembrado*
- Skills anti-codegen: `nuevo-modelo`, `nuevo-provider-riverpod`, `nueva-pantalla`.
- Subagente `revisor-movil` (corre la rúbrica + `flutter analyze` + grep anti-codegen).
- Spec de tracking GPS (asimetría de durabilidad de la cola de ubicaciones).
- Reconciliación de drift de `SETUP.md`/`README` + nombre canónico.

---

## Integración con la sesión del web (todo en una sola sesión)

Todo se hace en la **misma sesión** que el plan del web, en las mismas 3 fases por orden
de dependencia. Los artefactos del móvil se enganchan a la fase donde el SOTA **ya tiene
abiertos los mismos archivos del seam**, sin trabajo extra:

- **Fase 1 (fuente única de verdad):** el bloque grande cross-repo — contrato de API
  tipado + versionado/contract-tests, spec del flujo offline, contrato realtime
  Centrifugo/OneSignal + fix `getToken`, spec del refresh 401, contrato "driver capability
  set" RBAC y DTO de delivery-policy. Es lo único que SOLO el SOTA puede escribir.
- **Fase 2 (guardarraíles):** `REVIEW-RUBRIC-MOBILE` afinada + subagente `revisor-movil` +
  skills anti-codegen (`nuevo-modelo`/`provider`/`pantalla`) + spec de tracking GPS.

Regla de secuencia (igual que el web): **la fuente única va primero** (contratos del seam +
decisión no-codegen); rúbrica, skills y subagente se construyen encima. **Si la sesión se
acorta, prioriza los contratos del seam de la Fase 1** — es lo único irrecuperable después.

## Antipatrones (en qué NO gastar el SOTA)

- ❌ Correr `build_runner` / agregar `@freezed`/`@riverpod`/`part` para "cumplir" con pubspec.
- ❌ Confiar en `SETUP.md`/`README` sobre el código (tokens en secure_storage, no SharedPreferences).
- ❌ Escribir código de feature Dart / widgets / CRUD — eso lo ejecuta Opus.
- ❌ Editar intervalos GPS / `foregroundNotificationConfig` sin cuidar la legalidad de
  background-location (config native fuera de scope, sin test in-repo que lo atrape).
- ❌ Escribir el contrato de API solo en el móvil adivinando shapes — debe autorearse
  viendo ambos repos, o vuelve a driftear.

---

## Estado tras la sesión SOTA (2026-07-01) — hecho por el SOTA

- ✅ **`docs/API-CONTRACT-MOBILE.md`** (espejo byte-idéntico; canónico en
  `planeamiento/docs/`) — cubre los artefactos 🅰️ 1, 2, 4, 5, 6 y 7 de este
  plan: envelopes de 20 endpoints, drift PATCH-vs-my-route (§4), versionado
  + contract-tests (§10, fixtures golden sin codegen), realtime/OneSignal
  (§7, incl. fix `getToken` = FIX-5 y App ID = FIX-10), refresh 401 (§2,
  FIX-4), capability set RBAC (§8), DTO delivery-policy + quick replies
  (§3.8, FIX-9).
- ✅ **`docs/specs/offline-outbox.spec.md`** — artefacto 🅰️ 3 (FIX-1/FIX-2 +
  máquina de estados + tests requeridos).
- ✅ Rúbrica afinada (v2: §9 contrato, §10 sesión/realtime) y regla
  NO-CODEGEN con casos borde (purga de deps, mocktail, gen-l10n, `part`).
- ✅ CLAUDE.md: precedencia actualizada (el wire manda el contrato).

### Cola de Opus (en orden)

1. FIX-1 y FIX-2 (pérdida de datos) + tests de la spec del outbox — el
   directorio `test/` nace acá.
2. Contract-tests móviles (`test/contract/` sobre los fixtures espejados) +
   `lib/core/contract_version.dart` (contrato §10).
3. FIX-4 (single-flight), FIX-5 (`getToken`), FIX-10 (App ID a dart-define).
4. Subagente `revisor-movil` (corre rúbrica + `flutter analyze` + grep
   anti-codegen) y skills `nuevo-modelo`/`nuevo-provider`/`nueva-pantalla`.
5. Purga de deps codegen del `pubspec` + fix `README` línea build_runner +
   `SETUP.md` (tokens/prefijo `/api`) — la regla ya lo mandata.
6. Decisión GPS-queue (contrato §6): persistir la cola de ubicaciones con
   el patrón del outbox, o ADR-cito documentando la pérdida como aceptable.

## Ya hecho (2026-07-01 — bootstrap del harness móvil)

- **`CLAUDE.md`** creado: constitución con la decisión tajante **NO-CODEGEN**, convenciones,
  invariantes (evidencia-antes-de-cerrar, outbox idempotente, failureReason verbatim,
  secure_storage, fail-closed, trampa de lifecycle), precedencia de fuentes y drifts.
- **`docs/DOMAIN-MOBILE.md`** creado: Route Execution heredado del web + las 3 divergencias.
- **`docs/REVIEW-RUBRIC-MOBILE.md`** creada (v1): 9 checks, incluido el anti-codegen y el
  lifecycle-singletons.
- Este plan (`docs/AGENT-UPGRADE-PLAN.md`).
