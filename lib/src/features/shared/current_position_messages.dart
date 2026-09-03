import '../../../l10n/app_localizations.dart';
import '../../domain/utils/current_position.dart';

/// The one French/English phrase for each [CurrentPositionFailure], shared by
/// every "use my location" affordance so the copy cannot drift between the
/// home page's location filter and the booking address step.
String currentPositionFailureMessage(
  CurrentPositionFailure failure,
  AppLocalizations l10n,
) {
  switch (failure) {
    case CurrentPositionFailure.serviceDisabled:
      return l10n.locationServiceDisabled;
    case CurrentPositionFailure.permissionDenied:
      return l10n.locationPermissionDenied;
    case CurrentPositionFailure.error:
      return l10n.locationGeoError;
  }
}
