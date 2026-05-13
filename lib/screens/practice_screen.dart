import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../providers/app_state_provider.dart';
import '../models/blink_command.dart';
import '../core/gesture/gesture_event.dart';
import '../core/detection/face_detector_interface.dart';
import 'interpret_screen.dart' show HudOverlayPainter;

// ── Encouraging messages ─────────────────────────────────────────────────────
const _successMessages = [
  'Excellent! 🌟', 'Perfect! Keep going!', 'You nailed it! 💪',
  'Outstanding! 🎯', 'Brilliant! 🌈', 'That\'s the way! ✨',
  'Superb! You\'re getting stronger!', 'Amazing control! 🏆',
];
const _encourageMessages = [
  'Don\'t worry, try again!', 'So close! Give it another go 💙',
  'You\'re learning — keep at it!', 'Every try makes you stronger 💪',
  'Almost there — try once more!', 'That\'s okay, breathe and retry 🌿',
];

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with TickerProviderStateMixin {
  int _currentIndex  = 0;
  int _streak        = 0;
  int _lives         = 5;
  int _totalCorrect  = 0;
  int _totalAttempts = 0;

  List<BlinkCommand> _practiceCommands = [];
  bool _showSuccess = false;
  bool _showError   = false;
  String _feedbackMsg = '';

  // Data collection mode
  bool _isRecording = false;

  // Animations
  late AnimationController _feedbackController;
  late AnimationController _pulseController;
  late Animation<double>   _feedbackScale;
  late Animation<double>   _pulseAnim;

  final _rng = Random();

  @override
  void initState() {
    super.initState();

    _feedbackController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _feedbackScale = CurvedAnimation(
      parent: _feedbackController, curve: Curves.elasticOut,
    );

    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.practiceMode = true;
      state.resetCalibration();
      state.resetGestureBuffer();
      setState(() {
        _practiceCommands = state.allCommands
            .where((c) => c.sequence.isNotEmpty && c.id != 'emg')
            .toList();
        _practiceCommands.shuffle();
      });
    });
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _pulseController.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = context.read<AppState>();
        state.practiceMode = false;
        state.resetGestureBuffer();
      }
    });
    super.dispose();
  }

  void _skip() {
    if (_practiceCommands.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _practiceCommands.length;
      _showSuccess  = false;
      _showError    = false;
    });
    context.read<AppState>().resetGestureBuffer();
  }

  void _onBufferUpdate(List<GestureEvent> currentBuffer) {
    if (_practiceCommands.isEmpty || _showSuccess || _showError) return;
    if (currentBuffer.isEmpty) return;

    final target = _practiceCommands[_currentIndex].sequence;

    bool isValidPrefix = true;
    for (int i = 0; i < currentBuffer.length; i++) {
      if (i >= target.length || currentBuffer[i] != target[i]) {
        isValidPrefix = false;
        break;
      }
    }

    if (!isValidPrefix) {
      _totalAttempts++;
      final msg = _encourageMessages[_rng.nextInt(_encourageMessages.length)];
      setState(() {
        _showError    = true;
        _feedbackMsg  = msg;
        _streak       = 0;
        _lives        = (_lives - 1).clamp(0, 5);
      });
      _feedbackController.forward(from: 0);
      context.read<AppState>().resetGestureBuffer();
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showError = false);
      });
    } else {
      // ── Data Collection: Valid prefix means they correctly executed the gesture ──
      if (_isRecording) {
        final lastGesture = currentBuffer.last;
        String? cls;
        switch (lastGesture) {
          case GestureEvent.B:  cls = 'blink'; break;
          case GestureEvent.S:  cls = 'shut'; break;
          case GestureEvent.WL: cls = 'wink_L'; break;
          case GestureEvent.WR: cls = 'wink_R'; break;
          default: break;
        }
        if (cls != null) {
          context.read<AppState>().gestureRecorder?.labelLastN(cls);
        }
      }

      if (currentBuffer.length == target.length) {
        _totalAttempts++;
        _totalCorrect++;
        final msg = _successMessages[_rng.nextInt(_successMessages.length)];
        setState(() {
        _showSuccess = true;
        _feedbackMsg = msg;
        _streak++;
      });
      _feedbackController.forward(from: 0);
      context.read<AppState>().resetGestureBuffer();
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) _skip();
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onBufferUpdate(state.gestureBuffer);
    });

    if (_practiceCommands.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final targetCmd     = _practiceCommands[_currentIndex];
    final currentBuffer = state.gestureBuffer;
    final locale        = state.activeLocale.split('-').first;
    final accuracy      = _totalAttempts == 0
        ? 100
        : ((_totalCorrect / _totalAttempts) * 100).round();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: GestureDetector(
          onLongPress: () {
            setState(() {
              _isRecording = !_isRecording;
              state.gestureRecorder?.isRecording = _isRecording;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_isRecording ? 'Recording Started 🔴' : 'Recording Stopped ⏹️'),
              duration: const Duration(seconds: 1),
            ));
          },
          child: Text('Practice Mode',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700,
                  color: _isRecording ? Colors.red : null)),
        ),
        actions: [
          if (_isRecording)
            TextButton(
              onPressed: () async {
                final path = await state.gestureRecorder?.saveToStorage();
                if (mounted && path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Saved to $path'),
                  ));
                }
              },
              child: const Text('SAVE 💾', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
            ),
          TextButton(
            onPressed: _showSuccess || _showError ? null : _skip,
            child: Text('SKIP',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.5))),
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Stats bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                // Lives (hearts)
                Row(
                  children: List.generate(5, (i) => Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      i < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 18,
                      color: i < _lives ? Colors.redAccent : Colors.grey.shade300,
                    ),
                  )),
                ),
                const Spacer(),
                // Streak
                if (_streak > 0) ...[
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 3),
                  Text('$_streak streak',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.orange.shade700)),
                  const SizedBox(width: 10),
                ],
                // Accuracy
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$accuracy% accuracy',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: cs.primary)),
                ),
              ],
            ),
          ),

          // ── Progress bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / _practiceCommands.length,
                minHeight: 5,
                backgroundColor: cs.primary.withOpacity(0.12),
                color: cs.primary,
              ),
            ),
          ),

          // ── LOCKED GUIDE CARD ─────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 220,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _showSuccess
                  ? const Color(0xFFE8F5E9)
                  : _showError
                      ? const Color(0xFFFFEBEE)
                      : cs.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _showSuccess
                    ? Colors.green
                    : _showError
                        ? Colors.redAccent
                        : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_showSuccess ? Colors.green : _showError
                      ? Colors.redAccent : cs.primary).withOpacity(0.10),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      '${_currentIndex + 1} of ${_practiceCommands.length}',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.45),
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _categoryColor(targetCmd.category).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        targetCmd.category.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: _categoryColor(targetCmd.category)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Phrase label — always visible
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                  child: Text(
                    targetCmd.messages[locale] ?? targetCmd.messages['en'] ?? '',
                    style: TextStyle(
                      color: cs.onSurface, fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 10),

                // Gesture chips — always visible
                SizedBox(
                  height: 48,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(targetCmd.sequence.length, (i) {
                        final isPending = i >= currentBuffer.length;
                        final isCorrect = !isPending &&
                            i < currentBuffer.length &&
                            currentBuffer[i] == targetCmd.sequence[i];
                        final event = targetCmd.sequence[i];
                        Color bg = cs.surfaceVariant;
                        Color fg = cs.onSurface.withOpacity(0.5);
                        if (isCorrect) {
                          bg = Colors.green.withOpacity(0.18);
                          fg = Colors.green.shade700;
                        }
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isCorrect
                                    ? Colors.green.withOpacity(0.6)
                                    : fg.withOpacity(0.3)),
                          ),
                          child: Text(event.name,
                              style: TextStyle(color: fg, fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                        );
                      }),
                    ),
                  ),
                ),

                // Feedback banner — slides in below chips, never hides sequence
                if (_showSuccess || _showError) ...[  
                  const SizedBox(height: 8),
                  ScaleTransition(
                    scale: _feedbackScale,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _showSuccess
                            ? Colors.green.withOpacity(0.12)
                            : Colors.red.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _showSuccess
                              ? Colors.green.withOpacity(0.4)
                              : Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_showSuccess ? '🎉 ' : '💙 ',
                              style: const TextStyle(fontSize: 16)),
                          Flexible(
                            child: Text(
                              _feedbackMsg,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _showSuccess
                                    ? Colors.green.shade700
                                    : Colors.red.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── CAMERA VIEW ────────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black,
              ),
              clipBehavior: Clip.antiAlias,
              child: state.cameraReady && state.cameraController != null
                  ? ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.3),
                        child: SizedBox(
                          width:  state.cameraController!.value.previewSize?.height ?? 720,
                          height: state.cameraController!.value.previewSize?.width  ?? 1280,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(state.cameraController!),

                              if (state.faceDataStream != null)
                                StreamBuilder<FaceData>(
                                  stream: state.faceDataStream,
                                  builder: (context, snapshot) {
                                    final fd = snapshot.data;
                                    if (fd != null && fd.faceDetected) {
                                      return CustomPaint(
                                        size: Size.infinite,
                                        painter: HudOverlayPainter(
                                          faceData:  fd,
                                          baselineX: state.baselineGazeX,
                                          baselineY: state.baselineGazeY,
                                          threshold: state.gazeThreshold,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),

                              if (!state.isEarCalibrated)
                                Positioned(
                                  top: 12, left: 12, right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.88),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '⏳ Calibrating — keep eyes open for 3s',
                                      style: TextStyle(color: Colors.black,
                                          fontSize: 11, fontWeight: FontWeight.w700),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),

                              // EAR debug readout
                              if (state.faceDataStream != null)
                                Positioned(
                                  bottom: 10, left: 8,
                                  child: StreamBuilder<FaceData>(
                                    stream: state.faceDataStream,
                                    builder: (ctx, snap) {
                                      final fd = snap.data;
                                      if (fd == null || !fd.faceDetected) {
                                        return const SizedBox.shrink();
                                      }
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('L: ${fd.leftEAR.toStringAsFixed(3)}',
                                                style: TextStyle(
                                                  color: fd.leftEAR < state.adaptiveEarThreshold
                                                      ? Colors.redAccent : Colors.greenAccent,
                                                  fontSize: 10, fontFamily: 'monospace',
                                                )),
                                            Text('R: ${fd.rightEAR.toStringAsFixed(3)}',
                                                style: TextStyle(
                                                  color: fd.rightEAR < state.adaptiveEarThreshold
                                                      ? Colors.redAccent : Colors.greenAccent,
                                                  fontSize: 10, fontFamily: 'monospace',
                                                )),
                                            Text('T: ${state.adaptiveEarThreshold.toStringAsFixed(3)}',
                                                style: const TextStyle(
                                                    color: Colors.white70, fontSize: 10,
                                                    fontFamily: 'monospace')),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String cat) {
    const map = {
      'basics':    Color(0xFF4A6CF7),
      'needs':     Color(0xFFE74C3C),
      'health':    Color(0xFFE91E63),
      'comfort':   Color(0xFF9C27B0),
      'emotional': Color(0xFFFF9800),
      'social':    Color(0xFF27AE60),
      'utility':   Color(0xFF00BCD4),
      'emergency': Color(0xFFF44336),
      'custom':    Color(0xFF607D8B),
    };
    return map[cat] ?? const Color(0xFF607D8B);
  }
}
