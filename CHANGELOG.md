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



