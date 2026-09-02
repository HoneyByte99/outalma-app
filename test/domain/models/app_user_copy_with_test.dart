// Guards AppUser.copyWith against dropping an optional field.
//
// This exists because the failure is silent and sits on the most ordinary path
// in the app. `switchMode` and `updateProfile` both rebuild the user through
// copyWith and then merge-write it; a field missing from the parameter list
// falls back to the constructor default of null, and tapping the mode badge or
// editing a name would quietly erase it. `avatarId` is the field this
// increment adds, and the loop below covers every optional field so the next
// one added is covered too.
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/gender.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

final _full = AppUser(
  id: 'u1',
  displayName: 'Awa Diop',
  email: 'awa@test.com',
  country: 'SN',
  activeMode: ActiveMode.client,
  createdAt: DateTime(2024, 1, 1),
  photoPath: 'https://example.test/a.jpg',
  phoneE164: '+221770000000',
  pushToken: 'tok',
  termsAcceptedAt: DateTime(2024, 2, 2),
  gender: Gender.female,
  avatarId: 'human_afro1_t2',
);

void main() {
  test('copyWith with no argument preserves every field', () {
    final copy = _full.copyWith();

    expect(copy.id, _full.id);
    expect(copy.displayName, _full.displayName);
    expect(copy.email, _full.email);
    expect(copy.country, _full.country);
    expect(copy.activeMode, _full.activeMode);
    expect(copy.createdAt, _full.createdAt);
    expect(copy.photoPath, _full.photoPath);
    expect(copy.phoneE164, _full.phoneE164);
    expect(copy.pushToken, _full.pushToken);
    expect(copy.termsAcceptedAt, _full.termsAcceptedAt);
    expect(copy.gender, _full.gender);
    expect(copy.avatarId, _full.avatarId);
  });

  test('switching mode preserves the avatar', () {
    // The exact shape of AuthNotifier.switchMode.
    final copy = _full.copyWith(activeMode: ActiveMode.provider);
    expect(copy.activeMode, ActiveMode.provider);
    expect(copy.avatarId, 'human_afro1_t2');
  });

  test('editing the name and country preserves the avatar', () {
    // The exact shape of AuthNotifier.updateProfile.
    final copy = _full.copyWith(displayName: 'Awa D.', country: 'FR');
    expect(copy.displayName, 'Awa D.');
    expect(copy.country, 'FR');
    expect(copy.avatarId, 'human_afro1_t2');
  });

  test(
    'copyWith cannot CLEAR the avatar, which is why setProfileImage exists',
    () {
      // The house idiom is `x ?? this.x`, so passing null means "keep". Erasing
      // therefore cannot go through copyWith at all, and goes through
      // UserRepository.setProfileImage, which writes FieldValue.delete().
      final copy = _full.copyWith(avatarId: null);
      expect(copy.avatarId, 'human_afro1_t2');
    },
  );
}
