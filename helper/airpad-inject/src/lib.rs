use evdev::uinput::VirtualDevice;
use evdev::{AttributeSet, EventType, InputEvent, KeyCode, RelativeAxisCode};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::io::{self, Error, ErrorKind};
use std::thread::sleep;
use std::time::{Duration, Instant};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type")]
pub enum ProtocolEvent {
    #[serde(rename = "move")]
    Move { dx: f64, dy: f64 },

    #[serde(rename = "scroll")]
    Scroll { dx: f64, dy: f64 },

    #[serde(rename = "button")]
    Button { button: String, state: String },

    #[serde(rename = "click")]
    Click {
        button: String,
        #[serde(default = "default_click_count")]
        count: u32,
    },

    #[serde(rename = "key")]
    Key {
        code: String,
        state: String,
        #[serde(default)]
        mods: Vec<String>,
    },

    #[serde(rename = "text")]
    Text { value: String },

    #[serde(rename = "media")]
    Media { action: String },

    #[serde(rename = "settings")]
    Settings {
        #[serde(default)]
        sensitivity: Option<f64>,
        #[serde(default)]
        natural_scroll: Option<bool>,
    },
}

fn default_click_count() -> u32 {
    1
}

pub struct VirtualInput {
    device: VirtualDevice,
    pressed_keys: HashSet<KeyCode>,
    press_times: HashMap<KeyCode, Instant>,
}

impl VirtualInput {
    pub fn new() -> io::Result<Self> {
        let mut keys = AttributeSet::<KeyCode>::new();

        // Mouse buttons
        keys.insert(KeyCode::BTN_LEFT);
        keys.insert(KeyCode::BTN_RIGHT);
        keys.insert(KeyCode::BTN_MIDDLE);
        keys.insert(KeyCode::BTN_SIDE);
        keys.insert(KeyCode::BTN_EXTRA);

        // Standard keyboard keys
        let all_keys = [
            KeyCode::KEY_ESC, KeyCode::KEY_1, KeyCode::KEY_2, KeyCode::KEY_3, KeyCode::KEY_4, KeyCode::KEY_5,
            KeyCode::KEY_6, KeyCode::KEY_7, KeyCode::KEY_8, KeyCode::KEY_9, KeyCode::KEY_0, KeyCode::KEY_MINUS,
            KeyCode::KEY_EQUAL, KeyCode::KEY_BACKSPACE, KeyCode::KEY_TAB, KeyCode::KEY_Q, KeyCode::KEY_W,
            KeyCode::KEY_E, KeyCode::KEY_R, KeyCode::KEY_T, KeyCode::KEY_Y, KeyCode::KEY_U, KeyCode::KEY_I,
            KeyCode::KEY_O, KeyCode::KEY_P, KeyCode::KEY_LEFTBRACE, KeyCode::KEY_RIGHTBRACE, KeyCode::KEY_ENTER,
            KeyCode::KEY_LEFTCTRL, KeyCode::KEY_A, KeyCode::KEY_S, KeyCode::KEY_D, KeyCode::KEY_F, KeyCode::KEY_G,
            KeyCode::KEY_H, KeyCode::KEY_J, KeyCode::KEY_K, KeyCode::KEY_L, KeyCode::KEY_SEMICOLON,
            KeyCode::KEY_APOSTROPHE, KeyCode::KEY_GRAVE, KeyCode::KEY_LEFTSHIFT, KeyCode::KEY_BACKSLASH,
            KeyCode::KEY_Z, KeyCode::KEY_X, KeyCode::KEY_C, KeyCode::KEY_V, KeyCode::KEY_B, KeyCode::KEY_N,
            KeyCode::KEY_M, KeyCode::KEY_COMMA, KeyCode::KEY_DOT, KeyCode::KEY_SLASH, KeyCode::KEY_RIGHTSHIFT,
            KeyCode::KEY_KPASTERISK, KeyCode::KEY_LEFTALT, KeyCode::KEY_SPACE, KeyCode::KEY_CAPSLOCK,
            KeyCode::KEY_F1, KeyCode::KEY_F2, KeyCode::KEY_F3, KeyCode::KEY_F4, KeyCode::KEY_F5, KeyCode::KEY_F6,
            KeyCode::KEY_F7, KeyCode::KEY_F8, KeyCode::KEY_F9, KeyCode::KEY_F10, KeyCode::KEY_NUMLOCK,
            KeyCode::KEY_SCROLLLOCK, KeyCode::KEY_KP7, KeyCode::KEY_KP8, KeyCode::KEY_KP9, KeyCode::KEY_KPMINUS,
            KeyCode::KEY_KP4, KeyCode::KEY_KP5, KeyCode::KEY_KP6, KeyCode::KEY_KPPLUS, KeyCode::KEY_KP1,
            KeyCode::KEY_KP2, KeyCode::KEY_KP3, KeyCode::KEY_KP0, KeyCode::KEY_KPDOT, KeyCode::KEY_F11,
            KeyCode::KEY_F12, KeyCode::KEY_KPENTER, KeyCode::KEY_RIGHTCTRL, KeyCode::KEY_KPSLASH,
            KeyCode::KEY_SYSRQ, KeyCode::KEY_RIGHTALT, KeyCode::KEY_HOME, KeyCode::KEY_UP, KeyCode::KEY_PAGEUP,
            KeyCode::KEY_LEFT, KeyCode::KEY_RIGHT, KeyCode::KEY_END, KeyCode::KEY_DOWN, KeyCode::KEY_PAGEDOWN,
            KeyCode::KEY_INSERT, KeyCode::KEY_DELETE, KeyCode::KEY_LEFTMETA, KeyCode::KEY_RIGHTMETA,
            // Media keys
            KeyCode::KEY_PLAYPAUSE, KeyCode::KEY_VOLUMEUP, KeyCode::KEY_VOLUMEDOWN, KeyCode::KEY_MUTE,
            KeyCode::KEY_NEXTSONG, KeyCode::KEY_PREVIOUSSONG, KeyCode::KEY_STOPCD,
        ];

        for &k in &all_keys {
            keys.insert(k);
        }

        let mut rel_axes = AttributeSet::<RelativeAxisCode>::new();
        rel_axes.insert(RelativeAxisCode::REL_X);
        rel_axes.insert(RelativeAxisCode::REL_Y);
        rel_axes.insert(RelativeAxisCode::REL_WHEEL);
        rel_axes.insert(RelativeAxisCode::REL_HWHEEL);

        let device = VirtualDevice::builder()?
            .name("Airpad Virtual Input")
            .with_keys(&keys)?
            .with_relative_axes(&rel_axes)?
            .build()?;

        Ok(Self {
            device,
            pressed_keys: HashSet::new(),
            press_times: HashMap::new(),
        })
    }

