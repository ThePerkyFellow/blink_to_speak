import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../providers/app_state_provider.dart';
import '../models/blink_command.dart';
import '../core/gesture/gesture_event.dart';
import '../core/detection/face_detector_interface.dart';
import 'interpret_screen.dart' show HudOverlayPainter; // Expose the painter

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int _currentIndex = 0;
  List<BlinkCommand> _practiceCommands = [];
  bool _showSuccess = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    // Enable practice mode so TTS doesn't fire for normal resolving
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.practiceMode = true;
      state.resetCalibration();
      state.resetGestureBuffer();
      setState(() {
        // Filter out commands without sequences or emergency
        _practiceCommands = state.allCommands.where((c) => c.sequence.isNotEmpty && c.id != 'emg').toList();
        _practiceCommands.shuffle(); // Randomize practice order
      });
    });
  }

  @override
  void dispose() {
    // Reset buffer and exit practice mode
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
      _showSuccess = false;
      _showError = false;
    });
    context.read<AppState>().resetGestureBuffer();
  }

  void _onBufferUpdate(List<GestureEvent> currentBuffer) {
    if (_practiceCommands.isEmpty || _showSuccess || _showError) return;
    if (currentBuffer.isEmpty) return;

    final target = _practiceCommands[_currentIndex].sequence;

    // Check if current buffer is a valid prefix
    bool isValidPrefix = true;
    for (int i = 0; i < currentBuffer.length; i++) {
      if (i >= target.length || currentBuffer[i] != target[i]) {
        isValidPrefix = false;
        break;
      }
    }

    if (!isValidPrefix) {
      // Failed!
      setState(() => _showError = true);
      context.read<AppState>().resetGestureBuffer();
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showError = false);
      });
    } else if (currentBuffer.length == target.length) {
      // Success!
      setState(() => _showSuccess = true);
      context.read<AppState>().resetGestureBuffer();
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _skip();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();

    // We check the buffer manually here because we want to trigger side effects
    // without tying it purely to the build method. But since state changes trigger rebuild,
    // we can safely call our logic check here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onBufferUpdate(state.gestureBuffer);
    });

    if (_practiceCommands.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final targetCmd = _practiceCommands[_currentIndex];
    final currentBuffer = state.gestureBuffer;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Practice Mode', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _skip,
            child: const Text('SKIP', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Target phrase card
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _showSuccess ? Colors.greenAccent : (_showError ? Colors.redAccent : Colors.transparent),
                width: 3,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Practice Phrase:',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  targetCmd.messages[state.activeLocale.split('-').first] ?? targetCmd.messages['en'] ?? '',
                  style: TextStyle(color: cs.onSurface, fontSize: 24, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(targetCmd.sequence.length, (index) {
                    final isPending = index >= currentBuffer.length;
                    final isCorrect = !isPending && currentBuffer[index] == targetCmd.sequence[index];
                    final event = targetCmd.sequence[index];

                    Color bgColor = cs.surfaceVariant;
                    Color fgColor = cs.onSurfaceVariant;
                    
                    if (_showSuccess) {
                      bgColor = Colors.green.withOpacity(0.2);
                      fgColor = Colors.greenAccent;
                    } else if (_showError && !isPending && !isCorrect) {
                      bgColor = Colors.red.withOpacity(0.2);
                      fgColor = Colors.redAccent;
                    } else if (isCorrect) {
                      bgColor = Colors.green.withOpacity(0.2);
                      fgColor = Colors.greenAccent;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: fgColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        event.name,
                        style: TextStyle(color: fgColor, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    );
                  }),
                ),
                if (_showSuccess)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('Perfect! ✅', style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                if (_showError)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('Missed! Try again ❌', style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),

          // Camera View
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
                          width: state.cameraController!.value.previewSize?.height ?? 720,
                          height: state.cameraController!.value.previewSize?.width ?? 1280,
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
                                    faceData: fd,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '⏳ Calibrating EAR — keep eyes open for 3s',
                                style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
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
}
