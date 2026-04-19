import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.remove_red_eye_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'BLINK TO ',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: cs.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: 'SPEAK',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // ---- Main menu tiles ----
              _MenuTile(
                icon: Icons.remove_red_eye_outlined,
                label: 'Interpret my blink',
                color: const Color(0xFF4A6CF7),
                onTap: () => context.push('/interpret'),
              ),
              _MenuTile(
                icon: Icons.fitness_center_rounded,
                label: 'Practice screen',
                color: const Color(0xFF27AE60),
                onTap: () => context.push('/practice'),
              ),
              _MenuTile(
                icon: Icons.edit_note_rounded,
                label: 'Personalize messages',
                color: const Color(0xFFE67E22),
                onTap: () => context.push('/caregiver'),
              ),
              _MenuTile(
                icon: Icons.settings_rounded,
                label: 'Settings',
                color: const Color(0xFF2C3E50),
                onTap: () => context.push('/settings'),
              ),
              const Spacer(),
              // ---- Guidebook link ----
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.menu_book_rounded, color: cs.primary),
                  title: const Text('Blink to Speak Guidebook',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: 18, color: cs.onSurface.withOpacity(0.4)),
                  onTap: () async {
                    final uri = Uri.parse('https://ashaekhope.com/blink-to-speak/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 15,
                      )),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

