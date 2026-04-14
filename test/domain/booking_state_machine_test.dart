// Tests the canonical booking state machine transitions.
//
// The state machine is server-authoritative (Cloud Functions), but
// BookingStatus.canTransitionTo() provides a client-side guard used by the
// UI to decide which actions to offer.
//
// Reference: docs/domain-model-canonical.md, .claude/rules/booking-invariants.md

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/booking_status.dart';

void main() {
  group('BookingStatus.canTransitionTo — valid transitions', () {
    test('requested → accepted', () {
      expect(
        BookingStatus.requested.canTransitionTo(BookingStatus.accepted),
        isTrue,
      );
    });

    test('requested → rejected', () {
      expect(
        BookingStatus.requested.canTransitionTo(BookingStatus.rejected),
        isTrue,
      );
    });

    test('requested → cancelled', () {
      expect(
        BookingStatus.requested.canTransitionTo(BookingStatus.cancelled),
        isTrue,
      );
    });

    test('accepted → inProgress', () {
      expect(
        BookingStatus.accepted.canTransitionTo(BookingStatus.inProgress),
        isTrue,
      );
    });

    test('inProgress → done', () {
      expect(
        BookingStatus.inProgress.canTransitionTo(BookingStatus.done),
        isTrue,
      );
    });
  });

  group('BookingStatus.canTransitionTo — invalid transitions', () {
    test('requested → inProgress (must go through accepted)', () {
      expect(
        BookingStatus.requested.canTransitionTo(BookingStatus.inProgress),
        isFalse,
      );
    });

    test('requested → done (must go through full lifecycle)', () {
      expect(
        BookingStatus.requested.canTransitionTo(BookingStatus.done),
        isFalse,
      );
    });

    test('requested → requested (self-transition forbidden)', () {
      expect(
        BookingStatus.requested.canTransitionTo(BookingStatus.requested),
        isFalse,
      );
    });

    test('accepted → cancelled (MVP rule: no cancel after accept)', () {
      expect(
        BookingStatus.accepted.canTransitionTo(BookingStatus.cancelled),
        isFalse,
      );
    });

    test('accepted → done (must go through inProgress)', () {
      expect(
        BookingStatus.accepted.canTransitionTo(BookingStatus.done),
        isFalse,
      );
    });

    test('accepted → requested (no going back)', () {
      expect(
        BookingStatus.accepted.canTransitionTo(BookingStatus.requested),
        isFalse,
      );
    });

    test('accepted → rejected (already accepted)', () {
      expect(
        BookingStatus.accepted.canTransitionTo(BookingStatus.rejected),
        isFalse,
      );
    });

    test('inProgress → cancelled (no cancel mid-service)', () {
      expect(
        BookingStatus.inProgress.canTransitionTo(BookingStatus.cancelled),
        isFalse,
      );
    });

    test('inProgress → accepted (no going back)', () {
      expect(
        BookingStatus.inProgress.canTransitionTo(BookingStatus.accepted),
        isFalse,
      );
    });

    test('inProgress → requested (no going back)', () {
      expect(
        BookingStatus.inProgress.canTransitionTo(BookingStatus.requested),
        isFalse,
      );
    });
  });

  group(
    'BookingStatus.canTransitionTo — terminal states allow no transitions',
    () {
      const terminals = [
        BookingStatus.done,
        BookingStatus.rejected,
        BookingStatus.cancelled,
      ];

      for (final terminal in terminals) {
        for (final target in BookingStatus.values) {
          test('${terminal.value} → ${target.value} is forbidden', () {
            expect(terminal.canTransitionTo(target), isFalse);
          });
        }
      }
    },
  );

  group('BookingStatus serialization contract (Firestore alignment)', () {
    test('inProgress serializes to "in_progress" (snake_case)', () {
      expect(BookingStatus.inProgress.value, 'in_progress');
    });

    test('all statuses except inProgress serialize to their Dart name', () {
      for (final status in BookingStatus.values) {
        if (status == BookingStatus.inProgress) continue;
        expect(
          status.value,
          status.name,
          reason: '${status.name}.value must equal its Dart name',
        );
      }
    });

    test('"in_progress" string deserializes to inProgress', () {
      expect(BookingStatus.fromString('in_progress'), BookingStatus.inProgress);
    });

    test('all canonical strings roundtrip correctly', () {
      for (final status in BookingStatus.values) {
        expect(
          BookingStatus.fromString(status.value),
          status,
          reason: '"${status.value}" must roundtrip to ${status.name}',
        );
      }
    });

    test('unknown string falls back to requested (not a crash)', () {
      expect(
        BookingStatus.fromString('totally_unknown'),
        BookingStatus.requested,
      );
    });

    test('empty string falls back to requested', () {
      expect(BookingStatus.fromString(''), BookingStatus.requested);
    });
  });
}
