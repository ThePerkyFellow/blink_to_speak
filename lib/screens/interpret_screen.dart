import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../providers/app_state_provider.dart';
import '../core/gesture/gesture_event.dart';
import '../core/detection/face_detector_interface.dart';

class InterpretScreen extends StatelessWidget {
  const InterpretScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InterpretView();
  }
}

class _InterpretView extends StatefulWidget {
  const _InterpretView();

  @override
  State<_InterpretView> createState() => _InterpretViewState();
}

class _InterpretViewState extends State<_InterpretView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = context.read<AppState>();
        state.practiceMode = false;
        state.resetCalibration();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.remove_red_eye_rounded, color: cs.primary, size: 18),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(children: [
                TextSpan(text: 'BLINK TO ', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface)),
                TextSpan(text: 'SPEAK', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16, color: cs.primary)),
              ]),
            ),
          ],
        ),
        actions: [],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ---- Camera preview ----
              Expanded(
                flex: 5,
                child: _CameraPreviewCard(state: state),
              ),
              // ---- Gesture buffer ----
              _GestureBufferBar(buffer: state.gestureBuffer, isRecording: state.isRecording),
              // ---- Output card ----
              _OutputCard(
                message: state.lastMessage,
                isRecording: state.isRecording,
                patientName: state.patientName,
              ),
              // ---- YES / NO quick reference ----
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    _QuickRef(label: 'YES', sub: '1 blink', color: cs.primary),
                    const SizedBox(width: 12),
                    _QuickRef(label: 'NO', sub: '2 blinks', color: cs.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back'),
                        onPressed: () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.onSurface,
                          side: BorderSide(color: cs.primary.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          // ---- Emergency overlay ----
          if (state.emergencyActive) _EmergencyOverlay(onDismiss: state.dismissEmergency),
        ],
      ),
    );
  }
}

