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

# Rename flutter executable to airpad in bin/
mv "${STAGE_DIR}/desktop" "${STAGE_DIR}/bin/airpad" 2>/dev/null || true

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
BIN_DIR="${HOME}/.local/bin"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
APP_DIR="${HOME}/.local/share/applications"

echo "=== Installing AIRPAD on Linux ==="

# 1. Install binaries
mkdir -p "${BIN_DIR}"
cp "${DIR}/bin/airpad-inject" "${BIN_DIR}/"
cp "${DIR}/bin/airpad-test-cli" "${BIN_DIR}/"
cp "${DIR}/bin/airpad" "${BIN_DIR}/"
chmod +x "${BIN_DIR}/airpad-inject" "${BIN_DIR}/airpad-test-cli" "${BIN_DIR}/airpad"

# Copy Flutter bundle libs and data if present
if [ -d "${DIR}/lib" ]; then
  mkdir -p "${HOME}/.local/lib/airpad"
  cp -r "${DIR}/lib"/* "${HOME}/.local/lib/airpad/"
fi
if [ -d "${DIR}/data" ]; then
  mkdir -p "${HOME}/.local/share/airpad/data"
  cp -r "${DIR}/data"/* "${HOME}/.local/share/airpad/data/"
fi

# 2. Install desktop launcher
mkdir -p "${APP_DIR}"
cp "${DIR}/airpad.desktop" "${APP_DIR}/"

# 3. Install systemd user service
mkdir -p "${SYSTEMD_USER_DIR}"
cp "${DIR}/systemd/airpad-inject.service" "${SYSTEMD_USER_DIR}/"
systemctl --user daemon-reload
systemctl --user enable --now airpad-inject.service

# 4. Install udev rule for /dev/uinput access
if [ -w /etc/udev/rules.d ]; then
  cp "${DIR}/udev/99-airpad-uinput.rules" /etc/udev/rules.d/
  udevadm control --reload-rules && udevadm trigger
  echo "Udev rule installed to /etc/udev/rules.d/99-airpad-uinput.rules"
else
  echo ""
  echo ">>> NOTE: To grant permissions to /dev/uinput, run:"
  echo "  sudo cp \"${DIR}/udev/99-airpad-uinput.rules\" /etc/udev/rules.d/"
  echo "  sudo udevadm control --reload-rules && sudo udevadm trigger"
  echo "  sudo usermod -aG input \$USER"
  echo ""
fi

echo "=== AIRPAD installation complete! ==="
echo "Launch with 'airpad' or via your application launcher."
EOF

chmod +x "${STAGE_DIR}/install.sh"

# 6. Create tarball archive
echo "--- Creating distribution tarball ---"
(cd "${DIST_DIR}" && tar -czvf "airpad-linux-x86_64.tar.gz" "airpad-linux-x86_64")

echo "=== Build and packaging complete: ${DIST_DIR}/airpad-linux-x86_64.tar.gz ==="
