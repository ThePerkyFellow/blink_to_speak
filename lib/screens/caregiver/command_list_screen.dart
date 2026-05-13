import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../models/blink_command.dart';

class CommandListScreen extends StatelessWidget {
  const CommandListScreen({super.key});

  static const _categoryOrder = [
    'basics', 'needs', 'health', 'comfort',
    'emotional', 'social', 'utility', 'emergency', 'custom',
  ];

  static const _categoryIcons = {
    'basics':    Icons.check_circle_outline_rounded,
    'needs':     Icons.local_hospital_outlined,
    'health':    Icons.favorite_border_rounded,
    'comfort':   Icons.bed_outlined,
    'emotional': Icons.mood_rounded,
    'social':    Icons.group_outlined,
    'utility':   Icons.home_outlined,
    'emergency': Icons.warning_amber_rounded,
    'custom':    Icons.star_border_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final state    = context.watch<AppState>();
    final commands = state.allCommands;
    final locale   = state.activeLocale.split('-').first;

    // Group by category
    final Map<String, List<BlinkCommand>> grouped = {};
    for (final cmd in commands) {
      grouped.putIfAbsent(cmd.category, () => []).add(cmd);
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Command List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/caregiver/edit'),
            tooltip: 'Add custom command',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categoryOrder.length,
        itemBuilder: (_, catIdx) {
          final cat  = _categoryOrder[catIdx];
          final cmds = grouped[cat];
          if (cmds == null || cmds.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Row(
                  children: [
                    Icon(_categoryIcons[cat] ?? Icons.category,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(cat.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: cs.primary, letterSpacing: 0.8,
                        )),
                  ],
                ),
              ),
              ...cmds.map((cmd) => _CommandRow(
                command: cmd,
                locale: locale,
                onEdit: () => context.push('/caregiver/edit', extra: cmd),
              )),
            ],
          );
        },
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  final BlinkCommand command;
  final String locale;
  final VoidCallback onEdit;

  const _CommandRow({
    required this.command,
    required this.locale,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final msg = command.messages[locale] ?? command.messages['en'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // ── Sequence badge — auto-width, max 110px ──────────────────
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40, maxWidth: 110),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  command.sequenceLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: cs.primary,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ── Message label — takes all remaining space ──
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),

            // ── Controls — fixed width so they never push text ──
            SizedBox(
              width: 88,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Transform.scale(
                    scale: 0.80,
                    child: Switch(
                      value: command.isEnabled,
                      onChanged: (v) {
                        command.isEnabled = v;
                        context.read<AppState>().saveCommand(command);
                      },
                      activeColor: cs.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  GestureDetector(
                    onTap: onEdit,
                    child: Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color: cs.onSurface.withOpacity(0.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
