import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/core/utils/debouncer.dart';

void main() {
  group('Debouncer.run', () {
    test('a burst of calls runs the action once, with the LAST argument', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        final seen = <String>[];

        for (final input in ['D', 'Da', 'Dak', 'Daka', 'Dakar']) {
          debouncer.run(() => seen.add(input));
        }
        // Nothing has run yet: the delay has not elapsed.
        expect(seen, isEmpty);

        async.elapse(kAddressSearchDebounce + const Duration(milliseconds: 1));

        expect(
          seen,
          ['Dakar'],
          reason: 'one execution, and it carries the last input, not the first',
        );
      });
    });

    test('runs again once a full delay elapses between calls', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        final seen = <String>[];

        debouncer.run(() => seen.add('first'));
        async.elapse(kAddressSearchDebounce + const Duration(milliseconds: 1));
        debouncer.run(() => seen.add('second'));
        async.elapse(kAddressSearchDebounce + const Duration(milliseconds: 1));

        expect(seen, ['first', 'second']);
      });
    });

    test('awaits nothing: an async action does not block the caller', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        var ran = false;

        debouncer.run(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          ran = true;
        });
        async.elapse(kAddressSearchDebounce + const Duration(milliseconds: 20));

        expect(ran, isTrue);
      });
    });
  });

  group('Debouncer.cancel', () {
    test('drops the pending action: it never runs', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        var ran = false;

        debouncer.run(() => ran = true);
        debouncer.cancel();
        async.elapse(kAddressSearchDebounce * 3);

        expect(ran, isFalse);
      });
    });

    test('is a no-op when nothing is scheduled', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        expect(debouncer.cancel, returnsNormally);
        async.elapse(kAddressSearchDebounce * 3);
      });
    });
  });

  group('Debouncer.dispose', () {
    test('drops the pending action: it never runs', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        var ran = false;

        debouncer.run(() => ran = true);
        debouncer.dispose();
        async.elapse(kAddressSearchDebounce * 3);

        expect(ran, isFalse);
      });
    });
  });

  test('honours a custom delay', () {
    fakeAsync((async) {
      final debouncer = Debouncer(delay: const Duration(seconds: 2));
      var ran = false;

      debouncer.run(() => ran = true);
      async.elapse(kAddressSearchDebounce * 2);
      expect(ran, isFalse, reason: 'the default delay must not apply');

      async.elapse(const Duration(seconds: 2));
      expect(ran, isTrue);
    });
  });
}
