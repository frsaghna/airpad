# AIRPAD Design System — Black and White

This document specifies the visual design system and component architecture for **AIRPAD**.
The design across both the Android mobile controller and Linux desktop receiver is **strictly monochrome**.

---

## 1. Principles

1. **Zero Hue:** No accent colors, no green success indicators, no red error messages, no blue links. Color is never used to communicate state or meaning.
2. **High Contrast & Clarity:** Information hierarchy is established through contrast, typography, borders, and solid inversions.
3. **No Fluff:** No gradients, no dropshadows, no background blurs, no decorative illustrations. Every pixel serves utility.
4. **Offline & Self-Contained:** No external font or asset loading over the internet.
5. **Deterministic State:** Every interactive element has clear, high-contrast visual states (idle, hover/pressed, active/selected, disabled).

---

## 2. Color Palette & Tokens

### 2.1 Color Tokens

| Token Name | Hex Code | Purpose in Dark Theme (Default) | Inverted Light Theme |
|---|---|---|---|
| `airBlack` | `#000000` | Canvas background, text on inverted fills | Primary foreground / text, active fills |
| `airWhite` | `#FFFFFF` | Primary text, active fills, primary borders | Canvas background, text on inverted fills |
| `airGray900` | `#111111` | Raised surfaces, card backgrounds | `#EEEEEE` (light card background) |
| `airGray700` | `#2A2A2A` | Structural borders, dividers, subtle frames | `#D0D0D0` (light borders) |
| `airGray500` | `#777777` | Secondary text, captions, disabled borders | `#888888` (secondary text) |
| `airGray100` | `#EDEDED` | Light highlights, high-contrast accents | `#1A1A1A` |

### 2.2 Geometry & Spacing Tokens

- **Base Grid:** `8dp` (Spacing: 4, 8, 12, 16, 24, 32, 48 dp).
- **Border Width:** `1.0dp` uniform across all bordered elements.
- **Corner Radius:** `4.0dp` max (sharp or slightly rounded, uniform across the entire app).
- **Minimum Touch Target:** `48dp x 48dp` on touch screens.

---

## 3. Typography

Fonts are bundled locally with zero runtime network fetching:
- **Body & Headings:** `Inter` (or system clean sans fallback).
- **Fingerprints, Pairing Codes, IPs, Telemetry:** `JetBrains Mono` (or system monospace fallback).

### Type Hierarchy:
- **Display / Pairing Code:** Monospace, 32pt, Bold, letter spacing +2.0.
- **Header 1:** Sans, 20pt, Bold.
- **Header 2:** Sans, 16pt, SemiBold.
- **Section Label:** Monospace, 11pt, Uppercase, letter spacing +1.5, `airGray500`.
- **Body:** Sans, 14pt, Regular, line height 1.4.
- **Body Bold / Button:** Sans, 14pt, SemiBold.
- **Caption / Fingerprint:** Monospace, 12pt, Regular.

---

## 4. State Representation Without Color

Because color cannot be used for status, state is communicated explicitly through:
1. **Inversion:** Selected or connected items use solid white fill with black text.
2. **Borders:** Idle interactive elements have a 1px border.
3. **Fills & Hatches:** Disabled elements use `airGray500` text and border without fill.
4. **Icons & Text:** Errors, warnings, and alerts are accompanied by an explicit text badge (e.g. `[ERROR]`, `[DISCONNECTED]`, `[CONNECTED]`) paired with an icon.

### Status Table:
| Status | Visual Presentation |
|---|---|
| **Connected** | Solid white pill with black text: `[● CONNECTED]` |
| **Advertising / Searching** | 1px white border with subtle pulsing dot: `[○ SCANNING]` |
| **Disconnected / Idle** | 1px `airGray700` border with gray text: `[OFFLINE]` |
| **Error / Denied** | Solid white inverted banner with icon `✕` and explicit error description |
| **Active Button / Key Down** | Solid white background, black foreground |

---

## 5. Touchpad Surface Specifications

- **Container:** Full available area or large bounded card with 1px `airGray700` border.
- **Background:** Solid `airBlack`.
- **Active Finger Indicator:** When a finger touches down, a thin (1.5px) `airWhite` circle of radius `24dp` renders centered under each contact point.
- **Gesture Feedback:**
  - Left click tap: rapid invert flash (40ms) or subtle ring expansion.
  - Right click (two-finger tap): dual ring indicator.
  - Dragging: indicator switches from hollow ring to filled white circle (radius 16dp).

---

## 6. Shared Component Set

Both apps implement and reuse a consistent set of monochrome components:

### 6.1 `AirButton`
- **Primary:** Solid `airWhite` background, `airBlack` bold text.
- **Outline:** Transparent background, `1px airWhite` border, `airWhite` text.
- **Ghost:** Transparent background, no border, `airWhite` text.
- **Disabled:** Transparent background, `1px airGray700` border, `airGray500` text.

### 6.2 `AirCard`
- Background: `airGray900`
- Border: `1px airGray700`
- Padding: `16dp`
- Border Radius: `4dp`

### 6.3 `AirTile`
- Selectable row for devices, settings, or actions.
- Idle: transparent background, `1px airGray700` bottom divider.
- Hover / Selected: inverted solid `airWhite` fill with `airBlack` text and icon.

### 6.4 `AirToggle`
- Monochromatic switch.
- Off: `airBlack` track with `1px airGray500` border, empty dot.
- On: solid `airWhite` track with `airBlack` dot.

### 6.5 `AirCodeBox`
- For displaying the 6-digit pairing code.
- Centered, monospace 32pt bold digits.
- Large spacing between digits, encased in a card with 1px `airWhite` border.

### 6.6 `AirStatusBadge`
- Compact indicator pill.
- Examples: `[CONNECTED]`, `[PAIRED]`, `[PAIRING REQUEST]`.
- Always pairs text with an outline icon or symbol.
