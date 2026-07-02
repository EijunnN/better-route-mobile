import 'package:aea/core/contract_version.dart';
import 'package:aea/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Handshake §10.2: AuthService compara el x-br-contract post-login.
// Mismatch = solo advertencia + estado consultable; NUNCA bloquea.

void main() {
  final auth = AuthService();

  test('misma versión → sin mismatch', () {
    auth.recordServerContractVersion('$contractVersion');
    expect(auth.serverContractVersion, contractVersion);
    expect(auth.contractMismatch, isFalse);
  });

  test('versión distinta → mismatch consultable (no bloquea)', () {
    auth.recordServerContractVersion('${contractVersion + 1}');
    expect(auth.serverContractVersion, contractVersion + 1);
    expect(auth.contractMismatch, isTrue);
  });

  test('header ausente o no numérico → server pre-handshake, sin mismatch',
      () {
    auth.recordServerContractVersion(null);
    expect(auth.serverContractVersion, isNull);
    expect(auth.contractMismatch, isFalse);

    auth.recordServerContractVersion('no-numérico');
    expect(auth.serverContractVersion, isNull);
    expect(auth.contractMismatch, isFalse);
  });
}