    fn cleanup_stale_keys(&mut self) -> io::Result<()> {
        let now = Instant::now();
        let mut stale = Vec::new();

        for (&key, &time) in &self.press_times {
            if is_regular_typing_key(key) && now.duration_since(time) > Duration::from_millis(1500) {
                stale.push(key);
            }
        }

        for key in stale {
            self.pressed_keys.remove(&key);
            self.press_times.remove(&key);
            self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), 0)])?;
        }

        Ok(())
    }

    pub fn handle_event(&mut self, event: &ProtocolEvent) -> io::Result<()> {
        self.cleanup_stale_keys()?;
        match event {
            ProtocolEvent::Move { dx, dy } => {
                let rx = *dx as i32;
                let ry = *dy as i32;
                let mut events = Vec::new();
                if rx != 0 {
                    events.push(InputEvent::new(EventType::RELATIVE.0, RelativeAxisCode::REL_X.0, rx));
                }
                if ry != 0 {
                    events.push(InputEvent::new(EventType::RELATIVE.0, RelativeAxisCode::REL_Y.0, ry));
                }
                if !events.is_empty() {
                    self.device.emit(&events)?;
                }
            }

            ProtocolEvent::Scroll { dx, dy } => {
                let mut events = Vec::new();
                let wx = (*dx / 10.0).round() as i32;
                let wy = (*dy / 10.0).round() as i32;
                let clamped_wx = wx.clamp(-10, 10);
                let clamped_wy = wy.clamp(-10, 10);
                if clamped_wx != 0 {
                    events.push(InputEvent::new(EventType::RELATIVE.0, RelativeAxisCode::REL_HWHEEL.0, clamped_wx));
                }
                if clamped_wy != 0 {
                    events.push(InputEvent::new(EventType::RELATIVE.0, RelativeAxisCode::REL_WHEEL.0, clamped_wy));
                }
                if !events.is_empty() {
                    self.device.emit(&events)?;
                }
            }

            ProtocolEvent::Button { button, state } => {
                let key = match button.to_lowercase().as_str() {
                    "left" => KeyCode::BTN_LEFT,
                    "right" => KeyCode::BTN_RIGHT,
                    "middle" => KeyCode::BTN_MIDDLE,
                    other => {
                        return Err(Error::new(
                            ErrorKind::InvalidInput,
                            format!("Unknown mouse button: {other}"),
                        ))
                    }
                };
                let val = match state.to_lowercase().as_str() {
                    "down" => {
                        self.pressed_keys.insert(key);
                        1
                    }
                    "up" => {
                        self.pressed_keys.remove(&key);
                        0
                    }
                    other => {
                        return Err(Error::new(
                            ErrorKind::InvalidInput,
                            format!("Unknown button state: {other}"),
                        ))
                    }
                };
                self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), val)])?;
            }

            ProtocolEvent::Click { button, count } => {
                let key = match button.to_lowercase().as_str() {
                    "left" => KeyCode::BTN_LEFT,
                    "right" => KeyCode::BTN_RIGHT,
                    "middle" => KeyCode::BTN_MIDDLE,
                    other => {
                        return Err(Error::new(
                            ErrorKind::InvalidInput,
                            format!("Unknown mouse button: {other}"),
                        ))
                    }
                };
                let repeat = (*count).clamp(1, 5);
                for i in 0..repeat {
                    self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), 1)])?;
                    sleep(Duration::from_millis(15));
                    self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), 0)])?;
                    if i + 1 < repeat {
                        sleep(Duration::from_millis(40));
                    }
                }
            }

            ProtocolEvent::Key { code, state, mods } => {
                let key = map_key_code(code).ok_or_else(|| {
                    Error::new(ErrorKind::InvalidInput, format!("Unknown key code: {code}"))
                })?;

                match state.to_lowercase().as_str() {
                    "press" | "click" => {
                        let mut mod_keys = Vec::new();
                        for m in mods {
                            if let Some(m_key) = map_modifier_name(m) {
                                if !self.pressed_keys.contains(&m_key) {
                                    self.pressed_keys.insert(m_key);
                                    self.device.emit(&[InputEvent::new(EventType::KEY.0, m_key.code(), 1)])?;
                                    mod_keys.push(m_key);
                                }
                            }
                        }
                        self.pressed_keys.insert(key);
                        self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), 1)])?;
                        sleep(Duration::from_millis(20));
                        self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), 0)])?;
                        self.pressed_keys.remove(&key);
                        for m_key in mod_keys {
                            self.device.emit(&[InputEvent::new(EventType::KEY.0, m_key.code(), 0)])?;
                            self.pressed_keys.remove(&m_key);
                        }
                    }
                    "down" => {
                        // Apply any modifier keys if not already pressed down
                        for m in mods {
                            if let Some(m_key) = map_modifier_name(m) {
                                if !self.pressed_keys.contains(&m_key) {
                                    self.pressed_keys.insert(m_key);
                                    self.device.emit(&[InputEvent::new(EventType::KEY.0, m_key.code(), 1)])?;
                                }
                            }
                        }
                        self.pressed_keys.insert(key);
                        self.press_times.insert(key, Instant::now());
                        self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), 1)])?;
                    }
                    "up" => {
                        self.pressed_keys.remove(&key);
                        self.press_times.remove(&key);
                        self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), 0)])?;
                        for m in mods {
                            if let Some(m_key) = map_modifier_name(m) {
                                if self.pressed_keys.remove(&m_key) {
                                    self.press_times.remove(&m_key);
                                    self.device.emit(&[InputEvent::new(EventType::KEY.0, m_key.code(), 0)])?;
                                }
                            }
                        }
                    }
                    other => {
                        return Err(Error::new(
                            ErrorKind::InvalidInput,
                            format!("Unknown key state: {other}"),
                        ))
                    }
                }
            }

            ProtocolEvent::Text { value } => {
                for ch in value.chars() {
                    self.type_char(ch)?;
                }
            }

            ProtocolEvent::Media { action } => {
                let key = match action.to_lowercase().as_str() {
                    "play_pause" => KeyCode::KEY_PLAYPAUSE,
                    "volume_up" => KeyCode::KEY_VOLUMEUP,
                    "volume_down" => KeyCode::KEY_VOLUMEDOWN,
                    "volume_mute" => KeyCode::KEY_MUTE,
                    "next_track" => KeyCode::KEY_NEXTSONG,
                    "prev_track" => KeyCode::KEY_PREVIOUSSONG,
                    other => {
                        return Err(Error::new(
                            ErrorKind::InvalidInput,
                            format!("Unknown media action: {other}"),
                        ))
                    }
                };
                self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), 1)])?;
                sleep(Duration::from_millis(15));
                self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), 0)])?;
            }

            ProtocolEvent::Settings { .. } => {
                // Handled / acknowledged silently
            }
        }
        Ok(())
    }

    fn type_char(&mut self, ch: char) -> io::Result<()> {
        if let Some((key, needs_shift)) = map_char_to_key(ch) {
            if needs_shift {
                self.device.emit(&[InputEvent::new(EventType::KEY.0, KeyCode::KEY_LEFTSHIFT.code(), 1)])?;
            }
            self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), 1)])?;
            sleep(Duration::from_millis(10));
            self.device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), 0)])?;
            if needs_shift {
                self.device.emit(&[InputEvent::new(EventType::KEY.0, KeyCode::KEY_LEFTSHIFT.code(), 0)])?;
            }
        } else {
            // Non-ASCII & Unicode fallback strategy: Linux Ctrl+Shift+U <hex> Enter
            self.type_unicode_hex(ch)?;
        }
        Ok(())
    }

    fn type_unicode_hex(&mut self, ch: char) -> io::Result<()> {
        let code_point = ch as u32;
        let hex_str = format!("{:x}", code_point);

        // Press Ctrl+Shift+U
        self.device.emit(&[
            InputEvent::new(EventType::KEY.0, KeyCode::KEY_LEFTCTRL.code(), 1),
            InputEvent::new(EventType::KEY.0, KeyCode::KEY_LEFTSHIFT.code(), 1),
            InputEvent::new(EventType::KEY.0, KeyCode::KEY_U.code(), 1),
        ])?;
        sleep(Duration::from_millis(15));
        self.device.emit(&[
            InputEvent::new(EventType::KEY.0, KeyCode::KEY_U.code(), 0),
            InputEvent::new(EventType::KEY.0, KeyCode::KEY_LEFTSHIFT.code(), 0),
            InputEvent::new(EventType::KEY.0, KeyCode::KEY_LEFTCTRL.code(), 0),
        ])?;
        sleep(Duration::from_millis(15));

        // Type hex digits
        for hex_char in hex_str.chars() {
            if let Some((k, _)) = map_char_to_key(hex_char) {
                self.device.emit(&[InputEvent::new(EventType::KEY.0, k.code(), 1)])?;
                sleep(Duration::from_millis(10));
                self.device.emit(&[InputEvent::new(EventType::KEY.0, k.code(), 0)])?;
            }
        }
        sleep(Duration::from_millis(15));

        // Press Enter to commit unicode sequence
        self.device.emit(&[InputEvent::new(EventType::KEY.0, KeyCode::KEY_ENTER.code(), 1)])?;
        sleep(Duration::from_millis(10));
        self.device.emit(&[InputEvent::new(EventType::KEY.0, KeyCode::KEY_ENTER.code(), 0)])?;
        Ok(())
    }

    /// Releases all currently held keys and buttons.
    /// This is guaranteed to be called on client disconnect or shutdown.
    pub fn release_all(&mut self) -> io::Result<()> {
        if self.pressed_keys.is_empty() {
            return Ok(());
        }

        self.press_times.clear();
        let mut events = Vec::new();
        for key in self.pressed_keys.drain() {
            events.push(InputEvent::new(EventType::KEY.0, key.code(), 0));
        }

        self.device.emit(&events)?;
        Ok(())
    }

    pub fn pressed_count(&self) -> usize {
        self.pressed_keys.len()
    }
}

