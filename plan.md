# AIRPAD — Build Plan

> Working title. Rename freely; keep it in one constant.

Turn an Android phone into a wireless **touchpad + keyboard** for a Linux desktop over local Wi-Fi. Devices find and pair with each other the way **LocalSend** does: no accounts, no servers, no typing IP addresses.

This document is the single source of truth for the agent building it. Read it fully before writing code. Follow the phases in order. Do not skip acceptance criteria.

---

## 1. Goals and Non-Goals

### Goals
- Android app (phone) acts as touchpad and keyboard for a Linux PC.
- Linux desktop app receives events and injects them as real system input.
- LocalSend-like connection UX: automatic LAN discovery, friendly aliases, one-tap pairing.
- Works on **Wayland and X11** (Hyprland is a primary target).
- Low latency pointer movement (target: feels instant on a normal home Wi-Fi).
- Secure by default: a rogue device on the LAN must not be able to type on the PC.
- Strict black and white visual design (see Section 8).

### Non-Goals (v1)
- iOS, Windows, macOS clients.
- Screen mirroring, file transfer, clipboard sync.
- Internet / relay connections. LAN only.
- Bluetooth HID mode.
- Gamepad emulation.

---

## 2. Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| Mobile app | Flutter (Android) | Touchpad surface, keyboard, pairing UI |
| Desktop app | Flutter (Linux, GTK) | Receiver UI, tray, pairing prompts, networking |
| Shared logic | Dart package `airpad_core` | Protocol, discovery, crypto, models. Used by both apps |
| Input injection | Small **Rust** helper `airpad-inject` | Writes to `/dev/uinput`. Reads events from a local Unix socket |
| Transport | WebSocket over TLS (control + events) | Self-signed cert per device |
| Discovery | UDP multicast + HTTP register fallback | LocalSend-style |

**Decision record:** networking lives in Dart (shared by both apps) and the Rust helper is deliberately tiny and dumb. If Rust is unavailable or unwanted, Go is an acceptable substitute. Do not rewrite networking in the helper.

---

## 3. Repository Layout

```
airpad/
├── plan.md
├── README.md
├── packages/
│   └── airpad_core/          # Dart: protocol, discovery, crypto, models, tests
├── apps/
│   ├── mobile/               # Flutter Android app
│   └── desktop/              # Flutter Linux app
├── helper/
│   └── airpad-inject/        # Rust: uinput helper + udev rules + systemd user unit
├── docs/
│   ├── protocol.md           # Wire protocol spec (written in Phase 0)
│   └── design.md             # Design system (from Section 8)
└── scripts/                  # Dev scripts (run, lint, package)
```

Use a Dart workspace / melos (or plain path dependencies). Keep `airpad_core` free of Flutter imports so it is unit-testable with `dart test`.

---

## 4. Architecture

```
 ┌─────────────────────┐        Wi-Fi (LAN)        ┌──────────────────────────┐
 │  Android app        │                           │  Linux desktop app       │
 │  ─ touchpad UI      │  1. UDP multicast announce│  ─ discovery listener    │
 │  ─ keyboard UI      │ ◄───────────────────────► │  ─ TLS WebSocket server  │
 │  ─ airpad_core      │  2. TLS WebSocket session │  ─ pairing prompt + tray │
 └─────────────────────┘ ────────────────────────► │  ─ airpad_core           │
                                                   └────────────┬─────────────┘
                                                                │ Unix socket
                                                                ▼
                                                   ┌──────────────────────────┐
                                                   │  airpad-inject (Rust)    │
                                                   │  ─ /dev/uinput           │
                                                   └──────────────────────────┘
```

**Roles**
- The **desktop** is the *receiver*: it listens, shows pairing prompts, injects input.
- The **phone** is the *controller*: it discovers receivers, initiates pairing, streams events.

---

## 5. Protocol Specification

Write the final version into `docs/protocol.md` during Phase 0. The sections below are the required contents.

### 5.1 Defaults
- Port: `53318` (TCP and UDP). Deliberately different from LocalSend (`53317`) so both can run on one machine.
- Multicast group: `224.0.0.167` (same range LocalSend uses; some Android devices reject other groups).
- Protocol version string: `"airpad/1"`.

### 5.2 Device identity
- On first launch each device generates a self-signed TLS certificate and stores it.
- **Fingerprint** = SHA-256 of the certificate (hex).
- **Alias** = random friendly two-word name (e.g. "Quiet Falcon"), user-editable.

### 5.3 Discovery
1. **Multicast announce (default):** on startup and on a short interval, the receiver sends a UDP multicast message containing `{version, alias, fingerprint, port, deviceType, announce}`.
2. The phone listens, shows receivers in a list, and can also send its own announce with `announce: true`. Receivers reply with `announce: false` to avoid loops.
3. **HTTP register fallback:** if multicast fails (AP isolation, VPN), the phone scans the local subnet and calls `POST /v1/register` on port `53318`.
4. **Manual fallback:** enter IP, or scan a **QR code** shown on the desktop (encodes IP, port, fingerprint, one-time pairing code).

