#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
STAGE_DIR="${DIST_DIR}/airpad-linux-x86_64"

echo "=== Packaging AIRPAD for Linux (x86_64) ==="

rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}/bin"
mkdir -p "${STAGE_DIR}/udev"
mkdir -p "${STAGE_DIR}/systemd"

# 1. Build Rust injection helper
echo "--- Compiling airpad-inject helper (Rust release) ---"
(cd "${SCRIPT_DIR}/helper/airpad-inject" && cargo build --release)
cp "${SCRIPT_DIR}/helper/airpad-inject/target/release/airpad-inject" "${STAGE_DIR}/bin/"
cp "${SCRIPT_DIR}/helper/airpad-inject/target/release/airpad-test-cli" "${STAGE_DIR}/bin/"

# 2. Build Flutter Linux desktop application
echo "--- Compiling AIRPAD desktop receiver (Flutter release) ---"
(cd "${SCRIPT_DIR}/apps/desktop" && flutter build linux --release)

# Copy Flutter release bundle
FLUTTER_BUNDLE="${SCRIPT_DIR}/apps/desktop/build/linux/x64/release/bundle"
cp -r "${FLUTTER_BUNDLE}"/* "${STAGE_DIR}/"

# Rename flutter executable to airpad alongside lib/ and data/
mv "${STAGE_DIR}/desktop" "${STAGE_DIR}/airpad" 2>/dev/null || true

# 3. Copy systemd user unit and udev rules
cp "${SCRIPT_DIR}/helper/airpad-inject/systemd/airpad-inject.service" "${STAGE_DIR}/systemd/"
cp "${SCRIPT_DIR}/helper/airpad-inject/udev/99-airpad-uinput.rules" "${STAGE_DIR}/udev/"

# 4. Generate Desktop Launcher entry
cat << 'EOF' > "${STAGE_DIR}/airpad.desktop"
[Desktop Entry]
Name=AIRPAD
Comment=Wireless Touchpad & Keyboard Receiver
Exec=airpad
Icon=airpad
Terminal=false
Type=Application
Categories=Utility;HardwareSettings;
Keywords=touchpad;mouse;keyboard;remote;
EOF

# 5. Generate installer script
cat << 'EOF' > "${STAGE_DIR}/install.sh"
#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect target user context
if [ "$EUID" -eq 0 ]; then
  if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    REAL_UID=$(id -u "$SUDO_USER")
  else
    REAL_USER="root"
    REAL_HOME="$HOME"
    REAL_UID=0
  fi
else
  REAL_USER="$USER"
  REAL_HOME="$HOME"
  REAL_UID="$UID"
fi

echo "=== Installing AIRPAD on Linux (Target user: ${REAL_USER}) ==="

# 1. Install udev rule (requires root/sudo)
echo "--- 1. Configuring /dev/uinput permissions (udev) ---"
if [ "$EUID" -eq 0 ]; then
  cp "${DIR}/udev/99-airpad-uinput.rules" /etc/udev/rules.d/
  udevadm control --reload-rules && udevadm trigger
  echo "✓ Udev rule installed to /etc/udev/rules.d/99-airpad-uinput.rules"
  if [ "$REAL_USER" != "root" ]; then
    usermod -aG input "$REAL_USER" 2>/dev/null || true
  fi

  # Configure UFW if installed and active
  if command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -q "Status: active"; then
      ufw allow 53318/tcp comment 'AIRPAD Session' >/dev/null 2>&1 || true
      ufw allow 53318/udp comment 'AIRPAD Discovery' >/dev/null 2>&1 || true
      echo "✓ UFW firewall rules added for port 53318 (TCP/UDP)."
    fi
  fi
else
  if [ -f /etc/udev/rules.d/99-airpad-uinput.rules ]; then
    echo "✓ Udev rule already installed in /etc/udev/rules.d/"
  else
    echo "Requesting sudo to install /etc/udev/rules.d/99-airpad-uinput.rules..."
    if command -v sudo >/dev/null 2>&1; then
      sudo cp "${DIR}/udev/99-airpad-uinput.rules" /etc/udev/rules.d/
      sudo udevadm control --reload-rules && sudo udevadm trigger
      sudo usermod -aG input "$REAL_USER" 2>/dev/null || true
      echo "✓ Udev rule installed."
    else
      echo ">>> NOTE: To grant permissions to /dev/uinput, run:"
      echo "  sudo cp \"${DIR}/udev/99-airpad-uinput.rules\" /etc/udev/rules.d/"
      echo "  sudo udevadm control --reload-rules && sudo udevadm trigger"
    fi
  fi
fi

# 2. Install application files into user space
BIN_DIR="${REAL_HOME}/.local/bin"
APP_DIR="${REAL_HOME}/.local/share/applications"
LIB_DIR="${REAL_HOME}/.local/lib/airpad"
SYSTEMD_USER_DIR="${REAL_HOME}/.config/systemd/user"

mkdir -p "${BIN_DIR}" "${APP_DIR}" "${LIB_DIR}" "${SYSTEMD_USER_DIR}"

echo "--- 2. Installing binaries to ${REAL_HOME}/.local ---"

# Install Rust helper and test CLI
cp "${DIR}/bin/airpad-inject" "${BIN_DIR}/"
cp "${DIR}/bin/airpad-test-cli" "${BIN_DIR}/"
chmod +x "${BIN_DIR}/airpad-inject" "${BIN_DIR}/airpad-test-cli"

# Install Desktop Flutter bundle to ~/.local/lib/airpad
cp "${DIR}/airpad" "${LIB_DIR}/"
chmod +x "${LIB_DIR}/airpad"
if [ -d "${DIR}/lib" ]; then
  mkdir -p "${LIB_DIR}/lib"
  cp -r "${DIR}/lib"/* "${LIB_DIR}/lib/"
fi
if [ -d "${DIR}/data" ]; then
  mkdir -p "${LIB_DIR}/data"
  cp -r "${DIR}/data"/* "${LIB_DIR}/data/"
fi

# Create symlink in ~/.local/bin/airpad
ln -sf "${LIB_DIR}/airpad" "${BIN_DIR}/airpad"

# 3. Install desktop launcher
sed "s|Exec=airpad|Exec=${BIN_DIR}/airpad|g" "${DIR}/airpad.desktop" > "${APP_DIR}/airpad.desktop"
chmod +x "${APP_DIR}/airpad.desktop"

# 4. Install systemd user service
cp "${DIR}/systemd/airpad-inject.service" "${SYSTEMD_USER_DIR}/"

# Fix ownership if run under sudo
if [ "$EUID" -eq 0 ] && [ "$REAL_USER" != "root" ]; then
  chown -R "${REAL_USER}:${REAL_USER}" "${LIB_DIR}" "${BIN_DIR}/airpad"* "${APP_DIR}/airpad.desktop" "${SYSTEMD_USER_DIR}/airpad-inject.service"
fi

# 5. Enable and start systemd user service
echo "--- 3. Enabling airpad-inject systemd user service ---"
if [ "$EUID" -eq 0 ]; then
  if [ "$REAL_USER" != "root" ]; then
    sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/${REAL_UID}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${REAL_UID}/bus" systemctl --user daemon-reload 2>/dev/null || true
    sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/${REAL_UID}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${REAL_UID}/bus" systemctl --user enable --now airpad-inject.service 2>/dev/null || true
    echo "✓ Enabled and started airpad-inject.service for ${REAL_USER}."
  fi
else
  systemctl --user daemon-reload
  systemctl --user enable --now airpad-inject.service
  echo "✓ Enabled and started airpad-inject.service."
fi

echo ""
echo "=== AIRPAD installation complete! ==="
echo "Launch with 'airpad' or via your application launcher."
EOF

chmod +x "${STAGE_DIR}/install.sh"

# 6. Create tarball archive
echo "--- Creating distribution tarball ---"
(cd "${DIST_DIR}" && tar -czvf "airpad-linux-x86_64.tar.gz" "airpad-linux-x86_64")

echo "=== Build and packaging complete: ${DIST_DIR}/airpad-linux-x86_64.tar.gz ==="
