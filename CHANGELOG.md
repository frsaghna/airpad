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

### Phase 2 — Discovery
- Implemented `DeviceIdentity` cryptographic identity in `airpad_core` with self-signed X.509 cert and RSA keypair generation, DER export, and SHA-256 fingerprinting.
- Implemented `AliasGenerator` producing curated friendly two-word names.
- Implemented `MulticastDiscoveryService` supporting UDP multicast (`224.0.0.167:53318`) across all interfaces with broadcast fallback.
- Implemented `HttpRegisterServer` and `SubnetScanner` for HTTP fallback discovery when multicast is blocked by AP isolation.
- Implemented `DiscoveryManager` providing unified live tracking of active receivers and automatic expiration.
- Verified Phase 2 acceptance criteria: phone discovers desktop in < 50ms, HTTP fallback works when multicast is unavailable, and self-discovery is filtered out.

### Phase 3 — Secure session and pairing
- Implemented `TrustStore` with in-memory and persistent JSON storage of trusted device certificates.
- Implemented `PairingCodeHelper` and `QrPairingPayload` supporting 6-digit codes and `airpad://v1` QR codes.
- Implemented `TlsSessionServer` providing TLS WebSocket server at `wss://<ip>:53318/v1/session` with 6-digit pairing prompt, desktop confirmation, single active session enforcement, heartbeat monitor, and instant revocation.
- Implemented `TlsSessionClient` with strict certificate pinning, automatic reconnection, QR code pairing, and heartbeat ping.
- Verified Phase 3 acceptance criteria: unpaired devices rejected, paired devices reconnect automatically, revoking device disconnects immediately with close code 4401, rogue devices cannot hijack trusted slots, and QR pairing connects out-of-band.

### Phase 4 — Touchpad MVP
- Implemented `MoveCoalescer` providing 60-120 Hz motion delta batching to prevent network packet flooding.
- Implemented `TouchpadProcessor` supporting full gesture engine: 1-finger move, 1-finger tap (left click), 2-finger tap (right click), 3-finger tap (middle click), 2-finger drag (scroll), and tap-then-hold drag.
- Added velocity acceleration curve and configurable sensitivity.
- Implemented `AirpadInjectClient` Unix domain socket client connecting to `airpad-inject`.
- Verified Phase 4 acceptance criteria: smooth pointer control, all gestures stream across TLS session, tap/double-tap/drag/scroll, and guaranteed release of held buttons upon disconnection.

### Phase 5 — Keyboard
- Implemented `KeyboardState` managing text IME mode and on-screen key mode with sticky modifiers (Ctrl, Alt, Shift, Meta).
- Implemented shortcuts helper for multi-key combos (Ctrl+C, Ctrl+V, Alt+Tab).
- Enhanced `airpad-inject` in Rust with Linux Unicode hex input (`Ctrl+Shift+U <hex> Enter`) for non-ASCII/emoji characters and modifier key synchronization.
- Verified Phase 5 acceptance criteria: typed full sentence, dispatched Ctrl+C / Ctrl+V / Alt+Tab shortcuts, and streamed Unicode / non-ASCII strings across TLS session.

### Phase 6 — UX polish in black and white
- Created shared Flutter package `packages/airpad_ui` strictly adhering to monochrome design system (zero hue, no gradients, no shadows, no blur):
  - Inverted dark and light theme palettes (`AirTheme`).
  - Shared widgets: `AirButton`, `AirCard`, `AirTile`, `AirToggle`, `AirCodeBox`, `AirStatusBadge`, and `AirTouchpadSurface`.
- Built full desktop UI (`apps/desktop`):
  - Device identity card, active controller banner with disconnect control, connection status badge.
  - Interactive QR code dialog (`qr_flutter`) for instant out-of-band mobile pairing.
  - Desktop pairing prompt dialog with 6-digit code verification.
  - Trusted devices list with instant revocation.
- Built full mobile UI (`apps/mobile`):
  - `DiscoverScreen`: live receiver listing, status pills (`PAIRED` / `UNPAIRED`), pull-to-refresh, manual IP entry dialog, and camera QR code scanner.
  - `PairingScreen`: 6-digit verification code display, target receiver details, and desktop confirmation waiting status.
  - `ControllerScreen`: high-refresh `AirTouchpadSurface` with touch feedback rings, mouse buttons row, sticky modifier latches (Ctrl, Alt, Shift, Super) with visual inversion, quick navigation keys, shortcuts grid, function keys (F1-F12), and audio/media controls.
  - `SettingsScreen`: device alias editing, sensitivity slider, natural scrolling, haptic feedback, wakelock screen awake toggle, theme switcher, and trusted receiver management with instant revocation.
  - `QrScannerScreen`: monochrome viewfinder overlay with `mobile_scanner`.
- Verified Phase 6 acceptance criteria: 0 non-gray pixels in UI chrome across desktop and mobile, full status distinguishable without color, comprehensive widget tests and screen tests passing across the monorepo.

### Phase 7 — Hardening and packaging
- Hardened server and helper against flood attacks:
  - Added token-bucket `RateLimiter` to `TlsSessionServer` enforcing 240 events/sec throughput with burst capacity.
  - Implemented 8KB payload bounds check in `TlsSessionServer` and `airpad-inject` daemon.
  - Unit-tested rate limiting and recovery behavior (`rate_limiter_test.dart`).
- Built Android production release:
  - Signed release APK compiled via `flutter build apk --release` (`build/app/outputs/flutter-apk/app-release.apk`).
- Built Linux desktop distribution bundle:
  - Created automated build and packaging script `scripts/package-desktop.sh`.
  - Self-contained release tarball `dist/airpad-linux-x86_64.tar.gz` containing `airpad`, `airpad-inject`, shared libraries, udev rule, systemd user service, and `install.sh`.
  - Authored Arch Linux package specification `packaging/PKGBUILD`.
- Documented project architecture, verification checklist, and setup:
  - Created `docs/testing.md` with manual device checklist, AP isolation fallback tests, and latency benchmarking targets.
  - Created root `README.md` with installation guides, security guarantees, and troubleshooting.
- Verified Definition of Done (v1): all 75 monorepo tests pass, linter passes with zero warnings, fresh machine installable end to end.