Discovery is **unauthenticated**. Never trust an alias. Always show the fingerprint (shortened) during pairing.

### 5.4 Pairing
- First connection from an unknown fingerprint: the desktop shows a **pairing prompt** with the phone alias, short fingerprint, and a **6-digit code** displayed on both screens. The user must confirm on the desktop.
- On accept, both sides store each other's fingerprint ("trusted devices").
- Later connections from a trusted fingerprint auto-connect (user can toggle "ask every time").
- Certificate **pinning**: after pairing, the phone only connects to the stored fingerprint, and the desktop only accepts the stored phone fingerprint (mutual TLS or equivalent signed handshake).
- QR pairing skips the code compare because the fingerprint arrives out of band.

### 5.5 Session
- Single WebSocket per session at `wss://<ip>:53318/v1/session`.
- Heartbeat ping/pong every 2 s. Three missed → disconnect and show state.
- Desktop can **revoke** a device at any time (closes session, deletes trust).

### 5.6 Event messages
JSON for v1 (switch to a compact binary encoding only if profiling shows a need).

| `type` | Fields | Notes |
|---|---|---|
| `move` | `dx`, `dy` | Relative deltas, coalesced on the phone |
| `scroll` | `dx`, `dy` | Two-finger scroll; support natural direction toggle |
| `button` | `button` (`left`/`right`/`middle`), `state` (`down`/`up`) | Down/up so drag works |
| `click` | `button`, `count` | Convenience for tap and double tap |
| `key` | `code`, `state` (`down`/`up`), `mods` | Physical-style key events (arrows, F-keys, ctrl combos) |
| `text` | `value` | Composed text (IME, emoji, non-Latin) |
| `media` | `action` | Play/pause, volume, next, prev |
| `settings` | `sensitivity`, `naturalScroll`, … | Optional runtime sync |

Rules:
- `move` events are sent at a **fixed tick (~60–120 Hz)**, coalescing deltas between ticks.
- Every `button down` must be paired with an `up`. On disconnect, the desktop **releases all held buttons and keys**.
- Unknown message types are ignored, not fatal.
- Rate-limit incoming events on the desktop to prevent flooding.

### 5.7 Helper IPC (desktop app → `airpad-inject`)
- Unix domain socket in `$XDG_RUNTIME_DIR/airpad/inject.sock`, permissions `0600`.
- Newline-delimited JSON, same event schema as 5.6 (already validated by the desktop app).
- The helper **never** listens on the network.

---

## 6. Linux Desktop Side

### 6.1 Input injection (`airpad-inject`)
- Create a virtual device via `/dev/uinput` exposing relative pointer, buttons, wheel, and a keyboard.
- Works at kernel level, independent of X11/Wayland.
- Requires access to `/dev/uinput`:
  - Ship a **udev rule** granting an `input`-style group access, and a documented one-time setup (`install.sh` or first-run instructions).
  - Ship a **systemd user unit** to run the helper.
- Key mapping: map protocol key codes to Linux `KEY_*` codes. `text` events need a strategy for characters that have no direct keycode (see risks, Section 10).
- Must release all pressed keys/buttons when the client disconnects or the helper exits.

### 6.2 Desktop app
- System tray icon with states: idle, advertising, connected.
- Window shows: this device's alias and fingerprint, list of trusted devices, current connection, toggles (ask every time, start on login), QR code for pairing.
- Handles pairing prompts as a focused dialog (and a notification if minimized).
- Autostart option (XDG autostart entry).

---

## 7. Android Side

### 7.1 Screens
1. **Discover** — list of nearby receivers (alias, short fingerprint, status). Pull to refresh. Buttons: Scan QR, Enter IP.
2. **Pairing** — shows the 6-digit code, waits for desktop confirm.
3. **Controller** — the main screen: big touchpad surface, mouse buttons, keyboard toggle, modifiers row, media row (collapsible).
4. **Settings** — alias, sensitivity, scroll direction, haptics, keep screen on, trusted devices.

### 7.2 Touchpad gestures
- One finger move → `move`
- One finger tap → left click; double tap → double click
- Two finger tap → right click
- Two finger drag → scroll
- Tap-then-hold-drag → drag (button down, move, button up)
- Three finger tap → middle click (optional)
- Pointer acceleration curve with a sensitivity slider. Tune on a real device.
- Optional haptic tick on click.

