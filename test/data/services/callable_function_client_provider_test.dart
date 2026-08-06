import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/services/callable_function_client.dart';
import 'package:outalma_app/src/data/services/callable_function_client_provider.dart';

void main() {
  test('provides a CallableFunctionClient', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(callableFunctionClientProvider),
      isA<CallableFunctionClient>(),
    );
  });
}
