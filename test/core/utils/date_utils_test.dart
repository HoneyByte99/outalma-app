import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:outalma_app/src/core/utils/date_utils.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('isDifferentDay', () {
    test('same calendar day → false', () {
      final a = DateTime(2024, 6, 1, 8, 0);
      final b = DateTime(2024, 6, 1, 23, 59);
      expect(isDifferentDay(a, b), isFalse);
    });

    test('different day → true', () {
      final a = DateTime(2024, 6, 1, 23, 59);
      final b = DateTime(2024, 6, 2, 0, 1);
      expect(isDifferentDay(a, b), isTrue);
    });

    test('same day different year → true', () {
      expect(
        isDifferentDay(DateTime(2023, 6, 1), DateTime(2024, 6, 1)),
        isTrue,
      );
    });
  });

  group('formatChatDaySeparator', () {
    test('today returns the today label', () {
      final now = DateTime.now();
      expect(
        formatChatDaySeparator(now, today: 'Today', yesterday: 'Yesterday'),
        'Today',
      );
    });

    test('yesterday returns the yesterday label', () {
      final y = DateTime.now().subtract(const Duration(days: 1));
      expect(
        formatChatDaySeparator(y, today: 'Today', yesterday: 'Yesterday'),
        'Yesterday',
      );
    });

    test('older than a week returns an absolute date (not the labels)', () {
      final old = DateTime.now().subtract(const Duration(days: 30));
      final label = formatChatDaySeparator(
        old,
        today: 'Today',
        yesterday: 'Yesterday',
      );
      expect(label, isNot('Today'));
      expect(label, isNot('Yesterday'));
      expect(label, contains(old.year.toString()));
    });
  });
}
