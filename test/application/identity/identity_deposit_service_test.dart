import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/identity/identity_deposit_service.dart';
import 'package:outalma_app/src/application/identity/identity_ports.dart';
import 'package:outalma_app/src/domain/identity/identity_submit_error.dart';

class _SpyUpload implements IdentityUploadPort {
  final calls = <({String path, int size, String contentType})>[];
  FirebaseException? throwOn;

  @override
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (throwOn != null && path == throwOn!.message) throw throwOn!;
    calls.add((path: path, size: bytes.length, contentType: contentType));
  }
}

class _SpySubmit implements IdentitySubmitPort {
  final batchIds = <String>[];
  bool alreadySubmitted = false;
  IdentitySubmitError? error;

  @override
  Future<IdentitySubmitOutcome> submit({required String batchId}) async {
    batchIds.add(batchId);
    if (error != null) throw error!;
    return IdentitySubmitOutcome(alreadySubmitted: alreadySubmitted);
  }
}

class _SeqBatchIds implements BatchIdGenerator {
  _SeqBatchIds(this._ids);
  final List<String> _ids;
  int _i = 0;
  @override
  String generate() => _ids[_i++];
}

IdentityImages _images() => IdentityImages(
  recto: Uint8List.fromList(List.filled(10, 1)),
  verso: Uint8List.fromList(List.filled(20, 2)),
  selfie: Uint8List.fromList(List.filled(30, 3)),
);

void main() {
  group('IdentityDepositService', () {
    test(
      'uploads the three objects in order with the image content type',
      () async {
        final upload = _SpyUpload();
        final submit = _SpySubmit();
        final service = IdentityDepositService(
          upload: upload,
          submit: submit,
          batchIds: _SeqBatchIds(['batch0001']),
        );

        final result = await service.deposit(uid: 'u1', images: _images());

        expect(result, isA<IdentityDepositSuccess>());
        expect(upload.calls.map((c) => c.path).toList(), [
          'private/identity/u1/batch0001/recto.jpg',
          'private/identity/u1/batch0001/verso.jpg',
          'private/identity/u1/batch0001/selfie.jpg',
        ]);
        // AC-C10 is measured on size, not a counter: the port carries the bytes.
        expect(upload.calls.map((c) => c.size).toList(), [10, 20, 30]);
        // The Storage rule requires image/.*; octet-stream would be denied.
        expect(
          upload.calls.every((c) => c.contentType == 'image/jpeg'),
          isTrue,
        );
        expect(submit.batchIds, ['batch0001']);
      },
    );

    test(
      'surfaces alreadySubmitted as a replay, not a fresh success',
      () async {
        final submit = _SpySubmit()..alreadySubmitted = true;
        final service = IdentityDepositService(
          upload: _SpyUpload(),
          submit: submit,
          batchIds: _SeqBatchIds(['batch0001']),
        );

        final result = await service.deposit(uid: 'u1', images: _images());
        expect((result as IdentityDepositSuccess).alreadySubmitted, isTrue);
      },
    );

    test('a fresh batch id is used on each attempt (AC-C12)', () async {
      final submit = _SpySubmit();
      final ids = _SeqBatchIds(['batchAAAA', 'batchBBBB']);
      final service = IdentityDepositService(
        upload: _SpyUpload(),
        submit: submit,
        batchIds: ids,
      );

      await service.deposit(uid: 'u1', images: _images());
      await service.deposit(uid: 'u1', images: _images());

      expect(submit.batchIds, ['batchAAAA', 'batchBBBB']);
    });

    test('a denied Storage write becomes a storageDenied failure', () async {
      final upload = _SpyUpload()
        ..throwOn = FirebaseException(
          plugin: 'storage',
          code: 'unauthorized',
          message: 'private/identity/u1/batch0001/recto.jpg',
        );
      final submit = _SpySubmit();
      final service = IdentityDepositService(
        upload: upload,
        submit: submit,
        batchIds: _SeqBatchIds(['batch0001']),
      );

      final result = await service.deposit(uid: 'u1', images: _images());
      expect(result, isA<IdentityDepositFailure>());
      expect(
        (result as IdentityDepositFailure).error.kind,
        IdentitySubmitErrorKind.storageDenied,
      );
      // The callable is never reached when an upload was denied.
      expect(submit.batchIds, isEmpty);
    });

    test('a submit refusal is returned as a classified failure', () async {
      final submit = _SpySubmit()
        ..error = const IdentitySubmitError(
          IdentitySubmitErrorKind.rateLimited,
          retryAfterMs: 3600000,
        );
      final service = IdentityDepositService(
        upload: _SpyUpload(),
        submit: submit,
        batchIds: _SeqBatchIds(['batch0001']),
      );

      final result = await service.deposit(uid: 'u1', images: _images());
      final failure = result as IdentityDepositFailure;
      expect(failure.error.kind, IdentitySubmitErrorKind.rateLimited);
      expect(failure.error.retryAfterMs, 3600000);
    });
  });
}
