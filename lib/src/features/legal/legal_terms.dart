/// Version identifier of the currently published Terms of Service + Privacy
/// Policy. Bump this string whenever the legal texts change so a fresh consent
/// is recorded (RGPD / CDP Senegal, loi 2008-12: proof of what the user
/// accepted and when).
///
/// Date-based so the accepted revision is unambiguous. Kept in sync with the
/// server constant `TERMS_VERSION` in `functions/src/auth_phone.ts`.
const String kTermsVersion = '2026-06-07';
