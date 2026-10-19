#!/usr/bin/env bash
set -e

echo "=== Running Dart & Flutter tests ==="
if [ -d "packages/airpad_core" ]; then
  (cd packages/airpad_core && dart test)
fi
if [ -d "packages/airpad_ui" ]; then
  (cd packages/airpad_ui && flutter test)
fi
if [ -d "apps/desktop" ]; then
  (cd apps/desktop && flutter test)
fi
if [ -d "apps/mobile" ]; then
  (cd apps/mobile && flutter test)
fi

if [ -f "helper/airpad-inject/Cargo.toml" ]; then
  echo "=== Running Rust tests ==="
  (cd helper/airpad-inject && cargo test)
fi

echo "=== All tests passed ==="