### 7.3 Keyboard
Two modes, user-switchable:
- **Text mode:** system IME feeding `text` events (handles autocorrect, emoji, other scripts).
- **Key mode:** custom on-screen keys with modifiers (Ctrl, Alt, Shift, Super), arrows, Esc, Tab, F-keys, sending `key` events.

### 7.4 Platform concerns
- Acquire a **multicast lock** to receive multicast on Android.
- Keep the connection alive while the screen is on (wake lock / keep-screen-on option). Handle OEM battery managers gracefully with clear reconnect behavior.
- Request only the permissions needed (network state, Wi-Fi state, multicast, camera for QR).

---

## 8. Design System — Black and White

The entire UI, on both platforms, is **strictly monochrome**. No accent colors. No gradients. No shadows. No blur.

### 8.1 Palette

| Token | Value | Use |
|---|---|---|
| `black` | `#000000` | Primary background |
| `white` | `#FFFFFF` | Primary text, active fills |
| `gray-900` | `#111111` | Raised surfaces |
| `gray-700` | `#2A2A2A` | Borders, dividers |
| `gray-500` | `#777777` | Secondary text, disabled |
| `gray-100` | `#EDEDED` | Light-theme surface |

- **Default theme is dark** (black background, white text).
- Provide an optional **inverted light theme** (white background, black text), same tokens swapped. No other colors.

### 8.2 State without color
Communicate state with **inversion, fills, borders, and icons**, never hue:
- Selected / active / connected → solid white fill with black text (inverted).
- Idle → black with a 1 px white or gray border.
- Disabled → gray-500 text and border.
- Errors → inverted block with a clear text label and icon (never red). Always pair status with words.

### 8.3 Typography
- Bundle fonts locally (no network font loading). One monospace for labels, codes, and fingerprints (e.g. JetBrains Mono) and one clean sans for body (e.g. Inter).
- Few sizes, strong hierarchy. Uppercase small labels with letter spacing for section headers.
- Pairing codes and fingerprints in monospace, large.

### 8.4 Shape and layout
- 1 px borders, sharp or very slightly rounded corners (pick one radius token, ≤ 4 px, and keep it everywhere).
- Generous spacing, 8 px grid.
- Icons: simple outline icons, consistent stroke weight.
- Touch targets ≥ 48 dp on mobile.
- The **touchpad surface** is a large bordered rectangle with a subtle dot-grid or empty field; the active touch shows a thin white ring following the finger. Nothing decorative that distracts from the surface.
- Motion: minimal and fast (≤ 150 ms), mostly fades and inversions. Respect "reduce motion".

### 8.5 Implementation
- Define all tokens in one `design_tokens.dart` inside `airpad_core` (or a shared `airpad_ui` package) and build a `ThemeData` from it. No hard-coded colors in widgets.
- Build shared widgets once: `AirButton`, `AirCard`, `AirTile`, `AirToggle`, `AirCodeBox`, `AirStatusBadge`.
- Document it in `docs/design.md`.

---

## 9. Security Requirements

These are mandatory, not optional polish. A paired device can type on the PC, so treat it as remote code execution risk.

1. No unpaired device can send input. Ever.
2. Pairing requires explicit confirmation **on the desktop**.
3. TLS everywhere; certificate pinning after pairing.
4. Show fingerprint (shortened) in every pairing and device-management view.
5. Revoke device → session closes immediately and trust is deleted.
6. Helper socket is `0600`, owned by the user, never network-exposed.
7. Validate and bound every incoming message (size, rate, field ranges).
8. On any disconnect: release all held keys and buttons.
9. Visible **"controlled by <alias>"** indicator on the desktop while a session is active, plus a one-click "disconnect all".
10. Optional: a global panic hotkey on the desktop that kills the session.

---

## 10. Known Risks and Decisions Needed

| Risk | Plan |
|---|---|
| `text` events for characters without a direct keycode | Start with a keycode map for ASCII. For others, evaluate Unicode input via the compositor/IME (e.g. clipboard + paste, or Ctrl+Shift+U sequences) and document the chosen method in `docs/protocol.md` |
| Multicast blocked on some networks | HTTP subnet scan, manual IP, and QR fallbacks are all required in v1 |
| Wi-Fi jitter causes pointer stutter over TCP | Measure first. Only add a UDP side channel for `move` if measured stutter is unacceptable |
| `/dev/uinput` permission friction | Provide an installer script and clear first-run diagnostics ("input helper not authorized, run X") |
| Android background kills | Keep-screen-on mode first; foreground service only if needed |
| Flutter Linux tray support is limited | Use a maintained tray package; confirm it works on Hyprland/Waybar-style setups early (Phase 1 spike) |

---

## 11. Phases

Each phase ends with a **demo** and **acceptance criteria**. Do not start the next phase until the current one passes. Commit at the end of each phase with a clear message.