fn is_regular_typing_key(key: KeyCode) -> bool {
    !matches!(
        key,
        KeyCode::BTN_LEFT
            | KeyCode::BTN_RIGHT
            | KeyCode::BTN_MIDDLE
            | KeyCode::BTN_SIDE
            | KeyCode::BTN_EXTRA
            | KeyCode::KEY_LEFTCTRL
            | KeyCode::KEY_RIGHTCTRL
            | KeyCode::KEY_LEFTALT
            | KeyCode::KEY_RIGHTALT
            | KeyCode::KEY_LEFTSHIFT
            | KeyCode::KEY_RIGHTSHIFT
            | KeyCode::KEY_LEFTMETA
            | KeyCode::KEY_RIGHTMETA
    )
}

impl Drop for VirtualInput {
    fn drop(&mut self) {
        let _ = self.release_all();
    }
}

pub fn map_modifier_name(name: &str) -> Option<KeyCode> {
    match name.to_lowercase().as_str() {
        "ctrl" | "control" => Some(KeyCode::KEY_LEFTCTRL),
        "alt" => Some(KeyCode::KEY_LEFTALT),
        "shift" => Some(KeyCode::KEY_LEFTSHIFT),
        "meta" | "super" => Some(KeyCode::KEY_LEFTMETA),
        _ => None,
    }
}

