import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CaregiverHome extends StatelessWidget {
  const CaregiverHome({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Caregiver Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personalize for your patient',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: cs.onSurface)),
            const SizedBox(height: 4),
            Text('Edit which messages each blink sequence speaks.',
                style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.55), height: 1.4)),
            const SizedBox(height: 28),
            _CaregiverTile(
              icon: Icons.list_alt_rounded,
              title: 'View / Edit Commands',
              subtitle: 'See all 50 commands and customize messages',
              color: cs.primary,
              onTap: () => context.push('/caregiver/commands'),
            ),
            const SizedBox(height: 12),
            _CaregiverTile(
              icon: Icons.add_circle_outline_rounded,
              title: 'Add Custom Command',
              subtitle: 'Create a new gesture → message mapping',
              color: const Color(0xFF27AE60),
              onTap: () => context.push('/caregiver/edit'),
            ),
            const SizedBox(height: 12),
            _CaregiverTile(
              icon: Icons.info_outline_rounded,
              title: 'How gestures work',
              subtitle: 'Learn the 8 eye movements used as building blocks',
              color: const Color(0xFF4A6CF7),
              onTap: () => _showGestureLegend(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showGestureLegend(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _GestureLegendSheet(),
    );
  }
}

class _CaregiverTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CaregiverTile({
    required this.icon, required this.title,
    required this.subtitle, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _GestureLegendSheet extends StatelessWidget {
  const _GestureLegendSheet();

  static const _items = [
    ('B', 'Blink', 'Both eyes quick close + open'),
    ('S', 'Shut', 'Both eyes held closed (> 1 second)'),
    ('L', 'Look Left', 'Gaze moved to the left'),
    ('R', 'Look Right', 'Gaze moved to the right'),
    ('U', 'Look Up', 'Gaze moved upward'),
    ('D', 'Look Down', 'Gaze moved downward'),
    ('WL', 'Left Wink', 'Left eye closed, right stays open'),
    ('WR', 'Right Wink', 'Right eye closed, left stays open'),
    ('O', 'Roll', 'Circular / rotational eye movement'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2),
            )),
          ),
          const SizedBox(height: 16),
          Text('8 Eye Movement Building Blocks',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface)),
          const SizedBox(height: 12),
          ..._items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(item.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(item.$3, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.55))),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
