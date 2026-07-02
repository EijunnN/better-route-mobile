# BetterRoute — App del Conductor (setup)

Aplicacion movil Flutter para conductores de delivery. Permite visualizar rutas asignadas, gestionar entregas y registrar evidencia fotografica.

## Requisitos Previos

### Desarrollo
- Flutter SDK con Dart 3.10+ (el `pubspec.yaml` exige `sdk: ^3.10.7`)
- Android Studio / VS Code con extensiones Flutter
- Android SDK (para Android)
- Xcode (para iOS, solo en macOS)

### Backend
- El proyecto web (Next.js) debe estar corriendo
- Base de datos PostgreSQL configurada
- Cloudflare R2 configurado (para subida de fotos)

## Configuracion Inicial

### 1. Clonar e instalar dependencias

```bash
cd aea
flutter pub get
```

### 2. Configurar URLs del backend

Las URLs **no se editan en el código**: se inyectan en build-time con
`--dart-define`, y la app **falla al arrancar** (`ApiConfig.assertValid`) si en
un build de release faltan o no son TLS.

- **Desarrollo:** nada que configurar. En debug (`flutter run`) se usan por
  defecto `http://10.0.2.2:3000` (emulador Android) y `ws://10.0.2.2:8000`.
  Para un dispositivo físico, pasá tu IP local:
  `flutter run --dart-define=API_BASE_URL=http://192.168.X.X:3000`.
- **Producción / release:** copiá la plantilla y completá tus URLs (https/wss):

  ```bash
  cp dart_define.example.json dart_define.json
  # editá dart_define.json: API_BASE_URL (https://) y WS_URL (wss://)
  ```

  `dart_define.json` está en `.gitignore`; la plantilla `dart_define.example.json`
  se versiona.

### 3. Ejecutar la aplicacion

```bash
# Desarrollo con hot reload
flutter run

# Compilar APK de debug
flutter build apk --debug

# Compilar APK/AAB de release (inyecta dart_define.json — ver paso 2)
./scripts/build-release.sh apk        # o: appbundle / ios
```

## Flujo de Uso

### Requisitos en el Backend

Antes de que un conductor pueda usar la app:

1. **Crear usuario conductor** en el sistema web:
   - Ir a Configuracion > Usuarios
   - Crear usuario con rol `CONDUCTOR`
   - Guardar email y password

2. **Asignar vehiculo al conductor**:
   - Ir a Configuracion > Flota
   - Editar un vehiculo
   - En "Conductor Asignado", seleccionar al conductor

3. **Crear y confirmar un plan de rutas**:
   - Ir a Planificacion
   - Crear nueva configuracion
   - Seleccionar pedidos, vehiculos y conductores
   - Ejecutar optimizacion
   - **Confirmar el plan** (esto crea las `route_stops` en la BD)

### En la App Movil

1. **Login**: El conductor ingresa con su email y password
2. **Ver Ruta**: Automaticamente carga las paradas asignadas al vehiculo del conductor
3. **Gestionar Entregas**:
   - Tap en una parada para ver detalles
   - "Iniciar" para marcar en progreso
   - "Completar" con foto de evidencia
   - "No Entregado" con motivo de falla

## Estructura del Proyecto

```
lib/
├── core/        constants (URLs/config) · theme · design tokens · polyline
├── models/      user · driver_info · vehicle · route_data · route_stop ·
│                pending_close (outbox) · chat_message · field_definition ·
│                workflow_state — barrel models.dart
├── providers/   auth · route · location · tracking · chat ·
│                field_definition · workflow — barrel providers.dart
├── services/    api (Dio) · auth · storage · route · location · tracking ·
│                offline_outbox · chat · push_router · field_definition ·
│                workflow
├── screens/     splash · login · onboarding · permissions · home ·
│                stop_detail · success · end_of_day · chat · route_map
├── widgets/     componentes compartidos
├── router/      go_router
└── main.dart
```

## Endpoints del API

La app consume los siguientes endpoints:

