import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'face_detector_interface.dart';

/// Fallback detector using Google ML Kit Face Detection.
class MlKitDetector implements FaceDetectorInterface {
  late FaceDetector _detector;
  final _controller = StreamController<FaceData>.broadcast();
  bool _isProcessing = false;

  @override
  String get engineName => 'ML Kit (fallback)';

  @override
  Future<void> initialize() async {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: false,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  @override
  Stream<FaceData> get faceDataStream => _controller.stream;

  @override
  Future<void> processImage(dynamic cameraImage) async {
    if (_isProcessing || cameraImage is! CameraImage) return;
    _isProcessing = true;
    try {
      final inputImage = _buildInputImage(cameraImage);
      if (inputImage == null) return;

      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) {
        _controller.add(FaceData.empty());
        return;
      }

      final face = faces.first;
      final leftOpen  = face.leftEyeOpenProbability  ?? 0.5;
      final rightOpen = face.rightEyeOpenProbability ?? 0.5;
      final leftEAR  = 0.15 + leftOpen  * 0.23;
      final rightEAR = 0.15 + rightOpen * 0.23;

      final eulerY = (face.headEulerAngleY ?? 0.0).clamp(-30.0, 30.0);
      final eulerX = (face.headEulerAngleX ?? 0.0).clamp(-20.0, 20.0);
      final gazeX = eulerY / 30.0;
      final gazeY = -eulerX / 20.0;

      _controller.add(FaceData(
        leftEAR: leftEAR,
        rightEAR: rightEAR,
        gazeX: gazeX,
        gazeY: gazeY,
        irisX: 0.0,
        irisY: 0.0,
        faceDetected: true,
        timestamp: DateTime.now(),
      ));
    } catch (_) {
    } finally {
      _isProcessing = false;
    }
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
    // No-op for ML Kit fallback as it doesn't currently use adaptive baseline
  }

  @override
  Future<void> dispose() async {
    await _detector.close();
    await _controller.close();
  }
}
