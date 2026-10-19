#!/usr/bin/env bash
set -e

echo "=== Running Dart tests ==="
if [ -d "packages/airpad_core" ]; then
  (cd packages/airpad_core && dart test)
fi

if [ -f "helper/airpad-inject/Cargo.toml" ]; then
  echo "=== Running Rust tests ==="
  (cd helper/airpad-inject && cargo test)
fi

echo "=== All tests passed ==="
