import 'dart:async';
import '../detection/face_detector_interface.dart';
import 'gesture_event.dart';
import 'roll_detector.dart';

/// Thresholds (all configurable via settings)
class DetectionThresholds {
  /// EAR below this = eye closed
  final double earThreshold;
  /// Minimum ms eye must be closed to count as a Shut (S) vs Blink (B)
  final int shutMinMs;
  /// Maximum ms for a Blink — longer = Shut
  final int blinkMaxMs;
  /// Gaze axis must exceed this to register L/R/U/D
  final double gazeThreshold;
  /// How many rapid blinks in furiousBlink window = Emergency / Clear
  final int furiousBlinkCount;
  final int furiousBlinkWindowMs;

  const DetectionThresholds({
    this.earThreshold       = 0.25,
    this.shutMinMs          = 1200,
    this.blinkMaxMs         = 1000,
    this.gazeThreshold      = 0.30,
    this.furiousBlinkCount  = 5,
    this.furiousBlinkWindowMs = 2000,
  });
}

enum _EyeState { open, closing, closed }
enum _MachineState { waitingForStart, recording }

/// Core gesture state machine.
///
/// Flow:
///   WAITING → Long Shut (S > 1.5s) → RECORDING
///   RECORDING → buffers gestures for 3s after last gesture → resolves
///   RECORDING → Furious blink (5+ blinks in 2s) → clears buffer
///   Furious wink → emits EMERGENCY immediately
class GestureStateMachine {
  final DetectionThresholds thresholds;
  final RollDetector rollDetector = RollDetector();

  GestureStateMachine({this.thresholds = const DetectionThresholds()});

  // ---- Streams ----
  final _gestureController   = StreamController<GestureEvent>.broadcast();
  final _bufferController    = StreamController<List<GestureEvent>>.broadcast();
  final _stateController     = StreamController<_MachineState>.broadcast();

  Stream<GestureEvent>       get gestureStream => _gestureController.stream;
  Stream<List<GestureEvent>> get bufferStream  => _bufferController.stream;
  Stream<_MachineState>      get stateStream   => _stateController.stream;

  // ---- Internal state ----
  _MachineState _state = _MachineState.waitingForStart;
  final List<GestureEvent> _buffer = [];

  // Eye closure tracking
  _EyeState _leftState  = _EyeState.open;
  _EyeState _rightState = _EyeState.open;
  DateTime? _leftClosedAt;
  DateTime? _rightClosedAt;

  // Gaze direction tracking
  bool _isGazeNeutral = true;
  DateTime? _lastGazeEvent;
  static const _gazeDebounceMs = 600;

  // Dynamic baseline for gaze
  double _baselineGazeX = 0.0;
  double _baselineGazeY = 0.0;

  double get baselineGazeX => _baselineGazeX;
  double get baselineGazeY => _baselineGazeY;

  // Furious blink tracking (emergency & clear)
  final List<DateTime> _recentBlinks = [];

  // Session resolve timer
  Timer? _resolveTimer;
  static const _resolveWindowMs = 4500;

  // Wink tracking for emergency
  final List<DateTime> _recentWinks = [];

  bool get isRecording => _state == _MachineState.recording;

  /// Feed each FaceData frame into the state machine.
  void process(FaceData data) {
    if (!data.faceDetected) return;

    rollDetector.addSample(data.irisX, data.irisY);

    final now = DateTime.now();
    final bothClosed = data.leftEAR < thresholds.earThreshold &&
                       data.rightEAR < thresholds.earThreshold;
    final onlyLeftClosed  = data.leftEAR  < thresholds.earThreshold &&
                            data.rightEAR > thresholds.earThreshold + 0.05;
    final onlyRightClosed = data.rightEAR < thresholds.earThreshold &&
                            data.leftEAR  > thresholds.earThreshold + 0.05;

    // We no longer wait for a "long shut" to start. We are always recording.
    // If not recording, force it.
    if (_state != _MachineState.recording) {
      _setState(_MachineState.recording);
    }

    if (bothClosed) {
      if (_leftState != _EyeState.closed || _rightState != _EyeState.closed) {
        _leftState = _EyeState.closed;
        _rightState = _EyeState.closed;
        _leftClosedAt = now;
        _rightClosedAt = now;
      }
    } else if (onlyLeftClosed) {
      if (_leftState != _EyeState.closed) {
        _leftState = _EyeState.closed;
        _leftClosedAt = now;
      }
      _rightState = _EyeState.open;
      _rightClosedAt = null;
    } else if (onlyRightClosed) {
      if (_rightState != _EyeState.closed) {
        _rightState = _EyeState.closed;
        _rightClosedAt = now;
      }
      _leftState = _EyeState.open;
      _leftClosedAt = null;
    } else {
      // Eyes are open, check if they WERE closed to trigger events
      if (_leftState == _EyeState.closed && _rightState == _EyeState.closed) {
        // Both were closed -> Blink or Shut
        final closedAt = _leftClosedAt ?? _rightClosedAt ?? now;
        final ms = now.difference(closedAt).inMilliseconds;
        if (ms <= thresholds.blinkMaxMs) {
          _onBlink();
        } else if (ms >= thresholds.shutMinMs) {
          _onShut();
        }
      } else if (_leftState == _EyeState.closed) {
        // Only left was closed -> Left Wink
        final closedAt = _leftClosedAt ?? now;
        final ms = now.difference(closedAt).inMilliseconds;
        if (ms <= thresholds.blinkMaxMs) {
          _onWink(isLeft: true);
        }
      } else if (_rightState == _EyeState.closed) {
        // Only right was closed -> Right Wink
        final closedAt = _rightClosedAt ?? now;
        final ms = now.difference(closedAt).inMilliseconds;
        if (ms <= thresholds.blinkMaxMs) {
          _onWink(isLeft: false);
        }
      }

      // Reset states
      _leftState = _EyeState.open;
      _rightState = _EyeState.open;
      _leftClosedAt = null;
      _rightClosedAt = null;
    }

    // ---- Gaze direction (requires return to neutral) ----
    if (_state == _MachineState.recording) {
      final relGazeX = data.gazeX - _baselineGazeX;
      final relGazeY = data.gazeY - _baselineGazeY;

      // Neutral zone is half the threshold
      if (relGazeX.abs() < thresholds.gazeThreshold * 0.5 && 
          relGazeY.abs() < thresholds.gazeThreshold * 0.5) {
        _isGazeNeutral = true;
      }

      if (_isGazeNeutral) {
        final lastGaze = _lastGazeEvent;
        final elapsed = lastGaze == null ? 9999 : now.difference(lastGaze).inMilliseconds;
        
        if (elapsed > _gazeDebounceMs) {
          if (relGazeX < -thresholds.gazeThreshold) {
            _addToBuffer(GestureEvent.L); 
            _lastGazeEvent = now;
            _isGazeNeutral = false;
          } else if (relGazeX > thresholds.gazeThreshold) {
            _addToBuffer(GestureEvent.R); 
            _lastGazeEvent = now;
            _isGazeNeutral = false;
          } else if (relGazeY < -thresholds.gazeThreshold) {
            _addToBuffer(GestureEvent.U); 
            _lastGazeEvent = now;
            _isGazeNeutral = false;
          } else if (relGazeY > thresholds.gazeThreshold) {
            _addToBuffer(GestureEvent.D); 
            _lastGazeEvent = now;
            _isGazeNeutral = false;
          }
        }
      }
    }
  }

