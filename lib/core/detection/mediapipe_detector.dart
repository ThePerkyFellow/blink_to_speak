import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;
import 'dart:math';
import 'dart:collection';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'face_detector_interface.dart';

/// Face Mesh Detector (468 points)
///
/// Uses Google ML Kit's Face Mesh API which provides 468 dense 3D points.
/// This acts as our "MediaPipe" implementation, providing extremely accurate
/// eye contours, enabling us to calculate EAR and true eye centroid (iris approximation)
/// without the Dart SDK version conflicts of the native mediapipe packages.
class MediaPipeDetector implements FaceDetectorInterface {
  late FaceMeshDetector _detector;
  final _controller = StreamController<FaceData>.broadcast();
  bool _isProcessing = false;

  // ── Temporal smoothing ──────────────────────────────────────────────────
  final _leftEarQueue  = Queue<double>();
  final _rightEarQueue = Queue<double>();
  static const _earSmoothFrames = 5;

  final _gazeXQueue = Queue<double>();
  final _gazeYQueue = Queue<double>();
  static const _gazeSmoothFrames = 8;

  int _leftConsecBelow  = 0;
  int _rightConsecBelow = 0;
  static const _consecRequired = 3;

  // ── Adaptive EAR baseline calibration ──────────────────────────────────
  final _calibLeft  = <double>[];
  final _calibRight = <double>[];
  static const _calibFrames = 60;
  bool _calibrated = false;
  double _adaptiveThreshold = 0.22;

  bool   get isCalibrated      => _calibrated;
  double get adaptiveThreshold => _adaptiveThreshold;

  // ── Gaze baseline ──────────────────────────────────────────────────────
  double _gazeCentroidBaseX = 0.5;
  double _gazeCentroidBaseY = 0.5;
  bool _gazeBaselineReady = false;

  @override
  String get engineName => 'MLKit FaceMesh (468 pts)';

  Offset _lastLeftPupil = Offset.zero;
  Offset _lastRightPupil = Offset.zero;

  @override
  Future<void> initialize() async {
    _detector = FaceMeshDetector(
      option: FaceMeshDetectorOptions.faceMesh,
    );
  }

  @override
  Stream<FaceData> get faceDataStream => _controller.stream;

  @override
  Future<void> processImage(dynamic cameraImage) async {
    if (_isProcessing || cameraImage is! CameraImage) return;
    _isProcessing = true;
    try {
      final imgW = cameraImage.width.toDouble();
      final imgH = cameraImage.height.toDouble();
      final inputImage = _buildInputImage(cameraImage);
      if (inputImage == null) return;

      final meshes = await _detector.processImage(inputImage);
      if (meshes.isEmpty) {
        _controller.add(FaceData.empty());
        return;
      }

      final mesh = meshes.first;
      final pts = mesh.points;
      
      // Face Mesh has 468 points. If it doesn't, abort frame.
      if (pts.length < 468) {
        _controller.add(FaceData.empty());
        return;
      }

      // ── Left Eye (User's Left) ──
      // Corners: 33 (inner/medial), 133 (outer/lateral)
      // Top: 160, 158
      // Bottom: 144, 153
      final rawLeft = _earFromMesh(pts, 33, 133, 160, 158, 144, 153);
      
      // ── Right Eye (User's Right) ──
      // Corners: 362 (inner/medial), 263 (outer/lateral)
      // Top: 384, 387
      // Bottom: 380, 373
      final rawRight = _earFromMesh(pts, 362, 263, 384, 387, 380, 373);

      // ── Calibration ──────────────────────────────────────────────────────
      if (!_calibrated) {
        if (rawLeft > 0.20)  _calibLeft.add(rawLeft);
        if (rawRight > 0.20) _calibRight.add(rawRight);
        if (_calibLeft.length >= _calibFrames && _calibRight.length >= _calibFrames) {
          final meanL = _calibLeft.reduce((a, b) => a + b) / _calibLeft.length;
          final meanR = _calibRight.reduce((a, b) => a + b) / _calibRight.length;
          _adaptiveThreshold = ((meanL + meanR) / 2.0) * 0.72;
          _calibrated = true;
        }
      }

      // ── Smoothing + gating ───────────────────────────────────────────────
      final smoothLeft  = _smooth(_leftEarQueue,  rawLeft);
      final smoothRight = _smooth(_rightEarQueue, rawRight);
      final gatedLeft   = _gateEar(smoothLeft,  isLeft: true);
      final gatedRight  = _gateEar(smoothRight, isLeft: false);

      // ── Extract contours for HUD ─────────────────────────────────────────
      final logW = imgH; 
      final logH = imgW; 

      // Outline points for the eyes (approximate loops for Face Mesh)
      final leftContourIndices = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246];
      final rightContourIndices = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398];
      
