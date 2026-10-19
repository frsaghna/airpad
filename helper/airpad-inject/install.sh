#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

BIN_DIR="${REAL_HOME}/.local/bin"
SYSTEMD_USER_DIR="${REAL_HOME}/.config/systemd/user"

echo "=== Building airpad-inject ==="
cd "$SCRIPT_DIR"
cargo build --release

echo "=== Installing binary to ${BIN_DIR} ==="
mkdir -p "$BIN_DIR"
cp target/release/airpad-inject "$BIN_DIR/"
cp target/release/airpad-test-cli "$BIN_DIR/"
chmod +x "$BIN_DIR/airpad-inject" "$BIN_DIR/airpad-test-cli"

echo "=== Installing systemd user unit ==="
mkdir -p "$SYSTEMD_USER_DIR"
cp systemd/airpad-inject.service "$SYSTEMD_USER_DIR/"

if [ "$EUID" -eq 0 ] && [ "$REAL_USER" != "root" ]; then
  chown -R "${REAL_USER}:${REAL_USER}" "${BIN_DIR}/airpad"* "${SYSTEMD_USER_DIR}/airpad-inject.service"
fi

echo "=== Enabling systemd user service ==="
if [ "$EUID" -eq 0 ]; then
  if [ "$REAL_USER" != "root" ]; then
    sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/${REAL_UID}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${REAL_UID}/bus" systemctl --user daemon-reload 2>/dev/null || true
    sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/${REAL_UID}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${REAL_UID}/bus" systemctl --user enable --now airpad-inject.service 2>/dev/null || true
  fi
else
  systemctl --user daemon-reload
  systemctl --user enable --now airpad-inject.service
fi

echo "=== Udev rule setup ==="
if [ "$EUID" -eq 0 ]; then
  cp udev/99-airpad-uinput.rules /etc/udev/rules.d/
  udevadm control --reload-rules && udevadm trigger
  echo "Udev rule installed to /etc/udev/rules.d/99-airpad-uinput.rules"
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
    echo "Udev rule already installed in /etc/udev/rules.d/"
  else
    echo "To install the udev rule manually, run:"
    echo "  sudo cp \"$SCRIPT_DIR/udev/99-airpad-uinput.rules\" /etc/udev/rules.d/"
    echo "  sudo udevadm control --reload-rules && sudo udevadm trigger"
    echo "  sudo usermod -aG input $USER"
  fi
fi

echo "=== Installation complete! ==="
