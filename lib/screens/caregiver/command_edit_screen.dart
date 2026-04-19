import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/app_state_provider.dart';
import '../../models/blink_command.dart';
import '../../core/gesture/gesture_event.dart';

class CommandEditScreen extends StatefulWidget {
  final BlinkCommand? command;
  const CommandEditScreen({super.key, this.command});

  @override
  State<CommandEditScreen> createState() => _CommandEditScreenState();
}

class _CommandEditScreenState extends State<CommandEditScreen> {
  late List<GestureEvent> _sequence;
  late Map<String, TextEditingController> _msgControllers;
  late String _category;

  static const _gestures = [
    GestureEvent.B, GestureEvent.S, GestureEvent.L, GestureEvent.R,
    GestureEvent.U, GestureEvent.D, GestureEvent.WL, GestureEvent.WR,
    GestureEvent.O,
  ];
  static const _categories = [
    'basics','needs','health','comfort','emotional','social','utility','emergency','custom',
  ];
  static const _locales = [
    ('en', 'English'), ('hi', 'हिंदी'), ('kn', 'ಕನ್ನಡ'),
    ('ta', 'தமிழ்'), ('mr', 'मराठी'), ('te', 'తెలుగు'),
  ];

  @override
  void initState() {
    super.initState();
    final cmd = widget.command;
    _sequence = cmd != null ? List.from(cmd.sequence) : [];
    _category = cmd?.category ?? 'custom';
    _msgControllers = {
      for (final l in _locales)
        l.$1: TextEditingController(text: cmd?.messages[l.$1] ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _msgControllers.values) c.dispose();
    super.dispose();
  }

  void _save() {
    if (_sequence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please build a gesture sequence.')),
      );
      return;
    }
    final messages = {
      for (final l in _locales)
        if (_msgControllers[l.$1]!.text.trim().isNotEmpty)
          l.$1: _msgControllers[l.$1]!.text.trim(),
    };
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one language message.')),
      );
      return;
    }

    final cmd = BlinkCommand(
      id: widget.command?.id ?? const Uuid().v4(),
      sequence: _sequence,
      messages: messages,
      category: _category,
      isDefault: false,
    );
    context.read<AppState>().saveCommand(cmd);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(widget.command != null ? 'Edit Command' : 'Add Custom Command'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ---- Gesture sequence builder ----
          _SectionLabel('Gesture Sequence'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current sequence pills
                if (_sequence.isEmpty)
                  Text('Tap gestures below to build the sequence',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 13))
                else
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      ..._sequence.asMap().entries.map((e) => _SequencePill(
                        event: e.value,
                        onRemove: () => setState(() => _sequence.removeAt(e.key)),
                      )),
                    ],
                  ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),
                Text('Add gesture:', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _gestures.map((g) => _GestureChip(
                    event: g,
                    onTap: () => setState(() => _sequence.add(g)),
                  )).toList(),
                ),
                const SizedBox(height: 8),
                if (_sequence.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                    onPressed: () => setState(() => _sequence.clear()),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ---- Category ----
          _SectionLabel('Category'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(border: InputBorder.none),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
          ),
          const SizedBox(height: 20),
          // ---- Messages per language ----
          _SectionLabel('Message Text (per language)'),
          ...(_locales.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: TextField(
                controller: _msgControllers[l.$1],
                decoration: InputDecoration(
                  labelText: l.$2,
                  border: InputBorder.none,
                  labelStyle: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                ),
              ),
            ),
          ))),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _save, child: const Text('Save Command')),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          letterSpacing: 0.5,
        )),
  );
}

class _SequencePill extends StatelessWidget {
  final GestureEvent event;
  final VoidCallback onRemove;
  const _SequencePill({required this.event, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(event.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: Colors.white70, size: 14),
          ),
        ],
      ),
    );
  }
}

class _GestureChip extends StatelessWidget {
  final GestureEvent event;
  final VoidCallback onTap;
  const _GestureChip({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.primary.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(event.label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: cs.primary)),
            Text(event.description, style: TextStyle(fontSize: 9, color: cs.onSurface.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}
