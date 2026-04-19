import 'dart:async';
import 'dart:math';
import '../detection/face_detector_interface.dart';
import 'gesture_event.dart';

/// Detects the Roll (O) gesture by tracking the iris position trajectory
/// over a ~1-second window and looking for a circular pattern.
///
/// Algorithm:
///   1. Buffer (irisX, irisY) samples over a rolling 1200ms window.
///   2. If at least 20 samples, compute the centroid.
///   3. Measure the average radius from centroid.
///   4. Check that all 4 angular quadrants are covered (rotation swept ≥ 270°).
///   5. Check the radius consistency (std-dev / mean < 0.4).
///   6. If all pass → emit Roll detected.
class RollDetector {
  static const _windowMs     = 1200;
  static const _minSamples   = 20;
  static const _minRadius    = 6.0;   // pixels, ignores tiny movements
  static const _maxRadiusStd = 0.45;  // circularity tolerance
  static const _minArcDeg    = 260.0; // must sweep at least this many degrees

  final _samples = <_IrisSample>[];
  final _rollController = StreamController<bool>.broadcast();

  /// Stream emits `true` each time a roll is confirmed.
  Stream<bool> get rollStream => _rollController.stream;

  void addSample(double x, double y) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _samples.add(_IrisSample(x: x, y: y, t: now));

    // Prune old samples
    _samples.removeWhere((s) => now - s.t > _windowMs);

    if (_samples.length >= _minSamples) {
      _evaluate();
    }
  }

  void _evaluate() {
    // 1. Centroid
    final cx = _samples.map((s) => s.x).reduce((a, b) => a + b) / _samples.length;
    final cy = _samples.map((s) => s.y).reduce((a, b) => a + b) / _samples.length;

    // 2. Radii from centroid
    final radii = _samples.map((s) {
      final dx = s.x - cx, dy = s.y - cy;
      return sqrt(dx * dx + dy * dy);
    }).toList();

    final meanR = radii.reduce((a, b) => a + b) / radii.length;
    if (meanR < _minRadius) return; // movement too small

    // 3. Radius std-dev (circularity check)
    final variance = radii.map((r) => pow(r - meanR, 2)).reduce((a, b) => a + b) / radii.length;
    final stdR = sqrt(variance);
    if (stdR / meanR > _maxRadiusStd) return; // too elliptical / not circular

    // 4. Angular sweep — check that angles cover at least _minArcDeg
    final angles = _samples.map((s) => atan2(s.y - cy, s.x - cx)).toList(); // -π … π
    final sweepDeg = _computeAngularSweep(angles);
    if (sweepDeg < _minArcDeg) return; // arc not wide enough

    // All checks passed → roll detected; clear buffer to avoid double-fires
    _samples.clear();
    _rollController.add(true);
  }

  /// Compute the angular range actually swept, handling the wrap-around at ±π.
  double _computeAngularSweep(List<double> angles) {
    // Sort angles and find max gap (unwrapped)
    final sorted = [...angles]..sort();
    double maxGap = 0;
    for (int i = 1; i < sorted.length; i++) {
      final gap = sorted[i] - sorted[i - 1];
      if (gap > maxGap) maxGap = gap;
    }
    // Wrap-around gap
    final wrapGap = (2 * pi) - sorted.last + sorted.first;
    if (wrapGap > maxGap) maxGap = wrapGap;

    // Swept arc = full circle minus the biggest gap
    return ((2 * pi - maxGap) * 180 / pi).clamp(0, 360);
  }

  void dispose() {
    _rollController.close();
  }
}

class _IrisSample {
  final double x, y;
  final int t;
  _IrisSample({required this.x, required this.y, required this.t});
}
