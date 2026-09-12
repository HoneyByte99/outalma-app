// Parity between the dial codes the selector offers and the allowlist the
// server guard enforces.
//
// The two lists cannot be one file at runtime: `firebase.json` uploads only
// `functions/`, so `shared/` is absent from the deployed bundle and reading it
// there would kill the three phone callables on startup. So each side keeps its
// own copy and a test on each side pins it to the shared declaration:
// this one, and `functions/test/otp_rate_limit.test.ts` over there.
//
// What it catches: a country added to the selector but not to the guard is a
// user who picks their country and is refused for picking it, with a message
// that says the country is not served while the app is visibly offering it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/features/shared/phone_field.dart';

void main() {
  test('PhoneField.supportedDialCodes matches the shared declaration', () {
    final file = File('shared/allowed-phone-prefixes.json');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'shared/allowed-phone-prefixes.json is the declaration both '
          'sides are pinned to; it must not be moved without updating both.',
    );

    final declared =
        (jsonDecode(file.readAsStringSync())
                as Map<String, dynamic>)['prefixes']
            as List<dynamic>;

    expect(PhoneField.supportedDialCodes, declared.cast<String>().toSet());
  });

  test('every offered code is well formed', () {
    for (final code in PhoneField.supportedDialCodes) {
      expect(
        RegExp(r'^\+[1-9]\d{0,2}$').hasMatch(code),
        isTrue,
        reason: '$code is not a plausible dial code',
      );
    }
  });
}
