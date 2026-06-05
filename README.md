# BetterRoute — App del Conductor (Driver Cockpit)

**El cockpit del conductor de última milla.** App móvil Flutter (Android / iOS)
para que el conductor vea su ruta del día, navegue, cierre entregas con
evidencia y se mantenga conectado con despacho — **incluso en zonas sin señal**.

![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![Riverpod](https://img.shields.io/badge/Riverpod-2.6-blue)

> Es el cliente móvil de la plataforma **BetterRoute**. Habla con el backend
> Next.js (`/api/mobile/driver/*`, `/api/route-stops/*`, `/api/chat/*`).

---

## Tabla de contenidos

- [¿Por qué esta app?](#por-qué-esta-app)
- [Funcionalidades destacadas](#funcionalidades-destacadas)
- [Requisitos](#requisitos)
- [Cómo levantar el proyecto](#cómo-levantar-el-proyecto)
- [Configuración](#configuración)
- [Arquitectura](#arquitectura)
- [Compilar para producción](#compilar-para-producción)
- [Internacionalización (i18n)](#internacionalización-i18n)
- [Relacionado](#relacionado)

---

## ¿Por qué esta app?

El conductor es quien ejecuta la operación en la calle, muchas veces con
guantes, al sol, en movimiento y — sobre todo — **con señal intermitente**. Una
buena planificación no sirve de nada si la herramienta del conductor lo
bloquea cuando más la necesita.

Esta app nació con una prioridad clara: **que el conductor nunca quede
atascado**. Está diseñada para ser rápida, legible de un vistazo, con
confirmación háptica, y **resiliente al offline**: si no hay señal al cerrar una
entrega, el cierre se guarda local y se sincroniza solo cuando vuelve la
conexión. Nada se pierde.

---

## Funcionalidades destacadas

### Ruta y entregas
- **Agenda del día** ordenada por secuencia, con filtros (todas / pendientes /
  hechas) y *pull-to-refresh*.
- **Detalle de parada:** cliente (llamar · WhatsApp · copiar), navegación a
  **Google Maps o Waze**, nota de despacho y campos personalizados del pedido.
- **Cierre de entrega** guiado en 3 pasos: fotos de evidencia → datos (campos
  personalizados que la empresa configuró) → confirmar. La evidencia se sube a
  almacenamiento S3 (Cloudflare R2) por *presigned URL*.
- **Reporte de no-entrega** con los motivos que define cada empresa (la app los
  obtiene de la política de entrega; el motivo elegido se envía verbatim).

### Resiliencia offline (outbox)
- **Cierres a prueba de zonas muertas:** marcar una entrega COMPLETED/FAILED sin
  señal **no bloquea** al conductor. El cierre — estado, motivo, notas, campos,
  GPS y fotos — se **persiste en disco** y se **sincroniza automáticamente** al
  recuperar conexión (reintenta por *timer*, al volver al foreground y en cada
  carga de ruta).
- **Cierre optimista:** la parada se marca como hecha al instante, con un aviso
  *"Sin señal: se enviará al reconectar"* y un banner de *N pendientes de
  sincronizar* en el inicio.
- **Idempotente y seguro:** un reintento tras un *ack* perdido no duplica la
  visita de entrega; las fotos se suben una sola vez (resume-safe).

### Tracking GPS
- Envío de ubicación con **cadencia adaptativa** (≈20 s en movimiento / ≈60 s
  detenido) para ahorrar batería, con nivel de batería y contexto de parada.
- **Cola offline** de ubicaciones con reintentos cuando no hay conexión.
- El GPS del dispositivo funciona sin red, por lo que la **posición real**
  queda registrada también en cada cierre de entrega (insumo para reconstruir
  la trayectoria del conductor).

### Comunicación
- **Chat con despacho** en tiempo real (Centrifugo) + **notificaciones push**
  (OneSignal), incluyendo **mensajes de emergencia (broadcast)** a toda la
  flota.

### Diseño
- Tema **oscuro** con sistema de design tokens (paleta lime / navy alineada con
  el panel web), pensado para legibilidad en exteriores.

> **Nota de modelo:** los estados de entrega son fijos
> (`PENDING · IN_PROGRESS · COMPLETED · FAILED`). Lo que varía por empresa es la
> *presentación* (etiquetas, colores, requisitos de foto/firma/notas y la lista
> de motivos de fallo), que la app obtiene de
> `GET /api/mobile/driver/delivery-policy`.

---

## Requisitos

- **Flutter** 3.10+ y **Dart** 3.x
- **Android Studio** o **VS Code** con los plugins de Flutter
- **Android SDK** 21+ (o **iOS** 12+, solo en macOS con Xcode)
- El **backend BetterRoute** corriendo y accesible (ver su README)

---

## Cómo levantar el proyecto

```bash
flutter pub get

# Generar el código de modelos (freezed / json_serializable)
dart run build_runner build --delete-conflicting-outputs

# Listar dispositivos y correr
flutter devices
flutter run
```

En **desarrollo no hay que configurar URLs**: en debug, la app usa por defecto
el loopback del emulador Android (`http://10.0.2.2:3000` y
`ws://10.0.2.2:8000`). Para un **dispositivo físico**, pasá la IP de tu máquina:

```bash
flutter run --dart-define=API_BASE_URL=http://TU-IP:3000 \
            --dart-define=WS_URL=ws://TU-IP:8000/connection/websocket
```

> Para el flujo completo de setup, requisitos del backend (crear conductor,
> asignar vehículo, confirmar un plan) y troubleshooting, ver
> [`SETUP.md`](./SETUP.md).

---

## Configuración

### URLs del backend (build-time, no en el código)

Las URLs se inyectan con `--dart-define`. La app **falla al arrancar**
(`ApiConfig.assertValid`) si en un build de **release** faltan o no usan TLS
(`https://` / `wss://`) — así nunca se publica un build apuntando al entorno de
desarrollo por error.

```bash
cp dart_define.example.json dart_define.json   # editá API_BASE_URL + WS_URL
```

`dart_define.json` está en `.gitignore` (valores por instalación); la plantilla
`dart_define.example.json` sí se versiona.

### Push (OneSignal)

El push usa **External ID = id del usuario**, así el backend direcciona con
`include_aliases.external_id` sin que la app registre un *player id*. Verifica
que el **App ID** de OneSignal de la app coincida con el del backend
(`ONESIGNAL_APP_ID`).

### Tracking (cadencia y reintentos)

Ajustable en `lib/core/constants.dart` (`AppConstants`): intervalos en
movimiento/detenido, umbral de movimiento, filtro de distancia y reintentos.

### Permisos Android

Ya configurados en `android/app/src/main/AndroidManifest.xml` (internet,
ubicación fina/aproximada/background, cámara).

---

## Arquitectura

**Riverpod** para estado, **go_router** para navegación, **Dio** para HTTP
(con interceptor de refresh de JWT), y servicios singleton para la lógica.

```
UI (screens / widgets)
        │
        ▼
Providers (Riverpod)        auth · route · location · tracking · chat · …
        │
        ▼
Services (lógica)           api · auth · route · location · tracking ·
        │                   offline_outbox · chat · storage · push_router
        ▼
Fuentes de datos            API REST · Centrifugo (WS) · GPS · disco
```

```
lib/
├── core/            constants (URLs/config) · design tokens (colores/tipografía/spacing)
├── models/          user · driver_info · vehicle · route_data · route_stop ·
│                    pending_close (outbox) · field_definition · workflow_state
├── providers/       auth · route · location · tracking · chat · field_definition
├── services/        api · auth · route · location · tracking · offline_outbox ·
│                    chat · storage · push_router
├── screens/         splash · login · home · stop_detail · success · end_of_day ·
│                    chat · route_map · permissions · onboarding
├── widgets/         app (botones, inputs) · sheets (entrega, fallo, transición) · shared
└── router/          go_router
```

### Outbox offline (cómo funciona)

1. Al cerrar una entrega, el cierre (estado + fotos locales + GPS + campos) se
   **encola y persiste** (`shared_preferences`) antes de intentar enviarlo.
2. Se intenta sincronizar de inmediato. Si hay señal → listo. Si no → queda en
   cola y la parada se marca **optimistamente** como hecha.
3. El *flush* reintenta automáticamente: por *timer*, al volver al foreground y
   en cada carga de ruta exitosa. Sube las fotos pendientes y hace el `PATCH`.
4. El backend **no-opera** un reenvío de un estado terminal ya aplicado, así que
   un reintento nunca duplica la visita de entrega.

---

## Compilar para producción

Las builds de release inyectan las URLs desde `dart_define.json`
(ver [Configuración](#configuración)).

```bash
./scripts/build-release.sh apk         # Windows: .\scripts\build-release.ps1 apk
./scripts/build-release.sh appbundle   # AAB para Play Store
./scripts/build-release.sh ios         # requiere macOS + Xcode
# Equivalente directo:
# flutter build apk --release --dart-define-from-file=dart_define.json
```

Para firma de Android (keystore / `key.properties`) y subida a las tiendas, ver
[`SETUP.md`](./SETUP.md).

---

## Internacionalización (i18n)

Hoy la app está en **español** (mercado LATAM). Parte de los textos de cara al
conductor ya son **datos del backend** (motivos de no-entrega y etiquetas de
estado vienen de la política de entrega), lo que facilita traducirlos por
empresa.

**En el roadmap:** adoptar i18n para soportar cualquier idioma.

- `flutter_localizations` + `gen-l10n` con archivos `.arb` por idioma para los
  strings de la app.
- Selección de locale por usuario (o derivado del dispositivo).
- Mantener traducibles los datos por empresa (etiquetas / motivos) desde la
  configuración del panel web.

Meta: que el mismo binario sirva a operaciones en cualquier región.

---

## Relacionado

- **Backend / panel web BetterRoute** — API Next.js + optimización VROOM/OSRM,
  despacho, monitoreo y tracking. (Ver su `README.md`.)

<div align="center">

**BetterRoute — App del Conductor** · Entregas eficientes, conductores
informados.

</div>
