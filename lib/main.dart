import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'core/theme.dart';
import 'router/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI overlay style is set dynamically based on theme in EntregasApp

  runApp(
    const ProviderScope(
      child: EntregasApp(),
    ),
  );
}

class EntregasApp extends ConsumerWidget {
  const EntregasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Driver Cockpit is dark-only — the system bars must always render
    // light icons over the near-black canvas. Setting them once here keeps
    // them consistent across every screen.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF0A0A0B),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return ShadcnApp.router(
      title: 'BetterRoute',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
