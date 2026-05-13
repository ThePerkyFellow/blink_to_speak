import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'gesture_classifier.dart';

/// Records raw feature vectors and exports labeled JSON data for offline
/// TFLite model fine-tuning.
class GestureRecorder {
  final List<Map<String, dynamic>> _examples = [];
  final List<FeatureVector> _frameBuffer = [];
  bool isRecording = false;

  void addFrame(FeatureVector v) {
    if (!isRecording) return;
    _frameBuffer.add(v);
    // Keep max 500 frames (~30 seconds) in sliding buffer to prevent memory bloat
    if (_frameBuffer.length > 500) {
      _frameBuffer.removeAt(0);
    }
  }

  /// Extracts the last [n] frames from the buffer and saves them as a labeled
  /// training example. Call this immediately after a gesture is confirmed.
  void labelLastN(String label, {int n = GestureClassifier.windowSize}) {
    if (!isRecording) return;
    if (_frameBuffer.length < n) return;

    final window = _frameBuffer.sublist(_frameBuffer.length - n);
    _examples.add({
      'label': label,
      'timestamp': DateTime.now().toIso8601String(),
      'frames': window.map((v) => v.toJson()).toList(),
    });
  }

  void clear() {
    _examples.clear();
    _frameBuffer.clear();
  }

  Future<String?> saveToStorage() async {
    if (_examples.isEmpty) return null;

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return null;

      final recordDir = Directory('${extDir.path}/blink_recordings');
      if (!await recordDir.exists()) {
        await recordDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${recordDir.path}/session_$timestamp.json');

      final data = {
        'session_time': DateTime.now().toIso8601String(),
        'examples': _examples,
      };

      await file.writeAsString(jsonEncode(data));
      clear();
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
