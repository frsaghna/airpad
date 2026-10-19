#!/usr/bin/env bash
set -e

echo "=== Formatting Dart ==="
if [ -d "packages/airpad_core" ]; then
  (cd packages/airpad_core && dart format .)
fi

if [ -f "helper/airpad-inject/Cargo.toml" ]; then
  echo "=== Formatting Rust ==="
  (cd helper/airpad-inject && cargo fmt)
fi

echo "=== Format completed ==="
