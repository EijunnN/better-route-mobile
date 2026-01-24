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

### 2. Configurar URL del API

Editar `lib/core/constants.dart`:

```dart
class ApiConfig {
  // Para desarrollo local con emulador Android
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  // Para desarrollo local con dispositivo fisico
  // static const String baseUrl = 'http://192.168.X.X:3000/api';

  // Para produccion
  // static const String baseUrl = 'https://tu-dominio.com/api';
}
```

**Nota sobre URLs:**
- `10.0.2.2` - IP especial del emulador Android que apunta a localhost del host
- `localhost` - Solo funciona en iOS Simulator
- Para dispositivos fisicos, usar la IP local de tu computadora

### 3. Ejecutar la aplicacion

```bash
# Desarrollo con hot reload
flutter run

# Compilar APK de debug
flutter build apk --debug

# Compilar APK de release
flutter build apk --release
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
| `SKIPPED` | Omitido por el conductor |

## Motivos de No Entrega

- `CUSTOMER_ABSENT` - Cliente ausente
- `CUSTOMER_REFUSED` - Cliente rechazo la entrega
- `ADDRESS_NOT_FOUND` - Direccion incorrecta
- `PACKAGE_DAMAGED` - Paquete danado
- `RESCHEDULE_REQUESTED` - Solicito reprogramacion
- `UNSAFE_AREA` - Zona insegura
- `OTHER` - Otro motivo

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

# Compilar
flutter build apk --release
# APK en: build/app/outputs/flutter-apk/app-release.apk

# O App Bundle para Play Store
flutter build appbundle --release
```

### iOS

```bash
# Requiere macOS con Xcode
flutter build ios --release

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
- Verificar la URL en `constants.dart`
- Para emulador Android usar `10.0.2.2` en lugar de `localhost`

### Token expirado
- La app renueva tokens automaticamente
- Si falla, cerrar sesion y volver a iniciar

## Contacto

Para soporte tecnico o consultas sobre el sistema, contactar al administrador.
