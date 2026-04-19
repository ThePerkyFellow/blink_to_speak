/// Represents a single primitive eye gesture recognised by the detector.
enum GestureEvent {
  /// Both eyes blink briefly (EAR dip < 400ms)
  B,
  /// Both eyes shut (held closed > 1000ms)
  S,
  /// Gaze moved left
  L,
  /// Gaze moved right
  R,
  /// Gaze moved up
  U,
  /// Gaze moved down
  D,
  /// Left-eye wink (right stays open)
  WL,
  /// Right-eye wink (left stays open)
  WR,
  /// Roll — circular / rotational eye movement (trajectory-based)
  O,
  /// Emergency sentinel — emitted on furious winking
  EMERGENCY,
}

extension GestureEventLabel on GestureEvent {
  String get label {
    switch (this) {
      case GestureEvent.B:  return 'B';
      case GestureEvent.S:  return 'S';
      case GestureEvent.L:  return 'L';
      case GestureEvent.R:  return 'R';
      case GestureEvent.U:  return 'U';
      case GestureEvent.D:  return 'D';
      case GestureEvent.WL: return 'WL';
      case GestureEvent.WR: return 'WR';
      case GestureEvent.O:  return 'O';
      case GestureEvent.EMERGENCY: return '🚨';
    }
  }

  String get description {
    switch (this) {
      case GestureEvent.B:  return 'Blink';
      case GestureEvent.S:  return 'Shut (long)';
      case GestureEvent.L:  return 'Look Left';
      case GestureEvent.R:  return 'Look Right';
      case GestureEvent.U:  return 'Look Up';
      case GestureEvent.D:  return 'Look Down';
      case GestureEvent.WL: return 'Left Wink';
      case GestureEvent.WR: return 'Right Wink';
      case GestureEvent.O:  return 'Roll';
      case GestureEvent.EMERGENCY: return 'Emergency';
    }
  }

  static GestureEvent? fromString(String s) {
    switch (s.toUpperCase()) {
      case 'B':  return GestureEvent.B;
      case 'S':  return GestureEvent.S;
      case 'L':  return GestureEvent.L;
      case 'R':  return GestureEvent.R;
      case 'U':  return GestureEvent.U;
      case 'D':  return GestureEvent.D;
      case 'WL': return GestureEvent.WL;
      case 'WR': return GestureEvent.WR;
      case 'O':  return GestureEvent.O;
      case 'EMERGENCY': return GestureEvent.EMERGENCY;
      default: return null;
    }
  }
}
