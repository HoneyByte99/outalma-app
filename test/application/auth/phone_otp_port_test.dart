// What a successful send hands back to the screens.
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/auth/phone_otp_port.dart';

void main() {
  // Built from a variable, the way the data adapter builds it from the wire:
  // a const literal here would be folded at compile time and would exercise
  // nothing.
  OtpRequestOutcome fromServer(int? retryAfterMs) =>
      OtpRequestOutcome(retryAfterMs: retryAfterMs);

  test('rounds the delay UP to whole seconds', () {
    // Down would re-enable the resend button a fraction early, straight into
    // the refusal the countdown exists to avoid.
    expect(fromServer(59001).retryAfterSeconds, 60);
    expect(fromServer(60000).retryAfterSeconds, 60);
    expect(fromServer(1).retryAfterSeconds, 1);
  });

  test('an absent delay stays absent, never becomes zero', () {
    // A server that sent nothing (an older deployed build) must leave the
    // button usable, not locked for an invented duration nor unlocked by a
    // zero that reads like a real answer.
    expect(fromServer(null).retryAfterSeconds, isNull);
  });

  test('a zero delay is carried as zero, which means no countdown', () {
    expect(fromServer(0).retryAfterSeconds, 0);
  });
}