### Phase 0 — Foundations
- Create the monorepo layout from Section 3.
- Write `docs/protocol.md` from Section 5 and `docs/design.md` from Section 8.
- Set up lint, format, and CI-style local scripts.
- Create `airpad_core` with: models (Device, Event), design tokens, and unit-test scaffolding.

**Accept:** repo builds, `dart test` passes, docs exist and match this plan.

### Phase 1 — Linux injection spike
- Build `airpad-inject`: create a virtual mouse + keyboard, accept JSON events over the Unix socket.
- Write a tiny CLI to send test events (move in a square, click, type "hello").
- Write the udev rule and install script.
- Spike: confirm Flutter desktop tray works on the target compositor.

**Accept:** test CLI moves the cursor, clicks, and types on **both Wayland (Hyprland) and X11**. Killing the helper never leaves a key stuck.

### Phase 2 — Discovery
- Implement multicast announce/listen, HTTP register fallback, and subnet scan in `airpad_core`.
- Desktop advertises; phone lists receivers live.
- Alias generation and persistence; certificate generation and fingerprinting.

**Accept:** phone shows the desktop within ~2 s on the same Wi-Fi. With multicast artificially blocked, the fallback still finds it. Self-discovery is filtered out.

### Phase 3 — Secure session and pairing
- TLS WebSocket server (desktop) and client (phone).
- Pairing flow with 6-digit code and desktop confirmation; trusted-device storage; pinning.
- QR pairing flow.
- Heartbeat, reconnect, revoke.

**Accept:** unpaired device is rejected. Paired device reconnects automatically. Revoking disconnects immediately. A second phone with a different fingerprint cannot hijack a trusted slot.

### Phase 4 — Touchpad MVP
- Controller screen with the touchpad surface.
- Gestures from 7.2 → protocol events → desktop → helper.
- Fixed-rate move coalescing; sensitivity setting.

**Accept:** pointer control feels smooth on a real phone and real network. Tap, right click, scroll, and drag all work. No stuck buttons after disconnect.

### Phase 5 — Keyboard
- Text mode and key mode.
- Modifier handling, arrows, F-keys, media keys.
- Implement the chosen strategy for non-ASCII text.

**Accept:** can type a sentence, use Ctrl+C / Ctrl+V / Alt+Tab, and send at least one non-ASCII string correctly.

### Phase 6 — UX polish in black and white
- Apply the full design system to every screen on both apps; build shared widgets.
- Empty, error, and loading states, all monochrome and labeled in words.
- Desktop "controlled by" indicator, disconnect-all control, tray states.
- Settings screens, haptics, keep-screen-on, autostart.

**Accept:** a screenshot audit shows **zero** non-gray pixels in UI chrome. All state is distinguishable without color. Every screen follows the tokens.

### Phase 7 — Hardening and packaging
- Fuzz and bound incoming messages; add rate limiting.
- Test on at least two different Wi-Fi networks and one with multicast disabled.
- Android release build (signed APK).
- Linux packaging: AppImage and/or AUR `PKGBUILD`, with the helper, udev rule, and systemd user unit included.
- Write `README.md` with screenshots, install steps, and troubleshooting.

**Accept:** fresh-machine install following only the README works end to end.

---

## 12. Testing Strategy

- **Unit:** protocol encode/decode, event coalescing, fingerprint, pairing state machine, key mapping (`dart test`, `cargo test`).
- **Integration:** loopback test running a fake phone client against the desktop session layer.
- **Manual device checklist** (keep in `docs/testing.md`): discovery, pairing, each gesture, each key type, disconnect mid-drag, Wi-Fi drop and reconnect, screen off/on, revoke.
- **Latency check:** log timestamps phone-side and desktop-side in a debug build; report median and p95.

---

## 13. Rules for the Agent

1. Work phase by phase. Finish and verify before moving on.
2. After each phase, summarize what was built, what was tested, and what is unresolved.
3. Do not add features outside the non-goals list without asking.
4. Never weaken Section 9. If something conflicts with it, stop and ask.
5. No hard-coded colors outside the design tokens. No network font loading.
6. Prefer small, well-named files and clear module boundaries. Keep `airpad_core` Flutter-free.
7. Every public function in `airpad_core` gets a unit test.
8. When a decision is unclear (see Section 10), write the options and the choice into the relevant doc and continue with the safest option.
9. Keep a running `CHANGELOG.md`.

---

## 14. Definition of Done (v1)

- Phone discovers the PC automatically, pairs with a code or QR, and reconnects without friction.
- Smooth touchpad with all listed gestures; full keyboard in both modes.
- Works on Wayland and X11.
- Unpaired devices cannot inject input; user can revoke any device instantly.
- UI is strictly black and white, consistent across both apps.
- Installable from the README on a clean Linux machine and a clean Android phone.
