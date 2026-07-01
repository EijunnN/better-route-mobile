# Rúbrica de revisión — móvil (aea)

> **v1 — borrador generado durante el bootstrap del harness (2026-07-01).** Para que el
> SOTA la afine y para consumirse desde un subagente `revisor-movil`. Espeja el gate del
> web pero para invariantes del móvil. Recorre las reglas aplicables sobre cada diff;
> ante duda, **falla** (fail-closed).

## 0. No se introdujo codegen (la trampa #1)

- [ ] ¿El diff agregó algún `*.g.dart` / `*.freezed.dart`, alguna directiva `part '...'`,
      o alguna anotación `@freezed` / `@riverpod`? → **FALLA.** El repo es 100% a mano
      (ver `CLAUDE.md` §Regla #1).
- [ ] ¿Se corrió `build_runner`? → FALLA.

## 1. Evidencia antes de cerrar

- [ ] ¿Todo cierre `COMPLETED` con foto sube la evidencia a R2 **antes** de hacer el
      `PATCH`? ¿La excepción de subida **propaga** (nunca `null`, nunca cierre con
      `evidenceUrls` vacío)?
- [ ] En cierres offline con **varias fotos**: ¿cada subida pasa su `index`
      (= posición en `photoPaths` + 1, igual que el camino online)? Sin `index`,
      la key R2 con `trackingId` es determinística y las fotos se pisan →
      pérdida de evidencia. (FIX-1, `docs/specs/offline-outbox.spec.md` §3.)

## 2. Cierres por el OfflineOutbox (idempotencia)

- [ ] ¿El cierre pasa por `OfflineOutbox.submitClose` + `applyLocalClose`, nunca un
      `PATCH` terminal directo?
- [ ] ¿Se preservó la idempotencia (re-enviar un estado terminal no duplica
      `delivery_visit`)?
- [ ] En un `FAILED` offline: ¿se exige `failureReason` **antes** de encolar cuando la
      policy cacheada tiene motivos? El gate va en el formulario, no en el drain.
      (Un `FAILED` con `reason=''` → 400 permanente → el outbox lo descarta →
      **la falla se pierde**. FIX-2, `docs/specs/offline-outbox.spec.md` §4.)

## 3. `failureReason` verbatim

- [ ] ¿Se envía el string verbatim de `policy.failureReasons`? ¿No se introdujo un enum
      ni un código? (Ver divergencia en `docs/DOMAIN-MOBILE.md`.)

## 4. Estados terminales

- [ ] ¿El cambio evita reabrir un `COMPLETED`/`FAILED` desde el móvil?

## 5. Tokens y tenant

- [ ] ¿Los tokens y datos sensibles van **solo** en `flutter_secure_storage` (nunca
      `SharedPreferences`)?
- [ ] ¿Toda request nueva pasa por `ApiService` (headers de tenant + refresh 401)?

## 6. Config fail-closed

- [ ] ¿`main()` sigue llamando `ApiConfig.assertValid()` antes de `runApp`? ¿No se
      hardcodearon URLs (siguen por `--dart-define`)?

## 7. Trampa de lifecycle (singletons vs Riverpod)

- [ ] ¿El cambio asume que resetear/disponer un provider limpia el estado de un servicio
      singleton? → FALLA. `TrackingService` y `OfflineOutbox` **retienen su estado**
      independientemente del ciclo de vida de Riverpod.

## 8. UI del stop tras un PATCH

- [ ] ¿La UI refetchea `my-route` en vez de confiar en el resultado del `PATCH
      /route-stops`? (El PATCH devuelve una fila más plana, sin `order`/`timeWindow`/
      `liveEtaAt`/`attemptNumber` — mostrar eso degrada el stop. Contrato §4.)

## 9. Contrato del seam

- [ ] Si el diff toca `lib/services/` o `lib/models/` que hablan con la API:
      ¿se consultó `docs/API-CONTRACT-MOBILE.md`? ¿Los `fromJson` siguen
      alineados con los **campos congelados** (§9 del contrato)?
- [ ] Si cambió un shape esperado: ¿bump de `CONTRACT_VERSION` + fixtures de
      `test/contract/` actualizados **en ambos repos**?
- [ ] ¿El manejo de errores decide por **status code**, nunca por matching del
      string de `error`? (Los mensajes mezclan idiomas y no son estables.)

## 10. Resiliencia de sesión y realtime

- [ ] ¿El flujo de refresh 401 mantiene single-flight real (requests
      concurrentes **esperan** el refresh en vuelo y se replayean)? No copiar
      el patrón viejo del bool `_isRefreshing`. (FIX-4, contrato §2.)
- [ ] ¿`clearAll()` (logout duro) solo se dispara ante un **401 del propio
      `/api/auth/refresh`**, nunca por timeout/red? Un 401 del refresh =
      sesión terminada (7 días) → re-login; no es transitorio.
- [ ] ¿El `getToken` de Centrifugo lanza `UnauthorizedException` SOLO ante un
      401 real del endpoint? Cualquier otro error debe dejar reintentar al
      SDK. (FIX-5, contrato §7.)

---

*Los seams cross-repo ya tienen fuente única: `docs/API-CONTRACT-MOBILE.md`
(envelopes, versionado, realtime, refresh 401, capability set RBAC) y
`docs/specs/offline-outbox.spec.md` (flujo offline↔servidor).*
