import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'mediapipe_detector.dart';
import 'face_detector_interface.dart';
import 'gesture_classifier.dart';
import 'gesture_recorder.dart';
import '../gesture/gesture_event.dart';

/// Dual-engine detector combining:
///   1. FaceMesh  (MediaPipeDetector) → gaze, iris XY, eye contours, HUD
///   2. FaceDetector (classification) → eyeOpenProbLeft / Right (neural, pose-corrected)
///
/// Both engines share the same input image. The results are merged into a
/// single [FaceData] that carries all fields.
///
/// The eye-open probabilities replace the hand-crafted EAR formula as the
/// primary blink/wink signal. EAR is still emitted (for legacy HUD display)
/// but is no longer used for gesture classification decisions.
class CombinedDetector implements FaceDetectorInterface {
  // ── Inner engines ──────────────────────────────────────────────────────────
  final MediaPipeDetector  _meshEngine        = MediaPipeDetector();
  final GestureClassifier  _gestureClassifier = GestureClassifier();
  final GestureRecorder    recorder           = GestureRecorder();
  late  FaceDetector       _classEngine;

  // ── Output stream ──────────────────────────────────────────────────────────
  final _controller = StreamController<FaceData>.broadcast();

  // ── Latest mesh data (updated by mesh engine subscription) ────────────────
  FaceData? _latestMesh;
  StreamSubscription<FaceData>? _meshSub;

  // ── Last known eye probs (carry-forward on miss) ───────────────────────────
  double _eyeOpenProbLeft  = 1.0;
  double _eyeOpenProbRight = 1.0;

  // ── Previous iris position for velocity computation ────────────────────────
  double _prevIrisX = 0.0;
  double _prevIrisY = 0.0;

  // ── Frame throttle & busy guard ────────────────────────────────────────────
  bool _isBusy = false;          // drop frame if previous still processing
  int  _classFrameCount = 0;     // run FaceDetector every N frames only
  static const int _classEveryN = 3;

  @override
  String get engineName => 'Combined (FaceMesh + FaceDetector)';

  @override
  Future<void> initialize() async {
    // Initialise the mesh engine (gaze / iris / HUD)
    await _meshEngine.initialize();

    // Subscribe to mesh engine output so we always have the latest mesh data
    _meshSub = _meshEngine.faceDataStream.listen((fd) {
      _latestMesh = fd;
    });

    // Initialise the TFLite temporal classifier (non-fatal if model missing)
    await _gestureClassifier.initialize();

    // Initialise the classification engine (eye-open probabilities)
    _classEngine = FaceDetector(
      options: FaceDetectorOptions(
        // Classification gives leftEyeOpenProbability / rightEyeOpenProbability
        enableClassification: true,
        // Tracking keeps the same face across frames -> more stable probs
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  @override
  Stream<FaceData> get faceDataStream => _controller.stream;

  @override
  Future<void> processImage(dynamic cameraImage) async {
    if (cameraImage is! CameraImage) return;
    if (_isBusy) return; // previous frame still processing — drop this one
    _isBusy = true;

    try {
    // ── Mesh engine (blocking — we need its output) ───────────────────────────
    await _meshEngine.processImage(cameraImage);

    // ── FaceDetector classification (throttled, fire-and-forget) ─────────────
    _classFrameCount++;
    if (_classFrameCount >= _classEveryN) {
      _classFrameCount = 0;
      _runClassifier(cameraImage); // intentionally NOT awaited
    }

    // ── Merge & emit ──────────────────────────────────────────────────────────
    final mesh = _latestMesh;
    if (mesh == null) return;

    // TFLite classifier (synchronous, tiny model — fast)
    final irisVX = (mesh.irisX - _prevIrisX).clamp(-0.5, 0.5);
    final irisVY = (mesh.irisY - _prevIrisY).clamp(-0.5, 0.5);
    _prevIrisX = mesh.irisX;
    _prevIrisY = mesh.irisY;

    final feature = FeatureVector(
      eyeOpenProbLeft:  _eyeOpenProbLeft,
      eyeOpenProbRight: _eyeOpenProbRight,
      gazeX:  mesh.gazeX,
      gazeY:  mesh.gazeY,
      irisVX: irisVX,
      irisVY: irisVY,
    );

    recorder.addFrame(feature);

    final classifierEvent = _gestureClassifier.classify(feature);

    double emitL = _eyeOpenProbLeft;
    double emitR = _eyeOpenProbRight;

    if (classifierEvent != null) {
      switch (classifierEvent) {
        case GestureEvent.B:
        case GestureEvent.S:
          emitL = 0.01; emitR = 0.01;
        case GestureEvent.WL:
          emitL = 0.01; emitR = 0.90;
        case GestureEvent.WR:
          emitL = 0.90; emitR = 0.01;
        default: break;
      }
    }

    _controller.add(FaceData(
      leftEAR:         mesh.leftEAR,
      rightEAR:        mesh.rightEAR,
      gazeX:           mesh.gazeX,
      gazeY:           mesh.gazeY,
      irisX:           mesh.irisX,
      irisY:           mesh.irisY,
      faceDetected:    mesh.faceDetected,
      timestamp:       mesh.timestamp,
      leftEyeContour:  mesh.leftEyeContour,
      rightEyeContour: mesh.rightEyeContour,
      faceRect:        mesh.faceRect,
      imageSize:       mesh.imageSize,
      leftPupil:       mesh.leftPupil,
      rightPupil:      mesh.rightPupil,
      eyeOpenProbLeft:  emitL,
      eyeOpenProbRight: emitR,
    ));
    } finally {
      _isBusy = false;
    }
  }

  /// Runs the FaceDetector classification engine and updates [_eyeOpenProb*].
  Future<void> _runClassifier(CameraImage image) async {
    final inputImage = _buildInputImage(image);
    if (inputImage == null) return;

    try {
      final faces = await _classEngine.processImage(inputImage);
      if (faces.isEmpty) return;

      final face = faces.first;
      // ML Kit returns null if it could not determine the value.
      // Fall back to previous frame's value (carry-forward).
      final lp = face.leftEyeOpenProbability;
      final rp = face.rightEyeOpenProbability;
      if (lp != null) _eyeOpenProbLeft  = lp;
      if (rp != null) _eyeOpenProbRight = rp;
    } catch (_) {
      // Keep previous values on error — don't crash the detection loop
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    try {
      // NV21: first plane is full Y, second is interleaved UV.
      // Pass only the first plane bytes — avoids a large per-frame allocation
      // while still giving the FaceDetector the luma data it needs.
      final yPlane = image.planes.first;
      return InputImage.fromBytes(
        bytes: yPlane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
          bytesPerRow: yPlane.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Calibration delegation ─────────────────────────────────────────────────
  @override
  void resetCalibration() {
    _meshEngine.resetCalibration();
    _gestureClassifier.reset();
    _eyeOpenProbLeft  = 1.0;
    _eyeOpenProbRight = 1.0;
    _prevIrisX = 0.0;
    _prevIrisY = 0.0;
  }

  // Proxy calibration getters to the underlying mesh engine
  bool   get isCalibrated      => _meshEngine.isCalibrated;
  double get adaptiveThreshold => _meshEngine.adaptiveThreshold;

  @override
  Future<void> dispose() async {
    await _meshSub?.cancel();
    await _meshEngine.dispose();
    _gestureClassifier.dispose();
    await _classEngine.close();
    await _controller.close();
  }
}
