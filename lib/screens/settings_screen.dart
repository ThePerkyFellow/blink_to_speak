import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final nameCtrl = TextEditingController(text: state.patientName);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader('Patient Profile'),
          _SettingCard(
            child: TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Patient Name',
                border: InputBorder.none,
              ),
              onSubmitted: state.setPatientName,
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader('Language'),
          _SettingCard(
            child: DropdownButtonFormField<String>(
              value: state.activeLocale,
              decoration: const InputDecoration(border: InputBorder.none, labelText: 'App & Voice Language'),
              items: AppState.supportedLocales.map((l) {
                return DropdownMenuItem(
                  value: l['code'],
                  child: Text(l['label']!),
                );
              }).toList(),
              onChanged: (v) => state.setLocale(v!),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader('Detection Sensitivity'),
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EAR Threshold: ${state.earThreshold.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Lower = more sensitive (closes sooner)',
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
                Slider(
                  value: state.earThreshold,
                  min: 0.18, max: 0.32, divisions: 14,
                  onChanged: state.setEarThreshold,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader('Voice'),
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Speech Rate: ${state.speechRate.toStringAsFixed(1)}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Slider(
                  value: state.speechRate,
                  min: 0.2, max: 1.0, divisions: 8,
                  onChanged: state.setSpeechRate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader('About'),
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Blink to Speak', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Based on the Asha Ek Hope Foundation eye sign language system.\n\nEncoding guide: ashaekhope.com/blink-to-speak',
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6), height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            letterSpacing: 0.5,
          )),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}
