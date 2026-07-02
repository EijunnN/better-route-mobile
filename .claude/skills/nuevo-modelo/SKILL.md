---
name: nuevo-modelo
description: Usala cuando vayas a crear o modificar un modelo Dart en lib/models/ (clase que parsea JSON del backend o se persiste local). Impone la regla NO-CODEGEN y el parser defensivo tolerante al contrato.
---

# Modelo Dart nuevo (a mano, sin codegen)

Fuentes canónicas: `CLAUDE.md` (REGLA #1 y §Convenciones de código) y
`docs/API-CONTRACT-MOBILE.md` §9 (campos congelados). Esta skill las
aterriza.

**Ejemplo de referencia (copiá este patrón):** `lib/models/route_stop.dart`
— enum con `fromString` tolerante, clases anidadas (`TimeWindow`,
`OrderInfo`), `fromJson` defensivo, getters derivados, `copyWith`.

## REGLA #1 — NO codegen (CLAUDE.md)

- **Nada** de `@freezed`, `@JsonSerializable`, `part '...'`, `*.g.dart`,
  `build_runner`. El `pubspec` engaña: el repo no usa codegen.
- Clase plana: campos `final`, constructor `const`, `factory fromJson`,
  `toJson` **solo si se envía o persiste**, `copyWith`, getters derivados.

## Anatomía (patrón de `route_stop.dart`)

```dart
class Widget {
  final String id;
  final double latitude;
  final DateTime? createdAt;
  final int attempts;

  const Widget({
    required this.id,
    required this.latitude,
    this.createdAt,
    this.attempts = 1,
  });

  factory Widget.fromJson(Map<String, dynamic> json) {
    return Widget(
      id: json['id'] as String,
      latitude: _parseCoordinate(json['latitude']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      attempts: (json['attempts'] as num?)?.toInt() ?? 1,
    );
  }

  Widget copyWith({String? id, /* ... */}) => Widget(
        id: id ?? this.id,
        // ...
      );
}
```

## Parser defensivo — reglas concretas

- **Tolerante a campos extra**: `fromJson` lee por key; jamás valides que
  el JSON no traiga keys desconocidas. El backend puede agregar campos sin
  bump de contrato (§9: agregar es compatible, quitar no).
- **Nunca requieras un campo nuevo**: todo campo que no esté en la lista de
  congelados del §9 entra como nullable o con default
  (`json['x'] as bool? ?? false`), nunca con `as String` a secas.
- Coordenadas pueden venir `String` o `num` → helper tipo
  `_parseCoordinate` de `route_stop.dart`.
- Fechas: `DateTime.tryParse`, nunca `DateTime.parse`.
- Enums: `firstWhere(..., orElse: () => default)` como `StopStatus.fromString`.
- Listas/mapas: `List<String>.from(...)` / `Map<String, dynamic>.from(...)`
  detrás de null-check.
- **No inventes enums que el contrato define como texto libre**: p. ej.
  `failureReason` es string verbatim de `policy.failureReasons`
  (CLAUDE.md invariante 3; nota en `route_stop.dart` líneas 25–28).

## Seam con el backend

Si el modelo parsea una respuesta de la API: consultá
`docs/API-CONTRACT-MOBILE.md` **antes** de tocar campos. Cambiar un shape
(request o response) exige bump de `CONTRACT_VERSION` en ambos repos — no
lo hagas unilateralmente desde el móvil.

## Cierre

1. Registrar el export en el barrel `lib/models/models.dart`.
2. `flutter analyze`.
3. Tests con `mocktail` si hay lógica de parseo no trivial (nunca
   `mockito`, requiere build_runner).
