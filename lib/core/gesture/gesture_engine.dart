import 'dart:convert';
import 'package:flutter/services.dart';
import '../gesture/gesture_event.dart';
import '../../models/blink_command.dart';

/// Loads default commands from assets and merges with user overrides.
/// Resolves a gesture sequence to a localised message string.
class GestureEngine {
  final List<BlinkCommand> _commands = [];
  bool _loaded = false;

  Future<void> load({
    List<BlinkCommand> userOverrides = const [],
  }) async {
    _commands.clear();

    // Load defaults from bundled JSON
    final jsonStr = await rootBundle.loadString('assets/encodings/default_commands.json');
    final List<dynamic> data = json.decode(jsonStr);
    final defaults = data.map((e) => BlinkCommand.fromJson(e)).toList();

    // Merge: user overrides take precedence
    final overrideIds = userOverrides.map((c) => c.id).toSet();
    for (final cmd in defaults) {
      if (!overrideIds.contains(cmd.id)) _commands.add(cmd);
    }
    _commands.addAll(userOverrides);

    // Sort by sequence length descending (longest match first)
    _commands.sort((a, b) => b.sequence.length.compareTo(a.sequence.length));
    _loaded = true;
  }

  /// Returns the localised message for the given gesture sequence,
  /// or null if no match is found.
  String? resolve(List<GestureEvent> sequence, String locale) {
    if (!_loaded || sequence.isEmpty) return null;

    for (final cmd in _commands) {
      if (!cmd.isEnabled) continue;
      if (_sequenceMatches(cmd.sequence, sequence)) {
        return cmd.messages[locale] ??
               cmd.messages['en'] ??
               cmd.messages.values.firstOrNull;
      }
    }
    return null;
  }

  bool _sequenceMatches(List<GestureEvent> pattern, List<GestureEvent> input) {
    if (pattern.length != input.length) return false;
    for (int i = 0; i < pattern.length; i++) {
      if (pattern[i] != input[i]) return false;
    }
    return true;
  }

  /// Checks whether adding [next] to [current] still has potential matches.
  bool hasPotentialMatch(List<GestureEvent> current, GestureEvent next) {
    final candidate = [...current, next];
    return _commands.any(
      (cmd) => cmd.isEnabled && _sequenceStartsWith(cmd.sequence, candidate),
    );
  }

  bool _sequenceStartsWith(List<GestureEvent> full, List<GestureEvent> prefix) {
    if (prefix.length > full.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (full[i] != prefix[i]) return false;
    }
    return true;
  }

  List<BlinkCommand> get allCommands => List.unmodifiable(_commands);
}
