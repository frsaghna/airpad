import 'dart:async';

import '../models/event.dart';

/// Keyboard mode enum: system text IME mode vs specialized on-screen keys mode.
enum KeyboardMode {
  text,
  keys,
}

/// Manages keyboard state, sticky modifier latches (Ctrl, Alt, Shift, Meta),
/// and emits structured KeyEvents, TextEvents, and MediaEvents.
class KeyboardState {
  KeyboardState({void Function(AirpadEvent)? onEvent}) : _onEvent = onEvent;

  final void Function(AirpadEvent)? _onEvent;

  final Set<String> _activeModifiers = {};
  KeyboardMode _mode = KeyboardMode.text;

  final _eventController = StreamController<AirpadEvent>.broadcast();
  final _modifierChangeController = StreamController<Set<String>>.broadcast();

  Stream<AirpadEvent> get onEvent => _eventController.stream;
  Stream<Set<String>> get onModifiersChanged => _modifierChangeController.stream;

  Set<String> get activeModifiers => Set.unmodifiable(_activeModifiers);
  KeyboardMode get mode => _mode;

  bool get isCtrlActive => _activeModifiers.contains('ctrl');
  bool get isAltActive => _activeModifiers.contains('alt');
  bool get isShiftActive => _activeModifiers.contains('shift');
  bool get isMetaActive => _activeModifiers.contains('meta');

  void setMode(KeyboardMode newMode) {
    _mode = newMode;
  }

  /// Toggles a modifier (useful for on-screen modifier latch buttons).
  void toggleModifier(String mod) {
    final clean = mod.toLowerCase();
    if (_activeModifiers.contains(clean)) {
      _activeModifiers.remove(clean);
      // Emit modifier key up
      _emitEvent(KeyEvent(
        code: _mapModifierToCode(clean),
        state: KeyState.up,
      ));
    } else {
      _activeModifiers.add(clean);
      // Emit modifier key down
      _emitEvent(KeyEvent(
        code: _mapModifierToCode(clean),
        state: KeyState.down,
      ));
    }
    _modifierChangeController.add(activeModifiers);
  }

  /// Clears all latched modifiers.
  void clearModifiers() {
    for (final mod in _activeModifiers) {
      _emitEvent(KeyEvent(
        code: _mapModifierToCode(mod),
        state: KeyState.up,
      ));
    }
    _activeModifiers.clear();
    _modifierChangeController.add(activeModifiers);
  }

  /// Sends a physical key down or up event with currently active modifiers.
  void sendKey(String code, KeyState state) {
    final event = KeyEvent(
      code: code,
      state: state,
      mods: _activeModifiers.toList(),
    );
    _emitEvent(event);
  }

  /// Convenience method to simulate pressing and releasing a key atomically.
  void tapKey(String code) {
    sendKey(code, KeyState.press);
  }

  /// Convenience method to send a shortcut combination (e.g. Ctrl+C, Ctrl+V, Alt+Tab).
  void sendShortcut(String code, {List<String> mods = const []}) {
    final modsList = mods.map((m) => m.toLowerCase()).toList();

    // 1. Press modifiers down
    for (final m in modsList) {
      _emitEvent(KeyEvent(code: _mapModifierToCode(m), state: KeyState.down));
    }

    // 2. Tap key
    _emitEvent(KeyEvent(code: code, state: KeyState.down, mods: modsList));
    _emitEvent(KeyEvent(code: code, state: KeyState.up, mods: modsList));

    // 3. Release modifiers up
    for (final m in modsList) {
      _emitEvent(KeyEvent(code: _mapModifierToCode(m), state: KeyState.up));
    }
  }

  /// Sends a composed UTF-8 text string (from system IME).
  void sendText(String value) {
    if (value.isNotEmpty) {
      _emitEvent(TextEvent(value: value));
    }
  }

  /// Sends a media key action.
  void sendMedia(MediaAction action) {
    _emitEvent(MediaEvent(action: action));
  }

  String _mapModifierToCode(String mod) {
    switch (mod.toLowerCase()) {
      case 'ctrl':
        return 'ControlLeft';
      case 'alt':
        return 'AltLeft';
      case 'shift':
        return 'ShiftLeft';
      case 'meta':
      case 'super':
        return 'MetaLeft';
      default:
        return mod;
    }
  }

  void _emitEvent(AirpadEvent event) {
    _onEvent?.call(event);
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void dispose() {
    clearModifiers();
    _eventController.close();
    _modifierChangeController.close();
  }
}