pub fn map_key_code(code: &str) -> Option<KeyCode> {
    match code {
        "KeyA" | "a" | "A" => Some(KeyCode::KEY_A),
        "KeyB" | "b" | "B" => Some(KeyCode::KEY_B),
        "KeyC" | "c" | "C" => Some(KeyCode::KEY_C),
        "KeyD" | "d" | "D" => Some(KeyCode::KEY_D),
        "KeyE" | "e" | "E" => Some(KeyCode::KEY_E),
        "KeyF" | "f" | "F" => Some(KeyCode::KEY_F),
        "KeyG" | "g" | "G" => Some(KeyCode::KEY_G),
        "KeyH" | "h" | "H" => Some(KeyCode::KEY_H),
        "KeyI" | "i" | "I" => Some(KeyCode::KEY_I),
        "KeyJ" | "j" | "J" => Some(KeyCode::KEY_J),
        "KeyK" | "k" | "K" => Some(KeyCode::KEY_K),
        "KeyL" | "l" | "L" => Some(KeyCode::KEY_L),
        "KeyM" | "m" | "M" => Some(KeyCode::KEY_M),
        "KeyN" | "n" | "N" => Some(KeyCode::KEY_N),
        "KeyO" | "o" | "O" => Some(KeyCode::KEY_O),
        "KeyP" | "p" | "P" => Some(KeyCode::KEY_P),
        "KeyQ" | "q" | "Q" => Some(KeyCode::KEY_Q),
        "KeyR" | "r" | "R" => Some(KeyCode::KEY_R),
        "KeyS" | "s" | "S" => Some(KeyCode::KEY_S),
        "KeyT" | "t" | "T" => Some(KeyCode::KEY_T),
        "KeyU" | "u" | "U" => Some(KeyCode::KEY_U),
        "KeyV" | "v" | "V" => Some(KeyCode::KEY_V),
        "KeyW" | "w" | "W" => Some(KeyCode::KEY_W),
        "KeyX" | "x" | "X" => Some(KeyCode::KEY_X),
        "KeyY" | "y" | "Y" => Some(KeyCode::KEY_Y),
        "KeyZ" | "z" | "Z" => Some(KeyCode::KEY_Z),

        "Digit1" | "1" => Some(KeyCode::KEY_1),
        "Digit2" | "2" => Some(KeyCode::KEY_2),
        "Digit3" | "3" => Some(KeyCode::KEY_3),
        "Digit4" | "4" => Some(KeyCode::KEY_4),
        "Digit5" | "5" => Some(KeyCode::KEY_5),
        "Digit6" | "6" => Some(KeyCode::KEY_6),
        "Digit7" | "7" => Some(KeyCode::KEY_7),
        "Digit8" | "8" => Some(KeyCode::KEY_8),
        "Digit9" | "9" => Some(KeyCode::KEY_9),
        "Digit0" | "0" => Some(KeyCode::KEY_0),

        "Enter" => Some(KeyCode::KEY_ENTER),
        "Escape" => Some(KeyCode::KEY_ESC),
        "Backspace" => Some(KeyCode::KEY_BACKSPACE),
        "Tab" => Some(KeyCode::KEY_TAB),
        "Space" | " " => Some(KeyCode::KEY_SPACE),
        "Minus" | "-" => Some(KeyCode::KEY_MINUS),
        "Equal" | "=" => Some(KeyCode::KEY_EQUAL),
        "BracketLeft" | "[" => Some(KeyCode::KEY_LEFTBRACE),
        "BracketRight" | "]" => Some(KeyCode::KEY_RIGHTBRACE),
        "Backslash" | "\\" => Some(KeyCode::KEY_BACKSLASH),
        "Semicolon" | ";" => Some(KeyCode::KEY_SEMICOLON),
        "Quote" | "'" => Some(KeyCode::KEY_APOSTROPHE),
        "Backquote" | "`" => Some(KeyCode::KEY_GRAVE),
        "Comma" | "," => Some(KeyCode::KEY_COMMA),
        "Period" | "." => Some(KeyCode::KEY_DOT),
        "Slash" | "/" => Some(KeyCode::KEY_SLASH),

        "ControlLeft" | "ctrl" | "Ctrl" => Some(KeyCode::KEY_LEFTCTRL),
        "ControlRight" => Some(KeyCode::KEY_RIGHTCTRL),
        "ShiftLeft" | "shift" | "Shift" => Some(KeyCode::KEY_LEFTSHIFT),
        "ShiftRight" => Some(KeyCode::KEY_RIGHTSHIFT),
        "AltLeft" | "alt" | "Alt" => Some(KeyCode::KEY_LEFTALT),
        "AltRight" => Some(KeyCode::KEY_RIGHTALT),
        "MetaLeft" | "meta" | "Meta" | "Super" => Some(KeyCode::KEY_LEFTMETA),
        "MetaRight" => Some(KeyCode::KEY_RIGHTMETA),

        "ArrowUp" | "Up" => Some(KeyCode::KEY_UP),
        "ArrowDown" | "Down" => Some(KeyCode::KEY_DOWN),
        "ArrowLeft" | "Left" => Some(KeyCode::KEY_LEFT),
        "ArrowRight" | "Right" => Some(KeyCode::KEY_RIGHT),

        "Home" => Some(KeyCode::KEY_HOME),
        "End" => Some(KeyCode::KEY_END),
        "PageUp" => Some(KeyCode::KEY_PAGEUP),
        "PageDown" => Some(KeyCode::KEY_PAGEDOWN),
        "Insert" => Some(KeyCode::KEY_INSERT),
        "Delete" => Some(KeyCode::KEY_DELETE),

        "F1" => Some(KeyCode::KEY_F1),
        "F2" => Some(KeyCode::KEY_F2),
        "F3" => Some(KeyCode::KEY_F3),
        "F4" => Some(KeyCode::KEY_F4),
        "F5" => Some(KeyCode::KEY_F5),
        "F6" => Some(KeyCode::KEY_F6),
        "F7" => Some(KeyCode::KEY_F7),
        "F8" => Some(KeyCode::KEY_F8),
        "F9" => Some(KeyCode::KEY_F9),
        "F10" => Some(KeyCode::KEY_F10),
        "F11" => Some(KeyCode::KEY_F11),
        "F12" => Some(KeyCode::KEY_F12),

        _ => None,
    }
}

