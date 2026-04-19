
import 'dart:ui' show Offset, Rect, Size;

/// Data emitted each camera frame from the detection engine.
class FaceData {
  /// Eye Aspect Ratio for left eye (0 = closed, ~0.35 = normal open)
  final double leftEAR;

  /// Eye Aspect Ratio for right eye
  final double rightEAR;

  /// Normalised horizontal gaze: -1.0 (far left) … 0.0 (centre) … +1.0 (far right)
  final double gazeX;

  /// Normalised vertical gaze: -1.0 (far up) … 0.0 (centre) … +1.0 (far down)
  final double gazeY;

  /// Raw iris X position in frame (pixels) — used for roll trajectory
  final double irisX;

  /// Raw iris Y position in frame (pixels) — used for roll trajectory
  final double irisY;

  /// Whether a face was detected this frame
  final bool faceDetected;

  /// Timestamp of this frame
  final DateTime timestamp;

  // ── Landmark data for HUD drawing ───────────────────────────────────────
  /// Raw pixel coordinates of left eye contour in ML Kit's rotated image space
  final List<Offset> leftEyeContour;
  /// Raw pixel coordinates of right eye contour in ML Kit's rotated image space
  final List<Offset> rightEyeContour;
  /// Face bounding box in ML Kit's rotated image space (pixels)
  final Rect faceRect;
  /// Raw sensor image dimensions — used by painter to normalise coordinates
  final Size imageSize;
  /// Raw pixel coordinates of left pupil in ML Kit's rotated image space
  final Offset leftPupil;
  /// Raw pixel coordinates of right pupil in ML Kit's rotated image space
  final Offset rightPupil;

  const FaceData({
    required this.leftEAR,
    required this.rightEAR,
    required this.gazeX,
    required this.gazeY,
    required this.irisX,
    required this.irisY,
    required this.faceDetected,
    required this.timestamp,
    this.leftEyeContour  = const [],
    this.rightEyeContour = const [],
    this.faceRect        = Rect.zero,
    this.imageSize       = Size.zero,
    this.leftPupil       = Offset.zero,
    this.rightPupil      = Offset.zero,
  });

  factory FaceData.empty() => FaceData(
        leftEAR: 0.35,
        rightEAR: 0.35,
        gazeX: 0.0,
        gazeY: 0.0,
        irisX: 0.0,
        irisY: 0.0,
        faceDetected: false,
        timestamp: DateTime.now(),
      );
}

/// Abstract interface both ML engines implement.
abstract class FaceDetectorInterface {
  /// Initialise the detector (load models, etc.)
  Future<void> initialize();

  /// Stream of face data from each processed frame.
  Stream<FaceData> get faceDataStream;

  /// Process a camera image (called per frame by CameraController listener).
  Future<void> processImage(dynamic cameraImage);

  /// Resets internal calibration baselines (e.g., EAR, Gaze).
  void resetCalibration();

  /// Release resources.
  Future<void> dispose();

  /// Human-readable name for logging / UI badge.
  String get engineName;
}
