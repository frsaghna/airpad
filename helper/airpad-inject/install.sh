#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

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
systemctl --user daemon-reload
systemctl --user enable --now airpad-inject.service

echo "=== Udev rule setup ==="
if [ -w /etc/udev/rules.d ]; then
  cp udev/99-airpad-uinput.rules /etc/udev/rules.d/
  udevadm control --reload-rules && udevadm trigger
  echo "Udev rule installed to /etc/udev/rules.d/99-airpad-uinput.rules"
else
  echo "To install the udev rule manually, run:"
  echo "  sudo cp \"$SCRIPT_DIR/udev/99-airpad-uinput.rules\" /etc/udev/rules.d/"
  echo "  sudo udevadm control --reload-rules && sudo udevadm trigger"
fi

echo "=== Installation complete! ==="
