import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/identity_trust_status.dart';

void main() {
  test('parses the two stored values', () {
    expect(
      IdentityTrustStatus.fromString('pending'),
      IdentityTrustStatus.pending,
    );
    expect(
      IdentityTrustStatus.fromString('verified'),
      IdentityTrustStatus.verified,
    );
  });

  test('returns null for anything else, including null and empty', () {
    // Fails closed on purpose: an unreadable state must read as "not verified",
    // never as "verified". This is a trust signal, so the safe direction is
    // refusing to show one.
    for (final raw in [null, '', 'VERIFIED', 'approved', 'rejected', 'true']) {
      expect(IdentityTrustStatus.fromString(raw), isNull, reason: 'raw: $raw');
    }
  });

  test('round-trips every value through its stored form', () {
    for (final status in IdentityTrustStatus.values) {
      expect(IdentityTrustStatus.fromString(status.value), status);
    }
  });

  test('holds exactly two values, absence being the third state', () {
    // If someone adds a third enum value, the widget's switch and the server
    // projection have to be revisited together. This assertion is the reminder.
    expect(IdentityTrustStatus.values.map((s) => s.value).toList(), [
      'pending',
      'verified',
    ]);
  });
}
