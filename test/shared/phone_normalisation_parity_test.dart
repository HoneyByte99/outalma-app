// composeE164, pinned to the declaration the server is pinned to as well
// (shared/phone-normalisation-cases.json, read by
// functions/test/phone_canonical.test.ts). A case that passed here and failed
// there would be a number the app sends in one form and the server stores in
// another, which for a phone account means a second account.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/auth/phone_number.dart';
import 'package:outalma_app/src/features/shared/phone_field.dart';

void main() {
  final declaration =
      jsonDecode(
            File('shared/phone-normalisation-cases.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = (declaration['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  test('drops the trunk zero for exactly the declared dial codes', () {
    expect(
      kTrunkZeroDialCodes,
      (declaration['trunkZeroPrefixes'] as List<dynamic>)
          .cast<String>()
          .toSet(),
    );
  });

  test('every trunk-zero dial code is one the selector offers', () {
    expect(
      PhoneField.supportedDialCodes.containsAll(kTrunkZeroDialCodes),
      isTrue,
    );
  });

  for (final c in cases) {
    final dialCode = c['dialCode'] as String;
    final national = c['national'] as String;
    test('$dialCode "$national" becomes ${c['e164']}', () {
      expect(composeE164(dialCode, national), c['e164']);
    });
  }

  test('no digit typed means no number at all', () {
    expect(composeE164('+33', ''), isNull);
    expect(composeE164('+33', ' - '), isNull);
  });
}
