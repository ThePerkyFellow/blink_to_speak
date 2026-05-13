import 'dart:collection';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../gesture/gesture_event.dart';

/// Feature vector for one camera frame fed to the temporal classifier.
class FeatureVector {
  final double eyeOpenProbLeft;
  final double eyeOpenProbRight;
  final double gazeX;
  final double gazeY;
  final double irisVX;
  final double irisVY;

  const FeatureVector({
    required this.eyeOpenProbLeft,
    required this.eyeOpenProbRight,
    required this.gazeX,
    required this.gazeY,
    required this.irisVX,
    required this.irisVY,
  });

  List<double> toList() => [
        eyeOpenProbLeft,
        eyeOpenProbRight,
        gazeX,
        gazeY,
        irisVX,
        irisVY,
      ];

  Map<String, dynamic> toJson() => {
        'eyeOpenProbLeft':  eyeOpenProbLeft,
        'eyeOpenProbRight': eyeOpenProbRight,
        'gazeX':  gazeX,
        'gazeY':  gazeY,
        'irisVX': irisVX,
        'irisVY': irisVY,
      };
}

/// Gesture labels matching training script order:
///   0: neutral, 1: blink, 2: shut, 3: wink_L, 4: wink_R
const _gestureLabels = [null, 'blink', 'shut', 'wink_L', 'wink_R'];

/// Maps model output label string → GestureEvent
const _labelToEvent = {
  'blink':  GestureEvent.B,
  'shut':   GestureEvent.S,
  'wink_L': GestureEvent.WL,
  'wink_R': GestureEvent.WR,
};

/// On-device 1D-CNN temporal gesture classifier.
///
/// Consumes a sliding window of [windowSize] feature frames and outputs a
/// gesture probability distribution. A gesture event is emitted when any
/// non-neutral class exceeds [confidenceThreshold] and the classifier has
/// maintained that prediction for at least [minConfirmedFrames] consecutive
/// frames (prevents noise triggering a double-fire).
class GestureClassifier {
  static const int windowSize        = 15;
  static const int nFeatures         = 6;
  static const double confidenceThreshold = 0.80;   // must be very confident
  static const int minConfirmedFrames = 2;           // debounce: 2 frames in a row

  late Interpreter _interpreter;
  bool _isInitialized = false;

  // Sliding feature window
  final _window = Queue<List<double>>();

  // Debounce: track consecutive predictions of the same non-neutral label
  String? _pendingLabel;
  int _pendingCount = 0;
  String? _lastFiredLabel;

  /// Load the TFLite model from assets.
  Future<void> initialize() async {
    print('[GestureClassifier] Initializing TFLite model...');
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/gesture_classifier.tflite',
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        print('[GestureClassifier] TIMEOUT loading TFLite model!');
        throw Exception('TFLite Model Load Timeout');
      });
      print('[GestureClassifier] TFLite model loaded successfully!');
      _isInitialized = true;
    } catch (e, st) {
      print('[GestureClassifier] ERROR loading TFLite model: $e');
      print(st);
      // Non-fatal — fall back to rule-based detection in state machine
      _isInitialized = false;
    }
  }

  /// Feed one frame. Returns [GestureEvent] when a confident gesture is
  /// detected, null otherwise (including while window is still filling).
  GestureEvent? classify(FeatureVector v) {
    if (!_isInitialized) return null;

    _window.addLast(v.toList());
    if (_window.length > windowSize) _window.removeFirst();
    if (_window.length < windowSize) return null;

    // Run inference: input shape [1, 15, 6], output shape [1, 5]
    final input  = [_window.toList()];
    final output = [List<double>.filled(5, 0.0)];
    _interpreter.run(input, output);

    final probs    = output[0];
    final maxProb  = probs.reduce(max);
    final maxIndex = probs.indexOf(maxProb);
    final label    = _gestureLabels[maxIndex]; // null = neutral

    // If neutral or low confidence, reset pending
    if (label == null || maxProb < confidenceThreshold) {
      _pendingLabel = null;
      _pendingCount = 0;
      _lastFiredLabel = null;
      return null;
    }

    // Debounce: accumulate consecutive frames of the same prediction
    if (label == _pendingLabel) {
      _pendingCount++;
    } else {
      _pendingLabel = label;
      _pendingCount = 1;
    }

    // Fire only once per gesture occurrence (until label changes to neutral)
    if (_pendingCount == minConfirmedFrames && label != _lastFiredLabel) {
      _lastFiredLabel = label;
      return _labelToEvent[label];
    }

    return null;
  }

  /// Clear the feature window (call on calibration reset).
  void reset() {
    _window.clear();
    _pendingLabel  = null;
    _pendingCount  = 0;
    _lastFiredLabel = null;
  }

  void dispose() {
    if (_isInitialized) _interpreter.close();
  }
}
