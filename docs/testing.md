# AIRPAD Testing & Verification Guide

This document outlines the test strategy, verification checklists, and latency measurement guidelines for AIRPAD across Linux (Wayland/Hyprland and X11) and Android.

---

## 1. Automated Test Suites

Run all automated tests across all monorepo packages:
```bash
./scripts/test.sh
```

Run static analysis and linter checks:
```bash
./scripts/lint.sh
```

### Coverage Overview:
- `packages/airpad_core` (59 unit & integration tests):
  - Design tokens monochrome conformance.
  - Device, event, and pairing model JSON serialization & deserialization.
  - Clamping and bounds validation on move and scroll events.
  - Self-signed X.509 RSA certificate generation and SHA-256 fingerprinting.
  - Multicast discovery across network interfaces and HTTP subnet scanner fallback.
  - TLS WebSocket session server & client with strict certificate pinning.
  - 6-digit pairing prompt, desktop confirmation, and rogue certificate rejection.
  - QR code pairing with out-of-band secrets.
  - Move coalescing and multi-touch gesture processing.
  - Token-bucket rate limiter and payload size bounding.
- `packages/airpad_ui` (4 widget tests):
  - Monochrome widget rendering (`AirButton`, `AirCodeBox`, `AirStatusBadge`, `AirToggle`, `AirCard`, `AirTile`).
- `apps/desktop` (widget smoke test):
  - Desktop receiver initialization, identity display, and monochrome layout.
- `apps/mobile` (6 screen & widget tests):
  - App initialization and dark theme.
  - `DiscoverScreen`, `PairingScreen`, `ControllerScreen` (touchpad, shortcuts, media tabs), and `SettingsScreen`.
- `helper/airpad-inject` (5 Rust tests):
  - Virtual mouse motion, button mapping, keyboard scancodes, and modifier name mapping.

---

## 2. Manual Device Checklist

Perform these manual verification steps with a real Android device and Linux PC:

### 2.1 Discovery
- [ ] **LAN Discovery:** Open desktop app and mobile app on the same Wi-Fi. The desktop receiver appears in the mobile list within 2 seconds with its alias, IP, and fingerprint.
- [ ] **AP Isolation Fallback:** Connect to a network where multicast is disabled or blocked. Tap "Enter IP" or pull down to trigger HTTP subnet scan. The desktop receiver is discovered.
- [ ] **QR Pairing:** Click "Pairing QR" on desktop. Tap "Scan QR" on mobile. Point camera at desktop screen. App immediately auto-pairs and opens controller.

### 2.2 Pairing & Security
- [ ] **6-Digit Code Pairing:** Tap an unpaired receiver on mobile. Verify the 6-digit code on the phone matches the desktop prompt dialog.
- [ ] **Desktop Confirmation:** Click "Pair & Allow" on desktop. Phone transitions to controller screen.
- [ ] **Desktop Rejection:** Attempt pairing and click "Reject" on desktop. Phone displays "PAIRING REJECTED" without granting input access.
- [ ] **Unpaired Block:** Unpaired devices cannot inject any input events (verified by protocol unit tests).
- [ ] **Immediate Revocation:** In Desktop "Trusted Devices", click "REVOKE" for the active phone. Active session terminates immediately with close code 4401 and phone is disconnected.

### 2.3 Touchpad Gestures
- [ ] **1-Finger Move:** Move finger smoothly across touchpad surface; pointer follows smoothly with acceleration.
- [ ] **Sensitivity Slider:** Adjust sensitivity slider from 0.5x to 3.0x in Settings; cursor speed scales accordingly.
- [ ] **1-Finger Tap:** Tap once; triggers a left click.
- [ ] **1-Finger Double Tap:** Double tap quickly; triggers double click (e.g. highlights a word).
- [ ] **2-Finger Tap:** Tap with two fingers simultaneously; triggers a right click (context menu).
- [ ] **3-Finger Tap:** Tap with three fingers simultaneously; triggers a middle click.
- [ ] **2-Finger Drag (Scroll):** Drag with two fingers; window scrolls vertically and horizontally.
- [ ] **Natural Scroll Toggle:** Toggle "Natural Scrolling" in Settings; vertical scroll direction inverts.
- [ ] **Tap-and-Hold Drag:** Tap and immediately drag; window or text selection is dragged until finger lifts.

### 2.4 Keyboard & Controls
- [ ] **Text IME Mode:** Tap keyboard button to show text bar. Type text or emojis and tap SEND; text appears at desktop cursor position.
- [ ] **Unicode / Emoji Input:** Type non-ASCII characters (e.g. `café`, `🚀`); injected via Linux hex Unicode input (`Ctrl+Shift+U`).
- [ ] **Sticky Modifiers:** Tap `CTRL`, `ALT`, `SHIFT`, or `SUPER`. The button visually inverts (white background, black text). Tapping subsequent keys sends modifier combination.
- [ ] **Common Shortcuts:** Tap `Ctrl+C`, `Ctrl+V`, `Alt+Tab`, `Super+D`; desktop executes shortcut actions.
- [ ] **Function Keys:** Tap `F1` through `F12`; desktop registers function keys.
- [ ] **Media Controls:** Tap Play/Pause, Next, Prev, Vol +, Vol -, Mute; media player reacts accordingly.

### 2.5 Reliability & Safety
- [ ] **Disconnect Mid-Drag:** While holding a drag or pressing mouse button, turn off phone Wi-Fi or close app. Verify `airpad-inject` automatically releases all held mouse buttons and keys. No stuck keys on desktop.
- [ ] **Reconnection:** Toggle phone Wi-Fi off and back on. Tapping the desktop receiver reconnects instantly without needing re-pairing.
- [ ] **Wakelock Screen Awake:** While in controller mode, phone screen stays awake without timing out.

---

## 3. Latency Check & Benchmarking

To measure end-to-end event latency:
1. Enable debug timestamp logging:
   - Phone side: `MoveEvent` or `ClickEvent` logs high-resolution monotonic timestamp `t0`.
   - Desktop side: `airpad-desktop` logs timestamp `t1` upon socket read.
   - Inject helper: `airpad-inject` logs timestamp `t2` upon `/dev/uinput` event emission.
2. Calculate transmission latency `t1 - t0` and injection latency `t2 - t1`.
3. Target benchmarks:
   - Median latency: `< 8 ms` over 5 GHz Wi-Fi.
   - 95th percentile (p95): `< 18 ms`.
