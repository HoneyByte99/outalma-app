import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/application/booking/booking_actions.dart';
import 'package:outalma_app/src/data/services/callable_function_client.dart';

// The use cases delegate to `CallableFunctionClient` (server-authoritative
// Cloud Functions). Each use case now accepts the client via constructor
// injection (default: the real HTTP client) so the wire payload it builds can
// be verified without hitting the network.

class _MockClient extends Mock implements CallableFunctionClient {}

void main() {
  late _MockClient client;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = _MockClient();
    when(
      () => client.call(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => <String, dynamic>{});
  });

  /// Returns [name, data] captured from the single recorded call.
  List<dynamic> captureCall() {
    return verify(
      () => client.call(captureAny(), data: captureAny(named: 'data')),
    ).captured;
  }

  group('AcceptBookingUseCase', () {
    test('calls acceptBooking with the booking id', () async {
      await AcceptBookingUseCase(client).call('b1');
      final c = captureCall();
      expect(c[0], 'acceptBooking');
      expect(c[1], {'bookingId': 'b1'});
    });

    test('const default constructor is usable', () {
      expect(const AcceptBookingUseCase(), isA<AcceptBookingUseCase>());
    });
  });

  group('RejectBookingUseCase', () {
    test('passes trimmed reason when provided', () async {
      await RejectBookingUseCase(client).call('b1', reason: '  no-show  ');
      final c = captureCall();
      expect(c[0], 'rejectBooking');
      expect(c[1], {'bookingId': 'b1', 'reason': 'no-show'});
    });

    test('omits reason when null', () async {
      await RejectBookingUseCase(client).call('b1');
      final c = captureCall();
      expect(c[1], {'bookingId': 'b1'});
      expect((c[1] as Map).containsKey('reason'), isFalse);
    });

    test('omits reason when blank/whitespace only', () async {
      await RejectBookingUseCase(client).call('b1', reason: '   ');
      final c = captureCall();
      expect((c[1] as Map).containsKey('reason'), isFalse);
    });

    test('const default constructor is usable', () {
      expect(const RejectBookingUseCase(), isA<RejectBookingUseCase>());
    });
  });

  group('MarkInProgressUseCase', () {
    test('calls markInProgress with the booking id', () async {
      await MarkInProgressUseCase(client).call('b1');
      final c = captureCall();
      expect(c[0], 'markInProgress');
      expect(c[1], {'bookingId': 'b1'});
    });
  });

  group('ConfirmDoneUseCase', () {
    test('calls confirmDone with the booking id', () async {
      await ConfirmDoneUseCase(client).call('b1');
      final c = captureCall();
      expect(c[0], 'confirmDone');
      expect(c[1], {'bookingId': 'b1'});
    });
  });

  group('CancelBookingUseCase', () {
    test('passes trimmed reason when provided', () async {
      await CancelBookingUseCase(client).call('b1', reason: ' changed mind ');
      final c = captureCall();
      expect(c[0], 'cancelBooking');
      expect(c[1], {'bookingId': 'b1', 'reason': 'changed mind'});
    });

    test('omits reason when null', () async {
      await CancelBookingUseCase(client).call('b1');
      final c = captureCall();
      expect(c[1], {'bookingId': 'b1'});
    });
  });

  group('RescheduleBookingUseCase', () {
    test('sends newScheduledAt as epoch millis', () async {
      final when = DateTime.fromMillisecondsSinceEpoch(1735689600000);
      await RescheduleBookingUseCase(client).call('b1', when);
      final c = captureCall();
      expect(c[0], 'rescheduleBooking');
      expect(c[1], {'bookingId': 'b1', 'newScheduledAt': 1735689600000});
    });

    test('propagates the exception when the Cloud Function fails', () async {
      when(() => client.call(any(), data: any(named: 'data'))).thenThrow(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'max-reschedules-reached',
        ),
      );
      await expectLater(
        RescheduleBookingUseCase(
          client,
        ).call('b1', DateTime.fromMillisecondsSinceEpoch(1)),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test('const default constructor is usable', () {
      expect(const RescheduleBookingUseCase(), isA<RescheduleBookingUseCase>());
    });
  });

  group('Providers', () {
    test('each use-case provider builds the matching use case', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(acceptBookingUseCaseProvider),
        isA<AcceptBookingUseCase>(),
      );
      expect(
        container.read(rejectBookingUseCaseProvider),
        isA<RejectBookingUseCase>(),
      );
      expect(
        container.read(markInProgressUseCaseProvider),
        isA<MarkInProgressUseCase>(),
      );
      expect(
        container.read(confirmDoneUseCaseProvider),
        isA<ConfirmDoneUseCase>(),
      );
      expect(
        container.read(cancelBookingUseCaseProvider),
        isA<CancelBookingUseCase>(),
      );
      expect(
        container.read(rescheduleBookingUseCaseProvider),
        isA<RescheduleBookingUseCase>(),
      );
    });
  });
}
