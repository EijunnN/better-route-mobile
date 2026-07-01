# Dominio del móvil — Route Execution

> **v1 — borrador generado durante el bootstrap del harness (2026-07-01).** Para que
> el modelo SOTA lo afine. Adapta el bounded context **§5 Route Execution** del
> `docs/CONTEXT.md` del backend web (`../planeamiento`). El resto del dominio del web
> (Identity/Tenancy interno, Master Data, Order Management, Plan Optimization / VROOM /
> OSRM / verifier, Zones, Public Tracking, Reporting) **queda fuera del alcance del
> móvil** y solo se referencia.

## Lenguaje ubicuo (heredado tal cual)

Estos términos tienen **un solo significado** compartido con el web.

| Término | En el móvil |
|---|---|
| **Order** | Pedido de entrega. Llega anidada dentro del stop como `OrderInfo`. |
| **Stop** (`RouteStop`) | Una `Order` materializada como parada en una ruta. Una Order puede tener múltiples Stops históricos (revisitas). |
| **Visit / Revisita** | Cada cierre terminal (`COMPLETED`/`FAILED`) genera una `delivery_visit` **inmutable** en el backend. El móvil expone la vista vía `RouteStop.attemptNumber` (1 = primer intento, 2+ = revisita), `priorVisitsCount` e `isRevisit`. Úsalos para mensajes contextuales ("Intento #N"). |
| **Evidence** | Fotos subidas a R2 vía presigned URL. |
| **WorkflowState** | Estado de la parada + su presentación (label, color, gates de foto/notas). |
| **Driver / Conductor** | El usuario de esta app (`role == CONDUCTOR`). |

## Invariantes heredados (del web CONTEXT.md)

- **#7 Evidence falla la operación:** si la subida a R2 falla, la entrega **no** se
  cierra y el error sube al usuario. (Ya implementado; hubo un bug que devolvía `null`.)
- **#6 Estados terminales no se reabren:** `COMPLETED`/`FAILED` son terminales para el
  conductor. El reintento same-day lo dispara el operador desde el panel, **no** el
  conductor desde el móvil — esto acota lo que el móvil puede hacer.
- La máquina de estados está **cristalizada server-side** e idéntica para toda empresa;
  solo varía la presentación (labels, colores, gates, lista de motivos), que viene de
  `GET /api/mobile/driver/delivery-policy`. No hay endpoint `/workflow-states`: el móvil
  reconstruye `WorkflowState` desde `{policy, stateMachine}`.

## ⚠️ Divergencias deliberadas (el móvil NO es igual al web)

Un agente podría "corregir" estas hacia el web y **romper** el contrato. Son intencionales:

1. **`FailureReason` es texto libre, no enum.** El web define un enum categorizado
   (`CUSTOMER_ABSENT | CUSTOMER_REFUSED | ...`). El **móvil no tiene enum**: los motivos
   son strings en español por empresa (`policy.failureReasons`) y se envían **verbatim**
   (comentario explícito en `lib/models/route_stop.dart`). No introduzcas un enum.
2. **`StopStatus` no tiene `SKIPPED`.** El web lista `PENDING → IN_PROGRESS →
   COMPLETED | FAILED | SKIPPED`; el móvil solo maneja los **4** primeros — el conductor
   no puede saltar paradas.
3. **Realtime = Centrifugo + OneSignal.** El `CONTEXT.md §7` del web dice "SSE + Upstash
   Redis", pero eso está **stale** — la verdad (ADR-0007) es Centrifugo (chat) + OneSignal
   (push, con `external_id == user.id`), que es justo lo que usa el móvil. Hereda la
   versión corregida.

## Fuera de alcance del móvil

Optimización (VROOM/OSRM), verifier, zonas, presets, import CSV, aislamiento multi-tenant
a nivel de query (el móvil solo hereda el **contrato de headers** `Authorization` +
`x-company-id`, y la regla "el JWT manda").
