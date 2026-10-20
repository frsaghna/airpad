import 'dart:async';
import 'package:airpad_core/airpad_core.dart';
import 'package:airpad_ui/airpad_ui.dart';
import 'package:flutter/material.dart';
import '../services/mobile_services.dart';

enum ControllerTab {
  touchpad,
  keyboard,
  media,
}

/// Main controller screen with touchpad surface, mouse buttons, modifiers, and keyboard modes.
class ControllerScreen extends StatefulWidget {
  const ControllerScreen({
    super.key,
    required this.services,
  });

  final MobileServices services;

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  ControllerTab _currentTab = ControllerTab.touchpad;
  bool _showTextBar = false;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  StreamSubscription<SessionState>? _sessionSub;

  @override
  void initState() {
    super.initState();
    // Listen for disconnection
    _sessionSub = widget.services.sessionClient.onStateChanged.listen((state) {
      if (!mounted) return;
      if (state is SessionDisconnected || state is SessionRejected) {
        final snackColors = AirColors.of(context);
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: snackColors.activeFill,
            content: Text(
              state is SessionRejected
                  ? 'DISCONNECTED: ${state.reason}'
                  : 'DISCONNECTED FROM RECEIVER',
              style: TextStyle(
                color: snackColors.onActiveFill,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _sendLeftClick() {
    widget.services.triggerClickHaptic();
    widget.services.sessionClient.sendEvent(const ClickEvent(
      button: MouseButton.left,
      count: 1,
    ));
  }

  void _sendMiddleClick() {
    widget.services.triggerClickHaptic();
    widget.services.sessionClient.sendEvent(const ClickEvent(
      button: MouseButton.middle,
      count: 1,
    ));
  }

  void _sendRightClick() {
    widget.services.triggerClickHaptic();
    widget.services.sessionClient.sendEvent(const ClickEvent(
      button: MouseButton.right,
      count: 1,
    ));
  }

  void _sendTextString(String text) {
    if (text.isEmpty) return;
    widget.services.keyboardState.sendText(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AirColors.of(context);
    final state = widget.services.sessionState;
    final serverDevice = state is SessionConnected ? state.serverDevice : null;
    final alias = serverDevice?.alias ?? 'Desktop Receiver';
    final fp = serverDevice?.fingerprint ?? '';
    final shortFp = fp.length > 12 ? fp.substring(0, 12) : fp;

    final keyboard = widget.services.keyboardState;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Controller Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.bg,
                border: Border(
                  bottom: BorderSide(
                    color: colors.border,
                    width: AirpadTokens.borderWidth,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                    onPressed: () async {
                      await widget.services.disconnect();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    tooltip: 'Disconnect',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alias.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (shortFp.isNotEmpty)
                          Text(
                            'FP: $shortFp...',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const AirStatusBadge(
                    type: AirStatusType.connected,
                    customLabel: 'LIVE',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _showTextBar ? Icons.keyboard_hide : Icons.keyboard,
                      color: colors.textPrimary,
                    ),
                    onPressed: () {
                      setState(() {
                        _showTextBar = !_showTextBar;
                        if (_showTextBar) {
                          _textFocusNode.requestFocus();
                        } else {
                          _textFocusNode.unfocus();
                        }
                      });
                    },
                    tooltip: 'Toggle IME Keyboard',
                  ),
                ],
              ),
            ),

            // Mode Selector Tabs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: colors.cardBg,
              child: Row(
                children: [
                  Expanded(
                    child: _ModeTabButton(
                      label: 'TOUCHPAD',
                      isActive: _currentTab == ControllerTab.touchpad,
                      onTap: () => setState(() => _currentTab = ControllerTab.touchpad),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModeTabButton(
                      label: 'SHORTCUTS',
                      isActive: _currentTab == ControllerTab.keyboard,
                      onTap: () => setState(() => _currentTab = ControllerTab.keyboard),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModeTabButton(
                      label: 'MEDIA',
                      isActive: _currentTab == ControllerTab.media,
                      onTap: () => setState(() => _currentTab = ControllerTab.media),
                    ),
                  ),
                ],
              ),
            ),

            // Optional Collapsible Text Input Bar
            if (_showTextBar)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  border: Border(
                    bottom: BorderSide(
                      color: colors.border,
                      width: AirpadTokens.borderWidth,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _textFocusNode,
                        autofocus: true,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Type text or emoji to stream...',
                          hintStyle: TextStyle(color: colors.textSecondary),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: colors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colors.activeFill),
                          ),
                        ),
                        onSubmitted: (val) {
                          _sendTextString(val);
                          _textFocusNode.requestFocus();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    AirButton(
                      label: 'SEND',
                      onPressed: () {
                        _sendTextString(_textController.text);
                        _textFocusNode.requestFocus();
                      },
                    ),
                  ],
                ),
              ),

            // Tab Content
            Expanded(
              child: switch (_currentTab) {
                ControllerTab.touchpad => _buildTouchpadView(keyboard, colors),
                ControllerTab.keyboard => _buildShortcutsView(keyboard, colors),
                ControllerTab.media => _buildMediaView(colors),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTouchpadView(KeyboardState keyboard, AirColors colors) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          // Large Touchpad Surface
          Expanded(
            child: AirTouchpadSurface(
              processor: widget.services.touchpadProcessor,
            ),
          ),
          const SizedBox(height: 10),

          // Mouse Buttons Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AirButton(
                  label: 'LEFT CLICK',
                  onPressed: _sendLeftClick,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: AirButton(
                  label: 'MID',
                  variant: AirButtonVariant.outline,
                  onPressed: _sendMiddleClick,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: AirButton(
                  label: 'RIGHT CLICK',
                  variant: AirButtonVariant.outline,
                  onPressed: _sendRightClick,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Sticky Modifiers Row
          ListenableBuilder(
            listenable: widget.services,
            builder: (context, _) {
              return Row(
                children: [
                  Expanded(
                    child: _ModifierKeyButton(
                      label: 'CTRL',
                      isActive: keyboard.isCtrlActive,
                      onTap: () {
                        widget.services.triggerHaptic();
                        keyboard.toggleModifier('ctrl');
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModifierKeyButton(
                      label: 'ALT',
                      isActive: keyboard.isAltActive,
                      onTap: () {
                        widget.services.triggerHaptic();
                        keyboard.toggleModifier('alt');
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModifierKeyButton(
                      label: 'SHIFT',
                      isActive: keyboard.isShiftActive,
                      onTap: () {
                        widget.services.triggerHaptic();
                        keyboard.toggleModifier('shift');
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModifierKeyButton(
                      label: 'SUPER',
                      isActive: keyboard.isMetaActive,
                      onTap: () {
                        widget.services.triggerHaptic();
                        keyboard.toggleModifier('meta');
                        setState(() {});
                      },
                    ),
                  ),
                  if (keyboard.activeModifiers.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(Icons.clear, color: colors.textPrimary, size: 20),
                      onPressed: () {
                        widget.services.triggerHaptic();
                        keyboard.clearModifiers();
                        setState(() {});
                      },
                      tooltip: 'Clear Modifiers',
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Quick Navigation Row
          Row(
            children: [
              _KeyButton(label: 'ESC', code: 'Escape', keyboard: keyboard, haptic: widget.services.triggerHaptic),
              const SizedBox(width: 4),
              _KeyButton(label: 'TAB', code: 'Tab', keyboard: keyboard, haptic: widget.services.triggerHaptic),
              const SizedBox(width: 4),
              _KeyButton(label: 'BKSP', code: 'Backspace', keyboard: keyboard, haptic: widget.services.triggerHaptic),
              const SizedBox(width: 4),
              _KeyButton(label: 'ENTER', code: 'Enter', keyboard: keyboard, haptic: widget.services.triggerHaptic),
              const SizedBox(width: 4),
              _KeyButton(label: '←', code: 'ArrowLeft', keyboard: keyboard, haptic: widget.services.triggerHaptic),
              const SizedBox(width: 4),
              _KeyButton(label: '↑', code: 'ArrowUp', keyboard: keyboard, haptic: widget.services.triggerHaptic),
              const SizedBox(width: 4),
              _KeyButton(label: '↓', code: 'ArrowDown', keyboard: keyboard, haptic: widget.services.triggerHaptic),
              const SizedBox(width: 4),
              _KeyButton(label: '→', code: 'ArrowRight', keyboard: keyboard, haptic: widget.services.triggerHaptic),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutsView(KeyboardState keyboard, AirColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'COMMON SHORTCUTS',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Clipboard & Edit Shortcuts
          Row(
            children: [
              Expanded(child: _ShortcutButton('Ctrl+C', 'c', ['ctrl'], keyboard, widget.services.triggerHaptic)),
              const SizedBox(width: 8),
              Expanded(child: _ShortcutButton('Ctrl+V', 'v', ['ctrl'], keyboard, widget.services.triggerHaptic)),
              const SizedBox(width: 8),
              Expanded(child: _ShortcutButton('Ctrl+X', 'x', ['ctrl'], keyboard, widget.services.triggerHaptic)),
              const SizedBox(width: 8),
              Expanded(child: _ShortcutButton('Ctrl+Z', 'z', ['ctrl'], keyboard, widget.services.triggerHaptic)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _ShortcutButton('Ctrl+A', 'a', ['ctrl'], keyboard, widget.services.triggerHaptic)),
              const SizedBox(width: 8),
              Expanded(child: _ShortcutButton('Ctrl+S', 's', ['ctrl'], keyboard, widget.services.triggerHaptic)),
              const SizedBox(width: 8),
              Expanded(child: _ShortcutButton('Ctrl+F', 'f', ['ctrl'], keyboard, widget.services.triggerHaptic)),
              const SizedBox(width: 8),
              Expanded(child: _ShortcutButton('Ctrl+W', 'w', ['ctrl'], keyboard, widget.services.triggerHaptic)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _ShortcutButton('Alt+Tab', 'Tab', ['alt'], keyboard, widget.services.triggerHaptic)),
              const SizedBox(width: 8),
              Expanded(child: _ShortcutButton('Alt+F4', 'F4', ['alt'], keyboard, widget.services.triggerHaptic)),
              const SizedBox(width: 8),
              Expanded(child: _ShortcutButton('Super+D', 'd', ['meta'], keyboard, widget.services.triggerHaptic)),
              const SizedBox(width: 8),
              Expanded(child: _ShortcutButton('Ctrl+Alt+T', 't', ['ctrl', 'alt'], keyboard, widget.services.triggerHaptic)),
            ],
          ),

          const SizedBox(height: 24),
          Text(
            'FUNCTION KEYS',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(12, (index) {
              final fName = 'F${index + 1}';
              return SizedBox(
                width: 72,
                child: AirButton(
                  label: fName,
                  variant: AirButtonVariant.outline,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  onPressed: () {
                    widget.services.triggerHaptic();
                    keyboard.tapKey(fName);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaView(AirColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'MEDIA & AUDIO CONTROLS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Playback Controls Row
            Row(
              children: [
                Expanded(
                  child: AirButton(
                    label: '|<< PREV',
                    variant: AirButtonVariant.outline,
                    onPressed: () {
                      widget.services.triggerHaptic();
                      widget.services.keyboardState.sendMedia(MediaAction.prevTrack);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AirButton(
                    label: '> / || PLAY',
                    onPressed: () {
                      widget.services.triggerHaptic();
                      widget.services.keyboardState.sendMedia(MediaAction.playPause);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AirButton(
                    label: 'NEXT >>|',
                    variant: AirButtonVariant.outline,
                    onPressed: () {
                      widget.services.triggerHaptic();
                      widget.services.keyboardState.sendMedia(MediaAction.nextTrack);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Volume Controls Row
            Row(
              children: [
                Expanded(
                  child: AirButton(
                    label: 'VOL -',
                    variant: AirButtonVariant.outline,
                    onPressed: () {
                      widget.services.triggerHaptic();
                      widget.services.keyboardState.sendMedia(MediaAction.volumeDown);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AirButton(
                    label: 'MUTE',
                    variant: AirButtonVariant.outline,
                    onPressed: () {
                      widget.services.triggerHaptic();
                      widget.services.keyboardState.sendMedia(MediaAction.volumeMute);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AirButton(
                    label: 'VOL +',
                    variant: AirButtonVariant.outline,
                    onPressed: () {
                      widget.services.triggerHaptic();
                      widget.services.keyboardState.sendMedia(MediaAction.volumeUp);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AirColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colors.activeFill : Colors.transparent,
          borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
          border: Border.all(
            color: isActive ? colors.activeFill : colors.border,
            width: AirpadTokens.borderWidth,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isActive ? colors.onActiveFill : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ModifierKeyButton extends StatelessWidget {
  const _ModifierKeyButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AirColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? colors.activeFill : colors.cardBg,
          borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
          border: Border.all(
            color: isActive ? colors.activeFill : colors.border,
            width: AirpadTokens.borderWidth,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isActive ? colors.onActiveFill : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.code,
    required this.keyboard,
    required this.haptic,
  });

  final String label;
  final String code;
  final KeyboardState keyboard;
  final VoidCallback haptic;

  @override
  Widget build(BuildContext context) {
    final colors = AirColors.of(context);
    return Expanded(
      child: InkWell(
        onTap: () {
          haptic();
          keyboard.tapKey(code);
        },
        borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
            border: Border.all(
              color: colors.border,
              width: AirpadTokens.borderWidth,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton(
    this.label,
    this.code,
    this.mods,
    this.keyboard,
    this.haptic,
  );

  final String label;
  final String code;
  final List<String> mods;
  final KeyboardState keyboard;
  final VoidCallback haptic;

  @override
  Widget build(BuildContext context) {
    return AirButton(
      label: label,
      variant: AirButtonVariant.outline,
      onPressed: () {
        haptic();
        keyboard.sendShortcut(code, mods: mods);
      },
    );
  }
}
