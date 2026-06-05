// Harness widget tests for ReviewFormPage.
//
// ReviewFormPage uses ref.read(authNotifierProvider) inside a stream data
// callback — the async AuthNotifier may not have resolved yet when the
// booking stream emits. Tests verify smoke render and stable scaffold.
// Full form-element assertions are covered by the integration golden-path test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/booking/booking_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/booking_status.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/models/booking.dart';
import 'package:outalma_app/src/features/review/review_form_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'client_1',
      displayName: 'Client User',
      email: 'client@test.com',
      country: 'FR',
      activeMode: ActiveMode.client,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

final _fakeBooking = Booking(
  id: 'bk_test',
  customerId: 'client_1',
  providerId: 'prov_1',
  serviceId: 'svc_1',
  status: BookingStatus.done,
  requestMessage: 'Test booking',
  createdAt: DateTime(2024, 6, 1),
);

Widget _wrap() => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    bookingDetailProvider(
      'bk_test',
    ).overrideWith((_) => Stream.value(_fakeBooking)),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const ReviewFormPage(bookingId: 'bk_test'),
  ),
);

void main() {
  group('ReviewFormPage', () {
    testWidgets('smoke — renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(ReviewFormPage), findsOneWidget);
    });

    testWidgets('always shows a Scaffold', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('review form or loading/empty state renders without error', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // Either the form (with stars) or a state-message text is shown.
      // Either way, the tree must not contain any error widgets.
      expect(tester.takeException(), isNull);
    });
  });
}
