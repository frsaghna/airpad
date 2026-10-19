import 'dart:convert';
import 'package:meta/meta.dart';

/// Mouse button identifier.
enum MouseButton {
  left,
  right,
  middle;

  String toJson() => name;

  static MouseButton fromJson(String value) {
    switch (value.toLowerCase()) {
      case 'left':
        return MouseButton.left;
      case 'right':
        return MouseButton.right;
      case 'middle':
        return MouseButton.middle;
      default:
        throw ArgumentError.value(value, 'button', 'Unknown mouse button');
    }
  }
}

/// Up or down state for buttons and keys.
enum ButtonState {
  down,
  up;

  String toJson() => name;

  static ButtonState fromJson(String value) {
    switch (value.toLowerCase()) {
      case 'down':
        return ButtonState.down;
      case 'up':
        return ButtonState.up;
      default:
        throw ArgumentError.value(value, 'state', 'Unknown button state');
    }
  }
}

/// Up or down state for keyboard keys.
enum KeyState {
  down,
  up;

  String toJson() => name;

  static KeyState fromJson(String value) {
    switch (value.toLowerCase()) {
      case 'down':
        return KeyState.down;
      case 'up':
        return KeyState.up;
      default:
        throw ArgumentError.value(value, 'state', 'Unknown key state');
    }
  }
}

/// Media control action.
enum MediaAction {
  playPause('play_pause'),
  volumeUp('volume_up'),
  volumeDown('volume_down'),
  volumeMute('volume_mute'),
  nextTrack('next_track'),
  prevTrack('prev_track');

  final String wireName;
  const MediaAction(this.wireName);

  String toJson() => wireName;

  static MediaAction fromJson(String value) {
    for (final action in MediaAction.values) {
      if (action.wireName == value) return action;
    }
    throw ArgumentError.value(value, 'action', 'Unknown media action');
  }
}

/// Sealed base class for all Airpad protocol events.
@immutable
sealed class AirpadEvent {
  const AirpadEvent();

  String get type;
  Map<String, dynamic> toJson();

  String toJsonString() => jsonEncode(toJson());

  static AirpadEvent fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null) {
      throw const FormatException('Missing required "type" field in event');
    }

    switch (type) {
      case 'move':
        return MoveEvent.fromJson(json);
      case 'scroll':
        return ScrollEvent.fromJson(json);
      case 'button':
        return ButtonEvent.fromJson(json);
      case 'click':
        return ClickEvent.fromJson(json);
      case 'key':
        return KeyEvent.fromJson(json);
      case 'text':
        return TextEvent.fromJson(json);
      case 'media':
        return MediaEvent.fromJson(json);
      case 'settings':
        return SettingsEvent.fromJson(json);
      default:
        throw FormatException('Unknown event type: $type');
    }
  }

  static AirpadEvent fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object for event');
    }
    return AirpadEvent.fromJson(decoded);
  }
}

/// Relative pointer motion event.
@immutable
final class MoveEvent extends AirpadEvent {
  const MoveEvent({required this.dx, required this.dy});

  final double dx;
  final double dy;

  @override
  String get type => 'move';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'dx': dx,
        'dy': dy,
      };

  factory MoveEvent.fromJson(Map<String, dynamic> json) {
    final rawDx = (json['dx'] as num?)?.toDouble() ?? 0.0;
    final rawDy = (json['dy'] as num?)?.toDouble() ?? 0.0;
    // Bound deltas to avoid erratic jumps from corrupted packets
    final clampedDx = rawDx.clamp(-1000.0, 1000.0);
    final clampedDy = rawDy.clamp(-1000.0, 1000.0);
    return MoveEvent(dx: clampedDx, dy: clampedDy);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveEvent && dx == other.dx && dy == other.dy;

  @override
  int get hashCode => dx.hashCode ^ dy.hashCode;

  @override
  String toString() => 'MoveEvent(dx: $dx, dy: $dy)';
}

/// Two-finger scroll event.
@immutable
final class ScrollEvent extends AirpadEvent {
  const ScrollEvent({required this.dx, required this.dy});

  final double dx;
  final double dy;

  @override
  String get type => 'scroll';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'dx': dx,
        'dy': dy,
      };

  factory ScrollEvent.fromJson(Map<String, dynamic> json) {
    final rawDx = (json['dx'] as num?)?.toDouble() ?? 0.0;
    final rawDy = (json['dy'] as num?)?.toDouble() ?? 0.0;
    final clampedDx = rawDx.clamp(-1000.0, 1000.0);
    final clampedDy = rawDy.clamp(-1000.0, 1000.0);
    return ScrollEvent(dx: clampedDx, dy: clampedDy);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScrollEvent && dx == other.dx && dy == other.dy;

  @override
  int get hashCode => dx.hashCode ^ dy.hashCode;

  @override
  String toString() => 'ScrollEvent(dx: $dx, dy: $dy)';
}

/// Mouse button down/up event.
@immutable
final class ButtonEvent extends AirpadEvent {
  const ButtonEvent({required this.button, required this.state});

  final MouseButton button;
  final ButtonState state;