      final leftContour  = leftContourIndices.map((i) => Offset(pts[i].x, pts[i].y)).toList();
      final rightContour = rightContourIndices.map((i) => Offset(pts[i].x, pts[i].y)).toList();
      
      final bbox = mesh.boundingBox;
      final faceRect = Rect.fromLTWH(
        bbox.left.toDouble(),
        bbox.top.toDouble(),
        bbox.width.toDouble(),
        bbox.height.toDouble(),
      );

      // ── Iris Detection via Computer Vision (Darkest Pixel in Y-Plane) ──────
      double gazeX = 0.0;
      double gazeY = 0.0;
      double irisX = 0.0;
      double irisY = 0.0;

      final safeLeftEar = _adaptiveThreshold * 0.85;
      final safeRightEar = _adaptiveThreshold * 0.85;

      if (gatedLeft > safeLeftEar) {
        _lastLeftPupil = _findPupilInSensor(cameraImage, leftContour);
      }
      if (gatedRight > safeRightEar) {
        _lastRightPupil = _findPupilInSensor(cameraImage, rightContour);
      }

      final leftPupil = _lastLeftPupil;
      final rightPupil = _lastRightPupil;

      // We still want irisX and irisY for the trajectory roll
      final midX = (leftPupil.dx + rightPupil.dx) / 2.0;
      final midY = (leftPupil.dy + rightPupil.dy) / 2.0;
      irisX = midX;
      irisY = midY;

      // To calculate gaze, compare pupil to eye contour centroid
      final lc = _centroid(leftContour);
      final rc = _centroid(rightContour);

      // Eye dimensions (roughly)
      // indices: 0 is inner corner, 8 is outer corner. 5 is bottom, 13 is top.
      final eyeWidth = (leftContour[8].dx - leftContour[0].dx).abs(); 
      final eyeHeight = (leftContour[13].dy - leftContour[5].dy).abs(); 

      // Normalized pupil offset within the eye bounding box (approx [-0.5, 0.5])
      final normX = ((leftPupil.dx - lc.dx) + (rightPupil.dx - rc.dx)) / 2.0 / eyeWidth.clamp(1.0, double.infinity);
      final normY = ((leftPupil.dy - lc.dy) + (rightPupil.dy - rc.dy)) / 2.0 / eyeHeight.clamp(1.0, double.infinity);

      // Sync gaze baseline calibration with the EAR calibration phase
      // This ensures the baseline is built during the 3-second 'Calibrating' banner
      // when the user is explicitly looking at the screen.
      if (!_calibrated) {
        _gazeCentroidBaseX = (_gazeCentroidBaseX * 0.85) + (normX * 0.15);
        _gazeCentroidBaseY = (_gazeCentroidBaseY * 0.85) + (normY * 0.15);
      } else {
        _gazeBaselineReady = true;
      }

      if (_gazeBaselineReady) {
        // Front camera is mirrored: negate X so looking left goes left on screen
        // Sensitivity scalar: pupil generally moves maybe 20-30% of eye width
        final rawGazeX = -((normX - _gazeCentroidBaseX) / 0.18).clamp(-1.0, 1.0);
        final rawGazeY =  ((normY - _gazeCentroidBaseY) / 0.18).clamp(-1.0, 1.0);

        gazeX = _smoothGaze(_gazeXQueue, rawGazeX);
        gazeY = _smoothGaze(_gazeYQueue, rawGazeY);
      }