| Endpoint | Metodo | Descripcion |
|----------|--------|-------------|
| `/api/auth/login` | POST | Login con email/password |
| `/api/auth/refresh` | POST | Renovar access token |
| `/api/auth/logout` | POST | Cerrar sesion |
| `/api/mobile/driver/my-route` | GET | Obtener ruta del dia |
| `/api/mobile/driver/delivery-policy` | GET | Politica de entrega (estados + motivos) |
| `/api/mobile/driver/field-definitions` | GET | Campos personalizados (showInMobile) |
| `/api/mobile/driver/location` | POST | Ping de ubicacion GPS |
| `/api/route-stops/{id}` | PATCH | Actualizar estado de parada |
| `/api/upload/presigned-url` | GET | Obtener URL presignada para subir foto |
| `/api/chat/conversations/{driverId}/messages` | GET / POST | Chat con despacho |
| `/api/chat/conversations/{driverId}/read` | POST | Marcar hilo como leido |
| `/api/realtime/token` | GET | Token de conexion Centrifugo (WS) |

### Headers Requeridos

```
Authorization: Bearer {accessToken}
x-company-id: {companyId}
x-user-id: {userId}
Content-Type: application/json
```

## Autenticacion

La app usa JWT con tokens de acceso y refresh:

- **Access Token**: Expira en 15 minutos (24 horas en desarrollo)
- **Refresh Token**: Expira en 7 dias
- Los tokens se almacenan en `flutter_secure_storage` (Keychain / EncryptedSharedPreferences)
  via `lib/services/storage_service.dart`; `SharedPreferences` solo guarda el
  outbox offline y el flag de onboarding
- El interceptor de Dio renueva automaticamente tokens expirados

## Subida de Evidencia Fotografica

1. La app solicita un presigned URL al backend
2. El backend genera URL de Cloudflare R2
3. La app sube la foto directamente a R2
4. Se guarda la URL publica en la parada

```dart
// Flujo simplificado (presign + PUT a R2; index = posicion de la foto, 1..N)
final publicUrl = await routeService.uploadEvidencePhoto(
  photo: photo,
  trackingId: 'TRACK123',
  index: 1,
);
```

## Estados de Parada

| Estado | Descripcion |
|--------|-------------|
| `PENDING` | Pendiente de entrega |
| `IN_PROGRESS` | Conductor en camino/atendiendo |
| `COMPLETED` | Entregado exitosamente |
| `FAILED` | No se pudo entregar |

## Motivos de No Entrega

Los motivos **no estan hardcodeados**: cada empresa configura su propia lista
(texto libre en español) en la politica de entrega, y la app la obtiene de
`GET /api/mobile/driver/delivery-policy`. El motivo elegido se guarda verbatim
en la parada (no se usa un codigo fijo).

## Compilacion para Produccion

### Android

```bash
# Generar keystore (solo primera vez)
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Crear android/key.properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=/path/to/upload-keystore.jks

# Compilar (inyecta las URLs de prod desde dart_define.json — ver Configuracion)
./scripts/build-release.sh apk        # APK: build/app/outputs/flutter-apk/app-release.apk
./scripts/build-release.sh appbundle  # AAB para Play Store
# Equivalente: flutter build apk --release --dart-define-from-file=dart_define.json
```

### iOS

```bash
# Requiere macOS con Xcode
./scripts/build-release.sh ios
# Equivalente: flutter build ios --release --dart-define-from-file=dart_define.json

# Luego abrir en Xcode para firmar y subir a App Store
open ios/Runner.xcworkspace
```

## Troubleshooting

### "No tienes un vehiculo asignado"
- Verificar que el conductor tenga un vehiculo asignado en el sistema web
- El campo `assigned_driver_id` del vehiculo debe coincidir con el ID del usuario

### "No tienes rutas asignadas"
- Verificar que exista un plan confirmado para el dia
- El plan debe haberse **confirmado** (no solo completado la optimizacion)
- Las `route_stops` se crean al confirmar el plan

### Error de conexion
- Verificar que el backend este corriendo
- Debug: la app usa `10.0.2.2:3000` (emulador). Para dispositivo fisico, pasá
  `--dart-define=API_BASE_URL=http://TU-IP:3000` al `flutter run`
- Release: confirmá que `dart_define.json` tenga las URLs https/wss correctas
  (la app aborta al arrancar si faltan)

### Token expirado
- La app renueva tokens automaticamente
- Si falla, cerrar sesion y volver a iniciar

## Contacto

Para soporte tecnico o consultas sobre el sistema, contactar al administrador.
