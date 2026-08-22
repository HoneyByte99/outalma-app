import '../../../../l10n/app_localizations.dart';
import '../../../domain/identity/identity_submit_error.dart';

/// Maps a classified [IdentitySubmitError] to its localised, actionable message
/// (archi 5.5, AC-C13/C13b/C31).
///
/// The eight refusal kinds each get a distinct message; the rate-limit kind
/// folds in the server-computed delay when present, and the client never
/// estimates it (AC-C13b). No raw technical string ever reaches the user (U3).
String identitySubmitErrorMessage(
  AppLocalizations l10n,
  IdentitySubmitError error,
) {
  switch (error.kind) {
    case IdentitySubmitErrorKind.batchInvalid:
      return l10n.identityErrorBatchInvalid;
    case IdentitySubmitErrorKind.objectsMissing:
      return l10n.identityErrorObjectsMissing;
    case IdentitySubmitErrorKind.batchStale:
      return l10n.identityErrorBatchStale;
    case IdentitySubmitErrorKind.accountMissing:
      return l10n.identityErrorAccountMissing;
    case IdentitySubmitErrorKind.pendingExists:
      return l10n.identityErrorPendingExists;
    case IdentitySubmitErrorKind.alreadyVerified:
      return l10n.identityErrorAlreadyVerified;
    case IdentitySubmitErrorKind.rateLimited:
      final ms = error.retryAfterMs;
      if (ms == null || ms <= 0) return l10n.identityErrorRateLimited;
      return l10n.identityErrorRateLimitedWithDelay(_formatDelay(l10n, ms));
    case IdentitySubmitErrorKind.storageDenied:
      return l10n.identityErrorStorageDenied;
    case IdentitySubmitErrorKind.unauthenticated:
      return l10n.identityErrorAccountMissing;
    case IdentitySubmitErrorKind.network:
      return l10n.identityErrorNetwork;
    case IdentitySubmitErrorKind.unknown:
      return l10n.identityErrorUnknown;
  }
}

/// Whether a refusal warrants restarting the capture on a fresh batch, versus
/// leaving the journey (account or already-verified cases route away).
bool identityErrorIsResumable(IdentitySubmitError error) {
  switch (error.kind) {
    case IdentitySubmitErrorKind.accountMissing:
    case IdentitySubmitErrorKind.unauthenticated:
    case IdentitySubmitErrorKind.alreadyVerified:
    case IdentitySubmitErrorKind.pendingExists:
    case IdentitySubmitErrorKind.rateLimited:
      return false;
    case IdentitySubmitErrorKind.batchInvalid:
    case IdentitySubmitErrorKind.objectsMissing:
    case IdentitySubmitErrorKind.batchStale:
    case IdentitySubmitErrorKind.storageDenied:
    case IdentitySubmitErrorKind.network:
    case IdentitySubmitErrorKind.unknown:
      return true;
  }
}

String _formatDelay(AppLocalizations l10n, int ms) {
  final minutes = (ms / 60000).ceil();
  if (minutes >= 60) {
    final hours = (minutes / 60).ceil();
    return l10n.identityDurationHours(hours);
  }
  return l10n.identityDurationMinutes(minutes);
}