  @override
  String get type => 'button';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'button': button.toJson(),
        'state': state.toJson(),
      };

  factory ButtonEvent.fromJson(Map<String, dynamic> json) {
    final buttonStr = json['button'] as String? ?? 'left';
    final stateStr = json['state'] as String? ?? 'down';
    return ButtonEvent(
      button: MouseButton.fromJson(buttonStr),
      state: ButtonState.fromJson(stateStr),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ButtonEvent && button == other.button && state == other.state;

  @override
  int get hashCode => button.hashCode ^ state.hashCode;

  @override
  String toString() => 'ButtonEvent(button: ${button.name}, state: ${state.name})';
}

/// Single or multi-click convenience event.
@immutable
final class ClickEvent extends AirpadEvent {
  const ClickEvent({required this.button, this.count = 1});

  final MouseButton button;
  final int count;

  @override
  String get type => 'click';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'button': button.toJson(),
        'count': count,
      };

  factory ClickEvent.fromJson(Map<String, dynamic> json) {
    final buttonStr = json['button'] as String? ?? 'left';
    final rawCount = (json['count'] as num?)?.toInt() ?? 1;
    final clampedCount = rawCount.clamp(1, 5);
    return ClickEvent(
      button: MouseButton.fromJson(buttonStr),
      count: clampedCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClickEvent && button == other.button && count == other.count;

  @override
  int get hashCode => button.hashCode ^ count.hashCode;

  @override
  String toString() => 'ClickEvent(button: ${button.name}, count: $count)';
}

/// Physical keyboard key down/up event.
@immutable
final class KeyEvent extends AirpadEvent {
  const KeyEvent({
    required this.code,
    required this.state,
    this.mods = const [],
  });

  final String code;
  final KeyState state;
  final List<String> mods;

  @override
  String get type => 'key';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'code': code,
        'state': state.toJson(),
        if (mods.isNotEmpty) 'mods': mods,
      };

  factory KeyEvent.fromJson(Map<String, dynamic> json) {
    final rawCode = json['code'] as String? ?? '';
    if (rawCode.isEmpty || rawCode.length > 64) {
      throw const FormatException('Invalid or missing key code');
    }
    final stateStr = json['state'] as String? ?? 'down';
    final rawMods = (json['mods'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        const [];

    return KeyEvent(
      code: rawCode,
      state: KeyState.fromJson(stateStr),
      mods: rawMods,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyEvent &&
          code == other.code &&
          state == other.state &&
          _listEquals(mods, other.mods);

  @override
  int get hashCode => code.hashCode ^ state.hashCode ^ mods.length.hashCode;

  @override
  String toString() => 'KeyEvent(code: $code, state: ${state.name}, mods: $mods)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Composed text insertion event (e.g. from mobile IME).
@immutable
final class TextEvent extends AirpadEvent {
  const TextEvent({required this.value});

  final String value;

  @override
  String get type => 'text';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
      };

  factory TextEvent.fromJson(Map<String, dynamic> json) {
    final rawVal = json['value'] as String? ?? '';
    // Limit string length to 4096 characters to prevent buffer overflow attacks
    final safeVal = rawVal.length > 4096 ? rawVal.substring(0, 4096) : rawVal;
    return TextEvent(value: safeVal);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextEvent && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TextEvent(value: ${value.length > 20 ? '${value.substring(0, 20)}...' : value})';
}

/// Media key action event.
@immutable
final class MediaEvent extends AirpadEvent {
  const MediaEvent({required this.action});

  final MediaAction action;

  @override
  String get type => 'media';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'action': action.toJson(),
      };

  factory MediaEvent.fromJson(Map<String, dynamic> json) {
    final rawAction = json['action'] as String? ?? 'play_pause';
    return MediaEvent(action: MediaAction.fromJson(rawAction));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MediaEvent && action == other.action;

  @override
  int get hashCode => action.hashCode;

  @override
  String toString() => 'MediaEvent(action: ${action.wireName})';
}

/// Runtime settings sync event.
@immutable
final class SettingsEvent extends AirpadEvent {
  const SettingsEvent({
    this.sensitivity,
    this.naturalScroll,
  });

  final double? sensitivity;
  final bool? naturalScroll;

  @override
  String get type => 'settings';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (sensitivity != null) 'sensitivity': sensitivity,
        if (naturalScroll != null) 'naturalScroll': naturalScroll,
      };

  factory SettingsEvent.fromJson(Map<String, dynamic> json) {
    final rawSens = (json['sensitivity'] as num?)?.toDouble();
    final clampedSens = rawSens?.clamp(0.1, 5.0);
    final natural = json['naturalScroll'] as bool?;
    return SettingsEvent(
      sensitivity: clampedSens,
      naturalScroll: natural,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsEvent &&
          sensitivity == other.sensitivity &&
          naturalScroll == other.naturalScroll;

  @override
  int get hashCode => (sensitivity?.hashCode ?? 0) ^ (naturalScroll?.hashCode ?? 0);

  @override
  String toString() =>
      'SettingsEvent(sensitivity: $sensitivity, naturalScroll: $naturalScroll)';
}
