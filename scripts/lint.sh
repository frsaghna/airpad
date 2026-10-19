#!/usr/bin/env bash
set -e

echo "=== Linting Dart packages ==="
if [ -d "packages/airpad_core" ]; then
  (cd packages/airpad_core && dart analyze)
fi

if [ -f "helper/airpad-inject/Cargo.toml" ]; then
  echo "=== Linting Rust helper ==="
  (cd helper/airpad-inject && cargo clippy -- -D warnings)
fi

echo "=== Lint check passed ==="
