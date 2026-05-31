# AEA - App de Entregas para Conductores

Aplicacion movil Flutter para conductores de delivery. Permite visualizar rutas asignadas, gestionar entregas y registrar evidencia fotografica.

## Requisitos Previos

### Desarrollo
- Flutter SDK 3.19+
- Dart SDK 3.3+
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
├── core/
│   ├── constants.dart      # URLs y configuracion
│   └── theme.dart          # Colores y estilos
├── models/
│   ├── driver_info.dart    # Modelo del conductor
│   ├── vehicle.dart        # Modelo del vehiculo
│   ├── route_stop.dart     # Modelo de parada
│   └── route_data.dart     # Modelo de ruta completa
├── providers/
│   ├── auth_provider.dart      # Estado de autenticacion
│   ├── route_provider.dart     # Estado de la ruta
│   └── location_provider.dart  # GPS y ubicacion
├── screens/
│   ├── login_screen.dart       # Pantalla de login
│   ├── home_screen.dart        # Lista de paradas
│   └── stop_detail_screen.dart # Detalle de entrega
├── services/
│   ├── api_service.dart    # Cliente HTTP (Dio)
│   ├── auth_service.dart   # Autenticacion JWT
│   └── route_service.dart  # API de rutas
├── widgets/
│   ├── stop_card.dart      # Tarjeta de parada
│   └── ...
└── main.dart
```

## Endpoints del API

La app consume los siguientes endpoints:

| Endpoint | Metodo | Descripcion |
|----------|--------|-------------|
| `/auth/login` | POST | Login con email/password |
| `/auth/refresh` | POST | Renovar access token |
| `/mobile/driver/my-route` | GET | Obtener ruta del dia |
| `/route-stops/{id}` | PATCH | Actualizar estado de parada |
| `/upload/presigned-url` | GET | Obtener URL para subir foto |

### Headers Requeridos

```
Authorization: Bearer {accessToken}
x-company-id: {companyId}
x-user-id: {userId}
Content-Type: application/json
```

## Autenticacion

La app usa JWT con tokens de acceso y refresh:

- **Access Token**: Expira en 15 minutos
- **Refresh Token**: Expira en 7 dias
- Los tokens se almacenan en `SharedPreferences`
- El interceptor de Dio renueva automaticamente tokens expirados

## Subida de Evidencia Fotografica

1. La app solicita un presigned URL al backend
2. El backend genera URL de Cloudflare R2
3. La app sube la foto directamente a R2
4. Se guarda la URL publica en la parada

```dart
// Flujo simplificado
final presigned = await routeService.getPresignedUrl(trackingId: 'TRACK123');
await routeService.uploadEvidence(file: photo, uploadUrl: presigned.uploadUrl);
// presigned.publicUrl contiene la URL final de la imagen
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