pub fn map_char_to_key(ch: char) -> Option<(KeyCode, bool)> {
    match ch {
        'a'..='z' => {
            let code = format!("Key{}", ch.to_ascii_uppercase());
            map_key_code(&code).map(|k| (k, false))
        }
        'A'..='Z' => {
            let code = format!("Key{ch}");
            map_key_code(&code).map(|k| (k, true))
        }
        '0'..='9' => {
            let code = format!("Digit{ch}");
            map_key_code(&code).map(|k| (k, false))
        }
        ' ' => Some((KeyCode::KEY_SPACE, false)),
        '\n' => Some((KeyCode::KEY_ENTER, false)),
        '\t' => Some((KeyCode::KEY_TAB, false)),
        '-' => Some((KeyCode::KEY_MINUS, false)),
        '_' => Some((KeyCode::KEY_MINUS, true)),
        '=' => Some((KeyCode::KEY_EQUAL, false)),
        '+' => Some((KeyCode::KEY_EQUAL, true)),
        '[' => Some((KeyCode::KEY_LEFTBRACE, false)),
        '{' => Some((KeyCode::KEY_LEFTBRACE, true)),
        ']' => Some((KeyCode::KEY_RIGHTBRACE, false)),
        '}' => Some((KeyCode::KEY_RIGHTBRACE, true)),
        ';' => Some((KeyCode::KEY_SEMICOLON, false)),
        ':' => Some((KeyCode::KEY_SEMICOLON, true)),
        '\'' => Some((KeyCode::KEY_APOSTROPHE, false)),
        '"' => Some((KeyCode::KEY_APOSTROPHE, true)),
        ',' => Some((KeyCode::KEY_COMMA, false)),
        '<' => Some((KeyCode::KEY_COMMA, true)),
        '.' => Some((KeyCode::KEY_DOT, false)),
        '>' => Some((KeyCode::KEY_DOT, true)),
        '/' => Some((KeyCode::KEY_SLASH, false)),
        '?' => Some((KeyCode::KEY_SLASH, true)),
        '\\' => Some((KeyCode::KEY_BACKSLASH, false)),
        '|' => Some((KeyCode::KEY_BACKSLASH, true)),
        '`' => Some((KeyCode::KEY_GRAVE, false)),
        '~' => Some((KeyCode::KEY_GRAVE, true)),
        '!' => Some((KeyCode::KEY_1, true)),
        '@' => Some((KeyCode::KEY_2, true)),
        '#' => Some((KeyCode::KEY_3, true)),
        '$' => Some((KeyCode::KEY_4, true)),
        '%' => Some((KeyCode::KEY_5, true)),
        '^' => Some((KeyCode::KEY_6, true)),
        '&' => Some((KeyCode::KEY_7, true)),
        '*' => Some((KeyCode::KEY_8, true)),
        '(' => Some((KeyCode::KEY_9, true)),
        ')' => Some((KeyCode::KEY_0, true)),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_move_event() {
        let json_str = r#"{"type":"move","dx":10.5,"dy":-5.0}"#;
        let event: ProtocolEvent = serde_json::from_str(json_str).unwrap();
        assert_eq!(event, ProtocolEvent::Move { dx: 10.5, dy: -5.0 });
    }

    #[test]
    fn test_parse_button_event() {
        let json_str = r#"{"type":"button","button":"left","state":"down"}"#;
        let event: ProtocolEvent = serde_json::from_str(json_str).unwrap();
        assert_eq!(
            event,
            ProtocolEvent::Button {
                button: "left".into(),
                state: "down".into()
            }
        );
    }

    #[test]
    fn test_map_key_codes() {
        assert_eq!(map_key_code("KeyA"), Some(KeyCode::KEY_A));
        assert_eq!(map_key_code("Enter"), Some(KeyCode::KEY_ENTER));
        assert_eq!(map_key_code("ControlLeft"), Some(KeyCode::KEY_LEFTCTRL));
        assert_eq!(map_key_code("UnknownNonExistent"), None);
    }

    #[test]
    fn test_map_char_to_key() {
        let (k, shift) = map_char_to_key('a').unwrap();
        assert_eq!(k, KeyCode::KEY_A);
        assert!(!shift);

        let (k, shift) = map_char_to_key('A').unwrap();
        assert_eq!(k, KeyCode::KEY_A);
        assert!(shift);

        let (k, shift) = map_char_to_key('!').unwrap();
        assert_eq!(k, KeyCode::KEY_1);
        assert!(shift);
    }

    #[test]
    fn test_map_modifier_name() {
        assert_eq!(map_modifier_name("ctrl"), Some(KeyCode::KEY_LEFTCTRL));
        assert_eq!(map_modifier_name("alt"), Some(KeyCode::KEY_LEFTALT));
        assert_eq!(map_modifier_name("shift"), Some(KeyCode::KEY_LEFTSHIFT));
        assert_eq!(map_modifier_name("meta"), Some(KeyCode::KEY_LEFTMETA));
        assert_eq!(map_modifier_name("unknown"), None);
    }

    #[test]
    fn test_parse_key_event() {
        let json_str = r#"{"type":"key","code":"Tab","state":"press","mods":["super","shift"]}"#;
        let event: ProtocolEvent = serde_json::from_str(json_str).unwrap();
        assert_eq!(
            event,
            ProtocolEvent::Key {
                code: "Tab".into(),
                state: "press".into(),
                mods: vec!["super".into(), "shift".into()]
            }
        );
    }
}
