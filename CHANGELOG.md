# Changelog

All notable changes to the Airpad project will be documented in this file.

## [Unreleased]

### Phase 0 — Foundations
- Initialized repository structure.
- Authored `docs/protocol.md` wire protocol specification.
- Authored `docs/design.md` black-and-white design system specification.
- Created `packages/airpad_core` Dart package with:
  - Design tokens (`design_tokens.dart`).
  - Core event models (`event.dart`) with JSON serialization and validation.
  - Device and discovery models (`device.dart`).
  - Unit tests covering models and tokens.
- Created dev scripts: `scripts/lint.sh`, `scripts/format.sh`, `scripts/test.sh`.
