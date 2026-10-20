# AIRPAD

> **Turn your Android phone into a wireless trackpad and keyboard for Linux.**  
> Seamless zero-config Wi-Fi discovery, kernel-level `/dev/uinput` injection, strict monochrome aesthetic, and end-to-end TLS encryption. Works natively on **Wayland** (Hyprland, Sway, GNOME, KDE) and **X11**.

---

## ⚡ Quick Start

### 1. Install Desktop Receiver (Linux)

Pre-built binaries are ready in [`dist/`](dist/):

```bash
# Extract the release bundle
tar -xzf dist/airpad-linux-x86_64.tar.gz
cd airpad-linux-x86_64

# Run installer (do NOT run with sudo; it prompts for sudo only when needed)
./install.sh
```

Then launch **AIRPAD** from your application launcher or terminal:
```bash
airpad
```

> **Arch Linux users:** You can also install directly with `cd packaging && makepkg -si`.

---

### 2. Install Mobile App (Android)

Install the pre-built APK from [`dist/airpad-mobile.apk`](dist/airpad-mobile.apk):

```bash
# Via ADB:
adb install dist/airpad-mobile.apk

# Or copy dist/airpad-mobile.apk to your phone and install it.
```

---

### 3. Connect

Open **AIRPAD** on both devices while connected to the same Wi-Fi network:

- **Method A — QR Code (Recommended):** Click **Pair via QR Code** on desktop, then tap **Scan QR** on your phone.
- **Method B — Auto-Discovery:** Your PC appears under **Discovered Receivers** on the phone. Tap **Pair & Connect** and confirm the 6-digit code on your desktop.
- **Method C — Manual IP:** If your router has AP/Client isolation, tap **Enter IP** on mobile, enter your PC's local IP and port `53318`.

---

## 🖐️ Gesture & Control Cheat Sheet

| Gesture | Action |
| :--- | :--- |
| **1-Finger Drag** | Move mouse cursor (with natural acceleration) |
| **1-Finger Tap** | Left Click |
| **1-Finger Double-Tap** | Double Click |
| **2-Finger Tap** | Right Click |
| **3-Finger Tap** | Middle Click |
| **2-Finger Drag** | Smooth Vertical & Horizontal Scrolling |
| **Tap & Hold, then Drag** | Window drag / Text selection |
| **3-Finger Swipe Up / Down** | Open App Overview / Super Key *(Toggle in Settings)* |
| **3-Finger Swipe Left / Right** | Switch Workspaces *(Toggle in Settings)* |

---

## ⌨️ Controller Modes

Switch between modes using the top tabs on your mobile controller:

1. **Touchpad:** Full-screen responsive touch surface with dedicated Left, Middle, and Right click buttons, plus sticky latch buttons for **Ctrl**, **Alt**, and **Super**.
2. **Shortcuts:** One-tap productivity triggers (`Ctrl+C`, `Ctrl+V`, `Alt+Tab`, `Alt+F4`, `Super+D`, `Ctrl+Alt+T`) and function keys (`F1`–`F12`).
3. **Media:** Dedicated playback controls (Play/Pause, Next, Prev, Volume Up/Down, Mute).
4. **Text Streaming:** Tap the keyboard icon in the header to open your native phone keyboard and stream text or emoji directly to your PC.

---

## 🎨 Themes & Frameless Window

- **Dark & Light Themes:** Toggle between dark mode and high-contrast light mode anytime using the theme button (`☀` / `☾`) in the top bar of both apps.
- **Frameless Window:** The desktop receiver window is undecorated without window manager borders or headerbars. Close it anytime with the integrated `✕` button in the app bar or via your window manager (`Super+C` on Hyprland, `Alt+F4`, etc.).

---

## 🔧 Common Fixes & Troubleshooting

### Desktop not discovered on phone?
1. Make sure both devices are on the same Wi-Fi network.
2. Allow port `53318` on your firewall:
   ```bash
   sudo ufw allow 53318/tcp
   sudo ufw allow 53318/udp
   ```
3. If your router blocks multicast (AP Isolation), connect directly using **Scan QR** or **Enter IP**.

### Check the background input service:
AIRPAD uses a lightweight Rust helper (`airpad-inject`) to create a virtual input device at `/dev/uinput`:
```bash
# Check service status
systemctl --user status airpad-inject

# Restart service
systemctl --user restart airpad-inject
```

### Permission denied for `/dev/uinput`?
Ensure your user is in the `input` group:
```bash
sudo usermod -aG input $USER
```
*(Log out and back in for group changes to take effect).*

---

## 🛠️ Building from Source

Requirements: Flutter SDK 3.x+, Rust & Cargo, and Linux development headers (`libgtk-3-dev`).

```bash
# Run all tests (Core, UI, Desktop, Mobile, and Rust)
./scripts/test.sh

# Build desktop release package
./scripts/package-desktop.sh

# Build mobile Android APK
cd apps/mobile && flutter build apk --release
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
