/// Versión vigente del contrato del seam móvil
/// (docs/API-CONTRACT-MOBILE.md §10). Debe coincidir con
/// `src/lib/mobile-contract/version.ts` en el repo web (planeamiento):
/// todo bump se hace en ambos repos en el mismo cambio.
///
/// Historial: v1 = contrato inicial (2026-07-01); v2 = los 10 fixes
/// normativos del §11 (2026-07-02).
const int contractVersion = 2;

/// Header de handshake que el backend estampa en toda respuesta del seam
/// (§10.2). El móvil lo compara post-login y solo advierte en mismatch —
/// nunca bloquea al conductor.
const String contractHeader = 'x-br-contract';
