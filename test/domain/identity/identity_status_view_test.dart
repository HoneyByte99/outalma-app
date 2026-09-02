// Pure mapping of a file status to its distinct status-screen render (AC-C16).
//
// The mapping is total: every IdentityStatus reaches exactly one view, and the
// rejected split on attempt/priority is the only branch that reads the rank.
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/identity_status.dart';
import 'package:outalma_app/src/domain/identity/identity_status_view.dart';

void main() {
  group('identityStatusViewOf', () {
    test('none maps to notVerified', () {
      expect(
        identityStatusViewOf(IdentityStatus.none),
        IdentityStatusView.notVerified,
      );
    });

    test('pending maps to pending', () {
      expect(
        identityStatusViewOf(IdentityStatus.pending),
        IdentityStatusView.pending,
      );
    });

    test('approved maps to verified', () {
      expect(
        identityStatusViewOf(IdentityStatus.approved),
        IdentityStatusView.verified,
      );
    });

    test('revoked maps to revoked', () {
      expect(
        identityStatusViewOf(IdentityStatus.revoked),
        IdentityStatusView.revoked,
      );
    });

    test('rejected on attempts 1 to 3 maps to rejected', () {
      for (final attempt in [1, 2, 3]) {
        expect(
          identityStatusViewOf(IdentityStatus.rejected, attempt: attempt),
          IdentityStatusView.rejected,
          reason: 'attempt $attempt',
        );
      }
    });

    test('rejected on the 4th attempt maps to rejectedPriority', () {
      expect(
        identityStatusViewOf(IdentityStatus.rejected, attempt: 4),
        IdentityStatusView.rejectedPriority,
      );
    });

    test('rejected with the server priority flag maps to rejectedPriority', () {
      // The flag wins even on an early attempt: the server owns the policy.
      expect(
        identityStatusViewOf(
          IdentityStatus.rejected,
          attempt: 1,
          priority: true,
        ),
        IdentityStatusView.rejectedPriority,
      );
    });

    test('every status maps to a view (totality)', () {
      for (final status in IdentityStatus.values) {
        expect(() => identityStatusViewOf(status), returnsNormally);
      }
    });

    test('offersCapture is true only for the startable renders', () {
      expect(IdentityStatusView.notVerified.offersCapture, isTrue);
      expect(IdentityStatusView.rejected.offersCapture, isTrue);
      expect(IdentityStatusView.rejectedPriority.offersCapture, isTrue);
      expect(IdentityStatusView.revoked.offersCapture, isTrue);
      expect(IdentityStatusView.pending.offersCapture, isFalse);
      expect(IdentityStatusView.verified.offersCapture, isFalse);
    });
  });
}
