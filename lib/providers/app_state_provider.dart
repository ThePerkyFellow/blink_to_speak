import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/detection/face_detector_interface.dart';
import '../core/detection/combined_detector.dart';
import '../core/detection/mediapipe_detector.dart';
import '../core/detection/mlkit_detector.dart';
import '../core/detection/gesture_recorder.dart';
import '../core/gesture/gesture_state_machine.dart';
import '../core/gesture/gesture_engine.dart';
import '../core/gesture/gesture_event.dart';


import '../core/tts/tts_service.dart';
import '../models/blink_command.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  // ---- Camera ----
  CameraController? cameraController;
  bool cameraReady = false;

  // ---- Detection ----
  FaceDetectorInterface? _detector;
  late GestureStateMachine _stateMachine;
  late GestureEngine _engine;
  late TtsService ttsService;

  // ---- App state ----
  String activeLocale = 'en-IN';
  String patientName  = 'Patient';
  bool   practiceMode = false;
  bool   isRecording  = false;
  List<GestureEvent> gestureBuffer = [];
  String? lastMessage;
  bool   emergencyActive = false;
  double earThreshold   = 0.25;
  double speechRate     = 0.5;
  // Tracks whether the adaptive EAR threshold has been synced to the state
  // machine for this calibration session.
  bool _thresholdSynced = false;

  // ---- Supported languages ----
  static const supportedLocales = [
    {'code': 'en-IN', 'label': 'English'},
    {'code': 'hi-IN', 'label': 'हिंदी'},
    {'code': 'kn-IN', 'label': 'ಕನ್ನಡ'},
    {'code': 'ta-IN', 'label': 'தமிழ்'},
    {'code': 'mr-IN', 'label': 'मराठी'},
    {'code': 'te-IN', 'label': 'తెలుగు'},
  ];

  Future<void> init() async {
    print('[AppState] Starting init()...');
    await _loadPrefs();
    await _initEngine();
    await _initTts();
    await _initCamera();
    print('[AppState] init() complete.');
    WidgetsBinding.instance.addObserver(this); // lifecycle observer
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    activeLocale = prefs.getString('locale')  ?? 'en-IN';
    patientName  = prefs.getString('patient') ?? 'Patient';
    earThreshold = prefs.getDouble('ear')     ?? 0.25;
    speechRate   = prefs.getDouble('tts_rate') ?? 0.5;
  }

  Future<void> _initEngine() async {
    _engine = GestureEngine();
    await _engine.load();

    _stateMachine = GestureStateMachine(
      thresholds: DetectionThresholds(earThreshold: earThreshold),
    );

    // Listen for resolved sequences
    _stateMachine.resolvedSequenceStream.listen(_onSequenceResolved);

    // Listen for buffer updates
    _stateMachine.bufferStream.listen((buf) {
      gestureBuffer = buf;
      notifyListeners();
    });

    // Listen for state changes (recording on/off)
    _stateMachine.stateStream.listen((s) {
      isRecording = (s.toString().contains('recording'));
      notifyListeners();
    });

    // Wire roll detector → state machine
    _stateMachine.rollDetector.rollStream.listen((_) {
      _stateMachine.onRollDetected();
    });
  }

  Future<void> _initTts() async {
    ttsService = TtsService();
    await ttsService.initialize();
    await ttsService.setLanguage(activeLocale);
    await ttsService.setSpeechRate(speechRate);
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    cameraController = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await cameraController!.initialize();

    // Try CombinedDetector first (blend shapes + face mesh).
    // Falls back to MediaPipeDetector (mesh only) then MlKitDetector.
    try {
      print('[AppState] Initializing CombinedDetector...');
      _detector = CombinedDetector();
      await _detector!.initialize().timeout(const Duration(seconds: 10), onTimeout: () {
        print('[AppState] CombinedDetector initialization timed out!');
        throw Exception('CombinedDetector Init Timeout');
      });
      print('[AppState] CombinedDetector initialized.');
    } catch (e, st) {
      print('[AppState] CombinedDetector failed: $e\n$st');
      try {
        print('[AppState] Falling back to MediaPipeDetector...');
        _detector = MediaPipeDetector();
        await _detector!.initialize();
      } catch (e2) {
        print('[AppState] Falling back to MlKitDetector... $e2');
        _detector = MlKitDetector();
        await _detector!.initialize();
      }
    }

    print('[AppState] Detector initialized successfully.');

    _detector!.faceDataStream.listen((fd) {
      // Once the detector's per-user adaptive calibration completes, push that
      // threshold into the state machine so both layers agree on the same value.
      if (!_thresholdSynced && _detector is MediaPipeDetector) {
        final mp = _detector as MediaPipeDetector;
        if (mp.isCalibrated) {
          _stateMachine.updateEarThreshold(mp.adaptiveThreshold);
          _thresholdSynced = true;
        }
      }
      _stateMachine.process(fd);
    });

    await cameraController!.startImageStream((img) {
      _detector!.processImage(img);
    });

    cameraReady = true;
    notifyListeners();
  }

  // ── App lifecycle — pause/resume camera stream ────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Phone locked or app backgrounded — stop the image stream to free GPU
      if (ctrl.value.isStreamingImages) {
        ctrl.stopImageStream();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App foregrounded again — restart the stream so detection resumes
      _restartImageStream();
    }
  }

  void _restartImageStream() {
    final ctrl = cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isStreamingImages) return; // already running
    try {
      ctrl.startImageStream((img) {
        _detector?.processImage(img);
      });
    } catch (_) {}
  }

  void _onSequenceResolved(List<GestureEvent> sequence) {
    // Check for emergency first
    if (sequence.contains(GestureEvent.EMERGENCY)) {
      emergencyActive = true;
      lastMessage = 'EMERGENCY';
      notifyListeners();
      ttsService.speak('Emergency! Help needed!');
      return;
    }

    final shortLocale = activeLocale.split('-').first; // "en-IN" → "en"
    final msg = _engine.resolve(sequence, shortLocale);
    if (msg != null) {
      lastMessage = msg;
      notifyListeners();
      if (!practiceMode) ttsService.speak(msg);
    }
  }

  void dismissEmergency() {
    emergencyActive = false;
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    activeLocale = locale;
    await ttsService.setLanguage(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
    notifyListeners();
  }

  Future<void> setPatientName(String name) async {
    patientName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('patient', name);
    notifyListeners();
  }

  Future<void> setEarThreshold(double v) async {
    earThreshold = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ear', v);
    // Rebuild state machine with new threshold
    _stateMachine.dispose();
    await _initEngine();
    notifyListeners();
  }

  Future<void> setSpeechRate(double v) async {
    speechRate = v;
    await ttsService.setSpeechRate(v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_rate', v);
    notifyListeners();
  }

  List<BlinkCommand> get allCommands => _engine.allCommands;

  Stream<FaceData>? get faceDataStream => _detector?.faceDataStream;
  double get baselineGazeX => _stateMachine.baselineGazeX;
  double get baselineGazeY => _stateMachine.baselineGazeY;
  double get gazeThreshold => _stateMachine.thresholds.gazeThreshold;

  bool get isEarCalibrated =>
      (_detector is CombinedDetector)
          ? (_detector as CombinedDetector).isCalibrated
          : (_detector is MediaPipeDetector)
              ? (_detector as MediaPipeDetector).isCalibrated
              : true;

  double get adaptiveEarThreshold =>
      (_detector is CombinedDetector)
          ? (_detector as CombinedDetector).adaptiveThreshold
          : (_detector is MediaPipeDetector)
              ? (_detector as MediaPipeDetector).adaptiveThreshold
              : earThreshold;

  // ── Gesture Recording (Data Collection) ────────────────────────────────────
  GestureRecorder? get gestureRecorder => (_detector is CombinedDetector)
      ? (_detector as CombinedDetector).recorder
      : null;

  Future<void> saveCommand(BlinkCommand cmd) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('user_commands') ?? [];
    final updated = stored.where((s) {
      final m = json.decode(s) as Map<String, dynamic>;
      return m['id'] != cmd.id;
    }).toList();
    updated.add(json.encode(cmd.toJson()));
    await prefs.setStringList('user_commands', updated);
    await _reloadEngine();
  }

  Future<void> _reloadEngine() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('user_commands') ?? [];
    final overrides = stored
        .map((s) => BlinkCommand.fromJson(json.decode(s) as Map<String, dynamic>))
        .toList();
    await _engine.load(userOverrides: overrides);
    notifyListeners();
  }

  void resetGestureBuffer() {
    _stateMachine.resetBuffer();
  }

  void resetCalibration() {
    _thresholdSynced = false;
    _detector?.resetCalibration();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController?.dispose();
    _detector?.dispose();
    _stateMachine.dispose();
    ttsService.dispose();
    super.dispose();
  }
}
