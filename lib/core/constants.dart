import 'package:flutter/foundation.dart';

/// API Configuration
class ApiConfig {
  /// Base URL — supplied at build time via `--dart-define=API_BASE_URL=...`.
  /// In debug builds it defaults to the Android-emulator loopback for local
  /// dev. In release builds the default is empty so a forgotten define fails
  /// loudly at startup (see [assertValid]) instead of silently shipping the
  /// dev box over cleartext. Production builds MUST pass an https URL, e.g.
  /// `flutter build apk --dart-define=API_BASE_URL=https://api.example.com`.
  static final String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kDebugMode ? 'http://10.0.2.2:3000' : '',
  );

  // Endpoints
  static const String loginEndpoint = '/api/auth/login';
  static const String logoutEndpoint = '/api/auth/logout';
  static const String refreshEndpoint = '/api/auth/refresh';
  static const String myRouteEndpoint = '/api/mobile/driver/my-route';
  static const String routeStopsEndpoint = '/api/route-stops';
  static const String uploadEndpoint = '/api/upload/presigned-url';
  static const String locationEndpoint = '/api/mobile/driver/location';
  static const String fieldDefinitionsEndpoint =
      '/api/mobile/driver/field-definitions';

  /// Canonical workflow contract. The state machine (states + transitions)
  /// is crystallized server-side and identical for every company; only the
  /// per-company presentation (labels, colours, evidence gates, failure
  /// reasons) varies and ships in `data.policy`. There is no separate
  /// `/workflow-states` endpoint — this is the single source.
  static const String deliveryPolicyEndpoint =
      '/api/mobile/driver/delivery-policy';

  // Chat — driver only ever talks to their own thread. {driverId} ===
  // the logged-in user's id.
  static String chatMessages(String driverId) =>
      '/api/chat/conversations/$driverId/messages';
  static String chatRead(String driverId) =>
      '/api/chat/conversations/$driverId/read';
  static const String realtimeToken = '/api/realtime/token';

  /// Centrifugo realtime WebSocket URL — supplied at build time via
  /// `--dart-define=WS_URL=...`. In debug it defaults to the Android-emulator
  /// loopback (Centrifugo dev port 8000); in release the default is empty so
  /// a forgotten define is caught by [assertValid]. Production builds MUST
  /// pass a `wss://` URL.
  static final String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: kDebugMode ? 'ws://10.0.2.2:8000/connection/websocket' : '',
  );

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Fail-closed config guard. Call once at startup (before `runApp`).
  ///
  /// A release build that forgot the `--dart-define`s must crash loudly at
  /// boot rather than silently talk to the dev box over cleartext. We also
  /// enforce TLS (`https://` / `wss://`) in release so a misconfigured
  /// production URL can't downgrade traffic to plaintext.
  static void assertValid() {
    if (baseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not configured. Build with '
        '--dart-define=API_BASE_URL=https://your-api.example.com',
      );
    }
    if (kReleaseMode) {
      if (!baseUrl.startsWith('https://')) {
        throw StateError(
          'Release builds require an https API_BASE_URL (got "$baseUrl"). '
          'Build with --dart-define=API_BASE_URL=https://your-api.example.com',
        );
      }
      if (!wsUrl.startsWith('wss://')) {
        throw StateError(
          'Release builds require a wss WS_URL (got "$wsUrl"). '
          'Build with --dart-define=WS_URL=wss://your-host/connection/websocket',
        );
      }
    }
  }
}

/// Storage Keys
class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String user = 'user';
  static const String companyId = 'company_id';

  /// Offline outbox of pending stop closes (SharedPreferences, JSON list).
  static const String offlineOutbox = 'offline_outbox_v1';
}

/// Push notifications (OneSignal). App ID is public by design — the REST
/// API key lives only on the backend. Overridable at build time so another
/// install can pair its own OneSignal app: the value MUST match the
/// backend's `ONESIGNAL_APP_ID` env (see `dart_define.example.json`).
class PushConfig {
  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '35dbded5-641d-47b1-b931-07dad0d49770',
  );
}

/// App Constants
class AppConstants {
  // Tracking — adaptive cadence to balance freshness with battery.
  // Moving: send every 20s; stopped: every 60s. Switch threshold based
  // on speed in km/h. Distance filter limits redundant emissions when
  // the driver is parked at a customer.
  static const int trackingMovingIntervalSeconds = 20;
  static const int trackingStoppedIntervalSeconds = 60;
  static const int trackingMovingThresholdKmh = 2;
  static const int trackingDistanceFilterMeters = 25;
  static const int trackingRetryAttempts = 3;
  static const int trackingRetryDelaySeconds = 5;

  // Offline outbox — how often to retry syncing queued stop closes, and the
  // retry ceiling before an entry is dropped (with its error surfaced).
  static const int outboxFlushIntervalSeconds = 30;
  static const int outboxMaxRetries = 60;
}
