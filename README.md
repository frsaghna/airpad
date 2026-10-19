# AIRPAD

> **Wireless Android touchpad and keyboard for Linux desktop (Wayland & X11).**
> Zero-config LAN discovery, strict black-and-white aesthetic, TLS encryption with certificate pinning, and kernel-level `/dev/uinput` injection.

---

## Features

- **LocalSend-Style LAN Discovery:** Zero configuration needed. The desktop receiver announces over UDP multicast (`224.0.0.167:53318`) with automatic HTTP subnet scanning fallback for router AP isolation.
- **Strict Black & White Design:** Zero hue, no gradients, no drop shadows, and no blur. Pure high-contrast monochrome design system (`packages/airpad_ui`) with dark and light themes.
- **Kernel-Level Input Injection:** Lightweight Rust daemon (`airpad-inject`) creates a virtual pointer and keyboard device via Linux `/dev/uinput`. Works identically on **Wayland (Hyprland, Sway, GNOME, KDE)** and **X11**.
- **Security by Design:**
  - Unpaired devices cannot inject input.
  - 6-digit confirmation codes require explicit approval on the desktop.
  - TLS WebSocket transport with SHA-256 certificate pinning.
  - Instant revocation terminates active connections immediately (close code `4401`).
  - Unix domain socket helper uses `0600` permissions owned by the user.
  - Automatic release of all held keys and mouse buttons on client disconnection.
- **Multi-Touch Gestures:**
  - 1-finger move with customizable acceleration curve and sensitivity slider (0.5x–3.0x).
  - 1-finger tap (left click) and double tap (double click).
  - 2-finger tap (right click).
  - 3-finger tap (middle click).
  - 2-finger drag (smooth vertical & horizontal scrolling) with Natural Scrolling toggle.
  - Tap-then-hold drag.
- **Keyboard & Shortcuts:**
  - **Text Mode:** System IME integration with Unicode hex sequence translation (`Ctrl+Shift+U`) for full emoji and accented character support.
  - **Key Mode:** On-screen keys with sticky modifier latches (`Ctrl`, `Alt`, `Shift`, `Super`), quick navigation (`Esc`, `Tab`, `Enter`, `Backspace`, Arrow keys), function keys (`F1`–`F12`), and audio/media controls.

---

## Quickstart & Installation

### 1. Linux Desktop Receiver Setup

#### Option A: Binary Distribution Tarball
1. Download or build the distribution archive:
   ```bash
   ./scripts/package-desktop.sh
   ```
2. Extract and run the installer:
   ```bash
   tar -xzvf dist/airpad-linux-x86_64.tar.gz
   cd airpad-linux-x86_64
   ./install.sh
   ```

#### Option B: Arch Linux (PKGBUILD)
```bash
cd packaging
makepkg -si
```

#### Option C: Manual Setup from Source
1. **Grant `/dev/uinput` access to your user:**
   ```bash
   sudo cp helper/airpad-inject/udev/99-airpad-uinput.rules /etc/udev/rules.d/
   sudo udevadm control --reload-rules && sudo udevadm trigger
   sudo usermod -aG input $USER
   ```
   *(Log out and log back in for group membership to take effect)*

2. **Build and start `airpad-inject` helper:**
   ```bash
   cd helper/airpad-inject
   cargo build --release
   mkdir -p ~/.local/bin ~/.config/systemd/user
   cp target/release/airpad-inject ~/.local/bin/
   cp systemd/airpad-inject.service ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable --now airpad-inject.service
   ```

3. **Run Desktop Receiver:**
   ```bash
   cd apps/desktop
   flutter run -d linux
   ```

---

### 2. Android Mobile App Setup

#### Install Release APK:
Build or install the standalone release APK:
```bash
cd apps/mobile
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

#### Android Permissions:
The app requests only standard LAN and camera permissions:
- `INTERNET` & `ACCESS_NETWORK_STATE`: WebSocket communication.
- `CHANGE_WIFI_MULTICAST_STATE`: LocalSend-style UDP multicast discovery.
- `CAMERA`: Out-of-band QR code pairing.
- `WAKE_LOCK`: Keep screen awake during controller usage.

---

## Pairing & Connection

### Method 1: QR Code Pairing (Recommended)
1. In the AIRPAD desktop window, click **Pairing QR**.
2. On your phone, tap **Scan QR**.
3. Align camera with the desktop screen. The devices pair and connect instantly.

### Method 2: Automatic LAN Discovery + 6-Digit Code
1. Open AIRPAD on both devices while connected to the same Wi-Fi network.
2. The desktop receiver will appear under **Nearby Receivers** on your phone.
3. Tap **Pair & Connect**.
4. Compare the 6-digit verification code on both screens.
5. Click **Pair & Allow** on your desktop.

### Method 3: Manual IP Entry
If router AP isolation blocks multicast and broadcast discovery:
1. Tap **Enter IP** on mobile.
2. Input the desktop's local IP address (shown in the desktop window) and port (`53317`).
3. Tap **Connect**.

---

## Repository Structure

```
localkm/
├── packages/
│   ├── airpad_core/         # Pure Dart core: protocol models, crypto, TLS sessions, discovery
│   └── airpad_ui/           # Monochrome design system: AirTheme and custom widgets
├── apps/
│   ├── desktop/             # Flutter Linux desktop app with system tray
│   └── mobile/              # Flutter Android controller app
├── helper/
│   └── airpad-inject/       # Rust /dev/uinput injection daemon and test CLI
├── packaging/
│   └── PKGBUILD             # Arch Linux AUR package specification
├── scripts/
│   ├── lint.sh              # Full monorepo linter (Dart, Flutter, Clippy)
│   ├── test.sh              # Full monorepo test runner (Dart, Flutter, Cargo)
│   ├── format.sh            # Monorepo code formatter
│   └── package-desktop.sh   # Desktop release bundle builder
└── docs/
    ├── protocol.md          # Wire protocol and security specification
    ├── design.md            # Black & white design token specifications
    └── testing.md           # Manual test checklist and latency guide
```

---

## Security Architecture

1. **Strict Device Authentication:** Only devices recorded in the `TrustStore` can transmit input events. Unpaired sockets are disconnected immediately.
2. **Explicit Confirmation:** Pairing is strictly opt-in and requires user confirmation on the PC.
3. **Certificate Pinning:** The mobile app pins the desktop's SHA-256 certificate fingerprint during TLS handshakes.
4. **Immediate Revocation:** Revoking a device removes trust and terminates the active TLS session (code `4401`).
5. **Safe Key Release:** If the phone disconnects mid-drag or mid-keystroke, the helper automatically releases all held mouse buttons and keys.
6. **Strict Rate & Size Bounding:** Messages exceeding 8KB or flood rates exceeding 240 events/sec are throttled to protect system resources.

---

## Troubleshooting

### Error: `Failed to create virtual input device: Permission denied`
Your user does not have permission to write to `/dev/uinput`.
```bash
sudo cp helper/airpad-inject/udev/99-airpad-uinput.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo usermod -aG input $USER
```
Then log out and log back in. Verify permissions with:
```bash
ls -l /dev/uinput
# Expected: crw-rw---- 1 root input 10, 223 ... /dev/uinput
```

### Desktop Not Discovered on Mobile
1. Ensure both devices are connected to the same Wi-Fi subnet.
2. Check local firewall: ensure UDP port `53318` and TCP port `53318` are allowed.
   ```bash
   sudo ufw allow 53318/tcp
   sudo ufw allow 53318/udp
   ```
3. If your Wi-Fi router has AP Isolation enabled, use **Scan QR** or **Enter IP** to connect directly.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
