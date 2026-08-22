import 'dart:math';

import 'identity_ports.dart';

/// A [BatchIdGenerator] that produces 32 hex characters (archi 5.4).
///
/// 32 hex chars sit inside the server's 8-to-64 `[A-Za-z0-9_-]` window with
/// plenty of entropy (128 bits), so a fresh id per attempt never collides with
/// an abandoned one and reuse is never accidental. A new id per attempt is a
/// contract, not a convenience: `storage.rules` requires `resource == null`, so
/// reusing a batch whose recto already uploaded fails for good (archi 5.4).
class HexBatchIdGenerator implements BatchIdGenerator {
  HexBatchIdGenerator([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String generate() {
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(_random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }
}
