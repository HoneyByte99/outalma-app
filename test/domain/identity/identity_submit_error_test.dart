import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/identity_submit_error.dart';

void main() {
  group('classifyIdentitySubmitError by stable details.code (E11)', () {
    final cases = {
      'IDENTITY_BATCH_INVALID': IdentitySubmitErrorKind.batchInvalid,
      'IDENTITY_OBJECTS_MISSING': IdentitySubmitErrorKind.objectsMissing,
      'IDENTITY_BATCH_STALE': IdentitySubmitErrorKind.batchStale,
      'IDENTITY_ACCOUNT_MISSING': IdentitySubmitErrorKind.accountMissing,
      'IDENTITY_PENDING_EXISTS': IdentitySubmitErrorKind.pendingExists,
      'IDENTITY_ALREADY_VERIFIED': IdentitySubmitErrorKind.alreadyVerified,
      'IDENTITY_RATE_LIMITED': IdentitySubmitErrorKind.rateLimited,
    };
    cases.forEach((code, kind) {
      test('$code maps to $kind', () {
        expect(classifyIdentitySubmitError(detailsCode: code).kind, kind);
      });
    });

    test('rate limited carries the server retry delay verbatim', () {
      final e = classifyIdentitySubmitError(
        detailsCode: 'IDENTITY_RATE_LIMITED',
        retryAfterMs: 3600000,
      );
      expect(e.kind, IdentitySubmitErrorKind.rateLimited);
      expect(e.retryAfterMs, 3600000);
    });

    test('the stable code wins over a mismatched http code', () {
      final e = classifyIdentitySubmitError(
        detailsCode: 'IDENTITY_ALREADY_VERIFIED',
        httpCode: 'resource-exhausted',
      );
      expect(e.kind, IdentitySubmitErrorKind.alreadyVerified);
    });
  });

  group('fallback on the coarse http code the socle emits today', () {
    test('resource-exhausted is a rate limit', () {
      expect(
        classifyIdentitySubmitError(httpCode: 'resource-exhausted').kind,
        IdentitySubmitErrorKind.rateLimited,
      );
    });

    test('unauthenticated routes back to auth', () {
      expect(
        classifyIdentitySubmitError(httpCode: 'unauthenticated').kind,
        IdentitySubmitErrorKind.unauthenticated,
      );
    });

    test('permission-denied is a storage refusal', () {
      expect(
        classifyIdentitySubmitError(httpCode: 'permission-denied').kind,
        IdentitySubmitErrorKind.storageDenied,
      );
    });

    test('invalid-argument is a bad batch', () {
      expect(
        classifyIdentitySubmitError(httpCode: 'invalid-argument').kind,
        IdentitySubmitErrorKind.batchInvalid,
      );
    });

    test('transient codes are network failures', () {
      for (final code in ['unavailable', 'cancelled', 'deadline-exceeded']) {
        expect(
          classifyIdentitySubmitError(httpCode: code).kind,
          IdentitySubmitErrorKind.network,
          reason: code,
        );
      }
    });

    test('failed-precondition stays unknown without E11: three cases collapse '
        '(open question O-1)', () {
      expect(
        classifyIdentitySubmitError(httpCode: 'failed-precondition').kind,
        IdentitySubmitErrorKind.unknown,
      );
    });

    test('an unmapped code is unknown, never a raw technical leak (U3)', () {
      expect(
        classifyIdentitySubmitError(httpCode: 'internal').kind,
        IdentitySubmitErrorKind.unknown,
      );
      expect(
        classifyIdentitySubmitError().kind,
        IdentitySubmitErrorKind.unknown,
      );
    });
  });
}
