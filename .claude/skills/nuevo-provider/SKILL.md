---
name: nuevo-provider
description: Usala cuando vayas a crear o modificar un provider de estado en lib/providers/ (StateNotifier nuevo, estado global nuevo consumido por pantallas). Impone el patrón StateNotifier a mano — sin riverpod_generator — y el trío de providers del repo.
---

# Provider Riverpod nuevo (a mano, sin codegen)

Fuentes canónicas: `CLAUDE.md` (REGLA #1 y §Convenciones de código —
"Estado"). Esta skill las aterriza.

**Ejemplo de referencia (copiá este patrón):**
`lib/providers/workflow_provider.dart` — el más chico y canónico: state
inmutable + notifier + trío de providers en 88 líneas. Para uno con más
vuelo (optimistic updates, outbox): `lib/providers/route_provider.dart`.

## REGLA #1 — NO codegen

Nada de `@riverpod`, `riverpod_annotation`, `part '...'`, `build_runner`.
Providers son `StateNotifier` escritos a mano + `StateNotifierProvider`.

## Anatomía (patrón de `workflow_provider.dart`)

**1. State class inmutable** con `copyWith` — incluidos flags
`clearError`/`clearUser` para poder setear a null (un `copyWith` con `??`
no puede volver a null sin flag):

```dart
class WidgetState {
  final List<Widget> items;
  final bool isLoading;
  final String? error;

  const WidgetState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  WidgetState copyWith({
    List<Widget>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WidgetState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
```

**2. Notifier** — recibe el servicio por constructor; la lógica de red vive
en `lib/services/`, **no** acá:

```dart
class WidgetNotifier extends StateNotifier<WidgetState> {
  final WidgetService _service;
  WidgetNotifier(this._service) : super(const WidgetState());

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _service.getWidgets();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error al cargar');
    }
  }

  void clear() => state = const WidgetState();
}
```

Mensajes de error de cara al conductor **en español**.

**3. Trío de providers** (servicio + StateNotifierProvider + conveniencia):

```dart
final widgetServiceProvider = Provider<WidgetService>((ref) => WidgetService());

final widgetProvider =
    StateNotifierProvider<WidgetNotifier, WidgetState>((ref) {
  return WidgetNotifier(ref.watch(widgetServiceProvider));
});
```

El `Provider` de conveniencia para selects es opcional — agregalo solo si
varias pantallas leen el mismo slice.

## Trampas conocidas (CLAUDE.md)

- **Lifecycle:** los servicios singleton (`TrackingService`,
  `OfflineOutbox`) retienen estado aunque el provider se resetee. Resetear
  el provider NO limpia contadores GPS ni el outbox — no asumas lo
  contrario. Un método `clear()` en el notifier limpia el state de
  Riverpod, nada más.
- El servicio que consume el provider es singleton
  (`factory X() => _instance` + `_internal()`); la red va por el único
  `Dio` de `ApiService` (interceptor pone `Authorization` + headers de
  tenant y auto-refresca en 401).
- Si el provider dispara cierres de paradas: **siempre** vía
  `OfflineOutbox.submitClose` + `applyLocalClose`, nunca el `PATCH`
  directo (invariante 2).

## Cierre

1. Registrar el export en el barrel `lib/providers/providers.dart`.
2. `flutter analyze`.
3. Tests con `mocktail` para la lógica del notifier si no es trivial.
