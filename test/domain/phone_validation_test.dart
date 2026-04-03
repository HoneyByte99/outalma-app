import 'package:flutter_test/flutter_test.dart';

// Mirror of the validation logic in sign_up_page.dart.
// Keeping it here avoids coupling tests to a widget.
bool isValidE164(String phone) => RegExp(r'^\+\d{7,15}$').hasMatch(phone);

void main() {
  group('E.164 phone validation', () {
    group('valid numbers', () {
      test('French mobile', () => expect(isValidE164('+33612345678'), isTrue));
      test('Senegalese mobile', () => expect(isValidE164('+221771234567'), isTrue));
      test('US number', () => expect(isValidE164('+12025551234'), isTrue));
      test('minimum 7 digits after +', () => expect(isValidE164('+1234567'), isTrue));
      test('maximum 15 digits after +', () => expect(isValidE164('+123456789012345'), isTrue));
    });

    group('invalid numbers', () {
      test('missing + prefix', () => expect(isValidE164('33612345678'), isFalse));
      test('contains spaces', () => expect(isValidE164('+33 6 12 34 56 78'), isFalse));
      test('contains dashes', () => expect(isValidE164('+33-6-12-34-56-78'), isFalse));
      test('too short (6 digits)', () => expect(isValidE164('+123456'), isFalse));
      test('too long (16 digits)', () => expect(isValidE164('+1234567890123456'), isFalse));
      test('empty string', () => expect(isValidE164(''), isFalse));
      test('only plus sign', () => expect(isValidE164('+'), isFalse));
      test('letters in number', () => expect(isValidE164('+336abc12345'), isFalse));
    });
  });
}
