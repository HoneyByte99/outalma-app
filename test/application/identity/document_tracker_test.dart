import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/identity/document_tracker.dart';
import 'package:outalma_app/src/domain/identity/document_edge_detector.dart';
import 'package:outalma_app/src/domain/identity/document_quad.dart';

DocumentQuad _rect(double left, double top, double right, double bottom) {
  return DocumentQuad(
    topLeft: (x: left, y: top),
    topRight: (x: right, y: top),
    bottomRight: (x: right, y: bottom),
    bottomLeft: (x: left, y: bottom),
  );
}

DocumentEdgeObservation _seen(DocumentQuad quad) =>
    DocumentEdgeObservation(framing: DocumentFraming.good, quad: quad);

const _missed = DocumentEdgeObservation.none;

DocumentTrackState _step(
  DocumentTrackState prev,
  DocumentEdgeObservation observation, {
  double smoothing = 1,
  int acquireFrames = 3,
  int loseFrames = 5,
}) {
  return trackDocument(
    prev: prev,
    observation: observation,
    smoothing: smoothing,
    acquireFrames: acquireFrames,
    loseFrames: loseFrames,
  );
}

void main() {
  group('acquisition', () {
    test('stays hidden until acquireFrames detections in a row', () {
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      var state = const DocumentTrackState.initial();
      expect(state.visible, isFalse);

      state = _step(state, _seen(quad));
      expect(state.visible, isFalse);
      state = _step(state, _seen(quad));
      expect(state.visible, isFalse);
      state = _step(state, _seen(quad));
      expect(state.visible, isTrue);
    });

    test('a miss in the run sends the acquisition back to zero', () {
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      var state = const DocumentTrackState.initial();
      state = _step(state, _seen(quad));
      state = _step(state, _seen(quad));
      state = _step(state, _missed);
      expect(state.hits, 0);
      state = _step(state, _seen(quad));
      state = _step(state, _seen(quad));
      expect(state.visible, isFalse, reason: 'the run restarted');
      state = _step(state, _seen(quad));
      expect(state.visible, isTrue);
    });
  });

  group('loss', () {
    DocumentTrackState visible(DocumentQuad quad) {
      var state = const DocumentTrackState.initial();
      for (var i = 0; i < 3; i++) {
        state = _step(state, _seen(quad));
      }
      return state;
    }

    test('a single dropped frame does NOT blank the contour', () {
      // The reason hysteresis exists: a flickering contour is the worst signal
      // for someone who cannot read, so losing is deliberately slower than
      // acquiring.
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      var state = visible(quad);
      state = _step(state, _missed);
      expect(state.visible, isTrue);
      expect(state.quad, isNotNull);
    });

    test('goes after loseFrames misses in a row, and drops its quad', () {
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      var state = visible(quad);
      for (var i = 0; i < 4; i++) {
        state = _step(state, _missed);
        expect(state.visible, isTrue, reason: 'miss ${i + 1} of 5');
      }
      state = _step(state, _missed);
      expect(state.visible, isFalse);
      expect(state.quad, isNull);
    });

    test('one detection resets the miss run', () {
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      var state = visible(quad);
      state = _step(state, _missed);
      state = _step(state, _missed);
      state = _step(state, _seen(quad));
      expect(state.misses, 0);
      expect(state.visible, isTrue);
    });
  });

  group('smoothing', () {
    test('a low weight moves the outline only part of the way', () {
      final first = _rect(0.2, 0.3, 0.8, 0.6);
      final jumped = _rect(0.4, 0.3, 1.0, 0.6);
      var state = _step(
        const DocumentTrackState.initial(),
        _seen(first),
        smoothing: 0.25,
      );
      expect(state.quad!.topLeft.x, closeTo(0.2, 1e-9));

      state = _step(state, _seen(jumped), smoothing: 0.25);
      // A quarter of the way from 0.2 to 0.4.
      expect(state.quad!.topLeft.x, closeTo(0.25, 1e-9));
      expect(state.quad!.topLeft.x, lessThan(jumped.topLeft.x));
    });

    test('a weight of one follows the detection exactly', () {
      final first = _rect(0.2, 0.3, 0.8, 0.6);
      final jumped = _rect(0.4, 0.3, 1.0, 0.6);
      var state = _step(const DocumentTrackState.initial(), _seen(first));
      state = _step(state, _seen(jumped));
      expect(state.quad!.topLeft.x, closeTo(0.4, 1e-9));
    });

    test('reduces jitter across an alternating sequence', () {
      final a = _rect(0.20, 0.30, 0.80, 0.60);
      final b = _rect(0.24, 0.30, 0.84, 0.60);
      var smooth = const DocumentTrackState.initial();
      var raw = const DocumentTrackState.initial();
      for (var i = 0; i < 8; i++) {
        final observation = _seen(i.isEven ? a : b);
        smooth = _step(smooth, observation, smoothing: 0.3);
        raw = _step(raw, observation);
      }
      // The raw tracker sits exactly on the latest sample; the smoothed one
      // stays between the two, which is the whole point.
      expect(raw.quad!.topLeft.x, closeTo(0.24, 1e-9));
      expect(smooth.quad!.topLeft.x, greaterThan(0.20));
      expect(smooth.quad!.topLeft.x, lessThan(0.24));
    });

    test('clamps a degenerate smoothing weight instead of diverging', () {
      final first = _rect(0.2, 0.3, 0.8, 0.6);
      final next = _rect(0.4, 0.3, 1.0, 0.6);
      var state = _step(
        const DocumentTrackState.initial(),
        _seen(first),
        smoothing: 0,
      );
      state = _step(state, _seen(next), smoothing: 0);
      expect(state.quad!.topLeft.x, greaterThan(0.2));
      expect(state.quad!.topLeft.x, lessThan(0.4));
    });
  });

  group('framing', () {
    test('carries the observation framing through, hit or miss', () {
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      var state = _step(const DocumentTrackState.initial(), _seen(quad));
      expect(state.framing, DocumentFraming.good);

      state = _step(
        state,
        const DocumentEdgeObservation(
          framing: DocumentFraming.tooSmall,
          quad: null,
        ),
      );
      expect(state.framing, DocumentFraming.tooSmall);

      state = _step(state, DocumentEdgeObservation.unknown);
      expect(state.framing, DocumentFraming.unknown);
    });
  });

  group('parameter validation', () {
    test('throws on a degenerate run length', () {
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      expect(
        () => _step(
          const DocumentTrackState.initial(),
          _seen(quad),
          acquireFrames: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => _step(
          const DocumentTrackState.initial(),
          _seen(quad),
          loseFrames: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
