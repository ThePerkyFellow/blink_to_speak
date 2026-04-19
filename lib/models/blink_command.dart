import '../../core/gesture/gesture_event.dart';

/// Represents a single blink command: a gesture sequence → multilingual messages.
class BlinkCommand {
  final String id;
  final List<GestureEvent> sequence;
  final Map<String, String> messages; // locale → message text
  final String category;
  final bool isDefault;
  bool isEnabled;

  BlinkCommand({
    required this.id,
    required this.sequence,
    required this.messages,
    required this.category,
    this.isDefault = true,
    this.isEnabled = true,
  });

  factory BlinkCommand.fromJson(Map<String, dynamic> json) {
    final rawSeq = (json['sequence'] as List<dynamic>).cast<String>();
    final sequence = rawSeq
        .map((s) => GestureEventLabel.fromString(s))
        .whereType<GestureEvent>()
        .toList();

    final rawMsgs = (json['messages'] as Map<String, dynamic>);
    final messages = rawMsgs.map((k, v) => MapEntry(k, v.toString()));

    return BlinkCommand(
      id: json['id'] as String,
      sequence: sequence,
      messages: messages,
      category: (json['category'] as String?) ?? 'custom',
      isDefault: (json['isDefault'] as bool?) ?? true,
      isEnabled: (json['isEnabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sequence': sequence.map((e) => e.label).toList(),
    'messages': messages,
    'category': category,
    'isDefault': isDefault,
    'isEnabled': isEnabled,
  };

  BlinkCommand copyWith({
    String? id,
    List<GestureEvent>? sequence,
    Map<String, String>? messages,
    String? category,
    bool? isDefault,
    bool? isEnabled,
  }) =>
      BlinkCommand(
        id: id ?? this.id,
        sequence: sequence ?? List.from(this.sequence),
        messages: messages ?? Map.from(this.messages),
        category: category ?? this.category,
        isDefault: isDefault ?? this.isDefault,
        isEnabled: isEnabled ?? this.isEnabled,
      );

  String get sequenceLabel => sequence.map((e) => e.label).join(' → ');
}
