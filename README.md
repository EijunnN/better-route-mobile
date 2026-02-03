# BetterRoute Mobile

**App movil para conductores de delivery**

Aplicacion Flutter para Android/iOS que permite a los conductores gestionar sus entregas diarias, con tracking GPS en tiempo real.

![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)
![Riverpod](https://img.shields.io/badge/Riverpod-2.6-blue)

---

## Tabla de Contenidos

- [Caracteristicas](#caracteristicas)
- [Requisitos](#requisitos)
- [Instalacion](#instalacion)
- [Configuracion](#configuracion)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Arquitectura](#arquitectura)
- [Compilacion](#compilacion)
- [Uso](#uso)

---

## Caracteristicas

### Para el Conductor
- Ver lista de paradas del dia ordenadas por secuencia
- Navegar a cada parada con Google Maps o Waze
- Marcar entregas como completadas o fallidas
- Capturar foto de evidencia
- Registrar motivo de no entrega
- Ver metricas de progreso (completadas/pendientes)

### Tracking GPS
- Envio automatico de ubicacion cada 20 segundos
- Nivel de bateria incluido en cada reporte
- Cola offline para cuando no hay conexion
- Hasta 100 ubicaciones en cola
- Reintentos automaticos (3 intentos por envio)
- Inicia al abrir la app, detiene al cerrar sesion

### Offline-First
- Datos de ruta cacheados localmente
- Cola de sincronizacion para ubicaciones fallidas
- Tokens almacenados de forma segura

---

## Requisitos

- **Flutter** 3.10+
- **Dart** 3.0+
- **Android Studio** o **VS Code** con plugins Flutter
- **Android SDK** 21+ (Android 5.0 Lollipop)
- **iOS** 12+ (para compilacion iOS)

---

## Instalacion

### 1. Clonar el repositorio

```bash
git clone https://github.com/EijunnN/better-route-mobile.git
cd better-route-mobile
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Generar codigo (modelos freezed)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Ejecutar en desarrollo

```bash
# Listar dispositivos disponibles
flutter devices

# Ejecutar en dispositivo/emulador
flutter run
```

---

## Configuracion

### URL del Backend

Editar `lib/core/constants.dart`:

```dart
class ApiConfig {
  // Desarrollo - Android Emulator
  static const String baseUrl = 'http://10.0.2.2:3000';

  // Desarrollo - iOS Simulator
  // static const String baseUrl = 'http://localhost:3000';

  // Produccion
  // static const String baseUrl = 'https://tu-api.betterroute.com';
}
```

### Configuracion de Tracking

```dart
class AppConstants {
  // Intervalo de envio de ubicacion (segundos)
  static const int trackingIntervalSeconds = 20;

  // Distancia minima para actualizar (metros)
  static const int trackingDistanceFilterMeters = 15;

  // Intentos de reenvio en caso de fallo
  static const int trackingRetryAttempts = 3;

  // Delay entre reintentos (segundos)
  static const int trackingRetryDelaySeconds = 5;
}
```

### Permisos Android

Los permisos ya estan configurados en `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

---

## Estructura del Proyecto

```
lib/
├── main.dart                 # Entry point
├── core/
│   ├── constants.dart        # API config, app constants
│   └── theme.dart            # Colores y estilos
├── models/
│   ├── models.dart           # Export barrel
│   ├── user.dart             # Modelo de usuario
│   ├── driver_info.dart      # Info del conductor
│   ├── vehicle.dart          # Vehiculo asignado
│   ├── route_data.dart       # Datos de ruta
│   └── route_stop.dart       # Parada de ruta
├── providers/
│   ├── providers.dart        # Export barrel
│   ├── auth_provider.dart    # Estado de autenticacion
│   ├── route_provider.dart   # Estado de ruta/paradas
│   ├── location_provider.dart # Estado de GPS local
│   └── tracking_provider.dart # Estado de tracking al servidor
├── services/
│   ├── api_service.dart      # Cliente HTTP (Dio)
│   ├── auth_service.dart     # Login/logout
│   ├── route_service.dart    # Obtener ruta del dia
│   ├── location_service.dart # GPS local
│   ├── tracking_service.dart # Envio de ubicacion al servidor
│   └── storage_service.dart  # Almacenamiento seguro
├── screens/
│   ├── splash_screen.dart    # Pantalla inicial
│   ├── login_screen.dart     # Login
│   ├── home_screen.dart      # Lista de paradas
│   └── stop_detail_screen.dart # Detalle de parada
├── widgets/
│   ├── stop_card.dart        # Card de parada
│   ├── driver_header.dart    # Header con info conductor
│   ├── metrics_header.dart   # Metricas de progreso
│   ├── delivery_action_sheet.dart  # Acciones de entrega
│   └── failure_reason_sheet.dart   # Selector de motivos
└── router/
    └── router.dart           # GoRouter config
```

---

## Arquitectura

### State Management: Riverpod

```
UI (Screens/Widgets)
        │
        ▼
    Providers (Riverpod)
        │
        ▼
    Services (Business Logic)
        │
        ▼
    Data Sources (API, Storage, GPS)
```

### Providers Principales

| Provider | Descripcion |
|----------|-------------|
| `authProvider` | Estado de sesion (user, tokens) |
| `routeProvider` | Ruta del dia y paradas |
| `locationProvider` | Ubicacion GPS local |
| `trackingProvider` | Envio de ubicacion al servidor |

### Flujo de Tracking GPS

```
App Inicia
    │
    ▼
locationProvider.startTracking()  ─── GPS Local
    │
    ▼
trackingProvider.startTracking()  ─── Envio al Servidor
    │
    ▼
Timer cada 20s
    │
    ▼
POST /api/mobile/driver/location
    │
    ├── Success: Incrementar contador
    │
    └── Failure: Agregar a cola offline
                    │
                    ▼
              Reintentar cuando hay conexion
```

---

## Compilacion

### Android APK (Debug)

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Android APK (Release)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS (requiere macOS)

```bash
flutter build ios --release
```

---

## Uso

### Login

1. Abrir la app
2. Ingresar usuario y contrasena
3. El sistema valida contra el backend

### Ver Paradas

1. Despues del login, ver lista de paradas
2. Tabs: Todas / Pendientes / Completadas
3. Pull-to-refresh para actualizar

### Completar Entrega

1. Tap en una parada
2. Ver detalles (direccion, cliente, notas)
3. Tap "Navegar" para abrir Google Maps/Waze
4. Tap "Completar Entrega"
5. Capturar foto de evidencia (opcional)
6. Confirmar

### Registrar No Entrega

1. Tap en una parada
2. Tap "No se pudo entregar"
3. Seleccionar motivo (ausente, direccion incorrecta, etc.)
4. Agregar notas (opcional)
5. Confirmar

### Cerrar Sesion

1. Tap en icono de logout (header)
2. Confirmar
3. Se detiene el tracking GPS
4. Volver a pantalla de login

---

## Dependencias

| Paquete | Version | Uso |
|---------|---------|-----|
| flutter_riverpod | ^2.6.1 | State management |
| go_router | ^14.8.1 | Navegacion |
| dio | ^5.8.0 | HTTP client |
| flutter_secure_storage | ^9.2.4 | Tokens seguros |
| geolocator | ^13.0.2 | GPS |
| battery_plus | ^6.0.3 | Nivel de bateria |
| image_picker | ^1.1.2 | Captura de fotos |
| url_launcher | ^6.3.1 | Abrir Maps/Waze |
| freezed | ^2.5.8 | Data classes |

---

## API Endpoints Utilizados

| Metodo | Endpoint | Descripcion |
|--------|----------|-------------|
| POST | `/api/auth/login` | Autenticacion |
| POST | `/api/auth/refresh` | Renovar token |
| GET | `/api/mobile/driver/my-route` | Ruta del dia |
| GET | `/api/mobile/driver/my-orders` | Pedidos asignados |
| PATCH | `/api/route-stops/:id` | Actualizar parada |
| POST | `/api/mobile/driver/location` | Enviar ubicacion GPS |
| POST | `/api/upload/presigned-url` | Subir evidencia |

---

## Relacionado

- [BetterRoute Backend](https://github.com/EijunnN/better-route) - API Next.js

---

<div align="center">

**BetterRoute Mobile** — Entregas eficientes, conductores informados.

</div>
