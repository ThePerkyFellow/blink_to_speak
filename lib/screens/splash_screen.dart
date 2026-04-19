import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _eyeController;
  late Animation<double> _blinkAnim;
  bool _permissionGranted = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _eyeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300),
    )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) _eyeController.reverse();
        });
      } else if (s == AnimationStatus.dismissed) {
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) _eyeController.forward();
        });
      }
    });
    _blinkAnim = Tween<double>(begin: 1.0, end: 0.05).animate(
      CurvedAnimation(parent: _eyeController, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _eyeController.forward();
    });
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted && mounted) {
      setState(() => _permissionGranted = true);
    }
  }

  Future<void> _requestAndStart() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required.')),
        );
      }
      return;
    }
    setState(() => _loading = true);
    if (mounted) {
      await context.read<AppState>().init();
      if (mounted) context.go('/home');
    }
  }

  @override
  void dispose() {
    _eyeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // ---- Logo ----
              Text(
                'BLINK TO SPEAK',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'by Asha Ek Hope Foundation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 48),
              // ---- Animated eye ----
              AnimatedBuilder(
                animation: _blinkAnim,
                builder: (_, __) => Transform.scale(
                  scaleY: _blinkAnim.value,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary.withOpacity(0.15),
                    ),
                    child: Center(
                      child: Icon(Icons.remove_red_eye_rounded,
                          size: 64, color: cs.primary),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              // ---- Permission card ----
              if (!_permissionGranted) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Allow camera access',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: cs.onSurface,
                          )),
                      const SizedBox(height: 8),
                      Text(
                        'Please allow access to your device\'s camera '
                        'which is required for blink interpretation on this app.',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(0.65),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              // ---- Start button ----
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _requestAndStart,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white,
                          ))
                      : const Text("LET'S START"),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
