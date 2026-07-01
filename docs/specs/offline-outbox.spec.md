# Spec — Outbox offline de cierres (móvil) y sus garantías server-side

> **v1 — 2026-07-01 (sesión SOTA).** Spec de comportamiento del
> `OfflineOutbox` (`lib/services/offline_outbox.dart`). El wire format vive
> en `docs/API-CONTRACT-MOBILE.md §5` — este doc especifica el **algoritmo,
> los invariantes y los casos borde**, incluidos los dos fixes críticos
> (FIX-1, FIX-2) que Opus debe implementar. Los cambios de comportamiento
> aquí exigen actualizar los tests de esta spec y, si tocan el wire, bump de
> `CONTRACT_VERSION`.

## 1. Contrato de las partes

**El móvil garantiza:**
- Todo cierre terminal (`COMPLETED`/`FAILED`) entra por
  `OfflineOutbox.submitClose` — nunca un PATCH directo (rúbrica §2).
- `submitClose` **persiste a disco antes** de cualquier intento de red
  (SharedPreferences `offline_outbox_v1`), y aplica `applyLocalClose`
  (estado optimista + aviso "Sin señal: se enviará al reconectar").
- Un solo `PendingClose` por stop (`id == stopId`): re-cerrar reemplaza.

**El server garantiza (regla espejo — congelada en el contrato §3.6):**
- El PATCH de una transición terminal **re-enviada con el mismo status** es
  no-op idempotente: `200 { data: <fila actual> }` sin duplicar
  `delivery_visits` ni history. El outbox depende de esto para reintentar
  tras un ack perdido.
- Lock optimista → `409`: transitorio para el outbox (reintenta).

## 2. Máquina de estados de un `PendingClose`

```
encolado ──flush──> subiendo fotos ──> PATCH ──2xx──> done (se remueve)
   ▲                    │                 │
   │            (por foto: presign      4xx ──> DROP definitivo (lastError)
   │             +PUT; resume-safe      409/5xx/red ──> retryCount++
   │             vía uploadedByPath)         │
   └─────────────────────────────────────────┘  retryCount > 60 ──> DROP
```

- **Transitorio** = DioException sin response, status `null` o `>=500`,
  excepción desconocida, y `409`. **Definitivo** = cualquier otro `4xx`.
- El flush es secuencial y corta al primer fallo transitorio (si no hay
  red, el resto también fallaría). Triggers: timer 30 s, post-`submitClose`,
  app resume, reload de ruta.
- Un DROP es **solo client-side** (`lastError`); no se informa al server
  (gap aceptado v1 — no "arreglar" de pasada).

## 3. Fotos (evidencia) — FIX-1 🔴

- Por cada path en `photoPaths` que no esté en `uploadedByPath`:
  presign → PUT R2 → registrar `path → publicUrl` en `uploadedByPath` y
  **persistir** (resume-safe: un crash a mitad de subida no re-sube).
- **FIX-1 (obligatorio):** el presign del drain DEBE pasar
  `index = posición_en_photoPaths + 1`, igual que el camino online
  (`stop_detail_screen`). Sin `index`, la key R2 con `trackingId` es
  determinística (`{trackingId}.jpg`) y las fotos N>1 pisan la primera.
  No hace falta campo nuevo en `PendingClose`: el índice ES la posición.
- Archivo local desaparecido → se salta esa foto (el cierre sale con menos
  evidencia). Nota: si la policy exige foto y TODAS desaparecieron, el
  PATCH dará 400 → DROP definitivo; aceptado v1 (el operador ve el stop
  abierto y el driver la parada pendiente — consistente).

## 4. FAILED requiere motivo — FIX-2 🔴

- **FIX-2 móvil (obligatorio):** si la policy cacheada tiene
  `failureReasons` no-vacío, la UI del cierre FAILED exige motivo **antes
  de encolar**. El gate va en el formulario, no en el drain (un
  `PendingClose` inválido ya persistido es una falla garantizada).
- **FIX-2 web (obligatorio):** `failureReason` debe validarse no-blank tras
  `trim()` (hoy `"  "` pasa). No se valida membresía en la lista
  (deliberado, ADR-0011: una policy cacheada stale no debe convertir una
  falla real en 400 permanente).
- Racional del par: el modo de pérdida es `FAILED sin motivo → 400 → DROP →
  la falla nunca llega al server` — el peor outcome posible (el operador
  cree que el stop sigue pendiente de cierre).

## 5. Interacción con el estado local

- `applyLocalClose` marca el stop terminal en el provider; el refetch de
  `my-route` NO debe resucitar el stop mientras su `PendingClose` viva
  (el server aún lo ve PENDING/IN_PROGRESS). Regla: al mergear `my-route`,
  un stop con entrada viva en el outbox conserva el estado local.
- Tras un drain exitoso → refetch `my-route` (nunca renderizar desde la
  respuesta del PATCH — contrato §4).
- **Trampa de lifecycle:** `OfflineOutbox` es singleton; resetear providers
  de Riverpod NO limpia la cola (CLAUDE.md). El logout NO debe vaciar el
  outbox (cierres pendientes de otro login del mismo driver deben drenar);
  sí debe cortar el auto-flush hasta el próximo login.

## 6. Tests que Opus debe escribir (`test/` — primer contenido del repo)

Unit (mockear RouteService; sin red):
1. `submitClose` persiste antes de intentar red (kill simulado post-persist
   → la entrada sobrevive un reload).
2. Drain multi-foto presigna con `index` 1..N (FIX-1) y respeta
   `uploadedByPath` (no re-sube).
3. FAILED sin motivo con policy con motivos → `submitClose` rechaza
   (FIX-2; assert que NUNCA se encola).
4. 4xx → drop definitivo; 409/5xx/sin-response → retryCount++; >60 → drop.
5. Reenvío de terminal idéntico → el outbox trata 200-con-fila-actual como
   éxito (idempotencia).
6. Payload corrupto en SharedPreferences → se descarta sin crash.

Server-side (web repo, `src/tests/`):
7. PATCH terminal repetido no duplica `delivery_visits` (regla espejo).
8. `failureReason: "  "` → 400 (FIX-2 web).
