# Changelog

All notable changes to the Airpad project will be documented in this file.

## [Unreleased]

### Phase 0 — Foundations
- Initialized repository structure.
- Authored `docs/protocol.md` wire protocol specification.
- Authored `docs/design.md` black-and-white design system specification.
- Created `packages/airpad_core` Dart package with:
  - Design tokens (`design_tokens.dart`).
  - Core event models (`event.dart`) with JSON serialization and validation.
  - Device and discovery models (`device.dart`).
  - Unit tests covering models and tokens.
- Created dev scripts: `scripts/lint.sh`, `scripts/format.sh`, `scripts/test.sh`.

### Phase 1 — Linux injection spike
- Built `airpad-inject` in Rust using `evdev` to create a virtual mouse and keyboard device via `/dev/uinput`.
- Implemented Unix domain socket server at `$XDG_RUNTIME_DIR/airpad/inject.sock` with `0600` permissions.
- Implemented automatic key and button release on client disconnection or termination.
- Created `airpad-test-cli` to test cursor movement (200px square), clicking, and typing.
- Added udev rules (`99-airpad-uinput.rules`), systemd user service (`airpad-inject.service`), and `install.sh`.
- Performed Flutter Linux desktop spike with `tray_manager`, confirming compilation on Hyprland / Arch Linux.