  void _onBlink() {
    final now = DateTime.now();
    _recentBlinks.add(now);
    _recentBlinks.removeWhere(
      (t) => now.difference(t).inMilliseconds > thresholds.furiousBlinkWindowMs,
    );
    if (_recentBlinks.length >= thresholds.furiousBlinkCount) {
      // Furious blink → clear / go back
      _recentBlinks.clear();
      _buffer.clear();
      _resolveTimer?.cancel();
      _bufferController.add([]);
      return;
    }

    _addToBuffer(GestureEvent.B);
  }

  void _onShut() {
    _addToBuffer(GestureEvent.S);
  }

  void _onWink({required bool isLeft}) {
    // Emergency check: furious winks
    final now = DateTime.now();
    _recentWinks.add(now);
    _recentWinks.removeWhere((t) => now.difference(t).inMilliseconds > thresholds.furiousBlinkWindowMs);
    if (_recentWinks.length >= thresholds.furiousBlinkCount) {
      _recentWinks.clear();
      _emitGesture(GestureEvent.EMERGENCY);
      return;
    }
    if (_state != _MachineState.recording) return;
    _addToBuffer(isLeft ? GestureEvent.WL : GestureEvent.WR);
  }

  void _addToBuffer(GestureEvent event) {
    _buffer.add(event);
    _bufferController.add(List.unmodifiable(_buffer));
    _resetResolveTimer();
  }

  void _emitGesture(GestureEvent event) {
    _gestureController.add(event);
  }

  void _resetResolveTimer() {
    _resolveTimer?.cancel();
    _resolveTimer = Timer(const Duration(milliseconds: _resolveWindowMs), _resolveBuffer);
  }

  void _resolveBuffer() {
    if (_buffer.isEmpty) return;
    final sequence = List<GestureEvent>.unmodifiable(_buffer);
    _buffer.clear();
    _bufferController.add([]);
    // Emit each event in sequence for the engine to resolve
    for (final e in sequence) {
      _gestureController.add(e);
    }
    // Signal end of sequence with a special sentinel by emitting the list
    // via a dedicated resolved-sequence stream
    _resolvedController.add(sequence);
    _setState(_MachineState.waitingForStart);
  }

  /// Manually wipe the current buffer.
  void resetBuffer() {
    _buffer.clear();
    _bufferController.add([]);
    _resolveTimer?.cancel();
  }

  /// Manually wipe the buffer and return to waiting state.
  void resetToWaiting() {
    resetBuffer();
    _setState(_MachineState.waitingForStart);
  }

  final _resolvedController = StreamController<List<GestureEvent>>.broadcast();
  /// Stream of fully-resolved gesture sequences ready for GestureEngine lookup.
  Stream<List<GestureEvent>> get resolvedSequenceStream => _resolvedController.stream;

  void _setState(_MachineState s) {
    _state = s;
    _stateController.add(s);
  }

  void onRollDetected() {
    if (_state != _MachineState.recording) return;
    _addToBuffer(GestureEvent.O);
  }

  void dispose() {
    _gestureController.close();
    _bufferController.close();
    _stateController.close();
    _resolvedController.close();
    rollDetector.dispose();
    _resolveTimer?.cancel();
  }
}

typedef VoidCallback = void Function();