      _controller.add(FaceData(
        leftEAR:      gatedLeft,
        rightEAR:     gatedRight,
        gazeX:        gazeX,
        gazeY:        gazeY,
        irisX:        irisX,
        irisY:        irisY,
        faceDetected: true,
        timestamp:    DateTime.now(),
        leftEyeContour:  leftContour,
        rightEyeContour: rightContour,
        faceRect:        faceRect,
        imageSize:       Size(logW, logH),
        leftPupil:       leftPupil,
        rightPupil:      rightPupil,
      ));
    } catch (_) {
    } finally {
      _isProcessing = false;
    }
  }

  double _earFromMesh(List<FaceMeshPoint> pts, int p1, int p4, int p2, int p3, int p6, int p5) {
    // Note: p1=inner, p4=outer. p2,p3=top. p6,p5=bottom.
    final A = _dist(pts[p2], pts[p6]);
    final B = _dist(pts[p3], pts[p5]);
    final C = _dist(pts[p1], pts[p4]);
    if (C < 1.0) return 0.0;
    return (A + B) / (2.0 * C);
  }

  Offset _centroid(List<Offset> pts) {
    if (pts.isEmpty) return Offset.zero;
    double sx = 0, sy = 0;
    for (final p in pts) { sx += p.dx; sy += p.dy; }
    return Offset(sx / pts.length, sy / pts.length);
  }

  double _smooth(Queue<double> queue, double newValue) {
    queue.addLast(newValue);
    if (queue.length > _earSmoothFrames) queue.removeFirst();
    double weightedSum = 0.0, weightSum = 0.0, weight = 1.0;
    for (final v in queue.toList().reversed) {
      weightedSum += v * weight;
      weightSum   += weight;
      weight      *= 0.75;
    }
    return weightedSum / weightSum;
  }

  double _smoothGaze(Queue<double> queue, double newValue) {
    queue.addLast(newValue);
    if (queue.length > _gazeSmoothFrames) queue.removeFirst();
    double sum = 0.0;
    for (final v in queue) {
      sum += v;
    }
    return sum / queue.length; // simple rolling average for gaze is more stable
  }

  double _gateEar(double smoothedEar, {required bool isLeft}) {
    if (smoothedEar < _adaptiveThreshold) {
      if (isLeft) {
        _leftConsecBelow++;
        return _leftConsecBelow >= _consecRequired ? 0.10 : smoothedEar;
      } else {
        _rightConsecBelow++;
        return _rightConsecBelow >= _consecRequired ? 0.10 : smoothedEar;
      }
    } else {
      if (isLeft) { _leftConsecBelow = 0; }
      else { _rightConsecBelow = 0; }
      return smoothedEar;
    }
  }

  double _dist(FaceMeshPoint a, FaceMeshPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  InputImage? _buildInputImage(CameraImage image) {
    try {
      final allBytes = <int>[];
      for (final plane in image.planes) {
        allBytes.addAll(plane.bytes);
      }
      return InputImage.fromBytes(
        bytes: Uint8List.fromList(allBytes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void resetCalibration() {
    _calibrated = false;
    _calibLeft.clear();
    _calibRight.clear();
    _gazeBaselineReady = false;
    _gazeCentroidBaseX = 0.5;
    _gazeCentroidBaseY = 0.5;
    _leftEarQueue.clear();
    _rightEarQueue.clear();
    _gazeXQueue.clear();
    _gazeYQueue.clear();
  }

  @override
  Future<void> dispose() async {
    await _detector.close();
    await _controller.close();
  }

  // ── True Iris tracking via Darkest Pixel ───────────────────────────────
  Offset _findPupilInSensor(CameraImage image, List<Offset> meshContour) {
    if (meshContour.isEmpty || image.planes.isEmpty) return Offset.zero;

    final w = image.width;
    final h = image.height;
    final yPlane = image.planes[0].bytes;
    final rowStride = image.planes[0].bytesPerRow;

    int minX = w, maxX = 0, minY = h, maxY = 0;

    for (final pt in meshContour) {
      // meshX = pt.dx, meshY = pt.dy
      // Sensor rotation 270: sensorX = w - meshY, sensorY = meshX
      final sx = (w - pt.dy).toInt();
      final sy = pt.dx.toInt();

      if (sx < minX) minX = sx;
      if (sx > maxX) maxX = sx;
      if (sy < minY) minY = sy;
      if (sy > maxY) maxY = sy;
    }

    // small padding
    minX = (minX - 2).clamp(0, w - 1);
    maxX = (maxX + 2).clamp(0, w - 1);
    minY = (minY - 2).clamp(0, h - 1);
    maxY = (maxY + 2).clamp(0, h - 1);

    int minVal = 255;
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final val = yPlane[y * rowStride + x];
        if (val < minVal) minVal = val;
      }
    }

    // center of mass of darkest pixels
    final threshold = minVal + 10;
    double sumX = 0, sumY = 0;
    int count = 0;

    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        if (yPlane[y * rowStride + x] <= threshold) {
          sumX += x;
          sumY += y;
          count++;
        }
      }
    }

    final cx = count > 0 ? sumX / count : minX.toDouble();
    final cy = count > 0 ? sumY / count : minY.toDouble();

    // Map sensor back to mesh coordinates
    // meshX = sensorY, meshY = sensorWidth - sensorX
    return Offset(cy, w - cx);
  }
}
