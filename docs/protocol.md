# AIRPAD Wire Protocol Specification (v1)

This document is the authoritative wire protocol specification for **AIRPAD**, an open-source wireless touchpad and keyboard system connecting an Android phone (controller) to a Linux desktop (receiver).

---

## 1. Network & Protocol Defaults

- **Transport Port:** `53318` (TCP and UDP).
- **Multicast Group:** `224.0.0.167` (IPv4).
- **Protocol Version:** `"airpad/1"`.
- **Session Endpoint:** `wss://<receiver-ip>:53318/v1/session`.
- **Registration Endpoint (HTTP Fallback):** `http://<receiver-ip>:53318/v1/register`.
- **IPC Helper Socket:** `$XDG_RUNTIME_DIR/airpad/inject.sock` (permissions `0600`).

---

## 2. Device Identity & Cryptography

Every device (controller and receiver) creates a dedicated cryptographic identity on its first launch:
1. **Keypair & Certificate:** Generates a 2048-bit RSA or ECDSA (P-256) private key and a self-signed X.509 certificate valid for 10 years.
2. **Fingerprint:** The SHA-256 digest of the DER-encoded certificate, represented as a 64-character lowercase hexadecimal string:
   ```
   SHA256(CertificateDER) -> "a1b2c3d4e5f6..."
   ```
   For user display, the **short fingerprint** is formatted as the first 8 or 12 characters grouped: `a1b2-c3d4-e5f6`.
3. **Alias:** A friendly two-word name generated randomly from a curated list (e.g., "Quiet Falcon", "Swift Cedar"), stored locally and editable by the user.
4. **Device Type:** `"desktop"` or `"mobile"`.

---

## 3. LAN Discovery

Discovery operates without centralized servers or external internet access. Three discovery mechanisms are supported in priority order:

### 3.1 UDP Multicast Announce (Primary)

Receivers and controllers communicate via UDP packets to multicast address `224.0.0.167:53318`.

#### Discovery Message Payload (JSON)
```json
{
  "version": "airpad/1",
  "alias": "Quiet Falcon",
  "fingerprint": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "port": 53318,
  "deviceType": "desktop",
  "announce": true
}
```

#### Protocol Rules:
1. **Periodic Announce:** When advertising is enabled, the desktop receiver broadcasts a multicast packet every 3 seconds.
2. **Controller Query:** When the mobile app opens the discovery screen, it broadcasts an announce packet with `"announce": true`.
3. **Receiver Response:** Any receiver seeing an announce with `"announce": true` replies with its own packet having `"announce": false` (either to the multicast group or unicast to the sender) to avoid infinite ping-pong loops.
4. **Self-filtering:** Devices must ignore packets matching their own certificate fingerprint.

### 3.2 HTTP Subnet Registration (Fallback)

If multicast is blocked by the local Wi-Fi router (common in enterprise networks, guest networks, or AP-isolated environments):
1. The controller determines the local subnet mask (e.g., `192.168.1.0/24`).
2. The controller sends asynchronous HTTP `POST` requests to `http://<ip>:53318/v1/register`.
3. Request Body:
   ```json
   {
     "version": "airpad/1",
     "alias": "Clever Otter",
     "fingerprint": "1234abcd5678ef90...",
     "port": 53318,
     "deviceType": "mobile"
   }
   ```
4. Receiver Response: `200 OK` with the receiver's JSON identity payload.

### 3.3 Manual IP & QR Code Fallback

Users can manually enter an IP address or scan a QR code presented on the desktop.

#### QR Code Payload Format
```
airpad://v1?ip=192.168.1.42&port=53318&fp=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855&code=849201&alias=Quiet%20Falcon
```
Parameters:
- `ip`: IPv4 address of the receiver.
- `port`: Listening port (default 53318).
- `fp`: SHA-256 certificate fingerprint of the receiver.
- `code`: Temporary 6-digit pairing code (valid for 5 minutes).
- `alias`: URL-encoded receiver alias.

---

## 4. Pairing & Trust State Machine

Connections from unauthenticated devices must never be permitted to inject input.

### 4.1 First Connection (Manual Pairing Flow)
1. Controller initiates a TLS connection to `wss://<receiver-ip>:53318/v1/session`.
2. During the TLS handshake, both parties inspect the remote certificate fingerprint.
3. If the controller's fingerprint is **not** in the receiver's trusted list:
   - The desktop receiver creates an ephemeral **6-digit pairing code** (e.g. `849201`).
   - The desktop displays an elevated, modal pairing prompt showing:
     - Phone alias
     - Short fingerprint (`1234-abcd-5678`)
     - The 6-digit pairing code
   - Over the WebSocket connection, the receiver sends:
     ```json
     { "type": "pair_prompt", "code": "849201", "fingerprint": "<desktop_fingerprint>" }
     ```
   - The phone screen displays the 6-digit code and waits.
   - User verifies that the numbers match and clicks **"Pair & Allow"** on the Linux desktop.
   - On accept:
     - Receiver writes controller's fingerprint and alias to its persistent trusted device store.
     - Receiver sends `{ "type": "pair_ok" }`.
     - Controller adds desktop fingerprint to its persistent trusted store.
     - Session transitions to `ACTIVE`.
   - On reject or timeout (60 seconds):
     - Receiver closes the WebSocket with code `4403 (Pairing Rejected)`.

### 4.2 QR Code Pairing Flow
Because the desktop fingerprint and one-time code are transmitted visually out-of-band:
1. Phone connects via TLS, providing the QR code's one-time token in the initial greeting:
   ```json
   { "type": "pair_qr", "code": "849201", "alias": "Clever Otter", "fingerprint": "..." }
   ```
