// Throwaway probe: prints the AUTHORITATIVE option map of a style, so the
// manifest is written on facts rather than from memory.
//
//   dart run bin/dump_schema.dart open_peeps
//   dart run bin/dump_schema.dart critters
//
// This is the replacement for the `--list-options` mode the plan dropped: the
// style definition is a JSON constant in the package, and OptionsDescriptor is
// the same descriptor the DiceBear editor renders its form from, so it is the
// authority on which keys are legal. Reading it here is what proves that a
// component option is spelled `headVariant` and not `head`.
import 'dart:convert';

import 'package:dicebear_core/dicebear_core.dart';
import 'package:dicebear_styles/critters.dart' as critters_style;
import 'package:dicebear_styles/open_peeps.dart' as open_peeps_style;

void main(List<String> args) {
  final name = args.isEmpty ? 'open_peeps' : args.first;
  final raw = switch (name) {
    'open_peeps' => open_peeps_style.openPeeps,
    'critters' => critters_style.critters,
    _ => throw ArgumentError('unknown style: $name'),
  };

  final descriptor = OptionsDescriptor(Style.parse(raw)).toJson();

  print('=== $name : ${descriptor.length} options ===');
  for (final entry in descriptor.entries) {
    final value = entry.value;
    if (value is! Map) {
      print('${entry.key}: $value');
      continue;
    }
    final type = value['type'];
    final values = value['values'];
    if (values is List) {
      print('${entry.key} ($type, ${values.length} values)');
      print('    ${values.join(', ')}');
    } else {
      print('${entry.key} ($type) ${jsonEncode(value)}');
    }
  }
}
