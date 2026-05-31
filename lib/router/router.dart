import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/chat_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/end_of_day_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/permissions_screen.dart';
import '../screens/route_map_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/stop_detail_screen.dart';
import '../screens/success_screen.dart';
import '../services/push_router.dart';
import 'onboarding_bootstrap.dart';

/// Route names
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String permissions = '/permissions';
  static const String home = '/home';
  static const String routeMap = '/home/map';
  static const String stopDetail = '/stop/:stopId';
  static const String success = '/stop/:stopId/success';
  static const String chat = '/chat';
  static const String endOfDay = '/end-of-day';

  static String stopDetailPath(String stopId) => '/stop/$stopId';
  static String successPath(String stopId) => '/stop/$stopId/success';
}


/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isInitialized = authState.isInitialized;
      final currentPath = state.matchedLocation;

      // Wait for initialization
      if (!isInitialized) {
        return currentPath == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // Redirect logic.
      // While logged in, the user can be on home / detail / routeMap /
      // chat / onboarding / permissions / end-of-day / success — all
      // those routes are allowed through. While logged out only login
      // is allowed.
      final isOnLogin = currentPath == AppRoutes.login;
      final isOnSplash = currentPath == AppRoutes.splash;

      if (!isAuthenticated) {
        // Not logged in — only login is allowed.
        if (!isOnLogin) return AppRoutes.login;
        return null;
      }

      // Authenticated.
      // First-time user → onboarding → permissions → home.
      // Already onboarded users skip straight to home.
      if (isOnLogin || isOnSplash) {
        if (!OnboardingBootstrap.seen) return AppRoutes.onboarding;
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      // Splash screen
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Login screen
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Onboarding — first-launch slides. Skipped on subsequent
      // launches via the OnboardingFlag.
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Permissions — pre-prompt. Reachable from onboarding finish or
      // directly from "Configurar manualmente" later.
      GoRoute(
        path: AppRoutes.permissions,
        name: 'permissions',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PermissionsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Home screen
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Route map screen
      GoRoute(
        path: AppRoutes.routeMap,
        name: 'routeMap',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RouteMapScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Stop detail screen
      GoRoute(
        path: AppRoutes.stopDetail,
        name: 'stopDetail',
        pageBuilder: (context, state) {
          final stopId = state.pathParameters['stopId']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: StopDetailScreen(stopId: stopId),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;

              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),

      // Success — celebration screen after a stop is completed.
      GoRoute(
        path: AppRoutes.success,
        name: 'success',
        pageBuilder: (context, state) {
          final stopId = state.pathParameters['stopId']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: SuccessScreen(completedStopId: stopId),
            transitionsBuilder: (context, animation, secondary, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),

      // End-of-day — shift close summary.
      GoRoute(
        path: AppRoutes.endOfDay,
        name: 'endOfDay',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const EndOfDayScreen(),
          transitionsBuilder: (context, animation, secondary, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Chat screen — one thread between the driver and dispatch.
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ChatScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
    ],

    // Error page
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Pagina no encontrada',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                state.matchedLocation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // Hand the router to the push bridge so a tapped chat notification
  // can deep-link in. Safe to call on every recreation — idempotent.
  PushRouter().attachRouter(router);
  return router;
});

/// Helper to refresh router when auth state changes
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _ref.listen(authProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
