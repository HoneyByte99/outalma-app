/// The canonical E.164 string of a phone number, composed from the dial code
/// the user picked and the national number as they typed it.
///
/// The phone number is the identity of a phone account, so the app sends one
/// string per subscriber, whatever the spelling: separators dropped, and the
/// national trunk zero dropped for the dial codes that have one. A French user
/// types "06 39 98 12 34"; sent raw, it was refused by the server (spaces) or by
/// Twilio (`+330639981234`).
///
/// The server applies the same rule (`functions/src/phone_canonical.ts`), since
/// apps already installed and the web front send what was typed. Both sides
/// are pinned to `shared/phone-normalisation-cases.json`.
library;

/// Dial codes whose national numbers start with a trunk zero that is not part
/// of the international number. Italy (+39) and Cote d'Ivoire (+225) are
/// deliberately absent: their leading zero IS part of the number. Same list as
/// `TRUNK_ZERO_PREFIXES` in `functions/src/otp_rate_limit.ts`, each entry
/// checked against a real number of the country.
const Set<String> kTrunkZeroDialCodes = {
  '+212',
  '+213',
  '+32',
  '+33',
  '+41',
  '+44',
  '+49',
};

/// `dialCode` followed by the digits of `national`, trunk zeros dropped where
/// [kTrunkZeroDialCodes] says so. A national part made only of zeros is kept
/// as it is, exactly as the server does, so the two never disagree on it.
/// Returns `null` when no digit was typed.
String? composeE164(String dialCode, String national) {
  final digits = national.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (!kTrunkZeroDialCodes.contains(dialCode)) return '$dialCode$digits';
  final stripped = digits.replaceFirst(RegExp(r'^0+'), '');
  return '$dialCode${stripped.isEmpty ? digits : stripped}';
}