2. The desktop automatically verifies the code and fingerprint, skips the manual digit check, displays an informative toast ("Paired with Clever Otter via QR"), and marks the device as trusted.

### 4.3 Certificate Pinning & Auto-Reconnect
- Once paired, whenever a WebSocket connection is established, the client pins the server's certificate against the stored fingerprint.
- The server pins the client certificate against its trusted device table.
- If the fingerprint does not match, the connection is instantly aborted without prompting.
- If "Ask every time" is toggled on the desktop, trusted devices still require a single confirmation click before input streaming begins.

### 4.4 Revocation
- The desktop UI allows revoking any trusted device with a single click.
- Revocation immediately terminates any active WebSocket session (`CloseCode 4401`) and purges the fingerprint from disk.

---

## 5. Session Management

- **Endpoint:** `wss://<ip>:53318/v1/session`
- **Heartbeat:** Controller sends a `ping` message every 2,000 ms. Receiver replies with `pong`.
  - If three consecutive pings are missed (6 seconds), either side terminates the socket.
- **State Cleanup:** Upon socket termination (graceful or abrupt):
  - Desktop releases all held mouse buttons and keyboard keys immediately.
  - Desktop clears the active controller status.

---

## 6. Event Schema

All events across the WebSocket and IPC helper are formatted as newline-delimited or framed JSON objects.

### 6.1 `move` (Relative Pointer Motion)
Coalesced on the controller and transmitted at 60–120 Hz.
```json
{
  "type": "move",
  "dx": 2.45,
  "dy": -1.12
}
```
- `dx`: Horizontal relative delta in logical points.
- `dy`: Vertical relative delta in logical points.

### 6.2 `scroll` (Two-Finger Scroll)
```json
{
  "type": "scroll",
  "dx": 0.0,
  "dy": -15.0
}
```
- `dx`: Horizontal scroll delta.
- `dy`: Vertical scroll delta (negative is usually down; subject to desktop natural-scroll settings).

### 6.3 `button` (Mouse Button State)
```json
{
  "type": "button",
  "button": "left",
  "state": "down"
}
```
- `button`: `"left" | "right" | "middle"`
- `state`: `"down" | "up"`

### 6.4 `click` (Convenience Tap)
```json
{
  "type": "click",
  "button": "left",
  "count": 1
}
```
- `button`: `"left" | "right" | "middle"`
- `count`: `1` (single click) or `2` (double click).

### 6.5 `key` (Physical Keyboard Key)
```json
{
  "type": "key",
  "code": "KeyA",
  "state": "down",
  "mods": ["ctrl"]
}
```
- `code`: W3C KeyboardEvent `code` or Linux input key name (e.g. `"KeyA"`, `"Enter"`, `"Backspace"`, `"Escape"`, `"Tab"`, `"ArrowUp"`, `"F1"` - `"F12"`, `"ControlLeft"`, `"AltLeft"`, `"ShiftLeft"`, `"SuperLeft"`).
- `state`: `"down" | "up"`.
- `mods`: Array of active modifier strings: `["ctrl", "alt", "shift", "meta"]`.

### 6.6 `text` (Composed Text / IME)
Used when typing with Android keyboard autocomplete, emoji, or non-Latin scripts.
```json
{
  "type": "text",
  "value": "Hello, world! 🚀"
}
```
- `value`: UTF-8 string to be inserted.

#### Linux Non-ASCII Text Injection Strategy:
1. **ASCII Characters:** For standard ASCII printable characters (`0x20` to `0x7E`), the desktop/helper translates characters into synthetic `KEY_*` presses with appropriate Shift state.
2. **Unicode / Non-ASCII Characters:**
   - **Primary Strategy (Wayland & X11 Clipboard Paste):** The desktop application copies the text to the system clipboard via standard Wayland/X11 protocols and synthesizes a `Ctrl+V` (or `Ctrl+Shift+V` in terminals) key sequence.
   - **Fallback Strategy (Unicode Hex Sequence):** Synthesizes Linux standard `Ctrl+Shift+U <hex> Enter` unicode input sequence.
   The clipboard paste approach is default for general text strings because it supports arbitrary UTF-8 characters and emojis uniformly across Wayland and X11 compositors.

### 6.7 `media` (Media Keys)
```json
{
  "type": "media",
  "action": "play_pause"
}
```
- `action`: `"play_pause" | "volume_up" | "volume_down" | "volume_mute" | "next_track" | "prev_track"`

### 6.8 `settings` (Runtime Settings Sync)
```json
{
  "type": "settings",
  "sensitivity": 1.25,
  "naturalScroll": true
}
```

---

## 7. Helper IPC Protocol (Desktop App -> `airpad-inject`)

- **Socket Path:** `$XDG_RUNTIME_DIR/airpad/inject.sock`
- **Socket Permissions:** `0600` (User-only read/write).
- **Transport:** Unix Domain Stream Socket.
- **Framing:** Newline-delimited JSON (`\n`).
- **Validation:** The desktop app validates all messages before relaying them to the helper. The helper performs sanity checks (e.g. bounded floats, valid enum strings) and converts them to Linux `uinput` kernel events via `/dev/uinput`.
- **Release-on-Disconnect:** If the Unix socket closes or encounters EOF, the helper immediately issues `SYN_REPORT` releases for all currently down keys and buttons to guarantee no keys remain stuck.
