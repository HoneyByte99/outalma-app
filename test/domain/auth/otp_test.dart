import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/auth/otp.dart';

void main() {
  test(
    'otpCodeLength matches the 6-digit code functions/src/auth_phone.ts '
    'requires (Twilio Verify default, tightened server-side)',
    () => expect(otpCodeLength, 6),
  );
}