class _CameraPreviewCard extends StatelessWidget {
  final AppState state;
  const _CameraPreviewCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black,
        boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 6))],
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
                      
                      // HUD Overlay — gaze dot + EAR diagnostics
                      if (state.faceDataStream != null)
                        Positioned.fill(
                          child: StreamBuilder<FaceData>(
                            stream: state.faceDataStream,
                            builder: (context, snapshot) {
                        final fd = snapshot.data;
                        final detected = fd != null && fd.faceDetected;
                        return Stack(
                          children: [
                            // Gaze dot painter
                            if (detected)
                              CustomPaint(
                                size: Size.infinite,
                                painter: HudOverlayPainter(
                                  faceData: fd,
                                  baselineX: state.baselineGazeX,
                                  baselineY: state.baselineGazeY,
                                  threshold: state.gazeThreshold,
                                ),
                              ),
                            // Calibration banner
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
                            // Live EAR readout (bottom-left)
                            if (detected)
                              Positioned(
                                bottom: 48, left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'L-EAR: ${fd.leftEAR.toStringAsFixed(3)}',
                                        style: TextStyle(
                                          color: fd.leftEAR < state.adaptiveEarThreshold
                                              ? Colors.redAccent : Colors.greenAccent,
                                          fontSize: 11, fontFamily: 'monospace',
                                        ),
                                      ),
                                      Text(
                                        'R-EAR: ${fd.rightEAR.toStringAsFixed(3)}',
                                        style: TextStyle(
                                          color: fd.rightEAR < state.adaptiveEarThreshold
                                              ? Colors.redAccent : Colors.greenAccent,
                                          fontSize: 11, fontFamily: 'monospace',
                                        ),
                                      ),
                                      Text(
                                        'THR:   ${state.adaptiveEarThreshold.toStringAsFixed(3)}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                // Recording indicator
                if (state.isRecording)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                          SizedBox(width: 4),
                          Text('RECORDING', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      )
    : const Center(child: CircularProgressIndicator()),
    );
  }
}

class _GestureBufferBar extends StatelessWidget {
  final List<GestureEvent> buffer;
  final bool isRecording;
  const _GestureBufferBar({required this.buffer, required this.isRecording});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isRecording ? cs.primary.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRecording ? cs.primary.withOpacity(0.4) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.gesture, size: 18, color: cs.onSurface.withOpacity(0.4)),
          const SizedBox(width: 8),
          if (buffer.isEmpty)
            Text('Gesture buffer',
                style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 13))
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: buffer.map((e) => _GesturePill(event: e)).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GesturePill extends StatelessWidget {
  final GestureEvent event;
  const _GesturePill({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(event.label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

class _OutputCard extends StatelessWidget {
  final String? message;
  final bool isRecording;
  final String patientName;

  const _OutputCard({this.message, required this.isRecording, required this.patientName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primary.withOpacity(0.15),
            child: Icon(Icons.person_rounded, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Interpretation',
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5), fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  message ?? (isRecording ? 'Listening...' : 'Waiting for gesture...'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: message != null ? cs.primary : cs.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickRef extends StatelessWidget {
  final String label, sub;
  final Color color;
  const _QuickRef({required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            Text(sub, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _EmergencyOverlay extends StatelessWidget {
  final VoidCallback onDismiss;
  const _EmergencyOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.withOpacity(0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 80),
            const SizedBox(height: 16),
            const Text('EMERGENCY', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Emergency signal detected!\nAlerting caregiver.',
                style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class HudOverlayPainter extends CustomPainter {
  final FaceData faceData;
  final double baselineX;
  final double baselineY;
  final double threshold;

  HudOverlayPainter({
    required this.faceData,
    required this.baselineX,
    required this.baselineY,
    required this.threshold,
  });

  // Map a raw ML Kit coordinate to canvas pixel.
  // ML Kit with rotation270 returns coords in (imageSize.width x imageSize.height).
  // CameraPreview mirrors the front camera on X.
  Offset _toCanvas(Offset pt, Size canvas) {
    final imgW = faceData.imageSize.width;
    final imgH = faceData.imageSize.height;
    if (imgW <= 0 || imgH <= 0) return Offset.zero;
    final nx = pt.dx / imgW;
    final ny = pt.dy / imgH;
    return Offset((1.0 - nx) * canvas.width, ny * canvas.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. Face bounding box ────────────────────────────────────────────────
    if (faceData.faceRect != Rect.zero && faceData.imageSize != Size.zero) {
      final tl = _toCanvas(Offset(faceData.faceRect.left,  faceData.faceRect.top),    size);
      final tr = _toCanvas(Offset(faceData.faceRect.right, faceData.faceRect.top),    size);
      final bl = _toCanvas(Offset(faceData.faceRect.left,  faceData.faceRect.bottom), size);
      final br = _toCanvas(Offset(faceData.faceRect.right, faceData.faceRect.bottom), size);
      final boxPaint = Paint()..color = Colors.white.withOpacity(0.35)..strokeWidth = 1.5..style = PaintingStyle.stroke;
      final path = Path()..moveTo(tl.dx, tl.dy)..lineTo(tr.dx, tr.dy)..lineTo(br.dx, br.dy)..lineTo(bl.dx, bl.dy)..close();
      canvas.drawPath(path, boxPaint);
    }

    // ── 2. Eye contour dots ─────────────────────────────────────────────────
    void drawContour(List<Offset> pts, Color color) {
      if (pts.isEmpty) return;
      final dotPaint  = Paint()..color = color..style = PaintingStyle.fill;
      final linePaint = Paint()..color = color.withOpacity(0.5)..strokeWidth = 1.0..style = PaintingStyle.stroke;
      final screenPts = pts.map((p) => _toCanvas(p, size)).toList();
      if (screenPts.length >= 2) {
        final path = Path()..moveTo(screenPts.first.dx, screenPts.first.dy);
        for (int i = 1; i < screenPts.length; i++) { path.lineTo(screenPts[i].dx, screenPts[i].dy); }
        path.close();
        canvas.drawPath(path, linePaint);
      }
      for (final sp in screenPts) { canvas.drawCircle(sp, 3.0, dotPaint); }
    }

    drawContour(faceData.leftEyeContour,  Colors.cyanAccent);
    drawContour(faceData.rightEyeContour, Colors.cyanAccent);

    // Draw the CV detected pupils
    if (faceData.leftPupil != Offset.zero && faceData.rightPupil != Offset.zero) {
      final lp = _toCanvas(faceData.leftPupil, size);
      final rp = _toCanvas(faceData.rightPupil, size);
      final pupilPaint = Paint()..color = Colors.redAccent..style = PaintingStyle.fill;
      canvas.drawCircle(lp, 4.0, pupilPaint);
      canvas.drawCircle(rp, 4.0, pupilPaint);
    }

    // ── 3. Gaze direction dot at eye midpoint ───────────────────────────────
    if (faceData.leftEyeContour.isNotEmpty && faceData.rightEyeContour.isNotEmpty) {
      Offset centroid(List<Offset> pts) {
        double sx = 0, sy = 0;
        for (final p in pts) { sx += p.dx; sy += p.dy; }
        return Offset(sx / pts.length, sy / pts.length);
      }
      final lc = _toCanvas(centroid(faceData.leftEyeContour),  size);
      final rc = _toCanvas(centroid(faceData.rightEyeContour), size);
      final eyeMid = Offset((lc.dx + rc.dx) / 2, (lc.dy + rc.dy) / 2);

      Color gazeColor = Colors.greenAccent;
      String gazeLabel = '◉ C'; // Default to Center if below thresholds
      if (faceData.gazeX < -threshold) { gazeColor = Colors.blueAccent;   gazeLabel = '◀ L'; }
      else if (faceData.gazeX >  threshold) { gazeColor = Colors.orangeAccent; gazeLabel = 'R ▶'; }
      else if (faceData.gazeY < -threshold) { gazeColor = Colors.purpleAccent; gazeLabel = '▲ U'; }
      else if (faceData.gazeY >  threshold) { gazeColor = Colors.redAccent;    gazeLabel = '▼ D'; }

      canvas.drawCircle(eyeMid, 7, Paint()..color = gazeColor..style = PaintingStyle.fill);
      canvas.drawCircle(eyeMid, 7, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);

      if (gazeLabel.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: gazeLabel,
            style: TextStyle(color: gazeColor, fontSize: 14, fontWeight: FontWeight.w800,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4)])),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(eyeMid.dx - tp.width / 2, eyeMid.dy - 26));
      }
    }
  }

  @override
  bool shouldRepaint(covariant HudOverlayPainter oldDelegate) => true;
}
