import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/identity_status.dart';

void main() {
  group('IdentityStatus.fromString', () {
    test('maps every known status', () {
      expect(IdentityStatus.fromString('pending'), IdentityStatus.pending);
      expect(IdentityStatus.fromString('approved'), IdentityStatus.approved);
      expect(IdentityStatus.fromString('rejected'), IdentityStatus.rejected);
      expect(IdentityStatus.fromString('revoked'), IdentityStatus.revoked);
    });

    test('falls back to none for null or an unknown value', () {
      expect(IdentityStatus.fromString(null), IdentityStatus.none);
      expect(IdentityStatus.fromString('quantum'), IdentityStatus.none);
      expect(IdentityStatus.fromString(''), IdentityStatus.none);
    });
  });

  group('IdentityStatus.canSubmit', () {
    test('approved and pending have no path to a new submission', () {
      expect(IdentityStatus.approved.canSubmit, isFalse);
      expect(IdentityStatus.pending.canSubmit, isFalse);
    });

    test('none, rejected and revoked can start an attempt', () {
      expect(IdentityStatus.none.canSubmit, isTrue);
      expect(IdentityStatus.rejected.canSubmit, isTrue);
      expect(IdentityStatus.revoked.canSubmit, isTrue);
    });
  });
}
